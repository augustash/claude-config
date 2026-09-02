---
name: A variation save leaves every product listing cached stale
description: ProductVariation::getCacheTagsToInvalidate() adds the parent's commerce_product:ID tag but never the product *list* tags, so any listing built from variation data serves a stale render to anonymous users only
metadata:
  type: reference
---

Symptom: a product is published and visibly correct, but it is **missing from a
listing page for logged-out visitors only**. An editor checks while logged in,
sees it fine, and reports "works for me" — which reads as a permissions problem,
a publishing-workflow problem, or the editor mis-saving something. It is none of
those. Logged-in users bypass Internal Page Cache entirely; the listing is a
stale cached render and the product is fine.

The tell is that the client says "it's showing up now" while a cookie-less
request still shows the old page. **Verify anonymously with curl, never by
looking in a browser you are logged into.**

## Mechanism

`ProductVariation::getCacheTagsToInvalidate()`
(`commerce/modules/product/src/Entity/ProductVariation.php`) adds exactly one
thing beyond the variation's own tag:

```php
return Cache::mergeTags($tags, [
  'commerce_product:' . $this->getProductId(),
]);
```

That is the parent's **individual** tag, not `commerce_product_list` /
`commerce_product_list:<bundle>`. So saving a variation refreshes the product's
own canonical page and nothing else. Any listing whose *content* depends on
variation data — a date, a location, a price, or simply whether a purchasable
variation exists at all — keeps serving its cached render.

Nothing else rescues it. Internal Page Cache stores `CACHE_PERMANENT`, so the
entry does not age out; the external `max-age` only governs the edge, which
re-fetches and gets the same stale page back. It clears only by luck — someone
saves an unrelated product of that bundle and happens to invalidate the shared
list tag, or a full `drush cr`. Same shape as
[[node-access-rebuild-empties-listings]]: a permanently-cached empty listing that
no tag will ever evict.

The usual accidental rescue is absent for the same reason as there — a listing
that rendered *no* rows carries no `commerce_product:N` tags to be hit. That
asymmetry is the whole bug: a *populated* listing is rescued by the product tag
on every variation save, so only the empty-state render gets stranded.

**Scope claim honestly.** On KOW the stale page was real and the missing list tag
was real, but the trigger that first emptied the listing was never pinned down —
variation status, event date and capacity were each tested and ruled out. Treat
this memory as "closes a genuine staleness gap", not "explains every empty
listing"; the fix is worth shipping either way, and saying so is cheaper than
defending a root cause that does not hold.

## Diagnosing

Compare the canonical URL against a forced-fresh render. Both must be
**cookie-less**:

```sh
curl -s "$URL"            | grep -c 'empty message text'   # cached
curl -s "$URL?cb=$RANDOM" | grep -c 'empty message text'   # fresh render
```

Different answers = stale cache, not access or data. `x-drupal-cache: HIT` vs
`MISS` on the same two confirms which layer.

To prove *which* tag the page carries without debug headers (they are off in
prod), invalidate one candidate tag and re-probe the canonical URL with a header
that is in `Vary` — on Pantheon `X-Consumer-ID` works. That bypasses the edge
while keeping the same Internal Page Cache key, which is otherwise hard to reach:

```sh
terminus drush $SITE.live -- php:eval \
  "\Drupal\Core\Cache\Cache::invalidateTags(['commerce_product_list:class']);"
curl -s -H "X-Consumer-ID: probe$RANDOM" "$URL"   # MISS ⇒ that tag was on the page
```

**Two traps that produce confident wrong answers.** Both cost a full round trip
on KOW 2026-09-02:

*Do not measure invalidation in the `{cachetags}` table on Pantheon.* Redis is
the checksum backend there (`Drupal\redis\Cache\RedisCacheTagsChecksum`), so the
DB table is vestigial and its counters sit frozen while invalidation works fine —
a false negative that reads exactly like a hook that never fired. Ask the service
that actually holds the number, in two separate processes so the per-request
static cache doesn't lie:

```sh
drush php:eval "print \Drupal::service('cache_tags.invalidator.checksum')
  ->getCurrentChecksum(['commerce_product_list:class']);"   # save between calls
```

Confirm the hook is even wired before blaming the tag —
`function_exists()` only proves the file loaded, not that the implementation was
discovered:

```sh
drush php:eval "\Drupal::moduleHandler()->invokeAllWith(
  'commerce_product_variation_update', function (\$cb, string \$m) { print \$m; });"
```

*Do not regression-test by priming a page that renders the product.* A listing
showing the item carries `commerce_product:ID`, which Commerce **already**
invalidates on a variation save — so the page goes MISS with or without the fix
and the test proves nothing. The bug only exists for a listing cached while it
rendered *nothing*, which is the state that carries no product tags. Either
reproduce that empty state, or skip the page entirely and assert on the tag
checksum above.

## Fix

Invalidate the parent's list tags on every variation write. Three hooks and a
helper in the site's commerce module:

```php
function MODULE_commerce_product_variation_update(ProductVariationInterface $variation) {
  MODULE_invalidate_product_list_cache($variation);
}
// ...same for _insert and _delete.

function MODULE_invalidate_product_list_cache(ProductVariationInterface $variation) {
  $product = $variation->getProduct();
  if (!$product instanceof ProductInterface) {
    return;
  }
  Cache::invalidateTags([
    'commerce_product_list',
    'commerce_product_list:' . $product->bundle(),
  ]);
}
```

`getProduct()` returns NULL when the parent is being deleted in the same
operation — guard, don't assume.

**Check the churn before shipping it**, because this trades staleness for
invalidation on a catalog that may be sync-driven ([[internal-package-distribution]]
sites often run `jacerider/sync`). One query decides whether the broad
`commerce_product_list` tag is affordable or whether to scope to the bundle only:

```sh
drush sqlq "SELECT p.type, COUNT(*) FROM commerce_product_variation_field_data vfd
  JOIN commerce_product__variations pv ON pv.variations_target_id = vfd.variation_id
  JOIN commerce_product p ON p.product_id = pv.entity_id
  WHERE vfd.changed > UNIX_TIMESTAMP(NOW() - INTERVAL 7 DAY) GROUP BY p.type;"
```

On KOW (2026-09-02) that returned a single row — one save in seven days,
site-wide — so both tags were safe. A catalog syncing prices nightly would want
the bundle-scoped tag alone.

## Applies beyond eXo lists

Found on an `exo_list_builder` list, whose `EntityList::getCacheTags()` emits
`commerce_product_list:<bundle>` — note it only adds the *unqualified*
`commerce_product_list` when the bundle id equals the entity type id, which is
never true in practice. But the gap is Commerce's, not eXo's: a Views listing of
products showing variation fields has exactly the same hole.
