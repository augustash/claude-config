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

Ask whether the key is **there**, not whether it's truthy — **but exempt regions**:

```php
if (!is_array($value) || !array_key_exists($shape->getName(), $value)) {
  continue;
}
// A REGION cannot express a value: its children live in the component tree and
// RegionShape::form() sets #access = FALSE, so every form rebuild submits an
// empty array for it. Honouring that empty wipes the tree.
if ($shape instanceof ComponentShapeRegionPluginInterface && empty($value[$shape->getName()])) {
  continue;
}
```

`resolveChildValues()`, in the same class, already asks it the `array_key_exists()` way — the `empty()` is the outlier, which is the argument to lead with upstream.

⚠ **Ship the region exception with it, always.** Without it this patch converts one bug into a worse one: **the first Alchemist save of any component with a repeater-nested region empties every region on the page.** The stored tree still holds every child component, so nothing is lost — but the page renders its sections empty, and the unset props then show SDC examples, so it presents as catastrophic data loss. A re-run of the page's build script restores it completely, which is the tell that it is a resolution failure and not lost data.

Project-local patch `patches/neo-alchemist-nested-falsy-value.patch` until released; not promoted to [[patches]] (one project so far), same as [[neo-alchemist-nested-markup]].

## Verify it's safe before shipping

The change makes falsy values clear where they used to fall back, so confirm nothing relied on that.

**Diffing rendered byte lengths is NOT sufficient — it is what missed the region regression.** Writing the tree from a script produces a correct page either way; the damage only appears once a human saves a component in the editor, because that is what submits the empty. So the verification has to include:

1. Render every composed page, before and after — byte lengths identical except the page carrying the bug.
2. **Then open a component in the Alchemist editor, change one field, save, and re-render.** Assert the region children are still there. This step is the one that matters and the only one that would have caught it.

## The deeper cause, worth knowing

This whole family — this bug, [[neo-alchemist-nested-markup]], and unused props rendering phantom example rows — is one behaviour: **`ComponentShapePluginBase::init()` seeds every shape with its schema `examples`** (`$defaultValue = $this->getDefaultValue()` → `setFieldItemValue()`) and only replaces that seed when an override value is present. Examples act as a *seed*, not a *fallback*, so absence or falsiness leaves fabricated content in place. The patches above each fix one downstream symptom. A prop a builder never writes will show its examples on the **live page** — the fix on our side is to write the key explicitly (present-but-empty), which is what lets the resolver tell "deliberately nothing" from "never set".

## First hit

ar-md (md) 2026-07-28. A `table_s1` panel with `filter => false` rendered a search box, because the component's `tables` example for delta 1 sets `filter: true`. Nothing in the editor UI would ever have fixed it.
