---
name: Webforms are live-only config
description: "webform.webform.* is in config_ignore on nearly every site so clients can edit forms; the yml in config/ is stale and git never records a webform change — read the live DB instead"
type: reference
---

# Webforms are live-only config

Almost every augustash Drupal site puts `webform.webform.*` in `config_ignore`, because clients
edit their own forms. Two consequences follow:

- **The yml in `config/` is not the truth.** It is whatever the last `cex` caught, often years
  old. Checking a form's elements, handlers or recipients there answers the wrong question.
- **Our own webform fixes leave no trace in git.** A change made for a client, such as adding
  Turnstile or changing a recipient, goes onto live with `terminus drush … php:eval`, because
  a deploy can't carry it. So when someone asks "didn't we already fix this?", an empty
  `git log` doesn't prove the work never happened.

**How to apply:** for any question about how a form behaves now, pull a fresh DB (or run
`terminus drush <site>.live -- cget webform.webform.<id>`) and read it there. To find a past
fix, look in the session transcripts and the site's change notes, not the repo.

Incident, metro 2026-09-29: a scan of `config/` reported three open forms without a CAPTCHA
(all had one on live), and a Turnstile fix made the day before seemed to have vanished because
it existed only on live.
