---
name: ddev-drupal-pantheon-site-var
description: augustash/ddev-drupal exports the Pantheon site machine name as `PANTHEON_SITE` in older versions, `DDEV_PANTHEON_SITE` in newer versions, and `project=<site>.<env>` in the oldest. All live in `.ddev/config.yaml` under `web_environment`. Grep for all three when looking up the identifier.
metadata:
  type: reference
---

`augustash/ddev-drupal` exports the Pantheon site machine name (the `terminus` site identifier) as a `web_environment` variable in `.ddev/config.yaml`:

- **Oldest releases:** `project=<machine-name>.<env>` — a single var packing both the site and the environment, dot-separated (e.g. `project=ar-telos.live`). The original `pantheon.yaml` provider split it with `IFS='.'` → `[0]`=site, `[1]`=env.
- **Older releases:** `PANTHEON_SITE=<machine-name>` (env in separate `WORKING_ENVIRONMENT=`)
- **Newer releases:** `DDEV_PANTHEON_SITE=<machine-name>` (env in separate `DDEV_PANTHEON_ENVIRONMENT=`)

The variable was renamed across recipe refreshes; sites that haven't updated the package still carry the old form. All point at the same value (the Pantheon dashboard slug, used in `terminus drush <name>.<env> -- ...` and `https://dashboard.pantheon.io/sites/<name>`).

`Ddev::migratePantheonEnv()` (in the ddev-drupal / ddev-wordpress packages) auto-migrates all of these forward on a `ddev-setup -- -u` run — including splitting the oldest `project=<site>.<env>` into the two `DDEV_`-prefixed vars — so detection and the pantheon-db add-on hook light up without re-prompting.

**How to apply:** When you need the Pantheon site identifier on an augustash project, grep `.ddev/config.yaml` for `project=`, `PANTHEON_SITE`, and `DDEV_PANTHEON_SITE` rather than guessing from the repo or live URL — those rarely match the Pantheon machine name.

Related: [[repositories]]
