---
name: neo_alchemist discards nested markup prop values on render
description: "A `type: markup` prop nested inside an `array` prop never receives its stored value — it renders the parent array's `examples` for that delta instead, or nothing where no example exists. Authored content stays intact in the DB and never reaches the page. The tell is that sibling `type: string` props at the same nesting level are correct. Cause is the `formatted_text` value plugin tripping childHasOwnValueProvider()."
type: reference
---

# neo_alchemist discards nested markup prop values on render

Affects any Neo component with `type: markup` inside an `array` prop — table cells, FAQ answers, section intros, repeater copy. **The stored value is discarded at render; the database is fine.**

## The tell

Within the same array item, `type: string` props render the authored value and `type: markup` props don't. Top-level markup props are unaffected. On a 22-row table whose component declares 4 example rows, cells 0–3 rendered the **example** prose and cells 4–21 rendered correctly — because the fallback is the schema example for that delta, and beyond the example count there is nothing to fall back to, so the real value survives.

Diagnose by comparing stored vs rendered, not by reading the value back:

```php
$p = json_decode($node->get('field_full')->first()->get('props')->getValue(), TRUE);
// …stored is correct; render the node and grep the HTML for the authored string.
```

## Cause

`ChildrenShapeBase::getChildShapes()` refuses to push a parent's value into a child that "resolves its own value from a value provider":

```php
if ($this->childHasOwnValueProvider($shape)) {
  continue;                                   // markup child skipped here
}
$shape->setFieldItemValue($value[$shape->getName()]);
```

`MarkupShape` declares `default_plugins: ['formatted_text']` and `FormattedTextValue` is `group: 'providers'`, so the guard is TRUE for **every** markup shape. But `formatted_text` sources no value — it renders an existing one through a text format. `string` shapes carry no providers plugin, take the `setFieldItemValue()` line, and are correct.

The child then resolves to its own default, which `ArrayShape::loadChildSchema()` seeds from the parent array's `examples` for that delta.

Only children take a value pushed down from a parent, which is why top-level markup is fine — and why this can sit unnoticed for a long time: while component instances are still being assembled *from* the examples (the usual way a first page gets built), correct output and example output are the same bytes.

## Fix

Exclude `formatted_text` **by id**, not by group. Excluding everything in the shape's `default_plugins` is the more general rule but `media` is a default plugin that genuinely does source a value — and that is the case the guard was added for.

```php
if ($instanceId === 'default' || $instanceId === 'formatted_text') {
  continue;
}
if ($instance->getGroup() === 'providers') {
  return TRUE;
}
```

Fork `kazajhodo/neo_alchemist` `develop`, commit `f684d9c`. Project-local patch until released; not promoted to [[patches]] (one project so far).

## Ruled out — don't re-run

- Removing `examples:` from the nested markup prop. The child is still skipped; it just renders **empty**, which is strictly worse.
- Removing `examples:` from the containing array, same reason.
- Looking for a deep merge. There isn't one — it's a cache-plus-guard interaction, and searching for `array_merge_recursive` finds nothing.

First hit: ar-md (md) 2026-07-26, building a fault-code reference table into a `sections` region. See [[neo-skills-sync]] for the other neo-module gotcha that bites on `composer update`.
