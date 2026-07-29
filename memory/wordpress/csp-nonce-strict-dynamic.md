---
name: Pass CSP Evaluator on WordPress with nonce + strict-dynamic
description: How to clear Google CSP Evaluator's script-src HIGH on a WP+GTM site WITHOUT a host allowlist — a per-request nonce + 'strict-dynamic', nonced at BOTH WP's script-printing layer AND an output buffer. Covers why it works, the inline-handler gotcha, the buffer-misses-wp_add_inline_script gotcha (breaks Gravity Forms), and the two-tester validation.
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
the intersection). Real deployment: apf's `arrowhead-csp` plugin (v2.2+).

**The buffer alone is NOT enough — nonce at WP's printing layer too.** The
`ob_start` regex silently **misses some `wp_add_inline_script()` output**: it's
emitted during `wp_head` in a way that escapes the `template_redirect` buffer, so
that one tag comes out un-nonced while the buffer nonces every other. Under
`'strict-dynamic'` a *single* un-nonced inline script is **blocked** — and if it's
a bootstrap other scripts depend on, everything downstream throws. The bite at apf:
**Gravity Forms' `gform` foundation** (added `'before'` the
`gform_gravityforms_libraries` handle) was blocked → `gform` undefined → every
`gform.initializeOnLoaded()` threw → GF's wrapper (rendered `style="display:none"`
until JS reveals it) stayed hidden → **invisible form**, presenting as "the
third-party form broke" when the third party was fine. Fix belongs at the source:
inside the same `template_redirect` callback (paired with the header, so the nonce
matches), add
`add_filter('wp_inline_script_attributes', fn)` + `add_filter('wp_script_attributes', fn)`
that set `nonce` on the attribute array. WP 5.7+ routes enqueued inline/src scripts
through `wp_get_inline_script_tag()` / the loader, both of which run these filters,
so the nonce lands regardless of buffer timing. Keep the buffer as the fallback for
raw `<script>` echoed outside `wp_enqueue` (the regex skips tags already carrying
`nonce=`, so no double-nonce). Diagnose with `curl … | grep -c '^<script>'` — any
plain un-nonced inline `<script>` in the served HTML is a strict-dynamic landmine.

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
