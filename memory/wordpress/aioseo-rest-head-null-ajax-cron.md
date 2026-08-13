---
name: AIOSEO nulls its Head object in AJAX and cron
description: Product webhooks fail with "Call to a member function output() on null" and it reads as a broken scheduler; AIOSEO skips building Head in AJAX/cron while its REST controller calls it unconditionally
type: reference
---

**Symptom.** ActionScheduler shows `woocommerce_deliver_webhook_async` actions marked
**failed**, with the message:

```
action failed via Async Request: Call to a member function output() on null
action failed via WP Cron: Call to a member function output() on null
```

The queue itself looks healthy — pending stays low and current, because a fatal fails fast
rather than backing anything up. So the integration silently stops receiving events while
every dashboard says the scheduler is fine. On atr this ran for months and presented to the
client as "the scheduler is broken".

**It is not the scheduler.** ActionScheduler is accurately reporting a job that cannot
complete.

## Mechanism

AIOSEO only builds its Head object outside AJAX and cron — `app/AIOSEO.php`:

```php
if ( ! wp_doing_ajax() && ! wp_doing_cron() ) {
    $this->head = $this->pro ? new Pro\Main\Head() : new Common\Main\Head();
}
```

Its REST controller then calls that object unconditionally —
`app/Common/RestApi/Controllers/Base.php`:

```php
aioseo()->head->output();
```

WooCommerce builds a webhook payload by **dispatching an internal REST request**
(`WC_Webhook::get_wp_api_payload()` → `RestApiUtil::get_endpoint_data()`), and ActionScheduler
runs deliveries via an async admin-ajax request or via WP Cron — precisely the two contexts
AIOSEO skips. The two facts collide and PHP fatals.

The failure messages naming `Async Request` and `WP Cron` are the two branches of that guard,
which is the tell.

Only **product** endpoints route through AIOSEO. Order payloads build fine, so failures
cluster on `product.updated` — fired by the stock decrement on every order, which is what
makes the volume look alarming.

## Reproducing it

WP-CLI is neither AJAX nor cron, so the obvious repro *passes* and sends you looking elsewhere.
Force the context:

```bash
wp --exec="define('DOING_CRON', true);" eval-file repro.php
# in repro.php:
#   wp_set_current_user( <the webhook's user_id> );   // else REST 401s before reaching AIOSEO
#   wc_get_container()->get( \Automattic\WooCommerce\Utilities\RestApiUtil::class )
#       ->get_endpoint_data( "/wc/v3/products/{$id}" );
```

Orders return a payload; products throw.

## Fix

Filter `aioseo_rest_api_disable` — AIOSEO's own seam, checked at the top of `getHead()` before
the null object is touched, so returning `true` yields an empty string rather than a fatal.
The SEO head block is meaningless inside a webhook payload and nothing reads it.

Guard on **the object**, not on `wp_doing_ajax()/wp_doing_cron()`:

```php
add_filter( 'aioseo_rest_api_disable', function ( $disable, $object = null ) {
    if ( ! function_exists( 'aioseo' ) ) {
        return $disable;
    }
    $aioseo = aioseo();
    if ( ! property_exists( $aioseo, 'head' ) || null === $aioseo->head ) {
        return true;
    }
    return $disable;
}, 10, 2 );
```

Testing the object tracks the actual precondition, stays correct if AIOSEO changes *when* it
builds Head, and disarms itself once they fix it upstream. Ship it as an mu-plugin so a plugin
update cannot revert it.

Verify both directions: payloads build under forced cron, **and** a normal front-end page still
emits the AIOSEO block, `og:` tags, canonical and JSON-LD.

**Present in 4.9.10** (Lite and Pro). Delete this memory once AIOSEO null-checks that call.

## Two things that look like the cause and are not

- **Lite and Pro both active.** Unsupported and worth fixing, but not this: whichever loads
  second hits `if ( function_exists( 'aioseo' ) )` and returns early, so Lite is inert. The
  fatal is in Pro's own path. Deactivating Lite changes nothing here — its real risk is that
  load order alone decides which wins, so a reordered `active_plugins` silently disables Pro.
- **A failing queue.** Check `pending`, not `failed` totals. Healthy pending with a rising
  `failed` count is this bug's signature, and a healthy-looking queue is what hides it.

Related: [[woocommerce-pantheon-cache]], [[wp-cli-silent-on-pantheon]].
