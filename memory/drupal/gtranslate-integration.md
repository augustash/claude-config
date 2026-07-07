---
name: GTranslate integration — prefer hosted subdomain
description: Default to GTranslate hosted subdomain (CNAME to TDN); never ship the self-hosted subdirectory PHP addon — it's a synchronous per-request TDN proxy that saturates PHP-FPM. If subdirectory is forced with no DNS control, reuse the off-request store module in mymspconnect.
type: reference
---

GTranslate paid plans do server-side translation via two URL structures. The choice has a large operational consequence.

- **Hosted subdomain** (`es.site.com`) — **the default; use it.** CNAME each language subdomain to the assigned `{server}.tdn.gtranslate.net`; GTranslate's edge serves the translated page. Zero app load, no proxy code — just the base `gtranslate` module (widget + hreflang) with `url_structure: sub_domain`, `custom_domains: 1`, `enable_cdn: 1`. Reference build: `aairpm-v2` / reell.com (`es.reell.com`, `de.reell.com` → `sis.tdn.gtranslate.net`).
  - One cost to budget: cross-origin assets — fonts/XHR from `es.` to the apex can trip `Access-Control-Allow-Origin`; fix with CORS headers.

- **Self-hosted subdirectory** (`site.com/es/`) via GTranslate's "URL Translation Addon" — **avoid.** It's a synchronous per-request proxy: on every page-cache miss it `curl_exec`s `{server}.tdn.gtranslate.net` and holds the PHP-FPM worker until TDN returns (GTranslate's reference addon sets *no* curl timeout, so it can block to the FPM `request_terminate_timeout`). On a small pool (Pantheon = 6 workers) under crawler load, blocked workers cascade to `pm.max_children` saturation → 30s timeouts → empty `200`s cached at the edge → blank pages. Worse: TDN fetches your origin to translate, so your own saturation slows TDN, which holds workers longer — a feedback loop. Diagnosed on mymspconnect, Jun–Jul 2026.

**Decision rule:**
1. Default to **hosted subdomain**. The only argument for subdirectory is SEO (subdirectories inherit domain authority better than subdomains) — not worth a worker-saturating proxy.
2. If subdirectory is genuinely required, serve it via **GTranslate's CDN fronting the domain**, never the PHP addon.
3. If no hosted option is possible (e.g. no DNS control over the zone, as on mymspconnect where DNS is a client-held Route 53), do **not** run the addon on-request. Reuse the **off-request rebuild** in mymspconnect: `web/modules/custom/gtranslate_subdirectory` — translations are materialized off-request into a dedicated cache bin and served from the store; TDN is never touched on a user request. See that module and its project note (`.claude/memory/gtranslate_subdirectory.md`) for the store/warm-queue/read-path pattern.

Never wire the TDN proxy into a `kernel.request` subscriber.
