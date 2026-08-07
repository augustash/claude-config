---
name: log-audit
description: Read a site's access/error logs as evidence to answer who actually called, from where, with which credential, and when it stopped. Use when an integration or API consumer breaks, when a client reports errors from a system you can't see, when you need a third party's egress IP without asking them, when investigating bot/card-testing traffic, or when you need to establish exactly when behavior changed and correlate it to a deploy. NOT for reading code or config to find what a site is supposed to do — that's a site audit. This is the pass that establishes what actually happened on the wire.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Log audit — traffic as evidence

**The job:** something broke, and the code doesn't say why. Logs record what *did*
happen, not what should. That difference is the entire value: a site audit reads
intent, a log audit reads behavior, and when they disagree the log is right.

Reach for this when the question has the shape *"who called, from where, with what,
and when did it stop"* — an integration gone silent, a client reporting errors from a
system you have no access to, a third party whose egress IP you need, attack traffic
to characterize.

## The core insight

**Most integration outages are provable from a timestamp, and the timestamp is usually
already written down.** Any system that authenticates callers records when each last
succeeded. That column is a dead-man's switch nobody thinks to read:

| Platform | Where last-seen lives |
|---|---|
| WooCommerce | `wp_woocommerce_api_keys.last_access` |
| WordPress app passwords | `wp_usermeta` → `_application_passwords` (`last_used`, `last_ip`) |
| Drupal | `key_auth` / consumer tables, `watchdog` |
| Any OAuth server | token/refresh tables |

Read it *before* pulling a single log line. A frozen `last_access` gives you the
minute the integration died, and the minute is what turns "something changed
recently" into "this deploy, 80 minutes later." Everything after that is
confirmation.

**Don't stop at the first plausible cause.** Recent commits with suggestive messages
("hardening rate limiting," "adding Turnstile") attract suspicion and are usually
innocent. Order the candidates by *timestamp against the frozen clock*, not by how
guilty they sound — several will fall out immediately because they landed **before**
the last successful call.

## Pass 1 — establish the clock

Get three timestamps into the same timezone before touching logs. They rarely start
that way:

```bash
# Deploys — git author time is in the author's zone, not UTC
TZ=UTC git log -5 --date=iso-local --pretty='%h  %ad  %s'

# Platform deploy history (what's actually *running*, ≠ what's pushed)
terminus env:code-log <site>.live
```

Then the app's own clock. **WordPress writes `current_time('mysql')` in site-local
time**, so a site at `gmt_offset 0` logs UTC and one at `-6` does not. Check
`timezone_string` / `gmt_offset` before comparing anything to a log.

Nginx logs are UTC. Git author time usually isn't. Getting this wrong inverts cause
and effect.

## Pass 2 — pull the logs

Pantheon exposes nginx logs over rsync, rotated archives included — typically two
weeks back, which is almost always wider than the incident window:

```bash
terminus rsync <site>.live:logs/nginx/ ./nginxlogs/
```

`nginx-access.log` is today; `nginx-access.log-YYYYMMDD.gz` are the archives. Pull
the whole directory — the archives are where the *working* period lives, and you need
the before to characterize the after.

Check coverage before drawing conclusions:

```bash
head -1 nginx-access.log | grep -oE '\[[^]]+\]'
tail -1 nginx-access.log | grep -oE '\[[^]]+\]'
```

An empty result for a caller means nothing if the log doesn't reach back far enough.

**On other platforms:** WP Engine and Kinsta expose logs over SFTP in the same nginx
format; Acquia via `acli`; plain hosting via `/var/log/nginx/`. The parsing below is
the same everywhere. On a multi-appserver plan each server keeps its own log — pull
each, or accept that you're sampling.

**Analyze locally. Log contents — IPs, session identifiers, PII, request bodies — must
never be sent to an external service.** Shell tools (grep/awk/sort/uniq) over a local
copy are the justified case for reaching past the file tools. Where an aggregator is
available, prefer queries that summarize server-side (New Relic NRQL) so you pull back
numbers rather than raw log bodies. Quote the specific lines that carry a finding, not
the surrounding traffic. See [log-audit](../../memory/preferences/log-audit.md) for the
recurring health-and-security sweep across all six log types — a different job from this
one, which is incident forensics.

## Pass 3 — parse it correctly

Two traps, both of which produce *empty output that looks like a real answer*:

**The leading IP is the load balancer.** Pantheon logs `$remote_addr` as an internal
`10.x.x.x`. The real client is the **first** entry of the comma-separated
X-Forwarded-For chain in the final quoted field:

