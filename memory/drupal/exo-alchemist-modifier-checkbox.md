---
name: exo_alchemist per-item modifier checkbox + class via handler
description: Pattern for adding a checkbox to sequence items (or component) and applying a class via the PHP handler
type: project
---

To add a checkbox to an exo_alchemist component (or each item in a sequence) that toggles a class on the markup:

**Check for a built-in `modifier_globals.status` flag first.** Several common toggles (`invert`, `border_radius`, `color_bg`, `text_shadow`, `overlay`, `height`, `containment_content`, `margin_v`, `padding_v`) are built-in `ClassAttribute` properties — see `Plugin/ExoComponentProperty/`. Flipping them to `TRUE` in the component's `modifier_globals.status` block enables a per-instance editor checkbox and auto-adds a class like `.exo-modifier--invert` to the wrapper — no custom YAML modifier, no PHP handler, no twig change. Modifier values are stored on the component entity's `exo_modifiers` field, so toggles are per layout-builder placement (instance-level), not theme-wide. Before reaching for the custom pattern below, grep the component CSS for the built-in class to confirm it's not already in use.

Only use the custom pattern below when (a) no built-in covers the semantics, (b) the built-in's class name is already taken by other CSS, or (c) you need the class on a non-wrapper element.

**1. YAML — declare it as a modifier property** (NOT a sub-field):

Top-level (whole component):
```yaml
modifiers:
  overall:
    label: 'Overall display'
    properties:
      overall_display:
        type: custom
        label: 'Display with overall stats.'
        property_widget: checkbox
```

Per-sequence-item — add to the modifier group already linked via `sequence_modifier:`:
```yaml
modifiers:
  feature:
    label: 'Column'
    group: features
    properties:
      invert:
        type: custom
        label: 'Invert'
        property_widget: checkbox
```

**2. PHP handler — `<PascalCase>.php` in the component dir.**

Filename is derived by `ExoComponentDefinition::getHandlerName()` (`str_replace('_', '', ucwords($name, '_'))`), so `features_icon` ⇒ `FeaturesIcon.php`. Lowercase like `features_icon.php` will NOT load.

Top-level:
```php
public function viewAlter(array &$values, ExoComponentDefinition $definition, ContentEntityInterface $entity, array $contexts) {
  if (!empty($values['modifier_overall_value']['overall_display'])) {
    $values['#wrapper_attributes']['class'][] = 'exo-modifier--overall-value';
  }
}
```

Per-sequence-item:
```php
public function viewAlter(array &$values, ExoComponentDefinition $definition, ContentEntityInterface $entity, array $contexts) {
  if (empty($values['features']['value'])) {
    return;
  }
  foreach ($values['features']['value'] as &$feature) {
    if (!empty($feature['modifier_feature_value']['invert'])) {
      $feature['#wrapper_attributes']['class'][] = 'feature--invert';
    }
  }
}
```

**Key conventions:**
- Modifier values are auto-exposed at `$values['modifier_<group>_value']['<property>']`. The `modifier_<name>_value` key is built by `ExoComponentPropertyManager::modifierNameToKey()` + `_value`. Per-sequence-item, the same key lives on each item entity's view values.
- `propertyInfoAlter()` is NOT needed for modifier values — `ExoComponentPropertyManager::getPropertyInfo()` registers them automatically. Only use `propertyInfoAlter()` for fully synthetic computed properties (e.g. reviews' `average_rating` from a webform query).
- Adding to `$feature['#wrapper_attributes']['class']` propagates to `feature.attributes` in twig — no template change required.
- Cache rebuild required after adding a new modifier property or handler file.

**Why:** synthesized while wiring an `invert` toggle on `features_icon` (sisal). First-pass instinct was a custom modifier + handler; turned out the built-in `invert` global covered it. The lookup chain (modifier YAML → auto-registered property info → `modifier_<name>_value` key → per-item access) spans `ExoComponentPropertyManager`, `Sequence::viewValue`, and the handler discovery in `ExoComponentDefinition::getHandler()` — worth knowing for the cases where the built-in really doesn't fit.

**How to apply:** when an editor asks for a checkbox toggle that adds a class, first check `modifier_globals.status` for a built-in flag and the component's CSS for an unused `.exo-modifier--<name>` class. Reach for the custom YAML modifier + PascalCase handler pattern only when the built-in doesn't cover the semantics. Decide top-level vs per-item by whether the toggle is on the component or each sequence row.
