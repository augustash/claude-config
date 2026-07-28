---
name: neo_icon renders an empty span for a style-prefixed id
description: "A neo_icon id is stored UNPREFIXED (`exchange-alt`); neo adds the style itself, emitting `icon-regular-exchange-alt`. A stored value that already carries the style (`regular-exchange-alt`) double-prefixes and renders an EMPTY string — no error, no log. In a component the `{% if item.icon %}` guard still passes, so the wrapper span is emitted empty and it reads as 'this component does not support icons' rather than as bad data."
type: reference
---

# neo_icon renders an empty span for a style-prefixed id

## The tell

The markup is present and the icon is not:

```html
<span class="pillars-s1__icon" aria-hidden="true"></span><span>Inverter/charger</span>
```

The stored prop is non-empty, so `{% if group.icon %}` passes and the wrapper renders; only `{{ icon(group.icon) }}` comes back empty. Nothing is logged. The natural reading is that the feature was never wired up — which sends you into the twig and the component schema, both of which are fine.

## Cause

Ids are stored bare. neo prepends the style when building the class:

```
'arrow-right'          → <i class="neo-icon neo-icon-font icon-regular-arrow-right">
'regular-arrow-right'  → ''            // icon-regular-regular-arrow-right, no such glyph
```

So any id that already carries `regular-` / `solid-` / `light-` / `brands-` / `duotone-` / `thin-` is dead on arrival. Easy to introduce when props are written programmatically (a migration, a seeded article) by copying the *class* name instead of the id.

`IconRepository::getIcon()` is not the way to check — it returned NULL for known-good ids too. Render the element instead:

```php
$b = ['#type' => 'neo_icon', '#icon' => $id, '#icon_only' => TRUE];
$ok = trim((string) \Drupal::service('renderer')->renderInIsolation($b)) !== '';
```

`#icon_only` is irrelevant to whether it resolves (a bare `icon()` with no title renders the same glyph); it only controls the label. Don't chase it as the cause.

## Sweep

Scan every component tree for icon values that don't resolve, and offer the de-prefixed name:

```php
foreach ($db->query('SELECT entity_id, field_full_props FROM {node__field_full}') as $row) {
  preg_match_all('/"icon":"([^"]+)"/', $row->field_full_props, $m);
  // …test each; $s = preg_replace('/^(regular|solid|light|brands|duotone|thin)-/', '', $id);
}
```

Fix through the entity API (load → decode the `props` column → walk → `setValue()` → `save()`), not raw SQL, so cache tags invalidate. `setNewRevision(FALSE)` keeps a data repair out of the revision history.

First hit: ar-md (md) 2026-07-27, two seeded knowledge articles, 4 values. See [[neo-alchemist-nested-markup]] for the other way a nested component prop silently fails to reach the page — same symptom class, different cause, and worth ruling out together.
