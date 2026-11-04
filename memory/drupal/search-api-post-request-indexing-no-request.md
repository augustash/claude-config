---
name: search_api's post-request indexing dies without a request
description: An item saved with index-on-save (or registerIndexingOperation) stays pending until cron; the log shows RequestHelper::isCleanUrl() given null from ImageStyle. The indexing runs after the request has left the stack.
type: reference
---

# search_api's post-request indexing dies without a request

**Symptom.** An item is saved and should index straight away — the index has
`index_directly: true`, or code calls
`search_api.post_request_indexing->registerIndexingOperation()` — but it stays
`status = 1` in `search_api_item` until cron. Nothing in `watchdog` under
`search_api`. The PHP log has, once per attempt:

```
TypeError: Drupal\Core\Routing\RequestHelper::isCleanUrl(): Argument #1 ($request)
must be of type Symfony\Component\HttpFoundation\Request, null given,
called in core/modules/image/src/Entity/ImageStyle.php on line 246
```

**Cause.** `PostRequestIndexing` is a `needs_destruction` service: it runs in
`DrupalKernel::terminate()`, after `HttpKernel::handle()` has already popped the
request off the request stack. Indexing anything that builds an image style URL
— an image field in the index, a processor computing a thumbnail, a rendered
item — calls `ImageStyle::buildUrl()`, which asks `RequestHelper::isCleanUrl()`
about the current request, gets `NULL`, and throws a `TypeError`. It isn't a
`SearchApiException`, so search_api's own catch doesn't log it; the item is
never marked indexed and waits for cron. Same trap for any work you defer with
`drupal_register_shutdown_function()` that renders or generates URLs.

Seen on sisal (2026-11-04): a Featured flag meant to reorder lists at once only
did so after cron; the same shutdown-time rebuild of a catalogue that built
thumbnail URLs failed identically.

**Fix.** Don't rely on the post-request service for items with image URLs. Capture
the request when you schedule the work and push it back for its duration:

```php
$request = \Drupal::request();
drupal_register_shutdown_function(function () use ($request) {
  $stack = \Drupal::requestStack();
  $pushed = $request && !$stack->getCurrentRequest();
  if ($pushed) {
    $stack->push($request);
  }
  try {
    $index = \Drupal\search_api\Entity\Index::load('global');
    $index->indexSpecificItems($index->loadItemsMultiple([$item_id]));
  }
  finally {
    if ($pushed) {
      $stack->pop();
    }
  }
});
```

Push the **original** request, not a fresh `Request::create()`: a synthetic one has
no session, and the next thing to touch it dies on `SessionNotFoundException`.

**Testing it.** `drush ev` saves never run destructable services, so a drush save
proves nothing either way. Test through a real web request and read
`search_api_item.status` after it.
