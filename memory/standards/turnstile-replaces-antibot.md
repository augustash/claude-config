---
name: turnstile-replaces-antibot
description: Standard — a site that runs Turnstile doesn't also run antibot; move antibot's forms onto Turnstile, uninstall it, then remove the package.
metadata:
  type: project
---

# Standard: Turnstile replaces antibot

When a Drupal site has Turnstile, antibot comes out: uninstalled first, then removed from
composer in a later release.

**Why:** antibot is a weaker challenge, and once Turnstile is there it's a second layer that
mostly overlaps it. What it can still do is hide the forms only it covers. Kaza made it the
rule on wac (2026-10-26). There antibot's settings listed the login, password reset and
registration forms, and their Turnstile captcha points had sat disabled behind it, so
uninstalling without moving them would have left login with no challenge at all. The same
pass found a public webform with neither.

**Check** what antibot covers that Turnstile doesn't:

```bash
ddev drush cget antibot.settings form_ids
ls config/captcha.captcha_point.*.yml   # status: false on any of antibot's forms?
ddev drush php:eval 'foreach (\Drupal::entityTypeManager()->getStorage("webform")->loadMultiple() as $w) { $c=$w->getElementDecoded("captcha"); echo $w->id().": ".($c ? ($c["#captcha_type"] ?? "default") : "NONE")."\n"; }'
```

**Apply:**

1. Enable a Turnstile captcha point for every form in antibot's `form_ids` that the site
   actually serves (login, password reset, and registration if it's open).
2. Webforms are usually config-ignored ([[webforms-live-only-config]]), so add a `captcha`
   element (or drop a pinned `#captcha_type`) in a `MODULE.deploy.php` hook rather than in
   `config/`. Deploy hooks run after `cim`, so they land in the same deploy.
3. Uninstall antibot in a **`post_update` hook** (`module_installer->uninstall(['antibot'])`),
   then `pmu` + `cex` locally to drop it from `core.extension`. The uninstall strips antibot's
   third-party settings from each webform itself. Leaving the uninstall to `cim` fails the
   deploy wherever webforms are config-ignored: the import can't touch those webforms, so it
   refuses to remove a module they still depend on ("Configuration webform.webform.contact
   depends on the Antibot module that will not be installed after import"). A post-update runs
   in `updb`, before `cim`. A local `pmu` hides this, so only the deploy shows it: wac's
   drupal11 multidev failed exactly so, 2026-10-27, and passed with the hook.
4. Remove `drupal/antibot` from composer in the **next** release. Live still has it enabled
   until this one imports, and Drupal 11 refuses `updb` while an enabled module is missing.

Turnstile on the login form blocks any environment whose hostname isn't registered for the
site key, so check login on dev or a multidev after the deploy (`terminus drush … uli` gets
you in if not). Locally, use the test keys in [[local-form-submission]].
