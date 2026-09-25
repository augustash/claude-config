---
name: A Single Redirect needs its own token permission, not Transform Rules
description: Redirect rules live in the http_request_dynamic_redirect phase and need Zone > Single Redirect > Edit. Transform Rules sounds right and is not. Also — how to tell a missing permission from an empty ruleset.
type: reference
---

# A Single Redirect needs its own token permission, not Transform Rules

Creating a redirect rule over the API returns:

```
{"success": false, "errors": [{"message": "request is not authorized"}]}
```

on a token that demonstrably works — DNS edits succeed, zone lookups succeed.

**The names do not line up across the three places you meet this feature:**

| Where | What it is called |
|---|---|
| Dashboard | Rules → **Redirect Rules** ("Single Redirects") |
| Token permission | Zone → **Single Redirect** → Edit |
| API ruleset phase | `http_request_dynamic_redirect` |

So the phase says *dynamic redirect*, the permission says *single redirect*, and **Transform
Rules — which sounds like it should cover it, and governs the neighbouring
`http_request_transform` phase — does not**. Granting Transform Rules leaves redirects still
forbidden.

## Telling a missing permission from an empty ruleset

Probe the entrypoint of each phase and read the error text, which distinguishes the two cases
precisely:

```
GET /zones/<zone>/rulesets/phases/<phase>/entrypoint

"could not find entrypoint ruleset in the … phase"  → AUTHORIZED, nothing created yet
"request is not authorized"                          → the permission is missing
```

That distinction is the whole diagnostic. A zone with no rules yet looks like a permission
failure if you only check whether the call succeeded.

## Creating one

There is no rule to POST to — you PUT the whole phase entrypoint, so read it first if the zone
may already have rules:

```
PUT /zones/<zone>/rulesets/phases/http_request_dynamic_redirect/entrypoint
{"rules": [{
  "action": "redirect",
  "expression": "(http.host eq \"old.example\" or http.host eq \"www.old.example\")",
  "action_parameters": {"from_value": {
    "status_code": 301,
    "target_url": {"expression": "concat(\"https://new.example\", http.request.uri.path)"},
    "preserve_query_string": true
  }}
}]}
```

⚠ **`target_url.expression`, not `target_url.value`.** A static value sends every URL to one
page. On a rebrand that is the expensive mistake: Google treats mass redirects to a single
destination as soft-404s and discards the ranking signal rather than transferring it, and a
visitor following an old link lands on a homepage instead of the thing they wanted. `concat()`
with `http.request.uri.path` preserves the path, which also lets the destination site's own
redirect table finish the job — old path → Cloudflare → new domain, same path → Drupal
redirect → real page.

⚠ **The DNS record must exist and be PROXIED** for each hostname in the expression. Rules only
see traffic that reaches Cloudflare's edge — a grey-cloud record goes straight to origin and
the rule never fires, and a deleted record is NXDOMAIN, which is worse than the old site
still answering.

⚠ `templates/cloudflare/cf-rules.sh` is hardcoded to `http_request_firewall_custom` and will
not touch this phase — see [[waf-rule-tool]].
