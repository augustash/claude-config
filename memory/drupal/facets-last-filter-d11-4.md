---
name: Drupal 11.4 breaks removing the last active facet
description: On core 11.4+, a facet's deactivate link for the only active filter points back at the current URL, so unticking it reloads the page unchanged. Core changed Url::createFromRequest(); facets assumed the old behaviour.
type: reference
---

# Drupal 11.4 breaks removing the last active facet

**Symptom.** With exactly one facet filter active, unticking it (checkbox, link, summary chip,
or any custom UI that clicks through to the facet link) reloads the same page with the filter
still applied. With two or more active, each one removes fine. Any other query parameter on the
URL (`?sort=`, `?x=1`) also makes it work, which is the tell. No error anywhere.

**Cause.** Core 11.4 changed `Url::createFromRequest()` to copy the request's query into the URL
it returns. facets' `QueryString::buildUrls()` starts every result link from that URL and only
calls `setOption('query', …)` when the new params are not exactly `[f => []]`. Removing the
last filter is exactly that case, so the link keeps the current `f[]`. This is not a cache: a
render-cache clear doesn't change it. Logging `$requestUrl->getOptions()` inside `buildUrls()`
shows the `query` already populated.

**Fix.** Always set the query, even when empty. Upstream:
[facets #3609745](https://www.drupal.org/project/facets/issues/3609745), MR !390, RTBC against
**2.0.x** (unreleased as of 2026-10-26). It does **not** apply to 3.0.x as-is: one context line
differs (3.0.x has an extra `// @todo ajax review` comment above the `WRAPPER_FORMAT` unset), so
rebase it locally. The 3.0.x follow-up is
[#3627601](https://www.drupal.org/project/facets/issues/3627601). Sisal carries the rebased
patch as `patches/3609745-facets-remove-last-facet-3.0.x.patch` (facets 3.0.7).

Delete this memory once a facets release on each branch you use contains the fix.
