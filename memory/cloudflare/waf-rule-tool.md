---
name: Cloudflare WAF rule and event tool
description: templates/cloudflare/cf-rules.sh — rules, events, audit log; account tokens verify at a different endpoint than user tokens, GraphQL datasets cap at 1-day windows, Free-plan rate limiting entitlements
type: reference
---

`templates/cloudflare/cf-rules.sh` reads and edits a zone's Cloudflare config so an incident
doesn't have to be worked through the dashboard:

```
show    ordered custom rules with enabled state    events <ip> [date]  is this client getting through, and what hit it
pull    raw JSON -> <site-dir>/out/               audit [since] [before]  who changed what, when
backup  timestamped ruleset snapshot              apply <file>  PUT an edited rules array (atomic, reorders)
lists   account IP lists + items
```

Credentials go in `<site-dir>/cf.env` — a **gitignored dir in the site** (`.cloudflare/`),
never in this package, which ships everywhere. `cf.env.example` has the full setup.

## The token trap that costs an hour

Cloudflare has two kinds of API token and they verify at **different endpoints**:

| Kind | Created at | Verifies at | Length |
|---|---|---|---|
| User | My Profile → API Tokens | `/user/tokens/verify` | ~40 |
| Account | Manage Account → API Tokens | `/accounts/<id>/tokens/verify` | ~53 |

An account token checked against the user endpoint returns **`[1000] Invalid API Token`** while
working perfectly for every real call. Any preflight that knows only one endpoint will condemn
a good token — `cf-rules.sh` now tries both. A 32-char hex value is the token **ID**, not the
token; the value is shown once at creation and cannot be re-read.

Permissions, by what you need:

- **Zone → App Security → Zone WAF → Edit** — custom rules *and* rate limiting rules (same
  ruleset engine, one permission)
- **Zone → Analytics → Read** *and* **Zone → Logs → Read** — GraphQL event data. Grant both;
  which one gates `firewallEventsAdaptive` isn't obvious and a wrong guess costs a regeneration
- **Account → Audit Logs → Read** — the `audit` command
- Zone Settings and Bot Management are **separate** permissions; without them you can observe a
  toggle's effects but not read its state

## Two GraphQL datasets, and why you need both

- **`firewallEventsAdaptive`** — only requests something *actioned*. Names the service
  (`botFight`, `bic`, `waf`, `firewallCustom`, `securityLevel`) and the rule id. This is what
  turns "something is blocking us" into a name.
- **`httpRequestsAdaptiveGroups`** — every request, by response status. This is what says
  whether the client is actually getting anywhere.

Neither alone is enough: a client sailing through appears **nowhere** in the firewall events, so
absence there reads as success when it may mean the traffic stopped entirely.

Gotchas: both cap at a **1-day window** on non-Enterprise zones, and the error names the span
rather than the cap. Retention is ~8 days, so a week-old incident may already be unreachable.
Check `sampleInterval` — `1` means true counts, higher means extrapolation. `dimensions` is
**not** a query argument; it's inferred from the selection set.

## Ruleset version history

`/zones/{id}/rulesets/{id}/versions` lists every version with a timestamp, and fetching one
shows that version's expressions. This dates a change precisely — when an IP or country was
added to a rule, and whether it was live during the window you're investigating.

**Its blind spot is the important part:** zone *toggles* leave no ruleset version. Bot Fight
Mode, Under Attack, Security Level and Browser Integrity Check are invisible here, so a quiet
version history does not mean the config was quiet ([[bot-fight-mode-unskippable]]). Only the
account audit log covers those, and it records nothing Cloudflare changed on their own side.

## Free-plan rate limiting entitlements

Discovered one rejection at a time, because the API reports only the first violation:

- **one rule** total
- `period` must be **10** — 60 is rejected
- `mitigation_timeout` must be **10**
- **no query-string fields** — `http.request.uri.query` needs Advanced Rate Limiting

The practical consequence: on Free you cannot rate limit a WooCommerce classic AJAX checkout at
the edge, because it posts to `/?wc-ajax=checkout` — path `/`, everything distinguishing it in
the query string. Do that one in PHP and spend the single rule on something path-addressable.

Related: [[bot-fight-mode-unskippable]], [[waf-blocks-acme-renewal]], [[newrelic-audit-tool]].
