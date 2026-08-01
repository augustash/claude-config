---
name: Saving a neo_component entity wipes every prop plugin on the shape
description: removing one prop plugin programmatically silently takes the others with it — preSave re-derives settings.props from the value collection, so the fix is raw configFactory, not an entity save
type: reference
---

Editing a `neo_component`'s prop plugins by loading the entity, changing
`settings.props` and calling `save()` **does not partially apply — it clears every
plugin on that shape**, including the ones you never touched.

```php
// DON'T — removes far more than the two keys unset here.
$e = \Drupal::entityTypeManager()->getStorage('neo_component')->load('sections_s1');
$s = $e->get('settings');
unset($s['props']['sections']['plugins']['sections~copy']);
unset($s['props']['sections']['plugins']['sections~items~copy']);
$e->set('settings', $s)->save();
// → plugins is now EMPTY. A deliberate region_custom went with them.
```

**Why.** `Component::preSave()` calls `setPropShapeSettings()` for every unchanged
shape, and that method rebuilds `settings['plugins']` from scratch — from the shape's
**value collection instances whose status is TRUE**, not from the settings array you
just edited:

```php
foreach ($collection->getInstances() as $instanceId => $instance) {
  if ($collection->getStatus($instanceId)) {
    $settings['plugins'][$id][$instance->getPluginId()] = [...];
  }
}
```

Editing settings doesn't change the collection, so the rebuild writes whatever the
collection reports — which, after the entity is reconstructed mid-save, is nothing.
The settings array is an **output** of the collection, not an input to it.

## Do it with raw config instead

`configFactory()` writes the stored config directly and never enters `preSave()`:

```php
$cfg = \Drupal::configFactory()->getEditable('neo_alchemist.neo_component.sections_s1');
$props = $cfg->get('settings.props');
$props['sections']['plugins'] = [
  'sections~region' => ['region_custom' => ['id' => 'region_custom', 'settings' => []]],
];
$cfg->set('settings.props', $props)->save();
```

**Verify all three, because the config file alone proves nothing** — a key can be
written and still be inert:

1. `$shape->getPlugins()` reports the plugin (it is live, not cosmetic).
2. The page still renders what the plugin drives — assert real anchors or markers, not
   a byte count.
3. A fresh `drush cex` comes back with **no diff**, which is what proves active config
   and the export finally agree rather than the drift being re-derived next export.

## The drift this usually comes from

The component settings form adds plugin entries by itself — a `formatted_text`
provider on every markup-ish prop, and an `expanded` list — so a component picks up
`plugins` nobody configured. That is why the removal comes up at all. Prune it in the
export *and* in active config, or the next `cex` brings it straight back.

Corrects an earlier note claiming these "can only be changed through the form": the
form is one way, raw config is another, and the entity-save route is not merely
ineffective but destructive.
