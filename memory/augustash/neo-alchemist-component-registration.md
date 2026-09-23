---
name: Registering a theme SDC with Alchemist in code
description: An SDC Drupal discovers happily is invisible to Alchemist until a neo_component entity exists, and creating that entity without a description key makes it unloadable.
type: reference
---

Two traps, in the order you hit them, when placing a theme component into an
Alchemist tree programmatically rather than through the builder UI.

## 1. No `neo_component` entity → renders nothing, says nothing

A component under `themes/<theme>/components/<id>/` is discovered by Drupal as soon as
it exists. Alchemist will not render it until a matching `neo_component` **config
entity** exists as well.

With the entity missing, everything you would check to rule it out comes back clean:

- `\Drupal::service('plugin.manager.sdc')->getDefinition('front:<id>')` returns it;
- `drush neoa-validate front:<id>` reports valid;
- `drush neoa-components` lists it;
- the placement sits correctly in the node's `field_full` tree;
- nothing is logged, and the page renders fine — just without that component.

The tell is `neoa-components` showing the component with an empty *installed* column.
Create the entity and it renders on the next cache rebuild:

```php
$e = \Drupal::entityTypeManager()->getStorage('neo_component')->create([
  'id' => 'divider_s1',
  'label' => 'Divider | Cookie',
  'description' => '',          // ⚠ see below — never omit
  'component' => 'front:divider_s1',
  'group' => 'general',         // an existing group: list, callout, hero, general, special
  'status' => TRUE,
]);
$e->save();
```

`Component::preSave()` derives `schema`, `expression` and `settings.props` from the
`.component.yml` for a new entity, so do **not** hand-write them — a hand-built schema is
one that drifts from its source the first time either changes.

⚠ `neo_install: true` does not do this. That flag is for ejecting a **module's** component
into a theme; it has no effect on a component the theme already owns.

## 2. A missing `description` makes the entity unloadable

`Drupal\neo_alchemist\Entity\Component::$description` is a typed `string`. Creating the
entity without that key stores **NULL**, which `create()` and `save()` accept without
complaint — and then every subsequent load throws:

```
TypeError: Cannot assign null to property
Drupal\neo_alchemist\Entity\Component::$description of type string
in EntityBase.php on line 75
```

⚠ **The write reports success.** The fatal lands on the *next* read, so the failing command
is whatever runs afterwards — a Drush script, `cex`, the component picker — and the trace
names `EntityBase.php`, not the missing key or the entity you just created. Nothing points
back at the `create()` call. Read the entity straight back after saving; a save with no
read proves nothing here.

⚠ **`cex` exports it as `description: null`,** so the broken value is committed and rides to
every environment. Repair with `\Drupal::configFactory()->getEditable(...)->set('description',
'')->save()` and re-export; a hand-edit of the yml works too, but the active config is what
fatals.

⚠ The same shape applies to any typed scalar the entity declares. `ComponentForm::save()`
fills these in, which is why the UI path never hits it and only programmatic creation does —
and the neo-component skill's own example is a programmatic `create()`.

Related: [[internal-package-distribution]] for why `cex` output matters here.
