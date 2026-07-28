---
name: neo_alchemist heading anchors derive from the title unless anchor override is on
description: "HeadingShape ignores a stored `anchor` and slugs the title instead unless neo_alchemist.settings anchor_override_status is TRUE — and it hides the anchor field from the form when it's off. So programmatically-written anchors are silently inert, and any that appear to work do so only because the title happens to slug to the same string, which makes every #link on the page one heading re-word away from breaking."
type: reference
---

# neo_alchemist heading anchors derive from the title unless anchor override is on

`HeadingShape::preRenderValue()` stamps the id:

```php
$anchor = $this->allowAnchorOverride()
  ? ($value['anchor'] ?? $value['title'] ?? '')
  : ($value['title'] ?? '');
$attributes->setAttribute('id', Str::machine($anchor, '-'));
```

`allowAnchorOverride()` reads `anchor_override_status` from `neo_alchemist.settings`. **Off by default.** With it off the form also does `$form['anchor']['#access'] = FALSE`, so an editor never sees the field — which is why this only ever surfaces when props are written in code.

## Why it hides

A stored anchor that matches its own title slug works identically either way. So a page can be full of `#soft-reset` links that all resolve, with `'anchor' => 'soft-reset'` sitting in the build script looking load-bearing, purely because the heading says "Soft reset". Give a block a title that doesn't slug to its anchor and the id silently becomes the title slug instead.

The real exposure isn't the inert value — it's that **re-wording a heading moves its id**, so every in-page link to it breaks with no error anywhere.

## What to do

Check the setting before trusting any `anchor` in a heading value:

```bash
drush php:eval 'var_export(\Drupal::service("neo_alchemist.settings")->getActive()->getValue("anchor_override_status"));'
```

- Off and staying off → the title *is* the anchor. Say so where the anchor would have gone, and treat heading copy as an API.
- Want authored anchors → turn it on, but it changes ids site-wide for any heading whose stored anchor differs from its title slug. Audit before flipping.

Don't assume from a passing link. Grep the rendered `id=` and compare it to what you wrote.

## First hit

ar-md (md) 2026-07-28, building `/support`: an explicit `'anchor' => 'no-output-power'` rendered as `id="no-output-power-and-the-led-is-off"`. The soft/hard reset blocks alongside it read as though they set their own anchors — they don't.
