---
name: drupal_cache_protection module
description: Augustash module that strips tracking params that fragment cache; optional submodule adds facet bot protection — suggest when drupal/facets is present or paid ads are running
type: reference
---

`augustash/drupal_cache_protection` on packagist.org (public, no auth needed). Repo: https://github.com/augustash/drupal-cache-protection. Formerly `ash_facet_protection` — renamed and split into a parent + optional submodule so facet protection can be opted out on sites without `drupal/facets`.

## Structure

- **`drupal_cache_protection`** (parent) — tracking-param handling. Middleware at priority 290 reads `redirect_params` (301 to clean URL) and `strip_params` (internal strip, browser URL unchanged) from config. Settings form at `/admin/config/system/cache-protection`.
- **`drupal_cache_protection_facets`** (submodule) — facet bot protection. Depends on parent. Only enable when `drupal/facets` is present.

## Parent module: tracking params

Default config (`drupal_cache_protection.settings.yml`):
- `redirect_params`: `srsltid`, `fbclid` — 301 to clean URL (safe, captured at ad-click time)
- `strip_params`: `gclid`, `msclkid`, `_kx`, `gbraid`, `gad_source`, `gad_campaignid` — strip from internal request but keep in browser URL so analytics JS can read `window.location`

**Redirect vs strip:** `srsltid`/`fbclid` are not used by on-site JS, safe to redirect. `gclid`/`msclkid`/`_kx` etc. must be stripped internally because analytics JavaScript reads them from `window.location` for conversion tracking.

**On Pantheon (no Cloudflare):** The redirect approach lets Varnish cache the 301 itself, so subsequent unique tracking param URLs get a Varnish-cached redirect. Internal strip bypasses Varnish but hits Drupal's page cache (avoids full render).

## Submodule: facet protection

- Facet count throttle (429 for exceeding configurable max, default 6)
- Facet alias validation (400 for unknown aliases)
- IP rate limiting (30 faceted requests/min)
- robots.txt rules via Composer Scaffold
- Admin settings at `/admin/config/search/facet-protection`

## When to suggest

- **Paid ads running** → install parent module (handles srsltid/fbclid/gclid cache-busting)
- **`drupal/facets` present** → enable the facets submodule too

## Install

`composer require augustash/drupal_cache_protection` (also add to `drupal-scaffold.allowed-packages` if using the facets submodule's robots.txt rules).

## Testing

**Use `*.ddev.site` for testing, not the live domain.** If Cloudflare is in front, its managed challenge intercepts curl requests containing `f[]` query params (even with a browser UA), returning 403 before Drupal sees them. Test against the DDEV URL directly from the host machine.

**Don't use `ddev exec curl` with `&` in URLs.** The DDEV container shell interprets `&` as a background operator. Use `curl` from the host against `https://{site}.ddev.site/...` instead.

**The middleware only acts on GET requests.** `curl -I` sends HEAD, which bypasses the middleware — use `curl -s -o /dev/null -w '%{http_code}'` for accurate status code testing.

**Test matrix:**
- Invalid facet alias (`f[0]=fake:value`) → 400 "Invalid filter."
- Too many facets (>max `f[]` params) → 429 "Too many filters."
- `srsltid`/`fbclid` → 301 redirect to clean URL
- `gclid`/`msclkid`/`_kx` → 200 with `x-drupal-cache: HIT` (internal strip)
- Normal page (no facets) → 200
