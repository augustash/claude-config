---
name: config_ignore pattern over a config_split module deadlocks deploy
description: "cim aborts with \"Configuration X depends on the Y module that will not be installed after import\" when a config_ignore pattern covers config owned by a module in a config_split module list — the split uninstalls the module while the ignore forces its config to survive. Drop the ignore; the split already handles env separation. Follow-on: the first reconciliation import can OOM on Pantheon's 256MB CLI limit."
type: reference
---

# config_ignore pattern over a config_split module deadlocks deploy

`drush deploy` on a remote env dies in config import, listing every config item a dev-only module owns:

```
In ConfigImportCommands.php line 272:
  The import failed due to the following reasons:
  Configuration migrate_plus.migration.md_type depends on the Migrate Plus
  module that will not be installed after import.
  ... (×25)
```

**Why:** two mechanisms with opposite intents overlap on the same config.

- **config_split** is an *export-side filter*. Listing a module in a split's `module:` list strips it from `core.extension` in the main sync dir and relocates all config depending on it into the split folder. With the split inactive on the remote, that config is simply absent from sync → the importer plans to delete it alongside the module uninstall. Correct.
- **config_ignore** (simple mode) forces matching config to survive an import *untouched*, in both directions.

If the target env has the module installed in active storage, the import uninstalls it via `core.extension` while the ignore vetoes deleting its config. `ConfigImportSubscriber::validateModules` rejects exactly that state, and the whole import aborts before doing anything.

**Fix:** delete the overlapping patterns from `config_ignore.settings.yml`. The split already provides the environment separation the ignore was reaching for, and the ignore is worse than redundant — it also blocks edits made in the split folder from ever importing, even locally where the split is active.

**Audit:** cross-check every `ignored_config_entities` pattern against the `module:` list of each split. A pattern whose prefix is a split module (`migrate_plus.*`, `devel.*`) is the bug; ignores on shared modules (`system.site`, `search_api.server.*`, `webform.webform.*`) are fine.

## Follow-on: the reconciliation import can OOM

The first import after fixing this uninstalls the whole dev-module backlog in one PHP process, and on Pantheon's 256MB CLI limit that fatals mid-run:

```
Fatal error: Allowed memory size of 268435456 bytes exhausted
  in web/core/lib/Drupal/Core/Database/Statement/PdoTrait.php on line 109
[warning] Drush command terminated abnormally.
```

Not a config problem — just a dozen module uninstalls plus config deletes exceeding the ceiling. **Uninstalls persist to `core.extension` incrementally as each one completes**, so re-running the deploy resumes with only the remainder and normally finishes. To do it deterministically, drain them in their own process first, then deploy:

```
terminus drush {site}.{env} -- pm:uninstall md_migrate migrate_tools migrate_plus \
  migrate_drupal migrate devel views_ui kint config_inspector stage_file_proxy \
  reroute_email phpass -y
```

Verify with `terminus drush {site}.{env} -- config:status` → "No differences between DB and sync directory".

## Expect this on every cross-env DB move

Because the split is export-side only, a database carries whatever its *origin* env had enabled. Push a local DB (split active → migrate tooling on) up to a remote and that env inherits the enabled modules; the next import reconciles them back off. Expected and self-healing, but it recurs per DB move — front-run it with the standalone `pm:uninstall` above rather than letting `cim` absorb it. Dev DBs sourced from prod never see it.

First hit: ar-md (md) 2026-07-25, right after the split was introduced and the migration config moved into `config-dev/` — the ignore patterns predated the split and nobody had re-deployed since. See [[cross-version-db-pull]] for the other half of the "drush deploy order" story.
