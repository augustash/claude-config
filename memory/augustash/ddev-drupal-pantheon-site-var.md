---
name: ddev-drupal-pantheon-site-var
description: augustash ddev recipes export the Pantheon site + environment as `web_environment` vars in `.ddev/config.yaml`, renamed across three generations (oldest `project=<site>.<env>`; older `PANTHEON_SITE`/`WORKING_ENVIRONMENT`; current `DDEV_PANTHEON_SITE`/`DDEV_PANTHEON_ENVIRONMENT`). `DDEV_`-prefix is current; grep all forms. `Ddev::migratePantheonEnv()` auto-migrates on `-u`.
metadata:
  type: reference
---

`augustash/ddev-drupal` and `augustash/ddev-wordpress` export the Pantheon site machine name (the `terminus` site identifier) and target environment as `web_environment` variables in `.ddev/config.yaml`. Both vars were renamed across three generations:

| Generation | Site | Environment |
|---|---|---|
| Oldest | `project=<site>.<env>` (single packed var, e.g. `project=ar-telos.live`; original `pantheon.yaml` split it on `IFS='.'`) | — (packed in `project=`) |
| Older (pre-prefix) | `PANTHEON_SITE=<site>` | `WORKING_ENVIRONMENT=<env>` |
| Current | `DDEV_PANTHEON_SITE=<site>` | `DDEV_PANTHEON_ENVIRONMENT=<env>` |

All point at the same value (the Pantheon dashboard slug, used in `terminus drush <site>.<env> -- ...` and `https://dashboard.pantheon.io/sites/<site>`).

**Why the `DDEV_` prefix (current gen):** these track ddev's *stock* `pantheon.yaml` provider, which renamed its vars because the unprefixed names **collide with Pantheon's own server-side env vars** (Pantheon's platform sets `PANTHEON_ENVIRONMENT` to dev/test/live on its containers). ddev namespaced everything under `DDEV_` to kill the collision; augustash followed (ddev-drupal "Update to use new Pantheon variables", 2026-03). The source of truth for the current names is `Ddev::migratePantheonEnv()` in `src/Ddev.php` — not the stock `pantheon.yaml`, which is the upstream ancestor and sits vestigial/unused in projects (pulls go through the augustash `pantheon-db` provider, not stock `pantheon`).

**Looks like a migration gap but isn't:** ddev passed through an intermediate env name `PANTHEON_ENVIRONMENT` (the colliding one) before `DDEV_PANTHEON_ENVIRONMENT`. **augustash never shipped `PANTHEON_ENVIRONMENT`** — its lineage went `WORKING_ENVIRONMENT` → `DDEV_PANTHEON_ENVIRONMENT` directly. So `migratePantheonEnv()`'s rename map (`project=`, `PANTHEON_SITE=`, `WORKING_ENVIRONMENT=` → `DDEV_*`) is **exhaustive for augustash configs** even though it omits `PANTHEON_ENVIRONMENT`. Don't "fix" that omission — no augustash project carries that name.

**Producer / consumer split:**
- **Producers** — `ddev-drupal` / `ddev-wordpress` carry identical `Ddev::migratePantheonEnv()` logic that writes/migrates the vars into `config.yaml` on a `ddev-setup -- -u` run, so detection and the `pantheon-db` add-on hook light up without re-prompting. (The duplicated migration code in both packages is a drift risk — fix one, remember the other.)
- **Consumer** — `ddev-pantheon-db` (provider `pantheon-db.yaml` + `commands/host/db`) reads only the current `DDEV_PANTHEON_*` names and assumes the producer already migrated. No standalone back-compat shim, so it depends on being paired with ddev-drupal/ddev-wordpress (always the case in practice).

**How to apply:** When you need the Pantheon site identifier or target env on an augustash project, grep `.ddev/config.yaml` for `project=`, `PANTHEON_SITE`/`WORKING_ENVIRONMENT`, and `DDEV_PANTHEON_SITE`/`DDEV_PANTHEON_ENVIRONMENT` rather than guessing from the repo or live URL — those rarely match the Pantheon machine name. Legacy forms migrate forward on a `-u` run.

Related: [[repositories]]
