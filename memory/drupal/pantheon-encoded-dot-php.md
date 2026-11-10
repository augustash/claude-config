---
name: pantheon-encoded-dot-php
description: On Pantheon, a path with the dot written as %2e runs PHP files directly and poisons cached links with /index%2ephp/; ddev can't reproduce it.
metadata:
  type: reference
---

# `%2e` in a path on Pantheon

Pantheon's nginx treats `/index%2ephp/<path>` and `/<dir>/<file>%2ephp` as requests for
that PHP file. Two consequences, both seen on every MAC site (metro, msp, mymspconnect,
mace) on 2026-10-23:

- **Any PHP file in the docroot can be run by name.** `/sites/default/settings%2ephp`
  returns 500 (settings.php executed and fataled on `DRUPAL_ROOT`); `/core/install%2ephp`
  returns 200 with "Drupal already installed" on msp and mace. Nothing leaked in the cases
  seen, but the protection that keeps visitors off internal files is bypassed. A scanner
  used exactly this on metro on 2026-10-17, spoofing `X-Forwarded-For: 127.0.0.1`.
- **Cached links get the prefix.** A request to `/index%2ephp/about-us` makes Drupal
  believe its base path is `/index.php`, so every link built for that response is
  `/index%2ephp/...`. Render-cached menus and listings keep those links and serve them to
  everyone: 127 on one metro page, link-following bots (Meta, ClaudeBot, OpenAI) and the
  client's own office then request them, and the duplicate pages answer 200 with a
  **self-canonical**, so search engines get a second copy that claims to be the real one.
  On metro that traffic was 15.3% of all request time in 11 days. Plain `/index.php/x`
  is fine — the redirect module's route normalizer 301s it.

**ddev can't reproduce it.** Locally the same request 301s, so a page that looks clean in
ddev proves nothing. Test on a Pantheon dev environment.

**Spotting it:** `curl -s https://<site>/<busy page> | grep -c 'index%2ephp'` above zero,
or `index%2ephp` in the access log's top paths. Probe the exposure with
`curl -o /dev/null -w '%{http_code}' https://<site>/sites/default/settings%2ephp` —
anything but 403/404 means PHP ran.

**The fix direction (not yet verified on Pantheon):** reject or redirect any request whose
raw path contains `%2e`/`%2E` before Drupal builds anything — top of `settings.php`, or
`drupal_cache_protection` so every site gets it — then clear render and page caches so the
stored links go. Scope it wider than `index%2ephp`: the PHP-execution half is the security
issue. Update this note once a fix is proven on dev.
