---
name: BigPipe is not viable on Pantheon
description: Pantheon's Varnish edge cache is incompatible with BigPipe's chunked-streaming responses, so BigPipe is off the table for augustash projects on Pantheon — which closes the lazy_builder fix path for max-age 0 problems
type: reference
---

BigPipe streams HTML in chunks, replacing `#lazy_builder` placeholders as they finish rendering. Pantheon's Global CDN / Varnish edge cache does not handle the streamed/chunked response correctly — responses either fail to cache, get truncated, or bypass the edge entirely. Pantheon's own guidance is to leave BigPipe off, and most augustash production sites are on Pantheon.

**Why this matters for cache debugging.** When a placed block bubbles `max-age: 0` (typically a block that renders a form via `formBuilder->getForm()` in `build()`), the standard Drupal advice is "wrap it in a `#lazy_builder` placeholder so the page caches and the form renders lazily." That advice **does not apply on Pantheon**:

- BigPipe is the mechanism that makes `#lazy_builder` actually deferred. Without BigPipe, placeholders fall back to the standard render pipeline and render inline — same max-age 0 still bubbles to the page. See [[caching]] ("Lazy builders without BigPipe are useless").
- BigPipe can't be turned on because Pantheon's edge breaks under it.
- Therefore on Pantheon, lazy_builder is not a remediation for max-age 0 — it's a code-organization pattern only.

**The remaining options for uncacheable forms/blocks on Pantheon:**

1. **AJAX placeholder.** Render an empty container in the block; load the form via a JS fetch to a controller endpoint. The page caches; the form loads after. The endpoint itself returns max-age 0, which is fine — it's a JSON/HTML fragment, not a page response.
2. **Move the form off the global block layout.** If the form only really needs to exist on one route (e.g. a subscribe form that could live on a dedicated `/subscribe` page linked from the footer), removing the block placement removes the cache hit on all the *other* pages it currently poisons.
3. **Accept uncacheable for that route only.** If a form genuinely belongs on a single route and that route's traffic is low, scoping the block visibility tightly is cheaper than building the AJAX path.

**How to apply.** When debugging max-age 0 on an augustash site, confirm the host first (`grep PANTHEON_SITE .ddev/config.yaml` — see [[ddev-drupal-pantheon-site-var]]). On Pantheon, skip the "enable BigPipe and set lazy: true" path entirely — even if it works in dev, it will misbehave at the edge in prod. Reach for AJAX placeholders or visibility tightening from the start.

**Webform module specifics.** Webform's `lazy: true` block setting uses `#lazy_builder` under the hood, so the same trap applies: on Pantheon, `lazy: true` does not actually defer the form, and the webform block still bubbles max-age 0. Use Webform's `webform_share` / iframe embed, or an AJAX-loaded fragment, instead.
