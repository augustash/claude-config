---
name: Cross-project Drupal patches
description: Index of known-good patches — local .patch files in ~/claude-config/patches/, and vetted remote URLs. Check this file and proactively recommend applicable patches when context matches.
type: reference
---

Cross-project patches we've vetted and want to avoid re-hunting. Two sections:

- **Local patches** — actual `.patch` files at `~/claude-config/patches/`. Copy into the project's `patches/` directory and reference from composer.json.
- **Reference patches** — URLs to drupal.org / GitHub issues that have worked for us across multiple projects. Reference directly from composer.json by URL; only localize if a project needs offline reliability or the URL goes dead.

## Proactive use

**Before starting work that touches a listed context, scan this file and recommend the applicable patches up-front.** Don't wait for the dev to hit the bug the patch fixes — mention the patches that match what they're about to do, let them decide. Triggers are in each entry's "Suggest when" line.

Format when recommending: name the patch, state what it fixes in one line, and note whether it's local (copy from `~/claude-config/patches/`) or remote (reference URL in composer.json). Don't install without confirmation — patches change version compatibility and must be a choice.

## Add criteria

Add an entry here **only** when a patch has proven useful in ≥2 projects. One-off project bug fixes stay in the project's own `patches/` dir — promoting them here is noise. When adding, include a concrete "Suggest when" so future sessions know the trigger.

## Local patches

### 3421202-nightwatch-w3c-backport.patch

- **Target:** `drupal/core` 10.x
- **What it fixes:** Drupal 10.x core Nightwatch doesn't handle the W3C webdriver mode that `ddev/ddev-selenium-standalone-chrome` uses. Without this patch, `sendKeys(ENTER)` and similar browser actions silently fail.
- **Source:** Backport of [drupal.org #3421202](https://www.drupal.org/project/drupal/issues/3421202).
- **Suggest when:** The project is about to add or run Nightwatch tests AND is using (or about to install) `ddev/ddev-selenium-standalone-chrome`. See [nightwatch-testing.md](nightwatch-testing.md) for the full setup including this patch.

## Reference patches

*(None vetted for cross-project promotion yet — most custom project patches are version-specific bug fixes. Candidates get added here after the second project proves the pattern.)*
