---
name: Cloudflare tracking param cache rule
description: Cloudflare cache rule to exclude srsltid/fbclid from cache key — should be deployed on all augustash sites using Cloudflare
type: reference
---

Google Merchant Center/Shopping ads append `srsltid` (Search Result Source Link ID) and Facebook ads append `fbclid` to landing URLs. Each click gets a unique value, which busts CDN/Varnish cache — every ad click becomes a full backend render.

Both parameters are captured by the ad platform at click time and serve no purpose on the destination site. Stripping them from the cache key is transparent to ad tracking (Google uses `gclid`/`utm_*` separately, Facebook uses its pixel).

**Cloudflare cache rule:**
- Rules > Cache Rules > Create Rule
- Name: `Strip tracking params from cache key`
- When: all incoming requests (no filter needed — exclude is a no-op when params aren't present)
- Then: Eligible for cache
- Cache Key > Query String: Exclude `srsltid`, `fbclid`

**Note:** Query string cache key customization may be enterprise-only on some Cloudflare plans. If unavailable, `ash_facet_protection` handles stripping at the Drupal middleware level as a fallback (redirects to clean URL, second request hits cache).

**When to apply:** All augustash sites behind Cloudflare, especially those running paid ads. No downside to applying universally.
