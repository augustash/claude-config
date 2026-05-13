---
name: confirm-before-live-terminus
description: Always confirm before running any terminus command against a live or test environment. Local/dev/multidev are usually fine without confirmation.
metadata:
  type: feedback
---

Always confirm before running terminus commands against `live` (and generally `test`) environments. Local/dev/multidev are usually fine to run without asking.

**Why:** User wants to know before commands hit shared/production state — terminus drush commands can mutate production data (cache rebuilds, sitemap regeneration, db writes) and even read-only commands burn through Pantheon API rate limits if run in a loop.

**How to apply:** Before any `terminus * {site}.live ...` or `terminus * {site}.test ...` invocation, state what command will run and what it will do, then ask for confirmation. Local DDEV / dev / multidev environments don't need confirmation.

Confirmation can be batched — if the user OKs a list of read-only commands ("all of those are fine"), proceed with that whole list without re-asking. Confirmation does need to be re-requested when leaving a confirmed batch into new commands (especially if any new command might write).

Related: [[ddev-drupal-pantheon-site-var]]
