---
name: Local/temporary config overrides go in settings.local.php, never active config
description: Toggle dev settings (CSS/JS aggregation, dev flags) via $config overrides in settings.local.php — never drush config:set or the UI — so a stray change can't be exported and deployed to live.
type: feedback
---

Any temporary or environment-local configuration change — disabling CSS/JS aggregation, dev flags, error verbosity — must be done as a **`$config` override in `settings.local.php`**, never via `drush config:set` / `cset` or the admin UI against real config.

**Why:** a `config:set` writes to *active* config, which then shows as a diff in `drush config:status` and can be swept into a `drush cex` and committed — silently shipping the dev-only change (e.g. aggregation OFF) to live, a real performance/behavior regression. `settings.local.php` is per-environment and never exported, so the override stays local.

**How to apply:**

- Toggle aggregation locally in `settings.local.php`:
  ```php
  $config['system.performance']['css']['preprocess'] = FALSE;
  $config['system.performance']['js']['preprocess'] = FALSE;
  ```
- Need a different config value just to test something? Override it in `settings.local.php`, not with `cset`.
- If you *did* run `cset` while debugging, immediately check `drush config:status` and revert so nothing stray is left to export.
