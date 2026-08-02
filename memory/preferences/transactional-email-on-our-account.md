---
name: Transactional email runs on our account, the client pays for it
description: "Stand up the site's transactional email provider on an August Ash account and tell the client to pay the fee — do not route the site through the client's existing ESP, even when their SPF shows they already have one and reusing it would look like a saving. Holding the account is what makes a delivery problem ours to fix in minutes instead of a ticket in their IT queue."
type: feedback
---

# Transactional email runs on our account, the client pays for it

When wiring a site's transactional mail (Postmark, or whatever the equivalent is), the account
is **ours**. The client is told to pay the fee — it is typically ~$15/month and is never the
deciding factor.

**Why:** if the site sends through the client's provider, every delivery problem is debugged
through the client's IT department. Kaza stopped accepting that years ago. Owning the account
means an email issue is fixed directly, in minutes, by the person who is going to be asked
about it anyway.

**How to apply:** this is a standing decision, not a per-project judgement call. Two arguments
will present themselves and both have already been heard:

- *"Their SPF already includes an ESP, so they have one — reuse it."* No. Discovering an
  existing `include:` (SMTP2GO, SendGrid, Mailgun…) is worth **mentioning**, not acting on.
- *"It saves the client a subscription."* No. The fee is theirs to pay and is not the axis the
  decision turns on.

Raise it once if the situation looks genuinely novel, then proceed on our account.

⚠ **Owning the account does not remove the DNS step**, since the sending domain is still
theirs — DKIM and a Return-Path record have to exist on it. Check who runs the domain's
nameservers before assuming that means client involvement: on a project where we already
manage DNS (Cloudflare, commonly), the records are ours to add and there is no dependency at
all. See [[pantheon-secrets]] for where the resulting API token belongs — never config.

⚠ **Do not add the provider to an existing root SPF record.** Use the provider's custom
Return-Path subdomain instead, so SPF aligns on that subdomain. A client's root SPF is usually
carrying their mail platform plus two or three other includes and a `-all`; editing it to solve
our problem risks breaking theirs, and the failure lands on their staff email rather than on
the site.
