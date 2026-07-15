---
name: RSSSL Pro CSP enforce breaks analytics
description: Really Simple SSL Pro CSP flipped report-only→enforce silently blocks GA4/GTM/ads beacons; analytics traffic cliffs overnight while the site looks fine — diagnose via wp_rsssl_csp_log + connect-src diff, not the repo
type: reference
---

**Symptom:** GA4 "Active users" falls off a cliff overnight (e.g. ~150/day → ~10/day, then dead flat) with no gradual ramp, right after a "security hardening" pass. Site works fine, real conversions (form fills, orders) hold steady. A vertical cliff to a flat floor = **measurement broke**, not visitors left (real traffic loss ramps down over days as Google recrawls).

**Cause:** Really Simple SSL Pro's CSP feature runs in **report-only / "learning" mode** collecting sources, then someone flips it to **enforce**. If the learning window didn't capture every source, the enforced allowlist silently blackholes what it missed. Analytics is the classic casualty: the granular allowlist commonly includes `googletagmanager.com` + `www.google-analytics.com` (so the *script* loads and the site looks fine) but omits the beacon/measurement endpoints, so the GA4 *hit* is blocked at the connection layer. Nothing in the repo changes — it's a single wp-admin toggle, `rsssl_options['csp_status']` (`disabled` | learning/report-only | `enforce`) in the DB. Won't come down in a prod→repo sync either.

**Not in code.** Two plugins can emit CSP and both are DB-driven: RSSSL Pro (granular allowlist, has a `report-uri`, is the enforcing one) and Headers Security Advanced/HSTS (`hsts_csp` option, blunt `default-src * ...` written into the gitignored `.htaccess`). The live enforcing header is RSSSL's.

**Diagnose:**
- Live header: `curl -sD - -A 'Mozilla/5.0' https://SITE/ -o /dev/null | grep -i security-policy`. Enforcing = `content-security-policy:`; report-only = `content-security-policy-report-only:`. Use a real browser UA — some setups don't emit it to `curl -I`/HEAD.
- The receipt: `wp_rsssl_csp_log` (RSSSL's own learning log — cols `time, documenturi, violateddirective, blockeduri, status`) lists every source RSSSL saw. Diff it against the enforced `connect-src`/`script-src`; anything logged-but-absent is being blocked. Post-enforce rows for `google-analytics`/`doubleclick` = definitive proof.
- Prove the beacon (vs script) is what's blocked: headless Chrome with `--log-net-log=out.json --virtual-time-budget=12000 --dump-dom URL`, then grep for `/g/collect` (GA4 measurement hit) vs `ccm/collect`. Script loads + `/g/collect` absent = beacon suppressed.
- CSP mechanism to remember: `script-src` allows the tag to *load*; `connect-src` governs the *beacon*. A connect-src stricter than script-src lets GA load but silently drops its hits — no console "script blocked" error.

**Google measurement hosts that must be allowlisted** (seen needed on a real GA4+GTM+Ads+Signals site — put in `connect-src`, some also `img-src`): `googletagmanager.com`, `www.google-analytics.com`, `region1.google-analytics.com`, `analytics.google.com`, `region1.analytics.google.com`, `www.google.com` (ccm/collect — Consent Mode/Ads), `stats.g.doubleclick.net` (Google Signals), `googleads.g.doubleclick.net`, `ad.doubleclick.net`, `www.googleadservices.com`. Note `region1.google-analytics.com` ≠ `region1.analytics.google.com` — both exist and are distinct hosts.

**Fix:** In RSSSL admin on production, set CSP back to **Learning mode** (or disable) to restore tracking immediately — report-only blocks nothing. Complete the allowlist from the log, wait until Google violations stop, *then* re-enforce. Never flip to enforce off a short learning window.

**How to apply:** On any augustash WordPress site running Really Simple SSL Pro (check `wp plugin list`), if analytics "died" after a security change, this is the first thing to check — it's not in git. See also [[woocommerce-pantheon-cache]] for the general "traffic anomaly is a plugin/DB setting, not code" posture on WP.
