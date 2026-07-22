---
name: Pass CSP Evaluator on WordPress with nonce + strict-dynamic
description: How to clear Google CSP Evaluator's script-src HIGH on a WP+GTM site WITHOUT a host allowlist — a per-request nonce + 'strict-dynamic' plus an output buffer that auto-nonces every in-page <script>. Covers why it works, the inline-handler gotcha, and the two-tester validation.
metadata:
  type: reference
---

**When:** a client validates the site with **Google CSP Evaluator**
(csp-evaluator.withgoogle.com) and it flags `script-src` **HIGH** — the usual WP
policy `script-src 'self' 'unsafe-inline' … https:` trips both `'unsafe-inline'`
and the `https:` scheme wildcard. You need a passing grade but do **not** want a
host allowlist to maintain (a new GTM tag would get blackholed — the exact
failure in [[WP security-header CSP silently breaks analytics]]).

**The only shape that passes without an allowlist: a per-request nonce +
`'strict-dynamic'`, with an output buffer that nonces every in-page `<script>`.**

```
script-src 'nonce-{random}' 'strict-dynamic' https: 'unsafe-inline'
```

**Why it works:** `'strict-dynamic'` makes modern browsers trust a script that
carries the nonce and, transitively, any script *it* loads — so a nonced GTM
loader pulls in `gtm.js` → GA4/Ads tags and they **inherit** trust with no nonce
of their own. Browsers that honor strict-dynamic **ignore** the trailing
`https: 'unsafe-inline'` (so CSP Evaluator does not flag them); older browsers
fall back to it so nothing breaks. Because trust propagates, **only the
`<script>` tags in the served HTML need the nonce** — a `template_redirect` →
`ob_start` buffer adds `nonce="…"` to each via one regex (count-independent).
Drop `'unsafe-eval'` (a standalone MEDIUM finding); add it back only if a GTM tag
needs eval. Reference impl: `templates/wordpress/csp-nonce-strict-dynamic.php`
(single-owner rule still applies — RSSSL's CSP stays OFF or the browser enforces
the intersection). Real deployment: apf's `arrowhead-csp` plugin (v2).

**The gotcha — a nonce covers `<script>` TAGS only.** strict-dynamic disables
`'unsafe-inline'`, so inline `on*=` event handlers and `javascript:` URIs are
**blocked** and must be fixed at the source (a nonce can't cover them).
**Measure the surface first** on the real pages:
`grep -oiE "<[a-z][^>]*\son[a-z]+=" ` and `grep "javascript:"` — it's usually
near-zero on a brochure site. Known pattern: async-font-load
`<link rel="preload" … onload="this.rel='stylesheet'">` → move the flip into a
real `<script>` (the buffer nonces it), keep the `<noscript>` for JS-off.
CSP Evaluator also *suggests* `require-trusted-types-for 'script'` — informational,
**not** a finding; skip it (Trusted Types breaks plugin DOM-sink writes).

**Validate BOTH before deploy:**
1. Paste the emitted policy into csp-evaluator.withgoogle.com → `script-src` (and
   every directive) green, no HIGH/MEDIUM.
2. Headless under **enforcement**, home + a form page (Gravity Forms/Turnstile):
   no CSP-violation console errors; `googletagmanager.com/gtag/js` +
   `analytics.google.com/g/collect` still fire; `challenges.cloudflare.com`
   (Turnstile) loads; fonts render (the flip works). A CSP block shows as a
   browser-blocked request + console violation — a `503` from Google is a
   dev-env artifact, not a block.

**How to apply:** WP site failing CSP Evaluator on `script-src`, client wants a
pass, no allowlist appetite → this technique. It's the third option the RSSSL
memory's "Tier 1 vs Tier 2" framing was missing: you *can* get a clean
script-src grade on WP+GTM. See [[reference-scripts-not-embeds]] for why the impl
lives as a tracked template, not pasted here.
