---
name: login-wall-scanner-probes
description: On a login-walled Drupal site every scanner probe becomes a full uncacheable render, and the logs show no 404s to find them by
metadata:
  type: reference
---

# On a login-walled site every probe is a full render

With anonymous_redirect (or any "send anonymous visitors to login" setup), Drupal answers
`/wp-login.php`, `/shell.php` and the rest with a 302 to `/user/login?destination=…`,
then renders the login page, which can't be cached. So every probe costs a full bootstrap,
and the access log has **no 404s at all**. A sweep that looks for scanners by 404 rate finds
nothing. Count them by path pattern instead (`\.php$`, `^/wp-`, `.env`, `.git`).

On mace (2026-10-21) probes were 9% of two months' traffic and 7% of PHP time. Pantheon
hands unknown paths to `index.php`, and there was no Cloudflare in front to filter them.

**Fix:** [templates/drupal/settings-scanner-probe-404.php](../../templates/drupal/settings-scanner-probe-404.php)
at the top of `settings.php`. It ends the request before the kernel, and the cacheable 404 lets
the edge answer repeats. On a site that is behind Cloudflare, a WAF rule does the same job further out.

**Testing it locally is a trap.** ddev's nginx already returns 404 for missing `*.php`
without touching PHP, so `/admin.php` looks fixed before and after. Probe with paths that
do reach Drupal locally: uppercase `/ADMIN.PHP` (ddev's location match is case-sensitive)
and `/wp-` paths without `.php`. Run `ddev mutagen sync` after editing `settings.php`,
or the old file answers ([[ddev-mutagen-sync-lag]]).
