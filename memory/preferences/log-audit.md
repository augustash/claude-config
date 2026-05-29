---
name: log-audit
description: Process for auditing a site's server logs (nginx access + error, php error/fpm/slow, newrelic) — sequential, one log at a time, grouped nginx-then-php
metadata:
  type: feedback
---

Recurring task: audit an augustash site's server logs for security and health issues. Logs are exported and dropped into a local directory (commonly `~/Desktop/logs/`): typically `nginx-access.log`, `nginx-error.log`, `php-error.log`, `php-fpm-error.log`, `php-slow.log`, `newrelic.log`.

**Order (guideline, not a hard rule):** group by layer — nginx logs first, then php. 1) nginx access → 2) nginx error → 3) php-error → 4) php-fpm-error → 5) php-slow → 6) newrelic. Cross-reference between logs whenever it helps (e.g. tie an access-log traffic spike to an nginx-error upstream reset or a php-slow entry), but it's optional.

**Workflow:** review ONE log at a time — surface findings, let the dev assess/handle, then move to the next. Don't bulk-process all logs in one pass; sequential review keeps each log's findings focused and actionable.

**What each log tends to surface:**
- **nginx access** — traffic/status-code distribution, abusive clients (scanners, path enumeration, injection attempts in query strings), high-frequency IPs, bot/UA anomalies.
- **nginx error** — usually low-volume. Mostly blocked scans (`access forbidden by rule`) and forbidden directory listings (benign, confirms the block rules work). The ones that matter are the web-server view of 502/504s: `recv() failed`/`connection reset by peer`/`timed out` from the FPM upstream — tie those to php-fpm-error / php-slow and the offending request.
- **php-error / php-fpm-error** — recurring warnings/notices/fatals, deprecations, repeated stack traces.
- **php-slow** — slow-request hotspots (functions/paths) and repeated slow stacks.
- **newrelic** — agent/instrumentation health issues.

**Why:** These audits recur across sites. One-at-a-time keeps signal high and lets the dev act before moving on.

**How to apply:** When the dev says they're dropping logs for an audit, start with the access log, present findings, and proceed down the list. Use shell tools (grep/awk/sort/uniq/wc) for parsing large logs — this is the justified case for them. Analyze locally only; log contents (IPs, PII) must never be sent to external services.

Related: [[confirm-before-live-terminus]]
