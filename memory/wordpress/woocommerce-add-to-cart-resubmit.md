---
name: WooCommerce Back button re-adds to cart
description: A product page's Add to Cart leaves a form POST in browser history, so Back or refresh re-sends it and quantities double. The fix is a redirect-after-add mu-plugin, and the access log proves the cause.
metadata:
  type: reference
---

**Symptom.** A customer reports quantities going to 2 "on their own", or a removed item coming
back. They never mention doing anything twice, and nothing reproduces with one add plus a
cart edit. Caching gets blamed. It isn't caching.

**Cause.** WooCommerce's non-AJAX add to cart (`WC_Form_Handler::add_to_cart_action`) only
redirects when "Redirect to the cart page after successful addition" is on. Otherwise the page
the shopper lands on *is* the POST response, and it stays in history as one. Back onto it,
or refresh, re-sends the add:

- Firefox shows "Document Expired, Try Again", and Chrome shows "Confirm Form Resubmission".
  Shoppers read both as "the site glitched" and click through without seeing it as a second
  add.
- In the 2026-11-24 atrix case, iOS Safari re-POSTed two pages in reverse visit order 8s
  apart, and the customer described no prompt at all.

**Which sites have it.** Product pages that submit the form normally. That's the default for
`single_add_to_cart_button`; Flatsome's `product_ajax_add_to_cart` is off unless someone turns
it on. Archive buttons are usually AJAX (`woocommerce_enable_ajax_add_to_cart`), so they never
double. That's why it feels random: it only happens from product pages. Non-AJAX
`?add-to-cart=ID` links have the same flaw with no prompt at all, since a GET re-runs silently.

**Fix.** Drop in
[templates/wordpress/woocommerce-add-to-cart-redirect.php](../../templates/wordpress/woocommerce-add-to-cart-redirect.php)
as an mu-plugin. It hooks `woocommerce_add_to_cart_redirect` to redirect back to the same URL
with `add-to-cart`/`quantity` stripped. The history entry becomes a normal page, and the
"added to your cart" notice survives because it's held in the session.

- **No visible change.** Same page, same notice. Works with JS off.
- **Leaves alone:** error adds (WooCommerce doesn't redirect when notices hold errors),
  `wp_doing_ajax()`, the cart-redirect setting, and Flatsome Buy Now (its filter runs at 99
  and wins).
- **Don't** "fix" it by making archive buttons non-AJAX for consistency. That swaps a prompted
  re-send for a silent one and leaves the product page broken.

**Prove it from the access log** before telling the client
([log-audit](../../skills/log-audit/SKILL.md)). Look for repeat `POST /product/<slug>/` from one
client IP, each with the product page as referer and no query string. Re-sends land seconds
apart, in reverse visit order, with no product-page GET in between (those come from the edge
cache). A crafted URL is ruled out when no request or referer carries `quantity` or
`add-to-cart`. Matching the POST count to the cart total rules out a typed quantity, which
isn't logged.

**A second complaint that comes with it: "I couldn't fix it in the cart."** Flatsome's
mini-cart has no quantity input (`header_cart_qty` is off by default), so shoppers remove and
re-add, and the next Back re-sends the add again. Switching the header to "Go to cart page"
(`header_cart_style=link`) removes the mini-cart entirely. Then give the add its own feedback,
as atrix did: red loading buttons and a header-bag flash in the theme.
