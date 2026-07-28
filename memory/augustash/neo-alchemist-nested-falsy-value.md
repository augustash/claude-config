---
name: neo_alchemist overwrites a nested prop stored FALSE with the schema example
description: "A nested prop stored FALSE, 0 or '' is skipped by an empty() guard in ChildrenShapeBase::getChildShapes(), so the child keeps the SDC example for its delta. Where an example sets that property TRUE, an unchecked boolean renders switched ON and no amount of switching it off helps. Sibling deltas with no example behave correctly, which makes it look like data corruption on one row."
type: reference
---

# neo_alchemist overwrites a nested prop stored FALSE with the schema example

Second, separate cause of the same symptom as [[neo-alchemist-nested-markup]] — nested prop renders the `examples` instead of stored data — in the same method. Check both.

## The tell

**Only some deltas are wrong, and they're the ones the component declares examples for.** A boolean the editor switched off renders on; the delta after it, past the example count, is fine. Stored data is correct, so reading the prop back proves nothing.

```php
$p = json_decode($node->get('field_full')->first()->get('props')->getValue(), TRUE);
// filter => false in storage; render the node and the search box is there anyway.
```

Anything falsy is affected — `false`, `0`, `''`, `[]` — but booleans are where it bites, because a checkbox is exactly the control whose off state is a real choice rather than an absence.

## Cause

`ChildrenShapeBase::getChildShapes()` decides whether a child has a value with `empty()`:

```php
if (empty($value[$shape->getName()])) {
  continue;                                  // stored FALSE skipped here
}
```

`empty()` can't tell a stored `false` from a key that was never written, so `setFieldItemValue()` is skipped and the child falls through to its default — which `ArrayShape::loadChildSchema()` seeds from the parent array's `examples` for that delta.

## Fix

Ask whether the key is **there**, not whether it's truthy:

```php
if (!is_array($value) || !array_key_exists($shape->getName(), $value)) {
  continue;
}
```

`resolveChildValues()`, in the same class, already asks it exactly this way — the `empty()` is the outlier, which is the argument to lead with upstream.

Project-local patch `patches/neo-alchemist-nested-falsy-value.patch` until released; not promoted to [[patches]] (one project so far), same as [[neo-alchemist-nested-markup]].

## Verify it's safe before shipping

The change makes empty strings clear where they used to fall back, so confirm nothing relied on that. Render every composed page before and after and diff the byte lengths — on md, all 8 pages were identical except the one page carrying the bug, which lost exactly the stray widget.

## First hit

ar-md (md) 2026-07-28. A `table_s1` panel with `filter => false` rendered a search box, because the component's `tables` example for delta 1 sets `filter: true`. Nothing in the editor UI would ever have fixed it.
