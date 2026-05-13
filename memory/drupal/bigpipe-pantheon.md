---
name: BigPipe is not viable on Pantheon
description: Pantheon's Varnish edge cache is incompatible with BigPipe; without BigPipe, lazy_builder falls back to inline rendering. The practical impact on caching is narrower than it looks — anonymous page_cache + Pantheon Varnish still cache responses even when forms bubble max-age 0
type: reference
---

BigPipe streams HTML in chunks, replacing `#lazy_builder` placeholders as they finish rendering. Pantheon's Global CDN / Varnish edge cache does not handle the streamed/chunked response correctly — responses fail to cache, get truncated, or bypass the edge. Pantheon's own guidance is to leave BigPipe off, and most augustash production sites are on Pantheon.

## What this does NOT mean

It does **not** mean "pages with forms in blocks are uncacheable on Pantheon." That was my first read, and it's wrong. There are two Drupal cache layers and form-bubbled max-age 0 only affects one of them:

| Layer | Respects bubbled max-age 0? | Effect of forms-in-blocks |
|---|---|---|
| `page_cache` (anonymous) | **No** — uses outgoing `cache-control` header for TTL | Anonymous pages still cache for `system.performance:page.cache.max_age` |
| `dynamic_page_cache` (all users, cache-context-aware) | Yes | Bypassed; authenticated users render fresh every request |
| Pantheon Varnish | Reads `cache-control` header | Caches based on origin advertising `max-age=43200, public` |

So a typical augustash Pantheon site with a webform/subscribe block placed globally will show `x-drupal-cache-max-age: 0 (Uncacheable)` AND `x-drupal-cache: HIT` AND `x-cache: HIT` simultaneously on warm requests. The "Uncacheable" header refers only to dynamic_page_cache, not the overall caching path.

**Sanity-check the diagnosis before recommending a fix.** Run `curl -sI <prod-url>` and look at `x-drupal-cache` (anonymous page_cache HIT/MISS) and `x-cache` (Pantheon Varnish HIT/MISS) on warm requests. If those are HITting, the site is being cached and the dynamic_page_cache miss is a low-impact concern — fine for mostly-anonymous traffic.

## When does it actually matter?

The form-bubble cache miss only causes user-impacting problems when one of these is true:

- **Heavy authenticated traffic.** Logged-in users never get anonymous page_cache; they depend on dynamic_page_cache, which is bypassed.
- **Cache-context-sensitive content** that needs per-context variants (e.g., per-role rendering) — those variants live only in dynamic_page_cache.
- **Routes where you specifically need fresh CSRF/state per render but also want caching** — rare combination.

For most augustash brokerage / marketing / commerce sites (predominantly anonymous traffic), page_cache + Pantheon Varnish carries the load and the form-bubble is cosmetic in the headers.

## Fix paths when it does matter

1. **Tighten visibility.** If a form-block doesn't need to be on a high-traffic page, remove it. Cheapest and most architecturally Drupal-conventional.
2. **AJAX placeholder strategy** (custom). Drupal's `PlaceholderStrategyInterface` allows replacing core's inline fall-back with an AJAX-loaded marker. Generic — any `#lazy_builder` (webform `lazy: true`, anything patched to use it) gets deferred for free. The right home for this is a submodule of `augustash/drupal_cache_protection` (e.g., `drupal_cache_protection_placeholders`) — same shape as facets/search submodules: opt-in cache protection. Marshalling lazy_builder callables to a separate HTTP request needs HMAC-signed tokens + `TrustedCallbackInterface` enforcement.
3. **Patch contrib that bypasses placeholders** (e.g., `campaignmonitor` `CampaignMonitorSubscribeBlock::build()` calls `formBuilder->getForm()` directly with no `#lazy_builder` wrapper — upstream-worthy fix). Doesn't change runtime on Pantheon without (2) installed, but it's the correct-by-convention contribution.

## Webform specifics

Webform's `lazy: true` block setting uses `#lazy_builder` (`Drupal\webform\Element\Webform::lazyBuilder`). Without BigPipe, this is a no-op for caching — the placeholder falls back to inline render. Setting `lazy: true` on Pantheon doesn't improve dynamic_page_cache outcomes. It only matters if the AJAX placeholder strategy from (2) is installed.

## How to apply

When debugging "is caching working?" on a Pantheon site, don't lead with `x-drupal-cache-max-age: 0`. Lead with `x-drupal-cache` and `x-cache` on warm requests against prod (`curl -sI <prod-url>` twice, watch the second hit). If both HIT, caching is working as intended for anonymous traffic. Only reach for AJAX placeholders or visibility changes if a measurable problem (perf regressions, authenticated-user complaints, origin cost) justifies it.
