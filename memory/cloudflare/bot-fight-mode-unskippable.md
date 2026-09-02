---
name: Free Bot Fight Mode cannot be skipped by any WAF rule
description: A server-to-server integration gets 403 + an HTML challenge page while the origin log shows nothing; the WAF skip rule written to exempt it is a no-op because free Bot Fight Mode is not a phase
type: reference
---

An API client — an ERP connector, a monitor, a partner integration — starts failing. The
consumer reports a **parse error** (`Newtonsoft`, `json.decode`, "unexpected token <"), because
it asked for JSON and got an HTML challenge page. **The origin access log shows nothing at
all**: the requests stop appearing, yet the client keeps receiving a body.

A body with no origin hit means something in front of the origin answered. On a Cloudflare
zone the usual culprit is **Bot Fight Mode** — the free one, under Security → Bots.

## Why the obvious fix doesn't work

Bot Fight Mode is **not a WAF phase**. A custom rule with action `skip` can name
`http_ratelimit`, `http_request_firewall_managed`, `http_request_sbfm` — and `sbfm` is
**Super** Bot Fight Mode, a Pro-and-up feature. The free one has no phase, no allowlist, no
path exclusion, and no per-IP exception.

So a skip rule that is enabled, correctly scoped, and demonstrably matching the client's IP
still changes nothing. Cloudflare's own event log will show the rule firing as a `skip` while
the same requests are challenged by `botFight` in the same second. This reads as a broken rule
and sends you rewriting an expression that was never wrong.

Free-tier Bot Fight Mode scores datacenter ASNs as automated more or less by definition, so
**any integration hosted on AWS/Azure/GCP is caught** — which is every SaaS vendor's egress.

Legacy **IP Access Rules → Allow** did bypass it, and much older guidance still says so.
Cloudflare has retired that surface on newer zones: the nav entry is gone and
`/zones/{id}/firewall/access_rules/rules` returns `10000`. Check whether the zone actually has
it before recommending it — the old dashboard URL now redirects into Security → Security rules,
which makes it look present when it isn't.

**On a Free zone the only lever is turning it off.**

## Confirming it in one query, before changing anything

`firewallEventsAdaptive` attributes every action to a named service, so this is a lookup rather
than a bisect (see [[cloudflare-waf-rule-tool]] for the tool and the token setup):

```
source = botFight    ruleId = bot_fight_mode    action = managed_challenge
```

Toggling settings and re-testing is the slow path and cannot see a setting already reverted.
Ask the event log who acted instead.

## Why it keeps happening

It gets switched on **mid-incident**, during a card-testing or scraping response, by whoever
had the dashboard open — and it works, so nobody revisits it. The integration it broke fails
silently into a vendor's log, and the breakage surfaces days later as a third-party complaint
with no obvious link to the attack response. On one site it cost six days of ERP order sync;
746 consecutive requests, zero successes, while every check anyone ran looked clean because
Bot Fight Mode is a toggle and leaves **no ruleset version** to diff.

Corollary worth internalising: if a zone's config changed but the custom ruleset's version
history shows nothing, look at the toggles — Bot Fight Mode, Under Attack, Security Level,
Browser Integrity Check. Only the account audit log records those.

## Turning it off responsibly

It was usually protecting something real. Before removing it, confirm what else is standing:
geo/challenge custom rules, Turnstile or reCAPTCHA on the forms that matter, and rate limiting.
Check those actually fire rather than assuming — a rate limit scoped to the Store API does
nothing on a store running classic AJAX checkout, and Free-plan rate limiting cannot match on
query string at all.

Verification is free when the broken client polls on a schedule: turn it off, wait one interval,
and look for 2xx. No need to coordinate a test with the vendor.

Related: [[cloudflare-waf-rule-tool]], [[waf-blocks-acme-renewal]].
