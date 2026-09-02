---
name: A WAF rule keyed on http.referer exempts the attacker and penalises real users
description: Referer is client-controlled, so a scraper forges a same-site one while real users often send none. A rule excluding same-site referers inverts — measure any candidate condition against real traffic before shipping it.
type: reference
---

`http.referer` is set by the client. A scraper sets it to whatever gets it through; a real
browser frequently sends **nothing** — referrer-policy stripping, direct navigation, bookmarks,
a shared filtered link. So a condition of the form *"act unless the referer is our own domain"*
tends to **invert**: it exempts the attacker and actions the customers.

## The case

sisal (2026-08) had a rule named "Bot Slaughterhouse" aimed at facet-enumeration crawling:

```
managed_challenge
(http.request.uri.query contains "f%5B" and not http.referer contains "sisalrugs.com")
```

Measured against one day of origin logs (572k requests) plus Cloudflare's own
`firewallEventsAdaptiveGroups`:

| | crawler | real users |
|---|---|---|
| sends `sisalrugs.com` referer | **95.7%** — exempted | 35% |
| sends no referer | 4.3% | **65%** — challenged |

The rule fired 13,188 times that day; the origin log independently showed 13,057 no-referer
crawl requests. Two sources agreeing is what confirmed it was catching only the sliver that
did not bother to forge a header, while 290,684 requests walked past it.

A second, quieter hole: `contains "f%5B"` matches the URL-encoded bracket only. 4.3% of the
crawl sent raw `f[` and never matched at all. **Check both encodings** whenever a rule matches
on a query-string token.

**The challenge action was not the weak part.** Of 13,188 challenges only 135 were solved or
bypassed — 1%. Managed Challenge is highly effective against a residential-proxy pool; the
condition gating it was the failure.

## Key on request shape instead

Prefer something the attacker cannot change without abandoning the attack. Here, facet
enumeration means a long query string, and the app's own limit (`max_facets: 6`) defines what
legitimate looks like:

```
(http.request.uri.query contains "f%5B" or http.request.uri.query contains "f[")
and len(http.request.uri.query) > 300
```

`len()` is accepted on **Pro** — it is `matches` (regex) that needs Business+, so counting
parameters directly is not available below that, and length is the workable proxy.

## Measure the condition against real traffic first

Two candidate rules were discarded by checking, not by reasoning:

- **Facet-index thresholds don't work.** `f[6]` looks like "more than 6 facets", but indices go
  sparse when a user removes a filter, so legitimate ≤6-facet requests reach index 19. Matching
  `f[6]` would have actioned 431 real requests in one day.
- **Query length separates cleanly.** Legitimate faceted requests topped out at 242 characters;
  the crawl ran to 862. A threshold of 300 caught 428k crawler requests and **zero** legitimate
  ones, with a 58-character margin.

The check that caught the bad rule was looking at the requests that **succeeded**, not just the
ones already being throttled. A candidate condition looks perfect while you only examine
traffic you already believe is hostile — same error shape as [[prove-code-is-dead]].

Related: [[waf-rule-tool]] (pulling rules and events), [[bot-fight-mode-unskippable]],
[[waf-blocks-acme-renewal]].
