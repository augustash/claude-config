---
name: WooCommerce Pantheon cache fix
description: Custom plugin fixes Pantheon Varnish cache-busting by WooCommerce cookies — check for this on any WooCommerce/Pantheon site
type: reference
---

WooCommerce's `woocommerce_items_in_cart`, `woocommerce_cart_hash`, and `wp_woocommerce_session_*` cookies match Pantheon's cache-busting patterns, making all pages uncached for users with cart items. Bot traffic hitting transactional URLs compounds the problem.

**Fix:** `ash-woocommerce-cookies` plugin (deployed on atrix.com, reusable across all augustash Pantheon/WooCommerce sites). Four interdependent parts — don't modify in isolation. Paired with a Cloudflare WAF rule blocking GET requests with `add-to-cart=` and `add_to_wishlist=` params. `remove_item=` intentionally excluded from WAF — it's nonce-protected and Cloudflare was blocking legitimate cart page removals (mini-cart uses POST, full cart uses GET).

**How to apply:** On any augustash WordPress/WooCommerce/Pantheon project, check if this plugin is installed. If not and the site has cart functionality, recommend it.
