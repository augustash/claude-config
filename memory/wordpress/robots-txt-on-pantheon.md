---
name: robots-txt-on-pantheon-wordpress
description: WordPress robots.txt on Pantheon is the virtual one, Yoast reorders it, and Cloudflare holds it for a week; a change can be wrong or invisible.
metadata:
  type: reference
---

**Who serves it.** On Live with a custom domain, WordPress's virtual robots.txt (the
`robots_txt` filter); no physical file. Platform domains and Dev/Test/Multidev get Pantheon's
own `Disallow: /` file whatever the site does (docs.pantheon.io/bots-and-indexing). So check
robots changes on the custom domain only.

**Yoast reorders it.** Yoast filters `robots_txt` at 99999: it strips WordPress's default
`User-agent: *` rules, keeps what other plugins added, and appends its own block *after*
them. Anything added below 99999 therefore leads the file, and a `Disallow:` with no
`User-agent:` above it sits outside any group, where crawlers ignore it. Every block added
by filter must open its own group; repeated `User-agent: *` groups merge. Shipped in
wordpress-cache-protection 1.2.1 after ent's `Disallow: /xmlrpc.php` was found doing nothing
(2026-11-12).

**It's cached for a week.** Pantheon sends robots.txt with `max-age=604800`, and Cloudflare
caches `.txt` by default. Launcher's cache clear reaches Pantheon, not Cloudflare, so after a
deploy crawlers keep the old file for up to 7 days (ent: `age: 422614`, `cf-cache-status: HIT`).
Purge `/robots.txt` in Cloudflare after a robots change. Verify with a plain `curl -sI`; a
cache-busting query string shows the new file and hides the stale one crawlers get.
