---
name: Short edge TTL vs tag-purge for volatile pages
description: A block/render #cache max-age never sets the external Cache-Control (that comes from the global system.performance:cache.page.max_age); to give ONE page a short edge TTL, set the RESPONSE max-age in a response subscriber/middleware, keyed by cache tag. Time-sensitive pages should ride a short TTL, not edge tag-purge — purge (both pantheon_clear_edge_all and per-tag) silently dies in a Pantheon Global CDN outage while TTL keeps working.
type: reference
---

**Block `#cache['max-age']` does NOT set the edge/browser Cache-Control.** For an
anonymous cacheable page, Drupal writes `Cache-Control: max-age` from the
**global** `system.performance:cache.page.max_age`, not the render tree. A
positive bubbled render max-age (a block's `#cache['max-age'] => 300`) only bounds
Drupal's *internal* render/page cache — it can't lower the external header
(verified: a homepage whose block bubbled 300 still sent `max-age=43200` to
Fastly). Bubbling only ever makes a page *uncacheable* (max-age 0 → `no-cache`);
it can't shorten a positive TTL. **To give ONE page a short edge TTL, set the
RESPONSE max-age** (`$response->setMaxAge()` / `setSharedMaxAge()`) in a
`KernelEvents::RESPONSE` subscriber or a middleware — never via block/render
max-age. Confirm with the real response header (`curl -sI`), not the render array.

**Two edge-freshness mechanisms, one reliable:** TTL (Fastly re-fetches when
`max-age` elapses — never failed) and surrogate-key **tag purge** (fragile). In a
Pantheon **Global CDN partial outage**, purges silently stop landing — both the
full flush `pantheon_clear_edge_all()` (fired by `drush cr` / `env:clear-cache`;
throws `UnexpectedValueException: Unexpected result from Pantheon API` at
`/srv/includes/pantheon.php`) **and** per-tag surrogate-key purges — while TTL
keeps working. A page that leans on tag-purge then serves stale up to its full TTL
(default 12h). Cron completing and `invalidateTags()` firing prove nothing: the
Drupal side works; the purge just never reaches Fastly.

**Design rule:** pages showing **live/volatile data** (wait times, parking,
checkpoint/flight status) must **not** depend on tag-purge — give them a short TTL
(~5 min) so they refresh via TTL alone, purge-independent. Static pages keep long
TTL + purge (a stale static page during a rare outage costs ~nothing). Do it
**per-page, matched to how fast the data changes** — not a global short TTL, which
penalizes the whole site for a rare edge case.

**Reference impls** (both set the RESPONSE max-age, scoped by tag/path):
- `msp` → `web/modules/custom/msp_service/src/EventSubscriber/ServicePageCacheSubscriber.php`
  — RESPONSE subscriber that caps any response carrying a *volatile service cache
  tag* (`waitTimes:block`, `msp_parking_lot_list`, `terminalStatus:block`, …) to
  300s. Detects by **cache tag, not URL**, so new pages embedding those blocks
  inherit the short TTL automatically; only ever shortens (guards `max-age 0` and
  already-short). Global `cache.page.max_age` stays long. Unit-tested.
- `msp` → `msp_service_flight/src/StackMiddleware/FlightsBoardCacheMiddleware.php`
  — heavier: content is max-age 0, cron primes a persistent Redis bin (see
  [[Cache bin that survives drush cr]]), the middleware serves it with a short
  response max-age. Use when a page is both volatile AND expensive to render on
  each edge refill (also buys origin-load protection).

**Diagnosing a purge outage:** invalidate a tag the page carries on live
(`drush php:eval '\Drupal::service("cache_tags.invalidator")->invalidateTags(["msp_parking_lot_list"])'`),
then `curl -sI` the URL — if `last-modified`/`age` don't move and it stays
`x-cache: HIT`, the surrogate-key purge isn't landing. Test with core tags
(`node:1`, `config:system.site`) too: if those don't purge either, it's the
platform, not your tags. Check `status.pantheon.io` for "Global CDN: Partial
Outage." A page that's the **lone holdout** — stuck stale while siblings clear on
the *same* tag — points to **Surrogate-Key header truncation**: tag-dense
aggregate pages (a homepage) emit more keys than Fastly's header limit and drop
some, so the purge can't match. TTL, not deploy, is the only self-heal while
purge is down (`drush cr` can't flush the edge — it *is* the broken path).
