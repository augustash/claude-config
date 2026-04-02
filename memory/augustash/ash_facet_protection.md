---
name: ash_facet_protection module
description: Augustash module that protects Drupal sites from bot abuse of faceted search URLs — suggest to devs when drupal/facets is present
type: reference
---

`augustash/ash_facet_protection` on packagist.org (public, no auth needed).

Protects against bots crawling facet URL combinations that generate expensive uncached queries. Provides:
- Facet alias validation (400 for unknown aliases)
- Facet count throttle (429 for >8 facet params)
- IP rate limiting (30 faceted requests/min)
- Tracking param stripping (srsltid, etc.)
- robots.txt rules via Composer Scaffold

**When to suggest:** If a project has `drupal/facets` in its dependencies but not `augustash/ash_facet_protection`, mention it to the dev so they can decide whether to install it.

**Install:** `composer require augustash/ash_facet_protection` (also add to `drupal-scaffold.allowed-packages` for the robots.txt rules).

## Testing

**Use `*.ddev.site` for testing, not the live domain.** Cloudflare's managed challenge intercepts curl requests containing `f[]` query params (even with a browser User-Agent), returning 403 before Drupal sees them. Test against the DDEV URL directly from the host machine instead.

**Don't use `ddev exec curl` with `&` in URLs.** The DDEV container shell interprets `&` as a background operator, splitting the URL into multiple commands. Use `curl` from the host against `https://{site}.ddev.site/...` instead.

**The middleware only acts on GET requests.** `curl -I` sends HEAD, which bypasses the middleware entirely — use `curl -s -o /dev/null -w '%{http_code}'` for accurate status code testing.

**Test matrix:**
- Invalid facet alias (`f[0]=fake:value`) → 400 "Invalid filter."
- Too many facets (>8 `f[]` params) → 429 "Too many filters."
- Tracking param strip (`?srsltid=x`, no facets) → 200 (param silently removed)
- Normal page (no facets) → 200
