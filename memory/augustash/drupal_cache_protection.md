---
name: drupal_cache_protection module
description: Augustash module that strips tracking params + protects against bot abuse on hot routes; pair with augustash sites on free/Pro Cloudflare (Enterprise edge-strip not available)
type: reference
---

`augustash/drupal_cache_protection` on packagist.org (public, no auth needed). Repo: https://github.com/augustash/drupal-cache-protection. Formerly `ash_facet_protection` — renamed and split into a parent + opt-in submodules.

## Structure

- **`drupal_cache_protection`** (parent) — tracking-param handling. Middleware at priority 290 reads `redirect_params` (301 to clean URL) and `strip_params` (internal strip, browser URL unchanged) from config. Settings form at `/admin/config/system/cache-protection`. Also ships robots.txt scaffold via `assets/robots-additions.txt` with general bot-throttling rules.
- **`drupal_cache_protection_facets`** (submodule) — facet bot protection. Depends on parent. Only enable when `drupal/facets` is present.
- **`drupal_cache_protection_search`** (submodule) — per-IP rate limit + page-cache kill switch on search routes (`/search`, plus configurable query params like `s`, `keys`, `search_api_fulltext`). Enable on any site with a search route exposed — Drupal core Search, search_api, Solr, custom.

## Parent module: tracking params

Default config (`drupal_cache_protection.settings.yml`):
- `redirect_params`: `srsltid`, `fbclid` — 301 to clean URL (safe, captured at ad-click time)
- `strip_params`: `gclid`, `msclkid`, `_kx`, `gbraid`, `gad_source`, `gad_campaignid`, `utm_source/medium/campaign/term/content/id`, plus HubSpot Ads + analytics params (`hsa_*`, `_hsmi`, `_hsenc`, `__hstc`, `__hssc`, `__hsfp`)

**Redirect vs strip:** `srsltid`/`fbclid` are not used by on-site JS, safe to redirect. `gclid`/`msclkid`/`_kx`/`hsa_*`/`__hs*` must be stripped internally because client-side analytics/ads JS reads them from `window.location` for conversion tracking.

## Cloudflare tier reality

Many augustash clients run Cloudflare in front of Pantheon, but on **free or Pro tier — not Enterprise**. CF's edge param-stripping (Transform Rules → Rewrite URL → strip query params) is **Enterprise only**. So even with CF in front, origin-side strip is the right tool for the typical client setup.

The redirect approach (for `redirect_params`) lets Varnish cache the 301 itself, so subsequent unique tracking-param URLs get a Varnish-cached redirect with no PHP hit. The strip approach (for `strip_params`) bypasses Varnish on the first hit but reaches Drupal's page cache on the canonical URL, avoiding the full render path.

## Pantheon's own `PANTHEON_STRIPPED` behavior

Pantheon's edge already strips `utm_*` at the Varnish layer, but it **preserves the key with a literal `PANTHEON_STRIPPED` value** (e.g. `utm_source=PANTHEON_STRIPPED`). So Varnish keys on a stable URL across campaign variations.

The module's `strip_params` entry for `utm_*` is therefore **a no-op on Pantheon** (Pantheon handled it first; middleware just removes the still-present key entirely). It's not harmful — and it's load-bearing on non-Pantheon hosts. Keep `utm_*` in defaults.

## Submodule: facet protection

- Facet count throttle (429 for exceeding configurable max, default 6)
- Facet alias validation (400 for unknown aliases)
- IP rate limiting (30 faceted requests/min)
- Admin settings at `/admin/config/search/facet-protection`

## Submodule: search protection

- Two flood windows (burst + sustained), either limit triggers a 429
- Page-cache kill switch on search responses (each query is unique, caching is pointless)
- Only acts when a configured search query parameter is present (`?s=...`), so the empty search form stays cacheable
- Admin settings at `/admin/config/search/cache-protection/search`

## When to suggest

- **Paid ads running** → install parent module (handles all the common ad-click params, including HubSpot)
- **`drupal/facets` present** → enable the facets submodule too
- **Any search route exposed** → enable the search submodule (rate-limit + uncache is free protection regardless of search load)

## Install

```sh
ddev composer config --json --merge extra.drupal-scaffold.allowed-packages '["augustash/drupal_cache_protection"]'
ddev composer require augustash/drupal_cache_protection
ddev drush en -y drupal_cache_protection
# Conditionally:
ddev drush en -y drupal_cache_protection_facets   # only if drupal/facets is enabled
ddev drush en -y drupal_cache_protection_search   # if any search route is exposed
```

## Testing

**Use `*.ddev.site` for testing, not the live domain.** If Cloudflare is in front, its managed challenge intercepts curl requests containing `f[]` query params (even with a browser UA), returning 403 before Drupal sees them. Test against the DDEV URL directly from the host machine.

**Don't use `ddev exec curl` with `&` in URLs.** The DDEV container shell interprets `&` as a background operator. Use `curl` from the host against `https://{site}.ddev.site/...` instead.

**The middleware only acts on GET requests.** `curl -I` sends HEAD, which bypasses the middleware — use `curl -s -o /dev/null -w '%{http_code}'` for accurate status code testing.

**Test matrix:**
- Invalid facet alias (`f[0]=fake:value`) → 400 "Invalid filter."
- Too many facets (>max `f[]` params) → 429 "Too many filters."
- `srsltid`/`fbclid` → 301 redirect to clean URL
- `gclid`/`msclkid`/`_kx`/`hsa_acc` → 200 with `x-drupal-cache: HIT` (internal strip)
- Normal page (no facets) → 200
