---
name: A finished neo-animate reveal leaves an identity transform that seals a stacking context
description: "neo-animate-enter--* keeps its final keyframe, so the element holds transform: matrix(1,0,0,1,0,0) forever after. It changes nothing visually but still creates a stacking context, sealing every descendant into one layer — so no sibling can be interleaved between two children, and z-index alone will never fix it."
type: reference
---

# A finished neo-animate reveal still creates a stacking context

Any element carrying `neo-animate neo-animate-enter--fadeInRight` (or any other `enter--`
variant) ends its animation with `neo-animate--animated` applied and the final keyframe
retained. Computed style afterwards:

```
transform: matrix(1, 0, 0, 1, 0, 0)
```

That is the identity matrix — it moves, scales and rotates nothing. But **any** `transform`
other than `none` creates a stacking context, and the spec does not care that this one is a
no-op.

## Why that matters

A stacking context flattens everything inside it into a single layer *relative to the outside
world*. Descendants can reorder among themselves, but nothing outside can be placed between
two of them. So an element with a spent reveal on it silently becomes a wall:

- A sibling cannot be layered between two of its children.
- Raising the sibling's `z-index` does nothing — the whole subtree still paints as one unit.
- Lowering the wrapper's own `z-index`, or setting it to `auto`, **also** does nothing. The
  transform alone is sufficient; z-index is not what creates the context here.

## The tell

A decorative sibling that "will not come forward no matter what z-index it gets", where the
numbers all look right. Confirm by walking the ancestors and flagging every context-creating
property, rather than reading z-index:

```js
for (let el = target; el && el !== document.body; el = el.parentElement) {
  const s = getComputedStyle(el);
  const makes = s.transform !== 'none' || s.filter !== 'none' || s.opacity !== '1'
    || s.isolation === 'isolate' || s.willChange !== 'auto' || s.mixBlendMode !== 'normal';
  console.log(el.className, {z: s.zIndex, transform: s.transform, makes});
}
```

`transform: matrix(1, 0, 0, 1, 0, 0)` reads as harmless in devtools and is the thing to spot.

## The fix, and the trade

**Drop the reveal classes from that element** in the state that needs interleaving. There is no
way to keep both: any transformed wrapper re-seals the subtree, so moving the animation to an
inner wrapper just relocates the wall.

Where a reveal is genuinely wanted, an **opacity-only** fade is compatible — `opacity` creates
a context only while it is below 1, so a fade that finishes at 1 leaves nothing behind. A
transform-based one never stops costing.

First hit: md 2026-08-17, hero_s2. The green band had to sit between the first and second image
of a queue; the figure's spent `fadeInRight` made that impossible until the classes came off in
that state. Related: [[neo-base-css-button-specificity]] for the other case where Neo's own CSS
quietly outranks what a component is trying to do.
