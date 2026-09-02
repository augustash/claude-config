---
name: A neo_component created in code saves fine and then fatals on every load
description: Creating a neo_component with create() and no description stores NULL against a typed string property, so the entity writes cleanly and throws on the next load.
type: reference
---

`Drupal\neo_alchemist\Entity\Component::$description` is a typed `string`. Creating the
entity programmatically without that key stores **NULL**, which `create()` and `save()`
accept without complaint — and then every subsequent load throws:

```
TypeError: Cannot assign null to property
Drupal\neo_alchemist\Entity\Component::$description of type string
in EntityBase.php on line 75
```

So pass it, even empty:

```php
$e = \Drupal::entityTypeManager()->getStorage('neo_component')->create([
  'id' => 'hero_s4',
  'label' => 'Hero | Two Harbors',
  'description' => '',          // ⚠ omit this and the entity is unloadable
  'component' => 'front:hero_s4',
  'group' => 'hero',
  'status' => TRUE,
]);
$e->save();
```

⚠ **The write reports success.** The fatal lands on the *next* read, so the failing command
is whatever runs afterwards — a Drush script, `cex`, the component picker — and the trace
names `EntityBase.php`, not the missing key or the entity you just created. Nothing points
back at the `create()` call.

⚠ **`cex` exports it as `description: null`,** so the broken value is committed and rides to
every environment. Repair with `\Drupal::configFactory()->getEditable(...)->set('description',
'')->save()` and re-export; a hand-edit of the yml works too, but the active config is what
fatals.

⚠ The same shape applies to any typed scalar the entity declares. `ComponentForm::save()`
fills these in, which is why the UI path never hits it and only programmatic creation does —
and the neo-component skill's own example is a programmatic `create()`.

Related: [[internal-package-distribution]] for why `cex` output matters here.
