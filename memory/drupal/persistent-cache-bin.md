---
name: Cache bin that survives drush cr
description: Two patterns for a custom cache bin that a full cache rebuild (drush cr / drupal_flush_all_caches) does NOT wipe — for warm stores you don't want to cold-start on every deploy. Untagged bin (you own the freshness) vs decorator backend (rides real content cache tags).
type: reference
---

`drush cr` / `drupal_flush_all_caches()` iterates **`Cache::getBins()`** — every
service tagged **`cache.bin`** — and calls `deleteAll()` on each. So any normal
cache bin is wiped on every rebuild/deploy. When you're keeping a *warm store*
(pre-rendered pages, primed data) that's expensive to rebuild and shouldn't
cold-start on each deploy, you want it to survive. Two patterns, chosen by **who
owns the entry's freshness**:

**1. Untagged bin — when YOU own freshness (cron re-prime / a dedicated tag).**
Define the bin service via `cache_factory:get` but **omit the `cache.bin` tag**.
Not being in `Cache::getBins()`, it's invisible to every blanket clear. Simplest.
- **Caveat:** an untagged bin does **not** reliably participate in Drupal's
  automatic content-tag invalidation (the DB-checksum path can work, but it's
  env-fragile — kernel tests catch it going stale-blind). Only use this when the
  bin's freshness is *yours*: cron overwrites the entry wholesale each cycle, or
  you invalidate a **dedicated, hijacked tag** you control — not the content's
  real tags.
- Reference: `msp` → `web/modules/custom/msp_service_flight` (`cache.flights`,
  the flights-board survivor bin; cron is sole owner).

**2. Decorator backend — when the bin RIDES real content cache tags.**
Keep the bin **tagged `cache.bin`** (so all tag machinery works normally and
entries self-evict when their content's tags invalidate), but wrap the backend
and **no-op the blanket ops** `deleteAll()` / `invalidateAll()` that a rebuild
fires. Targeted ops (`get`/`set`/`delete`/`invalidate`) delegate, so per-tag
content-change staleness is fully intact — you only stop the global wipe.
- Wire a tiny `CacheFactoryInterface` that wraps `@cache.backend.database` and
  returns your decorator; reference it from settings.php:
  `$settings['cache']['bins']['<bin>'] = 'cache.backend.<x>_persistent';`
- Reference: `mymspconnect` → `web/modules/custom/gtranslate_subdirectory`
  (`src/Cache/PersistentBackend.php` + `PersistentBackendFactory.php`; the
  translation store rides the origin page's real cache tags).

**Both patterns:** also pin to a **durable** backend (DB, not Redis) in
settings.php if the data must survive Redis LRU-eviction / Pantheon container
recycles — and put the pin **outside** the `PANTHEON_ENVIRONMENT`/redis block if
you want it in every environment (local included). A `hook_requirements` runtime
check that asserts the bin resolves to the expected backend catches a silently
mis-wired deploy.

**Decision rule:** freshness driven by Drupal content tags → **decorator** (stay
tagged). Freshness you own via cron / a dedicated tag → **untagged** (simpler).
