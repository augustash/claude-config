---
name: A Pantheon site's own loopback arrives through Cloudflare from Google Cloud
description: Pantheon appservers egress from Google Cloud (AS396982) and reach the site's public domain through Cloudflare, so a rule challenging cloud ASNs also challenges the site's own background requests.
type: reference
---

When a Pantheon site calls itself — WordPress's Action Scheduler async runner
(`admin-ajax.php?action=as_async_request_queue_runner`), WP-Cron spawn (`wp-cron.php`), a
Drupal loopback — the request leaves the appserver from a Google Cloud address and resolves the
public hostname, so it goes **out to Cloudflare and back in**. The origin log shows it plainly:

```
POST /wp-admin/admin-ajax.php?action=as_async_request_queue_runner …
  "WordPress/7.1.3; https://eqlearn.com" … "136.115.183.8, 104.23.245.206, 104.23.245.206, 10.1.6.44"
                                             ^ the appserver, AS396982   ^ a Cloudflare hop
```

So any rule that challenges or blocks **AS396982** — the natural move against the cloud-hosted
scanners that make up most WordPress 404 probing — also catches the site talking to itself. A
challenge can't be solved by a server-side HTTP client, so the call fails and nothing reports it:
Action Scheduler simply stops draining, which on WooCommerce means async emails, Mailchimp
sync and webhooks quietly back up.

**Exempt the self-call paths in the rule itself**, not with a separate skip:

```
(ip.src.asnum in {396982 8075}) and not cf.client.bot
  and not (http.request.uri.path in {"/wp-admin/admin-ajax.php" "/wp-cron.php"})
```

Find a site's actual self-call paths before writing the rule: filter the access log for the
`WordPress/x.y; https://<site>` user agent (or the appserver IPs from
`dig +short appserver.live.<uuid>.drush.in`). Prefer Managed Challenge over Block for cloud
ASNs: real people browse from Azure Virtual Desktop and Windows 365, and a browser passes once.
`not cf.client.bot` keeps Bingbot (on AS8075) out of it.

Case: sal, 2026-11-05 — four US scanners on Google Cloud and Azure caused every remaining
`max_children` hit once the login brute force was blocked. The loopback came from the same ASN as
two of them: ~800 calls over four months, only a handful a day, so a challenged loopback would take
days to notice. Verified the next day: self-calls still 200, scanner 404 bursts and `max_children`
hits gone.

Related: [[proxying-pantheon-ssl-mode]], [[waf-rule-tool]], [[login-wall-scanner-probes]].

The same self-calls also cost PHP workers even with no rule in the way — see
[[background-loopback-holds-workers]].
