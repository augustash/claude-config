---
name: Use ddev for all commands
description: Always use ddev drush / ddev wp — projects run in ddev containers
type: feedback
---

Always use `ddev drush` or `ddev wp` for CLI commands, not `vendor/bin/drush` or direct `wp`.

**Why:** All projects run in ddev; direct commands won't work or may target wrong PHP/DB.

**How to apply:** Prefix all drush/wp-cli commands with `ddev`.
