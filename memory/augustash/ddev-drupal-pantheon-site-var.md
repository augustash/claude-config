---
name: ddev-drupal-pantheon-site-var
description: augustash/ddev-drupal exports the Pantheon site machine name as `PANTHEON_SITE` in older versions, `DDEV_PANTHEON_SITE` in newer versions. Both are in `.ddev/config.yaml` under `web_environment`. Grep for both when looking up the identifier.
metadata:
  type: reference
---

`augustash/ddev-drupal` exports the Pantheon site machine name (the `terminus` site identifier) as a `web_environment` variable in `.ddev/config.yaml`:

- **Older releases:** `PANTHEON_SITE=<machine-name>`
- **Newer releases:** `DDEV_PANTHEON_SITE=<machine-name>`

The variable was renamed during a refresh of the recipe; sites that haven't updated the package still use the unprefixed name. Both variants point at the same value (the Pantheon dashboard slug, used in `terminus drush <name>.<env> -- ...` and `https://dashboard.pantheon.io/sites/<name>`).

**How to apply:** When you need the Pantheon site identifier on an augustash project, grep `.ddev/config.yaml` for both `PANTHEON_SITE` and `DDEV_PANTHEON_SITE` rather than guessing from the repo or live URL — those rarely match the Pantheon machine name.

Related: [[repositories]]
