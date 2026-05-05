---
name: exo_alchemist per-item modifier checkbox + class via handler
description: Pattern for adding a checkbox to sequence items (or component) and applying a class via the PHP handler
type: project
---

To add a checkbox to an exo_alchemist component (or each item in a sequence) that toggles a class on the markup:

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

**Why:** synthesized while wiring per-feature `invert` toggle on `features_icon` (sisal). The lookup chain (modifier YAML → auto-registered property info → `modifier_<name>_value` key → per-item access) spans `ExoComponentPropertyManager`, `Sequence::viewValue`, and the handler discovery in `ExoComponentDefinition::getHandler()` — a fresh session would have to re-traverse all of that.

**How to apply:** when an editor asks for a checkbox toggle that adds a class, reach for this pattern instead of inventing a sub-field + propertyInfoAlter combo. Decide top-level vs per-item by whether the toggle is on the component or each sequence row.
