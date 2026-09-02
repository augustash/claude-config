---
name: Cloudflare rules silently break Let's Encrypt renewal
description: A WAF/geo/bot rule in front of /.well-known/acme-challenge/ breaks HTTP-01 renewal — silently, surfacing as total TLS failure 60-90 days later
type: reference
---

A WAF custom rule, geo challenge, or Super Bot Fight Mode sitting in front of
`/.well-known/acme-challenge/` breaks HTTP-01 certificate renewal. **The site keeps working
normally for the remaining life of the cert, then every browser rejects it at once.**

This is the highest-consequence, lowest-visibility mistake available in a Cloudflare config,
and it is increasingly made by people who don't own the origin — client IT, a marketing
agency, whoever had the dashboard open during an attack. Assume nobody who adds a rule is
thinking about certificates.

## Why it goes unnoticed

- **The delay.** Renewal runs ~30 days before expiry, so the break surfaces up to 60-90 days
  after the rule change. Nobody connects a browser-wide TLS error to a firewall edit from two
  months prior.
- **Your own test passes.** `curl`-ing the challenge path from a US desk succeeds, because the
  geo rule allows your country. Let's Encrypt validates from **multiple global perspectives** —
  a geo challenge that permits North America still fails validation from the other vantage
  points.
- **Nothing alerts.** A failed renewal is a quiet retry, not an outage, until expiry.

## When it applies — and when it doesn't

**At risk:** the origin issues its own cert via HTTP-01.

- Pantheon custom domain with DNS pointed **directly at Pantheon**
- WP Engine, or certbot on a VPS
- Any Cloudflare zone in **DNS-only (grey cloud)** mode, where the origin still answers directly

**Not at risk:** the CDN terminates TLS and issues its own cert via DNS-based DCV. On a
Cloudflare-proxied zone the edge cert is Cloudflare's (issued by Google Trust Services) and
validated through DNS Cloudflare already controls — no HTTP challenge crosses the WAF.

**Check which you are before assuming either.** DNS is the tell:

```bash
dig +short A example.com          # Cloudflare: 104.x / 172.67.x  |  Pantheon: 23.185.0.4
echo | openssl s_client -connect example.com:443 -servername example.com 2>/dev/null \
  | openssl x509 -noout -issuer -dates
```

Google Trust Services = Cloudflare's edge cert. Let's Encrypt = something is doing ACME, so
find out what and whether its challenge path is reachable.

On Pantheon, `terminus domain:list <site>.<env>` reporting **`action_required` / "Setup
Required"** on a custom domain is *expected and benign* when the zone is Cloudflare-proxied —
it means DNS points at Cloudflare rather than Pantheon, so Pantheon can't validate and never
issues a cert for that domain. Don't chase it, and don't "fix" it by repointing DNS at
Pantheon without also handling the edge cert.

## The rule to add

Give `/.well-known/` an unconditional skip that **also clears remaining custom rules**, or the
geo challenge still catches non-US validators:

```
starts_with(http.request.uri.path, "/.well-known/")
```
Action `skip` → phases `http_ratelimit`, `http_request_firewall_managed`, `http_request_sbfm`,
**plus `ruleset: current`**, positioned **above** any geo/challenge rule.

Keep the whole `/.well-known/` prefix rather than narrowing to `acme-challenge` — Apple Pay
domain verification for Stripe lives at
`/.well-known/apple-developer-merchantid-domain-association`, and narrowing breaks its
re-verification just as silently.

Use `starts_with`, never `contains`: an unanchored `contains` on a path is a WAF bypass any
visitor can use by embedding the string in a URL.

**When to apply:** any time a Cloudflare rule is added, reviewed, or inherited on a site whose
origin might issue its own cert — which is most of them, and increasingly not sites we
control. Cheap to add, silent and total to omit. Related: [[cloudflare-tracking-params]].
