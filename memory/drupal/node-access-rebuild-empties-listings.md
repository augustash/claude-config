---
name: A node access rebuild permanently caches every listing empty
description: node_access_rebuild() truncates {node_access} first, so listings render empty and Internal Page Cache stores them PERMANENTLY — grants are a cache context, never a tag, so nothing ever evicts them
type: reference
---

Symptom: listing pages across a site show their **empty message** — "There are no
content items yet", "no results" — while the content plainly exists and is
published. It reads as content loss, a broken import, or a search index that
never finished. It is none of those. The nodes are fine; the *page* is a
permanently-cached empty render.

## Mechanism

`node_access_rebuild()` (`core/modules/node/node.module`) truncates before it
refills:

```php
$access_control_handler->deleteGrants();   // TRUNCATE {node_access}
// ...then re-acquires grants one node at a time, oldest site = longest window
```

Node grants are only consulted at all if **some module implements
`hook_node_grants()`** — `node_unpublished`, `group`, `domain_access`,
`workbench_access`, `content_access`. When one does, every published node depends
on a `realm = all`, `gid = 0` row that `NodeAccessControlHandler::acquireGrants()`
writes as the default. While the table is empty those rows are gone, so every
node listing query returns **zero rows** for anyone without *bypass node access* —
which is every anonymous visitor.

Then the caching half, which is what makes it stick:

- Internal Page Cache stores with `CACHE_PERMANENT`. `system.performance
  cache.page.max_age` sets the **external** `max-age` header only; it is not the
  internal lifetime. Verify with `x-drupal-cache-max-age: -1 (Permanent)`.
- Grants reach the cache as a **context** — `user.node_grants:view` — and *never*
  as a tag. Page Cache ignores contexts entirely (it keys on URL for anonymous),
  and there is no tag on the response that means "grants changed".
- `node_access_rebuild()` invalidates **nothing**. Neither does
  `NodeGrantDatabaseStorage::write()` or `::delete()`.
- An empty listing carries no `node:N` tags *precisely because it rendered no
  nodes* — so even the usual accidental rescue is absent.

Net: the empty page outlives the rebuild indefinitely. It clears only by luck —
someone saves a node that happens to share a `*_list` tag with the listing, or a
full `drush cr`.

## Diagnosing

```sh
drush ev 'var_dump(Drupal::moduleHandler()->hasImplementations("node_grants"));'
drush sqlq "SELECT realm, gid, COUNT(*) FROM node_access GROUP BY realm, gid;"
drush ev 'var_dump(Drupal::state()->get("node.node_access_needs_rebuild"));'
```

`node.node_access_needs_rebuild` set to `1` is the standing hazard: it is what
puts the "rebuild permissions" link on the status report, and clicking that link
is what opens the window. Core sets the flag on any install/uninstall of a
`hook_node_grants` module — so a `config_split` that toggles modules on deploy
re-arms it every time.

Reproduce it in one minute locally, which is the only way to be sure caching (not
content) is the fault:

```sh
drush cr && curl -s $URL | grep -c <item-class>   # content present
drush sqlq "TRUNCATE node_access;"
curl -s $URL                                      # empty message
drush ev 'node_access_rebuild();'                 # grants fully restored
curl -s $URL                                      # STILL empty  ← the bug
```

## Fix

`drupal_cache_protection_node_access` (see
[[drupal_cache_protection]]) brackets the window: suppresses page/dynamic-page
caching plus emits `no-store` while grants are being rebuilt, then invalidates
`rendered` once on completion. It deliberately does **not** purge at the start —
stale-but-correct beats empty, and core's `DatabaseCacheTagsChecksum` dedupes
repeated invalidations of a tag within one process, so an opening purge silently
cancels the closing one for any rebuild that runs start-to-finish under drush.

It also runs a cron check for the case its decorator can't see: `{node_access}`
emptied by a hand-run `TRUNCATE`, or by a **database import carrying a table
that was empty when dumped** — the realistic one, since a Pantheon env clone
can move it. Empty grants + published nodes + a `hook_node_grants` module is an
impossible state, so it logs, opens the guard and flags the rebuild. Recovery
still needs `node_access_rebuild()` run by hand; an unattended rebuild on a
large site is its own hazard.

Without that module the operational fix after any rebuild is a full `drush cr`
(and an edge purge on Pantheon — `rendered` reaches it via
`pantheon_advanced_page_cache` surrogate keys).
