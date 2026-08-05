---
name: On four neo_alchemist shapes the 'default' option is ON out of the box and throws your stored value away
description: "Image, file and both video props ship with `$optionDefaultInitValue = TRUE`, so `initialize()` nulls the stored override before reading it and the component's `examples` render instead. Writing the key explicitly does NOT save you — the config needs `options.<prop>.default = FALSE`. Reads as a value that will not save."
type: reference
---

# The 'default' option discards a stored value on image, file and video props

Affects `neo_alchemist` (confirmed 1.0.114). Four shapes set `$optionDefaultInitValue = TRUE`:

| shape | prop `type:` |
|---|---|
| `ImageShape` | `image` |
| `FileShape` | `file` |
| `VideoLocalShape` | `video` |
| `VideoRemoteShape` | `remote_video` |

Every other shape defaults to `FALSE` (`ComponentShapePluginBase::$optionDefaultInitValue`), which is why this only ever bites on media.

## The tell

A media prop you demonstrably wrote renders the component's `examples:` instead — a stock photo, a placeholder thumbnail, an unrelated demo video. Reading storage back shows your value sitting there, correct, which is what makes it read as a render bug or a cache problem rather than a value being refused.

⚠ **It also swallows a deliberately EMPTY value.** Storing `['src' => '', 'alt' => '']` to mean "nothing here yet" is discarded exactly the same way, so the example renders and the component looks populated by content nobody chose.

## Cause

`ComponentShapePluginBase::initialize()`, ~line 543:

```php
$overrideValue = $this->getOverrideValue();
if ($this->getOptionDefault()->isEnabled() || !$this->isEditable()) {
  $overrideValue = NULL;
}
```

The override is nulled *before* any emptiness test, so nothing downstream can recover it. Note the second clause: a **non-editable prop is discarded by the same line**, which is why `editable: false` and an enabled option default present identically.

## Fix on our side

Write `options` alongside the value, keyed by the prop name:

```php
'image' => [
  'ref' => 'image',
  'value' => ['src' => '/sites/default/files/x.jpg', 'alt' => '…'],
  'options' => ['image' => ['default' => FALSE]],
],
```

Required for **every** one of the four, with or without a value. Matching form appears on every stored image in coss's `neo_alchemist_block` config, so this is the house pattern rather than a workaround.

## Why this is not [[neo-alchemist-example-seeding]]

Same symptom — examples on a live page — but the opposite mechanism, and **that memory's fix does not work here**. Seeding fills a prop the builder *never wrote*, and writing the key explicitly cures it. This discards a prop the builder *did* write. If you have written the key and still see the example, you are in this memory, not that one.

## Diagnosing

Assert on **rendered output**, never on stored props: storage is the one place this bug is invisible. Grep the rendered HTML for a distinctive string from the component's `examples:` block.

⚠ **Check every media prop on the component, not the one you are looking at.** A prop rendering an example is often silently covered by a sibling that is working — on ar-md 2026-08-05 a hero's `remote_video` had been serving its example Vimeo URL, wired live to a play button, for two days behind a stored poster image that hid it. It surfaced only when the image was emptied for unrelated reasons. One guarded prop is not evidence the others are.
