---
name: An active split whose modules aren't installed empties its folder on export
description: "drush cex deletes everything in a split folder (config-dev/) when the split is active but the modules in its module: list aren't installed — normal after a prod DB pull, and it reads as a broken split. Restore from git, cim to install them, re-export. Plain `cget` hides the settings.local.php status override; use --include-overridden."
type: reference
---

# An active split whose modules aren't installed empties its folder on export

A routine `drush cex` after updates deletes the entire split folder:

```
 D config-dev/devel.settings.yml
 D config-dev/kint.settings.yml
 D config-dev/stage_file_proxy.settings.yml
 ...
```

Nothing is misconfigured. config_split is an **export-side filter over active config**: an active split writes its folder from whatever the site currently has installed. If the modules in its `module:` list aren't installed, there is no active config to relocate, so the folder is written empty — silently, as an ordinary export result.

**Why the modules are missing:** the local DB was pulled from prod, where the split is inactive and those modules are therefore uninstalled. Nobody ran `cim` after the pull, so the dev tooling never came back. Same "a DB carries whatever its origin env had enabled" mechanism as [[config-split-ignore-collision]], seen from the export side instead of the import side.

**Diagnose** — both halves must be true:

```
drush cget config_split.config_split.dev status --include-overridden   # true
drush pm:list --status=enabled --format=list | grep -E 'devel|kint|…'  # empty
```

`--include-overridden` is not optional. Splits are activated per-env by a `$config['config_split.config_split.dev']['status'] = TRUE;` line in `settings.local.php`, and plain `cget` reports the **stored** value (`false`) — which reads as "the split is off, so it can't be the split," pointing the investigation the wrong way.

**Fix:** `git checkout -- config-dev/`, then `drush cim`. With the split active the import installs the dev modules and restores their config; re-exporting is then a no-op. Do the `cim` as part of every prod DB pull and this never happens.

**Don't revert every deletion in the same breath.** A post-update export mixes this in with legitimate removals — Drupal 11 dropped `field.settings` outright (`web/core/modules/field/config/install/` no longer exists), so `D config/field.settings.yml` next to the split-folder wipe is correct and comes from `updatedb`. Check whether core still ships the item before restoring it.

First hit: aaikow-v2 (kow) 2026-07-29, exporting after a D11 update on a prod-sourced DB. See [[cross-version-db-pull]] for the rest of the post-pull ordering story.
