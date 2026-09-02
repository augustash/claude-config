# An EMPTY config object kills cim with "Call to a member function delete() on null"

**Symptom.** `drush cim` dies part-way, every time, at the same point:

```
Error: Call to a member function delete() on null in
Drupal\Core\Config\ConfigImporter->checkOp() (line ~984 of ConfigImporter.php).
 [warning] Drush command terminated abnormally.
```

Config is left half-applied and `config:status` still lists differences, so it reads like a
dependency conflict the import refused. It is not. Re-running gets a little further each time
while other operations complete, then stops on the same one forever.

**Cause.** Core's `create` branch in `checkOp()`:

```php
case 'create':
  if ($target_exists) {
    // Target already exists — load the entity and delete it, then re-create.
    $entity = $entity_storage->load($entity_storage->getIDFromConfigName($name, $prefix));
    $entity->delete();   // ← NULL here
```

The config **name** exists in active storage, so `$target_exists` is TRUE, but the object has
**no data** — so it cannot hydrate into a config entity and `load()` returns NULL.

⚠ **`drush config:delete` will tell you the config does not exist.** ConfigFactory treats an
empty object as absent, so the obvious fix reports success-by-denial and changes nothing,
while the importer keeps seeing it. That contradiction is the whole diagnosis: raw storage and
ConfigFactory disagree.

## Confirming it in one command

```
drush php:eval 'print "active=" . var_export(\Drupal::service("config.storage")->exists("NAME"), TRUE)
  . " entity=" . (\Drupal::entityTypeManager()->getStorage("ENTITY_TYPE")->load("ID") ? "loads" : "NULL");'
```

`active=true entity=NULL` is the fingerprint.

## Fixing it

Delete at the **storage layer**, below ConfigFactory, then import normally:

```
drush php:eval '\Drupal::service("config.storage")->delete("NAME");'
drush cim -y
```

The import then performs a clean create from sync.

⚠ **Look for orphaned config from uninstalled modules in the same pass.** The same import
often carries a config entity whose provider module is already uninstalled — e.g.
`system.menu.devel` after `devel` goes — which fails the *delete* branch for the mirrored
reason. `drush config:delete` works for those, since they do have data.

## Where it comes from

Seen after pushing a local database into a Pantheon environment and importing (2026-08-13).
A DB push makes active config identical to the source site's, so the import's whole workload
becomes module installs/uninstalls plus whatever config was mid-write when the dump was taken
— which is where a half-written, dataless object comes from.

⚠ **Distinct from [[config-split-db-push-mass-uninstall]]**, which produces a *memory
exhaustion* on the same command after the same kind of push. Both leave config half-applied
and both are fixed by re-running, so they are easy to conflate — but the OOM has no PHP error
line and clears by itself after enough runs, while this one names `checkOp()` and never
clears until the empty object is removed. **Read the error text before assuming which.**
