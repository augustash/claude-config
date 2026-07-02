---
name: ddev-wordpress-wpengine-gate
description: augustash/ddev-wordpress auto-fixes WP Engine sites on every composer update (postUpdate) — gates wp-config.php so ddev's DB creds win, and un-ignores .ddev/ in the WPE `/*` deny-all .gitignore. Detection keys on WPE_APIKEY/WPE_CLUSTER_ID/PWP_NAME. Shipped 1.0.31.
metadata:
  type: reference
---

`augustash/ddev-wordpress` carries a **WP Engine arm** in `src/Ddev.php` that runs on every `ddev-setup` / `composer update` (via `Ddev::postUpdate`), mirroring the Pantheon `isPantheonSite → applyPantheonHooks` pattern. Entry point: `applyWpEngineFixups()`, called from `run()` right after `writeSettingsLocal()`. Self-guarding + idempotent, so non-WPE sites are untouched and re-runs (and re-seeds from production) are no-ops that self-heal.

**Why it exists — the WPE + ddev conflict.** A WP Engine wp-config.php seeded from production:
- hard-defines the prod DB credentials with bare `define()`s and ships **no local-override hook**, so under ddev the prod creds win and the container can't reach its own DB; and
- lives in a repo that ignores the doc root wholesale (`/*`, tracking `wp-content` only — WPE runs from committed `wp-content`, `vendor/` is untracked dev tooling), which **swallows `.ddev/`** so a fresh clone comes up with no ddev config.

**Detection — `isWpEngineSite($wpConfig)`:** greps wp-config.php for `WPE_APIKEY` / `WPE_CLUSTER_ID` / `PWP_NAME` (any one). Note the asymmetry with Pantheon: the WPE marker lives **in the config file**, not in `.ddev/config.yaml` `web_environment` (that's where the Pantheon marker lives — see [[ddev-drupal-pantheon-site-var]]).

**Two fixups, both keyed on that detection:**

1. **`applyWpEngineDbGate()`** — idempotent, sentinel-guarded edits to wp-config.php:
   - `wrapDbDefines()` wraps the **contiguous `DB_*` define run** in `if ( getenv('IS_DDEV_PROJECT') !== 'true' ) { … }` (keyed on the `DB_` prefix, tolerating blank/comment lines, so the optional `DB_HOST_SLAVE`/`DB_CHARSET`/`DB_COLLATE` variants are handled). Sentinel = the `IS_DDEV_PROJECT` guard itself; also respects a hand-wrapped block.
   - `insertDdevInclude()` inserts the `wp-config-ddev.php` include (guarded `is_readable(...) && !defined('DB_USER')`) **immediately before the `wp-settings.php` require** — the one line every wp-config.php must have, so it's the stable anchor regardless of platform mods above it. Under ddev: the wrap skips prod defines → `DB_USER` undefined → include loads ddev creds; off-ddev both are inert.
2. **`unignoreDdevDir()`** — surgically inserts `!/.ddev/` + `!/.ddev/**` into the allowlist of a `/*` deny-all .gitignore (only acts when `/*` is present and `.ddev` isn't already un-ignored). ddev's own generated `.ddev/.gitignore` still excludes the machine-specific bits, so only `config.yaml` + module assets get tracked.

**Git un-ignore gotcha (bit me during this work):** you **cannot** re-include files inside a dir git never descends into — `/*` ignores `.ddev` itself, so `!/.ddev/**` alone is a no-op. Both rules are needed (`!/.ddev/` un-ignores the dir, `!/.ddev/**` its contents). Also: `git check-ignore -q PATH` returns exit 0 when a path matches **any** rule *including a negation* — so a successful un-ignore reads as "ignored" under `-q`. Use `git check-ignore -v PATH` and look at whether the winning rule starts with `!`.

**Deploy safety (satisfies [[internal-package-distribution]]'s hazard):** the require-dev plugin mutates wp-config.php, which that memory flags as the thing that breaks `--no-dev` deploys. Safe here because (a) the injected PHP is runtime-gated on `IS_DDEV_PROJECT`, inert in production even if it reached WPE, and (b) wp-config.php is untracked under `/*`, so a composer uninstall touching it can't abort a deploy. No cleanup hook that reverts.

**How to apply:** On any augustash WPE WordPress site, `composer update` (or `ddev-setup`) applies both fixups automatically — devs don't hand-edit wp-config.php or the .gitignore. If wp-config.php has an unexplained `IS_DDEV_PROJECT` wrapper around the DB block, that's this — expected and production-safe. The DB gate has **no explanatory comment in the file** (deliberately not added), so this memory is the "why." The `vendor/` tree (incl. `claude-config`) stays fully ignored on WPE repos by design — it's dev-only, not deployed.

Related: [[ddev-drupal-pantheon-site-var]] (sibling recipe, Pantheon arm), [[internal-package-distribution]] (dev-master/prefer-source distribution + the deploy hazard), [[ddev-setup-post-update-cmd]] (the postUpdate wiring)
