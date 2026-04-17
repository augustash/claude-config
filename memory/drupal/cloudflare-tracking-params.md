---
name: Tracking params and CDN cache
description: srsltid/fbclid/gclid etc. bust CDN cache with unique values per ad click — handle at Drupal middleware level, not Cloudflare cache rules
type: reference
---

Google Merchant Center/Shopping ads append `srsltid`, Facebook appends `fbclid`, Google Ads appends `gclid`/`gbraid`/`gad_source`/`gad_campaignid`, Bing appends `msclkid`, and Klaviyo appends `_kx`. Each click gets a unique value, busting CDN/Varnish cache.

**Cloudflare cache key exclusion does NOT help** — since every value is unique, there's never a cached entry to match against. The `drupal_cache_protection` module handles this at the Drupal middleware level instead (redirect for srsltid/fbclid, internal strip for gclid/msclkid/_kx). This works on Pantheon Varnish too — not Cloudflare-specific.

**Safe to redirect:** `srsltid`, `fbclid` — captured by the ad platform at click time, not used by on-site JS.

**Must strip internally (not redirect):** `gclid`, `msclkid`, `_kx`, `gbraid`, `gad_source`, `gad_campaignid` — analytics JavaScript (GA, Bing UET, Klaviyo) reads these from `window.location` for conversion tracking. Redirecting would remove them before JS can capture them.

**When to apply:** All augustash sites running paid ads. Handled by `drupal_cache_protection` module — no separate CDN rule needed.
