---
name: Config created at runtime gets a per-environment UUID, so the next cim deletes it
description: "An update hook (or any programmatic ConfigEntity save) that creates config which ALSO lives in the repo mints a fresh UUID on every environment. The repo and each environment then disagree, and the next cim schedules delete-then-create for that config — which, for a bundle that has content, either fails validation or deletes the bundle out from under live content. Config belongs to the repo and arrives via cim; an update hook may only touch content."
type: reference
---

# Config created at runtime gets a per-environment UUID

The rule this exists to enforce: **update hooks change content. `cim` changes config.** Any
hook that also creates config is building a divergence generator.

Config entities carry a `uuid`, and it is the identity `cim` compares on — not the machine
name. Two config entities with the same id and different uuids are, to the importer, one
entity to delete and a different one to create.

So a hook like this looks defensive and is not:

```php
// Install the bundle here in case updb runs before cim. ← the bug
if (!$manager->hasInstalledDefinition($plugin_id)) {
  $manager->installEntityType($manager->getDefinition($plugin_id));
}
```

Each environment it runs on mints its **own** uuid. The repo has a fourth. Nothing ever
reconciles them, because nothing re-exports from every environment.

## The tell

`drush config:status` names config you know you deployed, in a state that makes no sense —
"Only in sync dir" for entities that are demonstrably in the `config` table. Then `cim`
prints the same config **twice**, once as Create and once as Delete:

```
| block_content.type.exo_186d…  | Create |
…
| block_content.type.exo_186d…  | Delete |
```

If content exists of that bundle, validation stops the import:

> Entities exist of type Content block and Block type Error Page. These entities need to be
> deleted before importing.

That refusal is the *lucky* outcome. Where the delete is allowed to proceed, `cim` removes a
bundle that live content still points at.

## Second-order damage on exo_alchemist

An alchemist component keeps an **installed definition** separately from the block_content
config. `cim` recreates the bundle and does not touch that definition, so it is left stale —
still listing a field the component's yml no longer declares. A removed `form` field is the
sharp case: its `form_class` gets built with no arguments, and if that form's constructor
signature does not tolerate it, **every page on the site 500s**, not only the pages using the
component. Recover with:

```
drush exo:alchemist:update <plugin_id>
```

then rebuild any content that referenced the recreated bundle.

## Do it this way instead

- Let `cim` create the config. If a hook needs the config present, **depend on ordering**
  (`drush deploy` runs updb then cim; run `cim` first when a hook needs config that does not
  exist yet) and fail loudly rather than self-healing:

  ```php
  if (!$manager->hasInstalledDefinition($plugin_id)) {
    throw new UpdateException("The $plugin_id component is not installed. Run drush cim before updb.");
  }
  ```

- A hook that must place a component may build the **content** — a block_content entity, a
  layout section — freely. That is content, and content is meant to differ per environment.

## Already diverged?

Do not "fix" it by running `cim` on production and hoping. Make the repo match the
environment you cannot break: pull that environment's database, export, and confirm `cim` is
a no-op before deploying. See [[verify-cim-is-clean-before-commit]] for the check, and
[[config-split-db-push-mass-uninstall]] for the other way a `cim` on this platform half-applies.

First hit: kow 2026-09-01, an error_page component installed by `kow_update_11001()`. Four
environments, four uuids; discovered only when an unrelated deploy needed `cim` and it
proposed deleting the live 404 and 403 pages.
