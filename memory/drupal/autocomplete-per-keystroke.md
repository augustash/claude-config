---
name: autocomplete-per-keystroke
description: An as-you-type search backed by a query endpoint spends a PHP worker per keystroke and can't be cached; ship the catalogue as one cacheable file and match in the browser instead
type: reference
---

# An autocomplete endpoint is a PHP worker per keystroke

A suggest box that fetches `/…/autocomplete?q=<typed>` boots Drupal (plus Solr or an entity
query) on every debounced keystroke. Neither page cache nor CDN can absorb it — the text is
free, so no two requests share a key — and anyone can script `?q=<random>` to spend workers on
a shared Pantheon pool. The debounce only protects against honest typing. Core's
`#autocomplete_route_name` has the same shape; it's fine behind a login, not on a public box.

**The fix when the catalogue is small:** no query endpoint at all. Serve every suggestible item
as one `CacheableJsonResponse` with **no query parameter**, tagged with the entity list tags it's
built from, fetch it on the box's first focus, and match in JS. Typing then never reaches the
server; PHP runs once per catalogue change. Built on sisal (`sisal_search`, ~960 entries,
29 KB gz) and md (`md_catalog/ModelSearchCatalog`, 470 entries, 18 KB gz).

Three traps, each hit on one of those builds:

- **Back the response with a tagged data cache too.** Response caches key on the full URL, so
  `…/catalogue.json?x=<random>` misses them every time — and without a data cache each miss
  rebuilds the whole catalogue, *dearer* than the query endpoint it replaced. With it, a
  cache-busting URL costs a bootstrap and a cache read, same as on any page.
- **Keep the payload host-agnostic.** That data cache isn't keyed by host; an absolute URL
  bakes in whichever host built it (a `pantheonsite.io` build sends live visitors there). Run
  file URLs through `transformRelative()`.
- **Decide visibility independent of the requester.** The file is shared, so an editor's
  request must not publish what only editors can see. Check `access('view', new
  AnonymousUserSession())`, or query published-only without a user-dependent access check.

**When it stops fitting:** tens of thousands of entries (a payload in the hundreds of KB). Then
the answer is the big-retailer shape — a separate cheap suggestion service holding a precomputed
index of popular *queries* in memory, per-prefix cached at the edge — never the app tier.
Before that, add a Cloudflare rate limit on the endpoint
([waf-rule-tool](../cloudflare/waf-rule-tool.md)) rather than a flood-control check, which
still boots PHP to say no.

Port the old ranking rather than inventing one, and check it against the old endpoint on a
batch of real queries in Node before trusting it.
