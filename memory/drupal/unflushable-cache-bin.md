---
name: Unflushable cache bin (survives drush cr by skipping the cache.bin tag)
description: A cache bin defined WITHOUT the `cache.bin` service tag is invisible to drupal_flush_all_caches()/`drush cr` (it's absent from Cache::getBins(), the list the flush iterates) yet still inherits the default backend (Redis on Pantheon) via the factory. The way to keep a load-bearing warm artifact alive across cache clears and deploys. Serve it with a StackMiddleware ahead of page_cache.
type: reference
---

**The problem.** You have a warm artifact that MUST NOT be wiped by a cache clear — e.g. an off-path-primed full-page entry that stampedes when cold (see [[page-cache-cron-reprime]]). If it lives in a normal bin (`cache.page`, `cache.render`, …), every `drush cr` / deploy `drupal_flush_all_caches()` deletes it, re-opening the cold window. There is **no per-cid exemption** and no "protect this entry" flag — the flush calls `deleteAll()` on whole bins.

**The mechanism that decides what gets flushed.** `drupal_flush_all_caches()` clears exactly the bins returned by `Cache::getBins()`, and that list is built (via `ListCacheBinsPass`) from services tagged **`cache.bin`**. Two things are independent and people conflate them:

- **Backend (Redis vs DB)** — set by the cache *factory* + `$settings['cache']['default']` (= `cache.backend.redis` on Pantheon). A bin pulled through `cache_factory:get` inherits that default **regardless of tags**.
- **Flush participation** — set *only* by the `cache.bin` tag.

So the fix is one line of YAML: **define the bin service without the `cache.bin` tag.** It still lands in Redis (factory default), but it's not in `Cache::getBins()`, so no global clear can `deleteAll()` it.

```yaml
# Survivor bin: factory-built (→ default backend, Redis on Pantheon) but NOT
# tagged cache.bin, so drupal_flush_all_caches()/`drush cr` can't see it to clear it.
cache.flights:
  class: Drupal\Core\Cache\CacheBackendInterface
  factory: ['@cache_factory', 'get']
  arguments: [flights]
```

(Alternative: a custom backend decorator whose `deleteAll()`/`invalidateAll()` are no-ops. Works, but it's more code and a "cache you can't clear" surprise; untagging is simpler and the same outcome. Reach for the decorator only if you need the bin to *also* appear in tooling but ignore the global flush specifically.)

**Serving it.** `page_cache` only reads `cache.page`, so a custom bin needs its own reader: a `StackMiddleware` registered ahead of page_cache. Tag it `http_middleware` with **priority > 200** (page_cache is 200) and **< 300** (reverse_proxy is 300, so the request scheme/host are already resolved). Gate it the same way page_cache does by reusing `@page_cache_request_policy` (`check($request) !== RequestPolicyInterface::DENY` → anonymous + cacheable method). On a hit return the stored `Response`; on a miss delegate to the next kernel. Keep the cache-id derivation in ONE shared service that both the writer (cron prime) and this reader use, or they silently drift and the reader looks under a key the writer never wrote.

**No update hook for the table.** Cache-bin tables aren't provisioned by update hooks — `DatabaseBackend::ensureBinExists()` lazily creates `cache_<bin>` on first access, and a Redis bin has no table at all. The service definition is the whole install; the deploy's container rebuild registers it. (Core ships no schema/update hook for `cache_render` etc. either.)

**Deploy survival (Pantheon).** An untagged **Redis** bin survives both `drush cr` *and* a deploy: Pantheon bounces the app container and clears caches at the *Drupal* level (key deletion by bin prefix), which the untagged bin ignores — and Redis itself persists across the deploy. So the warm entry rides through deploys sitting in Redis. Residual (not Drupal's to control): a raw `FLUSHALL` or LRU eviction under memory pressure can still drop it — but a hot, every-cycle-rewritten key is the last thing LRU sheds, and any non-deploy miss is soft-caught by the edge + the next cron prime. "Survives every Drupal-level clear" is usually the actual requirement.

**Deliberately unclearable is a feature.** For a load-bearing protection mechanism, the *inability* to clear it via normal tooling is the point: clearing requires knowing the bin name and either `\Drupal::cache('<bin>')->deleteAll()` or `redis-cli` — a high enough bar that someone who doesn't know how should be going through someone who does. Don't add a convenience drush command.

**Migrating an existing entry off a normal bin** (e.g. `cache.page` → the survivor bin) in a one-time `hook_update_N`: the cid scheme doesn't change, so enumerate the same cids, and for each — copy `cache.page[cid]` → `cache.<bin>[cid]` and **delete the orphan** (else page_cache can still serve it stale on a survivor-miss), falling back to a fresh render where the deploy already cleared `cache.page`. Reusing the bytes is the reliable, env-agnostic path; the render fallback depends on a working render path, so if your prime renders off-path via a loopback curl (which only connects on live — see [[page-cache-cron-reprime]]), **gate the fallback to live** or a non-live deploy burns a ~5s timeout per variant warming nothing. Runs once, after the container rebuild; cron owns the bin thereafter.

**Reference implementation:** MSP flights board — `cache.flights` bin + `FlightsBoardCache` (shared cid/policy) + `FlightsBoardCacheMiddleware` + `hook_update_8002` in `web/modules/custom/msp_service_flight`. Tests: `FlightsBoardCacheSurvivalTest` (absent from `Cache::getBins()`, survives the deleteAll sweep), `FlightsBoardCacheMiddlewareTest` (serves/bypasses/delegates + write-id == read-id), `FlightReprimeTest::testMigrateCopiesPresentRecordsAndRendersTheRest`.

Related: [[page-cache-cron-reprime]] (the off-path prime this protects), [[caching]], [[pantheon-quicksilver-cache-warmer]].
