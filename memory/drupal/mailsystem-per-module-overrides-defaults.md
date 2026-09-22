---
name: mailsystem resolves a per-module sender before its defaults
description: "mail from one module vanishes with no error while everything else reaches Mailpit — mailsystem.settings pins that module to a provider plugin, and overriding system.mail or mailsystem's defaults in settings.local.php silently changes nothing for it"
type: reference
---

# A per-module mailsystem entry beats every default you override

`mailsystem.settings` carries **two** levels, and the per-module one wins:

```yaml
defaults:
  sender: postmark_mail       # what you think decides
modules:
  webform:
    none:
      sender: postmark_mail   # what actually decides, for webform
```

Point the defaults at `php_mail` in `settings.local.php` and every module obeys — except the
ones with their own entry. On md that was `webform`, which is *every form on the site*, so no
form notification was locally testable while the settings file said mail goes to Mailpit.

## The failure is silent, which is the whole problem

With no API key the provider plugin neither delivers nor throws:

```
submit the form  → "your message has been sent"
Mailpit          → empty
watchdog         → nothing
```

Nothing anywhere says the message went to a provider that dropped it. The obvious reading is
"the form is broken", and the obvious next step — re-reading the email handler — is the one
place the answer is not.

## Override both levels

```php
$config['system.mail']['interface']['default'] = 'php_mail';
$config['mailsystem.settings']['defaults']['sender'] = 'php_mail';
$config['mailsystem.settings']['defaults']['formatter'] = 'php_mail';
// The one that actually matters for webform mail:
$config['mailsystem.settings']['modules']['webform']['none']['sender'] = 'php_mail';
$config['mailsystem.settings']['modules']['webform']['none']['formatter'] = 'php_mail';
```

⚠ **`system.mail` alone is not enough either.** The mailsystem module replaces
`plugin.manager.mail` with its own manager, which reads its own config — so overriding core's
`system.mail` looks right and changes nothing. Set both: `system.mail` is what anyone reading
Drupal core expects to be true, and leaving the two disagreeing is its own trap.

⚠ **Check which modules have an entry before assuming the defaults cover you** —
`drush cget mailsystem.settings --format=yaml` and read the `modules:` key. Anything listed
there is exempt from whatever you just set.

⚠ **reroute_email is not a substitute.** It rewrites the recipient; it does not change which
plugin sends. An empty reroute address makes it worse — reroute *cancels* the send when it has
nowhere to put it, so the message dies before any interface sees it. Give it a real address on
a local hostname.

See [[transactional-email-on-our-account]] for whose provider account this should be in the
first place.
