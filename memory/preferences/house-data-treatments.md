---
name: Data gets the house treatment on every project
description: How we present contact data (phones, emails) is a settled decision carried from site to site, mocks included, until something better replaces it everywhere.
type: feedback
---

Some decisions about how data is treated are **standing house decisions**, not per-site
design calls. Every project gets them, and so does every mock and proposal page, even a fake one,
because the concept is part of what we're showing. They change only when we find something
better, and then they change everywhere.

**Why:** Kaza, su proposal 2026-10-30: *"There are many decisions that are a basis of how we treat
data, and we'll always do those things the same way, until we find something better."* He said
this while the Syracuse Utilities pitch was getting the md call card. Reinventing these per
project loses the hard-won detail and gives each site a different answer to the same question.

**The current treatments.** Reuse the reference implementation; don't rebuild from memory.

- **A phone number opens a call card.** The card shows a QR code to scan from a desk, the number
  as a `tel:` link to tap on a phone, and the hint "Unlock your phone, then scan to call" set in
  alert red. An iPhone scanning from the lock screen offers Messages instead of Call. Encode the
  QR as `TEL:+1…`: the `+1` makes it dial from anywhere, and uppercase keeps it in QR
  alphanumeric mode, which makes a smaller code. Reference: md, `md_locator/js/sales-map.js`
  (`openCall`, `qr`, `telUri`), library `qrcode-generator`.
- **An email address ships as a decoy and is resolved on click.** The markup carries a
  plausible wrong address, which harvesters take and which bounces, plus an opaque token that
  only the server can reverse, through a flood-controlled endpoint. Don't use entity-encoding or
  JS string assembly: they announce that something was hidden. Reference: md,
  `md_core/src/Mail/EmailCloak.php` and `/api/mail`. A static page has no server, so it states
  the treatment in copy instead of faking it.

**How to apply:** before rendering a phone number or an email on any site or proposal, check this
list and use the treatment. When a new treatment gets settled the same way, add it here.

Related: [[follow-site-conventions]] is the same rule within one codebase; this one runs across
codebases.
