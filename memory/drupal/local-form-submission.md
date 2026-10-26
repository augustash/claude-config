---
name: local-form-submission
description: Submitting a site's forms end to end on ddev after a live DB pull — captcha test keys, antibot, page-less webforms, and mail that leaves the machine.
metadata:
  type: reference
---

# Submitting forms locally after a live pull

A GET crawl never runs a submit handler, so an upgrade or update round has to actually submit
each form and see the mail arrive ([drupal-11-upgrade](../../skills/drupal-11-upgrade/SKILL.md)
done list). Four things stand in the way, and one of them sends real email.

**1. Mail leaves the machine.** A live pull brings live's SMTP credentials when they live in
config (usually behind config_ignore, so git shows them empty). `SMTPMailSystem` ignores
`smtp_on` when sending; mailsystem picks the sender. So local submissions go out through the
client's real mail account, and Mailpit stays empty while watchdog says *sent*. On wac
(2026-10-26) two test submissions were handed to the district's Gmail SMTP, logged without
error, before anyone noticed. reroute_email had sent them to a dev, but only because it
happened to be on. Set this before submitting
anything:

```php
// settings.local.php
$config['mailsystem.settings']['defaults']['sender'] = 'php_mail';
$config['mailsystem.settings']['defaults']['formatter'] = 'php_mail';
$config['smtp.settings']['smtp_password'] = '';
```

Check a module-level row in `mailsystem.settings:modules` doesn't route around it
([[mailsystem-per-module-overrides-defaults]]). Then read Mailpit from inside the
container: `ddev exec 'curl -s "http://127.0.0.1:8025/api/v1/messages?limit=10"'`.

**2. Captchas fail on localhost.** The production site key isn't registered for `*.ddev.site`
(Turnstile shows error 110200). Use each vendor's always-pass test keys, in
`settings.local.php`:

```php
// Turnstile: the testing pair overrides the Key entity when both are set.
$config['turnstile.settings']['testing_site_key'] = '1x00000000000000000000AA';
$config['turnstile.settings']['testing_secret_key'] = '1x0000000000000000000000000000000AA';
// reCAPTCHA v2, for any form still pinning it.
$config['recaptcha.settings']['site_key'] = '6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI';
$config['recaptcha.settings']['secret_key'] = '6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe';
```

A webform element can pin `#captcha_type` and ignore the site default, so one site can need
both. A form still pinned to reCAPTCHA after a Turnstile migration is worth flagging.

**3. Antibot never unlocks on typing.** The form posts to `/antibot` until the body sees a
`mousemove`, a `touchmove`, or a **Tab or Enter** keydown. Plain characters don't count. In a
driven browser, press Tab once after filling; check the form's `action` has switched to the
real path before clicking submit.

**4. Some webforms have no page.** A webform with `page: false` returns 403 at
`/webform/<id>` (on live too). It's embedded through a webform field on a node; find the host
pages by querying every `webform`-type field for the id, then submit there.

Programmatic `WebformSubmissionForm::submitFormValues()` skips all of this but also skips
the captcha, antibot and the real form build, so it proves the handlers and nothing else.
Use the browser.