```
10.1.2.11 - ck_032d…a6e5ac2 [04/Aug/2026:16:11:21 +0000] "POST /wp-json/… HTTP/1.1" 200 …
  "WooCommerce Connector" 0.4 "54.197.90.197, 54.197.90.197, 10.1.2.11"
                                ^^^^^^^^^^^^^ the actual caller
```

**`$NF` is empty.** The line ends with a quote, so awk's last `"`-delimited field is
the empty string after it. Use `$(NF-1)`.

Inventory every non-browser caller first — you rarely know the right user agent going
in, and the list itself is the finding:

```bash
(zcat -f nginx-access.log-*.gz; cat nginx-access.log) \
  | grep -aE '"(GET|POST|PUT|PATCH|DELETE) /(wp-json|wc-api|api)/' \
  | awk -F'"' '{ua=$6; split($(NF-1),a,","); gsub(/ /,"",a[1]); print a[1]" | "ua}' \
  | sort | uniq -c | sort -rn
```

Integrations announce themselves: `WooCommerce Connector`, `Klaviyo/1.0`,
`tiktok-business-plugin`, `MailChimp`. Grep the noisy ones out (`Chrome/`, `Safari/`,
`Googlebot`, `Applebot`, `GPTBot`) and what remains is your integration inventory —
often including systems nobody mentioned.

## Pass 4 — identify, then confirm

**The credential is in the log line.** WooCommerce logs the consumer key as the
auth-user field (`ck_032d…a6e5ac2`). Match its tail against `truncated_key` in
`wp_woocommerce_api_keys` and you've bound a user agent to a named integration with
no guessing. Do this before acting on any inference about who a caller is.

Then the two questions that matter:

```bash
# Source IPs — one stable address, or a range?
grep -a "<UA>" nginx-access.log* \
  | awk -F'"' '{split($(NF-1),a,","); gsub(/ /,"",a[1]); print a[1]}' \
  | sort | uniq -c | sort -rn

# Volume per day — where does it stop?
grep -a "<UA>" nginx-access.log* \
  | awk '{split($4,d,":"); gsub(/\[/,"",d[1]); print d[1]}' | uniq -c

# The last thing it ever did — often names the broken operation outright
grep -a "<UA>" nginx-access.log* | tail -5
```

That last line is disproportionately useful. A connector's final call being
`POST /wp-json/wc-shipment-tracking/v3/orders/35198/…` identifies the exact operation
failing in the remote system, which is how you confirm a mechanism you'd otherwise be
inferring.

`whois` the resulting IP. Its ASN and country decide things — whether a geo-fence
could have been responsible, whether a "residential broadband" address is really the
vendor it's labelled as.

## The traps

Each of these has cost a wrong conclusion.

**1. Your own probe traffic is in the log.** Diagnostic `curl` runs land in the same
file, and a spoofed user agent set during testing reads exactly like the real thing —
an `MS Web Services Client Protocol` UA looks like a .NET connector because it is one.
Check counts and timestamps against your own shell history before concluding anything
about a non-browser agent. Prefer a distinctive UA on your own probes for this reason.

**2. Edge cache masks origin behavior.** A `curl -I` can return a response the origin
stopped producing hours ago. Always compare a plain request against a cache-busted one
and read the headers:

```bash
curl -sI "https://site.com/path"                  # age: 9908  x-cache: MISS, HIT
curl -sI "https://site.com/path?cb=$(date +%s)"   # age: 0     x-cache: MISS, MISS
```

`age:` greater than zero means you're reading history. A fix can be correctly deployed
and still invisible until the cache is purged — and a cacheable `301` with
`max-age=86400` will keep redirecting clients for a day after the code is right.

**3. Deployed ≠ pushed.** On Pantheon, `git push` reaches Dev only. `terminus
env:code-log <site>.live` shows what Live is actually running. Verifying a fix against
an environment that never received it wastes a cycle and can send you chasing a
phantom second bug.

**4. One observed IP is not a documented range.** Ten days of a single stable address
is strong evidence and still not a guarantee against vendor failover. Use it, then
confirm with the vendor — derive first so you're not blocked, verify after so you're
not wrong.

**5. An empty result is a finding only if coverage is proven.** "No traffic from X"
means nothing until you've shown the log window covers the period X should have been
active in.

## What to hand back

Lead with the timeline in one timezone — frozen clock, candidate changes, first
failure. That table is the argument; everything else supports it.

Then: the actor (UA, IP, ASN, credential binding), what its last successful call was,
and what stopped. Name what you proved versus what you inferred — a mechanism you
haven't observed is a hypothesis, and saying so is what lets someone else check it.

Volunteer the incidental findings. A log inventory surfaces integrations nobody
mentioned, credentials still active for departed vendors, and scanner traffic worth
a separate ticket. They're cheap to note while you're already in the data and
expensive to discover later.
