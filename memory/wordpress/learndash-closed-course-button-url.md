---
name: LearnDash closed-course button URL is stored absolute
description: LearnDash "closed" courses bake an absolute buy URL into postmeta, so the Take This Course button points at production from every other environment — fix at render, not in the DB
type: reference
---

A LearnDash course set to `course_price_type = closed` gets its buy button from a **per-course absolute URL stored in postmeta**, not from anything computed at runtime:

```
_sfwd-courses => [ 'sfwd-courses_custom_button_url' => 'http://livedomain.com/cart/?add-to-cart=2795', ... ]
```

`learndash_payment_buttons()` (`includes/ld-misc-functions.php`) only prepends `home_url()` when the stored value is **relative** — anything starting `http://`, `https://`, or `/` is emitted verbatim. So whoever configured the courses in production pinned every environment's buy button to the production domain. Presents as "add to cart always goes to the live site locally", and the trail is non-obvious: the rendered HTML gives no hint the URL came from postmeta.

**Fix at render time, via the `learndash_payment_closed_button` filter** (`$button, $payment_params` where params carry `custom_button_url` + `post`). Do **not** search-replace the database — the next production pull overwrites it. Normalize **scheme and host**, not just host: these values are typically stale `http://` even on production, costing a redirect hop on every buy click.

Scope the rewrite so a course deliberately linking to an external enrollment page isn't clobbered — an `add-to-cart=` query arg carries a local post ID and so can only mean this site.

**How to apply:** On any LearnDash + WooCommerce site where buy buttons point off-environment, check `sfwd-courses_custom_button_url` in postmeta before hunting through code. Same filter is the natural seam for gating purchases (e.g. swapping the button for a login prompt) — see [[woocommerce-purchase-gate-seams]].
