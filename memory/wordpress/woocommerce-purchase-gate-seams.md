---
name: WooCommerce purchase gate — the seams that actually cover it
description: Requiring login before purchase needs four hooks, not one — the three buy affordances are UI, and add_to_cart_validation is the only real rule
type: reference
---

"Users must register before they can buy" is a rule, not a button swap. Anonymous purchase can start from more places than the obvious one, so gating only the visible button leaves a hand-typed URL wide open.

**The rule (enforcement):**
- `woocommerce_add_to_cart_validation` — returns `false` for anonymous. This is the only thing that actually stops a purchase. Exempt `is_admin()` and `WP_CLI`, which build carts on a customer's behalf with no front-end user.

**The affordances (UI, so the rule is never hit by a normal user):**
- `woocommerce_single_product_summary` — `remove_action( ..., 'woocommerce_template_single_add_to_cart', 30 )` on the `wp` hook, then add your own at 30. Removing the outer callback takes the whole form, including the per-product-type `woocommerce_{type}_add_to_cart` inner action.
- `woocommerce_loop_add_to_cart_link` — shop/category/upsell/related loops.
- Whatever the LMS or page builder renders — e.g. LearnDash's `learndash_payment_closed_button`, see [[learndash-closed-course-button-url]].

**The direct-URL path:** intercept `$_REQUEST['add-to-cart']` on `wp_loaded` at priority < 20 — `WC_Form_Handler::add_to_cart_action()` is registered at exactly 20 — and redirect to login. Beating it there gives a clean redirect instead of a validation error notice. Bail on `wp_doing_ajax()` / `REST_REQUEST` so a background request never eats a redirect. The AJAX add-to-cart endpoint posts `product_id`, **not** `add-to-cart`, so it slips past this intercept entirely and is caught by the validation filter — which is why both are needed.

**Returning the user after login.** `WC_Form_Handler::process_login()` / `process_registration()` both prefer `$_POST['redirect']`, then fall back to `wc_get_raw_referer()`, then the my-account page. Read `$_POST['redirect']` **directly** in the `woocommerce_login_redirect` / `woocommerce_registration_redirect` filters rather than trusting the filtered value — the referer fallback is the login page itself, so honoring the filtered value blindly loops the user. Pass the destination into the form via `woocommerce_login_form( array( 'redirect' => $url ) )`; a hand-rolled registration form needs its own hidden `redirect` input. Registration auto-logs-in, so the redirect fires there too.

Always run the incoming `?redirect_to=` through a same-host check before emitting or honoring it — otherwise the gate is an open redirect. `add_query_arg()` does **not** encode values, so `rawurlencode()` the URL yourself.

**How to apply:** any WooCommerce site that must force registration before purchase. Verify end-to-end over HTTP (anon → gate → login → back → add to cart → cart), not just by eyeballing the button; a `wp eval` check runs as WP-CLI and takes the exemption branch.
