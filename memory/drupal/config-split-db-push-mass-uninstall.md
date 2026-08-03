---
name: A DB push makes cim uninstall the whole dev split in one process, and it OOMs
description: "After `ddev push pantheon` (or any local-DB-into-Pantheon), `drush deploy`/`cim` dies with 'Drush command terminated abnormally', leaving config half-applied. It is PHP memory exhaustion, not a config conflict: the pushed DB has every dev-split module installed and the export has none, so cim's whole workload is a mass uninstall in one process. Re-run cim until clean. Do not raise memory_limit."
type: reference
---

# A DB push makes cim uninstall the whole dev split in one process, and it OOMs

`drush deploy` after pushing a local database to Pantheon:

```
[notice] Synchronized extensions: uninstalled phpass.
[warning] Drush command terminated abnormally.
```

Config is left **half-applied** — some modules uninstalled, some not — and `config:status` still lists differences. It reads exactly like a config conflict the import refused. It isn't one: the PHP process died.

**Why the workload is unusual.** A DB push makes the target's *active* config identical to local's, so the only thing left for `cim` to reconcile is the **module list**: every module in the dev split is installed in the pushed DB and absent from the export, so cim's entire job becomes a mass uninstall. Each uninstall rebuilds the service container and re-runs plugin discovery in the same PHP process, and that memory is never handed back — so cost scales with the *number* of modules in the split, not with the size of the config.

A normal code deploy never does this. `cim` there imports a few changed values and uninstalls nothing, which is why the platform documents no memory requirement and why this only ever appears on a DB push.

**Scale is the whole story** — house dev splits run 3–4 modules and never hit it. A *migration* project's split also carries `migrate`, `migrate_drupal`, `migrate_plus`, `migrate_tools` and the site's own migrate module, reaching ~12, which is what tips it over:

```
drush cget config_split.config_split.dev module --include-overridden
```

**It cannot reproduce locally.** ddev runs CLI PHP at `memory_limit=-1`; Pantheon's is `256M`. Check both before theorising — the asymmetry is the reason the failure only exists on deploy.

**Fix: just run `cim` again**, up to a few times. Each run completes some uninstalls before dying, so the remaining batch shrinks until it fits and the last run goes green. Loop until `config:status` is clean.

**It recurs on every DB push and then stops for good.** Each push reinstalls the split's modules, so each one pays the same cost — but a rebuild only moves a database up a handful of times before launch, after which content flows the other way and it never happens again. Remembering to re-run `cim` is the whole remedy; it is not worth engineering around.

**Do NOT `ini_set('memory_limit')` in settings.php.** It masks a self-inflicted, temporary cost as though it were a platform limit. If a batch genuinely needs shrinking, uninstall the migrate modules once the migration is done — that is what made the split big.

## Reading the actual error

Two traps, both of which send the diagnosis the wrong way:

- **`terminus` output never carries the fatal**, and it never reaches `watchdog` either — the process died, so nothing logged it. Worse, `watchdog` on a freshly-pushed environment is full of *local* entries that rode up inside the DB, so recent-looking errors there are from your own machine.
- **The fatal is on the appserver** at `logs/php/php-error.log`. `terminus` has no `logs` command by default and Pantheon refuses `ssh` exec, so fetch it over SFTP:

  ```
  printf 'get logs/php/php-error.log /tmp/\nbye\n' | sftp -P 2222 -b - dev.$UUID@appserver.dev.$UUID.drush.in
  ```

**The named file and line in a memory fatal is the straw, not the load.** `Allowed memory size … exhausted (tried to allocate 8192 bytes) in …/PhpSerialize.php` means an 8KB allocation failed after something else consumed 256MB — it does not implicate the serializer or the cache backend. Chasing the named frame invents a Redis or config-volume theory that measurement then kills.

Same "a DB carries whatever its origin env had enabled" mechanism as [[config-split-export-wipes-folder]] and [[config-split-ignore-collision]], seen from a third angle: the import side of a *push* rather than a pull. Splits are activated per-env from `settings.local.php`, so use `--include-overridden` when reading their status ([[local-config-in-settings-local]]).

First hit: md (DMX Power) 2026-08-03, pushing a migration-project DB to Pantheon dev; the same failure is in that site's logs from 2026-08-02, unrecognised at the time.
