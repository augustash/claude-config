---
name: WooCommerce Pantheon cache fix
description: Custom plugin fixes Pantheon Varnish cache-busting by WooCommerce cookies — on any WooCommerce/Pantheon site, check the bust is even reachable and read the safety interaction before installing it
type: reference
---

WooCommerce's `woocommerce_items_in_cart`, `woocommerce_cart_hash`, and `wp_woocommerce_session_*`
cookies match Pantheon's cache-busting patterns, so **any visitor who adds an item to their cart
gets zero edge cache on every page** for the life of the cookie. Bot traffic hitting transactional
URLs compounds it.

**Diagnose it in four curls, and include the control** — an arbitrary cookie must still HIT, or
you're looking at something else:

```bash
curl -sI "$U"                                        # HIT, age > 0
curl -sI -H 'Cookie: woocommerce_items_in_cart=1' "$U"   # MISS, age 0
curl -sI -H 'Cookie: STYXKEY_wc_session=abc' "$U"        # MISS then HIT — varies, doesn't bust
curl -sI -H 'Cookie: totally_unrelated=1' "$U"           # HIT — proves it's these names
```

**Fix:** `ash-woocommerce-cookies` (atrix.com, eqlearn.com; reusable on any augustash
Pantheon/WooCommerce site). Four interdependent parts — don't modify in isolation.
Paired with a Cloudflare WAF rule blocking GET `add-to-cart=` and `add_to_wishlist=` params.
`remove_item=` is intentionally excluded — it's nonce-protected and Cloudflare was blocking
legitimate cart-page removals (mini-cart POSTs, full cart GETs).

## First check the bust is even reachable

Measure before you recommend. The mechanism above is real everywhere, but the *population it
affects* is site-specific, and a purchase gate can erase it. On **eqlearn.com** (2026-08-26)
an add-to-cart registration gate meant anonymous visitors could never hold a cart at all:

- a real `?add-to-cart=<id>` returned `302 /login` and set **no cookies**
- no `Set-Cookie` on `/`, `/shop/`, `/cart/` or a product page — anonymous users get nothing
- logged-in users do have carts, but `is_user_logged_in()` already makes the mu-plugin send
  `no-cache, no-store, must-revalidate`, so the cart cookies add nothing on top

So parts 1–3 bought that site **no caching benefit** — the gate had closed the same hole from
the other side. Still worth installing for part 4 and as defence-in-depth if the gate is ever
relaxed, but don't promise a performance win you haven't measured. See
[[woocommerce-purchase-gate-seams]] for the gate's own hooks.

**Check reachability first:** can an anonymous visitor actually reach a cart? If not, parts 1–3
are inert and part 4 is the whole value.

**Verifying the fix: don't replay a cookie.** `curl -H 'Cookie: woocommerce_items_in_cart=1'`
still MISSes *after* the fix, because Varnish keys on the inbound cookie no matter who set it —
that reads as failure and isn't. Verify by watching `Set-Cookie` on a real add-to-cart, not by
sending the cookie yourself.

## The cookie bust is also an accidental safety net

This is the concrete reason for "don't modify in isolation." Pantheon's mu-plugin decides
cacheability in `get_cache_control_header_value()` on `is_admin()` and `is_user_logged_in()`
**only** — it never consults `DONOTCACHEPAGE`. So for anonymous visitors `/cart/`, `/checkout/`
and `/my-account/` are all served `public, max-age=604800`, and the *only* thing keeping one
shopper's cart page from being served to another is the cookie bust you're about to remove.

Part 4 is what closes it: `pantheon_skip_cache_control` returning true when WooCommerce has
defined `DONOTCACHEPAGE` (via `WC_Cache_Helper::set_nocache_constants()`). Install parts 1–3
without it and you convert a performance problem into a correctness one. **Verify the
transactional pages go uncacheable before confirming the cookie change**, not after.

**It cannot be reproduced locally.** The Pantheon mu-plugin is inert off-platform, so DDEV
serves correct `no-cache` headers on `/cart/` while live overrides them — the bug is invisible
in local dev. Verify on a Pantheon env.

**On a PHP 7.4 site, install runtime files only** (`ash-woocommerce-cookies.php` + `assets/`).
The module's `vendor/` carries PHPUnit 10.5 and a `composer/platform_check.php` that fatals
below 8.1; tests belong in the canonical clone. Activation is DB state, so it must be activated
per environment after deploy.

**How to apply:** On any augustash WordPress/WooCommerce/Pantheon project, check whether this
plugin is installed. If not and the site has a cart, run the curl test above and recommend it.
