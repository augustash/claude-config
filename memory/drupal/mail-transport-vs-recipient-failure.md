---
name: mail-transport-vs-recipient-failure
description: Watchdog says "error" whether one address bounced or the whole transport is dead — how to tell a revoked API key from weather the queue will fix itself
type: project
---

**Drupal logs a single bounced recipient and a completely dead mail transport at the same
`error` severity. The level cannot distinguish them; only the provider's status code can.**

The symptom that matters is silent. When the transport is rejected, the site keeps working
perfectly — forms submit, visitors get their thank-you page — and only the mail never
arrives. Nobody reports it because nobody can see it. Password resets, contact-form
notifications and order confirmations all go nowhere until someone replaces a credential.

## The codes that mean a human is required

Only **401 / 403** (and SMTP **530 / 535**) mean the credential is rejected: revoked,
rotated, or the account suspended. Nothing recovers on its own.

Everything else on `sendgrid_integration` is **retryable and self-healing** —
`SendGridMail.php` re-queues `-110, 404, 408, 500, 502, 503, 504` through
`SendGridResendQueue`, which drains on the next cron run. A 503 is weather. Treating it as
an outage means alerting on something that fixed itself four minutes later, which is how
people learn to ignore the alert.

`429` is throttling, not rejection. `5.1.x` / `5.2.x` / `5.4.x` SMTP codes,
`Recipient address rejected`, `User unknown` and `Mailbox unavailable` are one bad address,
not a dead transport.

## Matching on the sentence rather than the code will burn you

`sendgrid_integration` writes `Sending emails to Sendgrid service failed with error code N`
for *every* one of these — success and disaster share a sentence and differ only in `N`. A
pattern like `/sending emails to \w+ service failed/i` matches the self-healing case
identically to the fatal one.

Worse, if you group log entries by a normalised message (collapsing digits so repeats
collapse), 401 and 503 land in the **same group**. Judge the group on one sampled message
and a run of harmless blips gets classified off a single 401.

## Module wording differs in ways a single regex misses

Symfony Mailer and SwiftMailer phrase it backwards from SendGrid — `Failed to authenticate
on SMTP server` rather than `authentication failed` — so a pattern written from one vendor's
string silently never matches the other. Others worth covering: `Bad or missing API token`
(Postmark), `Invalid_Key` / `Unknown_Subaccount` (Mailchimp Transactional),
`The security token included in the request is invalid` (SES),
`The provided authorization grant is invalid, expired, or revoked` (Gmail OAuth).

## Corroboration is what makes it certain

Drupal's own `mail` channel logs `Error sending email (from … to … with reply-to not set).`
alongside a genuinely failing transport, but says nothing about *why* — it is useless alone
and decisive as a second signal. One noisy integration with the `mail` channel silent is a
single flaky send; both channels firing together is the transport.

Found on aaimolin-v2 (SendGrid 401, whole site unable to send). Related:
[[transactional-email-on-our-account]] for whose ESP account the key should belong to,
[[watchdog-programmatic-reads]] for getting the untruncated message in the first place.
