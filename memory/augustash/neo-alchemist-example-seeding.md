---
name: neo_alchemist seeds every prop with its schema examples, so an unwritten prop shows fabricated content
description: "Schema `examples` are a SEED, not a fallback: ComponentShapePluginBase::init() sets every shape to its examples up front and only overlays a value when an override exists. A prop the builder never writes therefore renders the component's example content on the LIVE page, and editors see repeater rows nobody created. Writing the key explicitly (present-but-empty) is the fix on our side."
type: reference
---

# neo_alchemist seeds every prop with its schema examples

Affects any Neo component with `examples:` in its `*.component.yml` — which is all of them, since the scaffolding writes examples by default.

**Examples act as a seed, not a fallback.** The distinction is the whole memory: a fallback fills a hole at render time and disappears once real data arrives; a seed is installed first and survives anything that fails to positively overwrite it.

## The tell

Content on the page that nobody authored, matching the component's `examples:` block. Most legible in a repeater: an editor opens a page and finds rows they did not create, in a prop the page never uses. Reading storage proves nothing — the prop is genuinely absent, and absence is exactly what leaves the seed standing.

## Cause

`ComponentShapePluginBase::init()` (~line 520 in neo_alchemist 1.0.109):

```php
$defaultValue = $this->getDefaultValue();   // resolves the schema `examples`
$this->setFieldItemValue($defaultValue, FALSE);

// Overlay the field/entity value — only if there IS one.
$overrideValue = $this->getParentValue();
if (is_null($overrideValue)) {
  $overrideValue = $this->getOverrideValue();
  …
}
```

The overlay is conditional; the seed is not. No override, no replacement.

## Fix on our side

**Write the key explicitly, present-but-empty**, rather than omitting it. That is what lets the resolver tell "deliberately nothing" from "never set" — omission is indistinguishable from absence, and absence keeps the seed.

⚠ **Not sufficient on image, file or video props.** Those four shapes discard a written value outright via a separate mechanism, so the same symptom survives this fix — see [[neo-alchemist-option-default-discards-value]]. If you have written the key and still see examples, you are in that memory, not this one.

There is no upstream patch for this and none of ours ever covered it. Whether examples should seed or only fall back is a design call on the module, worth raising with Cyle rather than patching around.

## What is NOT this any more

Two downstream bugs in this family were fixed upstream in **neo_alchemist 1.0.109** — don't go hunting for either:

- A nested `type: markup` prop rendering examples instead of its stored value. Cause was `FormattedTextValue` being declared `group: 'providers'` when it sources no value, so `ChildrenShapeBase::childHasOwnValueProvider()` blocked the parent's pushdown. Upstream re-grouped it to `modifiers`. **Pick the right `group:` — it is a behavioral contract other code queries, not a form tab.**
- A nested prop stored `false`/`0` losing to the example. `ComponentShapePluginBase::isProvidedValueEmpty()` now delegates the emptiness test, and in canonical prop form a falsy scalar arrives wrapped (`['ref' => 'boolean', 'value' => false]`), which is not empty — while a region's submitted `[]` is, so regions stay protected.

Both had project-local patches, both dropped 2026-07-30. The seeding behaviour above is the part that survived them.

## Diagnosing

Compare stored against rendered — never read the value back and call it proof. Render the node and grep the HTML for a distinctive string from the component's `examples:` block; a hit is a seed that was never overwritten.

First hit: ar-md (md) 2026-07-29, an `items` prop the `/support` builder never wrote, showing four example rows to editors. See [[neo-skills-sync]] for the other neo-module gotcha that bites on `composer update`.
