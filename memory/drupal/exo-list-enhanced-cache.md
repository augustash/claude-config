---
name: Exo list "Enhanced Cache" keys on almost nothing
description: exo_list_builder's cache_status setting stores the built list PERMANENTLY in the default bin under a hand-built cid — no user, no node grants, no language — so the first render is served to everyone unless the results are identical for all of them
type: reference
---

The **Enhanced Cache** checkbox on an eXo entity list (`settings.cache_status`,
admin form field "Enhanced Cache") is not the render cache. It is a raw
`\Drupal::cache()->set()` in `ExoListBuilderBase::buildList()`, storing the built
render array at `Cache::PERMANENT` in the **default bin, shared by every user**,
under a cid the class assembles by hand:

```php
$cid = ['exo_list_builder', $entity_list->id()];   // + non-empty options
                                                   // + resolved filter values
```

That is the whole key. It carries **no user, no `user.node_grants:view`, no
language** — every dimension the render cache would have varied on via
`getCacheContexts()` is absent, because this path bypasses the render cache
entirely. The setting's own description states the precondition and nothing
enforces it:

> "This should only be used when the results of the list are the same for all users."

## Before enabling it

Ask what the results vary by, then confirm the cid covers it:

- **Access** — is any row visible to one visitor and not another? A list locked to
  `status = 1` is usually safe; one that surfaces unpublished content to editors,
  or sits on a site with `hook_node_grants()` where grants differ by role, is not.
- **Language** — more than one content language means two audiences, one entry.
- **Anything read at build time that isn't an option or a filter** — session
  state, the current user, a service. Options come from the query string only.

If any answer is yes, leave it off. The failure is silent: whoever renders first
wins, and everyone else is served their copy until a tag invalidation.

## Symptom when the key is short a dimension

Every page showing the list renders **identical results**, and which results
depends on which page was hit first after a cache clear. Reproduce in three
requests — clear caches, request the page you expect to be empty, then request a
populated one:

```sh
drush cr
curl -s "$SITE/category-with-no-items"  | grep -c <item-class>   # 0
curl -s "$SITE/category-with-many"      | grep -c <item-class>   # also 0  ← bug
```

Reverse the order and every page shows the first category's items instead. That
ordering dependence is the signature; a genuinely empty list is empty in both
directions.

## Route-derived filters

A filter using `default_from_url` (`ContentProperty::getDefaultValue()` reads
`\Drupal::routeMatch()`) makes results depend on the **route** — a taxonomy term
page filtering itself. Both the cid and `getCacheContexts()` used to ignore that,
so every category page shared one entry and one render cache variant. Fixed in
`jacerider/exo` Sep 2026: `route` is now declared as a context when any filter
uses `default_from_url`, and resolved filter values are folded into the cid.

**A site pinned below that must not enable Enhanced Cache on a route-filtered
list** — and the render-cache half of the bug is live there regardless of the
setting. Check with:

```sh
drush ev 'var_dump(method_exists(
  Drupal::entityTypeManager()->getStorage("exo_entity_list")->load("<list_id>")->getHandler(),
  "hasRouteDependentFilters"));'
```

## Is it worth it?

Usually not on a mostly-anonymous site. The pages are already served by
`page_cache` and the CDN, so Enhanced Cache only earns its keep on a page-cache
miss — and it buys that by taking on a permanent, shared, hand-keyed entry that
no cache context protects. Bound the max-age on the pages instead
([[node-access-rebuild-empties-listings]] covers why a permanent listing entry is
the dangerous part), and reach for this only on a list that is genuinely
expensive and genuinely identical for everyone.
