---
name: Drupal caching pitfalls and debugging
description: Reusable knowledge for debugging Drupal page cache issues — max-age, session poisoning, lazy builders, Exo components
type: reference
---

## Debugging max-age: 0

When `x-drupal-cache-max-age: 0` appears on pages that should be cached:

- **Check placed blocks:** Any block with `getCacheMaxAge() === 0` placed in a global region will bubble up and kill cache on every page. Fix: remove from block layout, render directly in the template where it's actually needed via `drupal_block()`.
- **Check views:** Look for `cache_metadata: max-age: 0` in view config YMLs. Common culprit: `webform_submission_bulk_form` or other admin bulk ops fields accidentally left in frontend views.
- **Check contrib modules:** Search for `page_cache_kill_switch->trigger()` calls.
- **Inspect headers:** `x-drupal-cache-tags` header shows which entities/views are rendering on a page. Sort them: `curl -sI URL | grep cache-tags | tr ' ' '\n' | sort`

## Behind a CDN, x-drupal-cache describes the origin fetch, not your request

`x-drupal-cache` is an ordinary response header, so the CDN **stores and replays it**
along with the body. On a Fastly/Varnish HIT you are reading what Drupal said when
the edge last went to origin — possibly minutes ago — not what happened just now.

So repeated requests returning `x-drupal-cache: MISS` do **not** mean page_cache is
failing to store. Read `age` and `x-cache` first; they are the only headers the edge
rewrites per request:

```
req 1/2/3:  x-drupal-cache: MISS   age: 74   x-cache: MISS, HIT
```

Identical `age` and `last-modified` across consecutive requests is the tell: one
origin fetch, replayed. To ask Drupal's page cache anything, you must miss the edge —
add a unique query arg (`?cb=$RANDOM`), which also makes it a fresh render.

This sharpens, rather than contradicts, the "watch the second hit" advice in
[[bigpipe-pantheon]]: `x-drupal-cache` HIT is still good news, but a MISS beside an
`x-cache` HIT is no news at all.

## Session poisoning kills CDN cache

Any module that starts a PHP session for anonymous users will poison CDN/Varnish cache. The `SESS*` cookie causes `Vary: Cookie` to miss on every request. If anonymous page load times spike, check for modules that call `$this->sessionManager->start()` or set session data for anonymous users. Fix: use localStorage or AJAX instead of server-side sessions for anonymous tracking.

## Lazy builders without BigPipe are useless

Without BigPipe enabled, `#lazy_builder` provides no caching or deferral benefit — content renders inline in the standard pipeline. It's only a code organization pattern (enforces scalar args, static callable). Don't use lazy builders expecting performance gains unless BigPipe is installed and enabled. For volatile/churning cache tags on non-BigPipe sites, use AJAX placeholders instead.

**On Pantheon this is permanent.** Pantheon's edge cache is incompatible with BigPipe's chunked streaming, so BigPipe can't be enabled in production — see [[bigpipe-pantheon]]. Treat `#lazy_builder` as a no-op on every augustash Pantheon site. But: before reaching for AJAX placeholders, sanity-check whether the problem is actually user-impacting. Anonymous page_cache + Pantheon Varnish ignore bubbled max-age 0 and cache based on the outgoing `cache-control` header — most mostly-anonymous augustash sites are cached fine despite scary `x-drupal-cache-max-age: 0` headers. The miss only matters for authenticated traffic or cache-context-sensitive variants. Diagnose via `x-drupal-cache` and `x-cache` HIT/MISS on warm prod requests, not via `x-drupal-cache-max-age`.

## Exo Alchemist component cache

Components with `cache: false` in their YAML definition will trigger `page_cache_kill_switch` for anonymous users, killing page cache on any page that renders the component. Audit component definitions (`{theme}/components/{name}/{name}.yml`) if cache issues appear on specific pages.

## Cache tag invalidation

- `*_list` entity tags (e.g., `recently_read_list`, `node_list`) invalidate on ANY entity create/update/delete of that type — avoid these on high-traffic pages
- Check `cachetags` table: `SELECT tag, invalidations FROM cachetags WHERE tag = 'some_tag'`
- `search_api_list:global` only invalidates when items are actually indexed, not on every cron run

## Redis compress_length default is too low

The boilerplate `$settings['redis_compress_length'] = 100` (lifted from Pantheon's Redis docs and propagated by copy-paste across augustash sites) gzips every cache entry over 100 bytes — which is essentially everything Drupal caches: config, render arrays, plugin defs, views data, theme registry, search_api fields. Every read and write pays gzip CPU.

The cost is most visible during cold-cache rebuilds after a Pantheon container shuffle: workers spend seconds in `gzuncompress() → CacheBase::expandEntry()` while populating Redis from scratch, and with Pantheon's small FPM pools a dogpile of cold-rebuild workers stalls the whole site. Confirmed on MSP 2026-05-21 via php-slow.log — a 5.5s slow request was caught with its top frame in `gzuncompress`.

Raise to 4096. Compression only kicks in for entries large enough that the size savings outweigh the decompression CPU; smaller entries skip it entirely.

```php
$settings['redis_compress_length'] = 4096;
```

**Audit other sites** — anything ≤ 1024 is too low for a typical Drupal site:

```bash
grep -rn "redis_compress_length" ~/Projects/*/web/sites/default/settings.php
```
