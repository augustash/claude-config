---
name: contact-hidden-subject-d11
description: On D11 a contact form with its Subject field hidden stores every submission and mails none; the visitor gets a 500
metadata:
  type: reference
---

# A hidden contact Subject breaks every submission on D11

Contact left core for contrib (`drupal/contact`) in D11. Its `hook_mail()` passes
`$contact_message->getSubject()` as the `@subject` placeholder, and a form whose
*Manage form display* hides Subject leaves it NULL. D11's typed `Html::escape(string)`
throws:

```
TypeError: Html::escape(): Argument #1 ($text) must be of type string, null given
  … contact/src/Hook/ContactHooks.php → MailManager → MessageForm::save()
```

D10 coerced the NULL to an empty string, so a form that ran for years breaks the
moment the D11 deploy lands.

**The trap is that nothing else looks wrong.** `MessageForm::save()` stores the message
*before* mailing, so with `contact_storage` installed every submission is in the
database. The throw then aborts the mail and serves the visitor a 500. Page crawls,
smoke tests and console checks all pass, because only a POST reaches it. On mspairport
(2026-10-21) every form hid Subject: 18 submissions across 16 hours, no email, people
retrying three times. A post-launch log audit found it as the only 500s in the access
log, all `POST /contact-us` or footer newsletter posts to whatever page the visitor was on.

**Fix:** upstream MR [contact !2](https://git.drupalcode.org/project/contact/-/merge_requests/2)
on [#3515019](https://www.drupal.org/project/contact/issues/3515019), still open at 1.0.0
and 1.x-dev. Carry its `src/` hunks as a local patch (msp:
`patches/contact-hidden-subject-3515019.patch`). The subject becomes *submission from
<site name>*, and the sender name falls back the same way. Drop the patch when it releases.

**What doesn't work:** defaulting the subject to `''` in a `contact_message` presave hook.
Field presave filters empty items, so `''` is back to NULL before the mail runs. A kernel
test caught it. Any non-empty default puts words in the subject nobody chose.

**Recovering what was missed:** the stored messages can be re-mailed from drush with
`\Drupal::service('contact.mail_handler')->sendMailMessages($message, User::getAnonymousUser())`.
Check the forms' `reply` (auto-reply) first, or visitors get a day-late reply. Dedupe the
retries by fingerprinting their `field_*` values; the core mail/message fields are often
hidden too and read empty.

Related: [[mailsystem-per-module-overrides-defaults]]
