---
name: ash_facet_protection module
description: Augustash module that protects Drupal sites from bot abuse of faceted search URLs and strips tracking params that fragment cache — suggest when drupal/facets is present
type: reference
---

`augustash/ash_facet_protection` on packagist.org (public, no auth needed).

Protects against bots crawling facet URL combinations that generate expensive uncached queries. Provides:
- Facet count throttle (429 for exceeding configurable max, default 6)
- Facet alias validation (400 for unknown aliases)
- IP rate limiting (30 faceted requests/min)
- Tracking param redirect (`srsltid`, `fbclid`) — 301 to clean URL, safe because these are captured at click time by the ad platform
- Tracking param internal strip (`gclid`, `msclkid`, `_kx`, `gbraid`, `gad_source`, `gad_campaignid`) — strips from Drupal's internal request/cache key but preserves browser URL so analytics JS can still read them
- robots.txt rules via Composer Scaffold
- Admin settings form at `/admin/config/search/facet-protection` for configuring max facets

**Redirect vs strip:** `srsltid`/`fbclid` are safe to redirect away (not used by on-site JS). `gclid`/`msclkid`/`_kx` etc. must be stripped internally because analytics JavaScript reads them from `window.location` for conversion tracking.

**On Pantheon:** The redirect approach lets Varnish cache the 301 itself, so subsequent unique tracking param URLs get a Varnish-cached redirect. Internal strip bypasses Varnish but hits Drupal's page cache (avoids full render).

**When to suggest:** If a project has `drupal/facets` in its dependencies but not `augustash/ash_facet_protection`, mention it to the dev so they can decide whether to install it.

**Install:** `composer require augustash/ash_facet_protection` (also add to `drupal-scaffold.allowed-packages` for the robots.txt rules).

## Testing

**Use `*.ddev.site` for testing, not the live domain.** Cloudflare's managed challenge intercepts curl requests containing `f[]` query params (even with a browser User-Agent), returning 403 before Drupal sees them. Test against the DDEV URL directly from the host machine instead.

**Don't use `ddev exec curl` with `&` in URLs.** The DDEV container shell interprets `&` as a background operator, splitting the URL into multiple commands. Use `curl` from the host against `https://{site}.ddev.site/...` instead.

**The middleware only acts on GET requests.** `curl -I` sends HEAD, which bypasses the middleware entirely — use `curl -s -o /dev/null -w '%{http_code}'` for accurate status code testing.

**Test matrix:**
- Invalid facet alias (`f[0]=fake:value`) → 400 "Invalid filter."
- Too many facets (>max `f[]` params) → 429 "Too many filters."
- `srsltid`/`fbclid` → 301 redirect to clean URL
- `gclid`/`msclkid`/`_kx` → 200 with `x-drupal-cache: HIT` (internal strip)
- Normal page (no facets) → 200
