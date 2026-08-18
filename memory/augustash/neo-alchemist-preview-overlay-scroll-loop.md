---
name: Editor chrome must not sit in the preview's document flow
description: "Alchemist sizes each preview iframe to exactly its content height, so the document sits permanently a fraction of a pixel from needing a scrollbar. Anything the editor draws INTO that document — outlines, labels, hit targets — can tip it over, and the frame then rings: scrollbar, relayout, resize, repeat, tens of times a second."
metadata:
  type: reference
---

# Editor chrome must not sit in the preview's document flow

The parent sets each preview frame's height from the height the child reports, so
`scrollHeight` and `clientHeight` end up **exactly equal**. That is a knife edge: one extra
fractional pixel inside that document means a scrollbar, and a scrollbar means a relayout,
which changes the reported height, which resizes the frame, which changes it again.

Measured on ar-md at **~90 `size` messages a second**, visible as the preview shaking. It bit
the narrowest frame worst and only while a prop outline was drawn — the outline was the extra
pixel.

**Rule: anything the editor draws over a preview goes on its own layer, outside the flow.**

```css
.neo-alchemist--prop-overlays {
  position: fixed;
  inset: 0;
  overflow: hidden;
  pointer-events: none;
}
```

Fixed and clipped, it cannot influence layout or scroll size at all. Children are then
positioned in **viewport** coordinates, not document ones — safe because the frame is sized to
its content and never scrolls itself.

⚠ **Not browser-specific.** It reproduced in Chrome and Firefox alike. It was first
misdiagnosed as Firefox-only, from Chrome sessions that stayed quiet for unrelated reasons —
so do not let "Chrome looks fine" rule this out. Verify with the counter below rather than by
eye, in whichever browser is to hand.

## Corollaries

- **Entrance animations do not belong in an editor preview.** neo_animate holds elements at
  `opacity: 0` then applies catalog keyframes that move them by `transform`. A preview
  re-renders on every edit, so reveals replay constantly — and anything measured mid-flight
  (prop outlines, the component rects reported to the canvas) lands 30-odd pixels out. A
  transform fires no resize, so nothing ever corrects it. Suppress with
  `animation/opacity/transform` overrides in the preview stylesheet; arming
  `neo-animate--animated` does **not** work, because the driver's IntersectionObserver re-arms
  any new subtree regardless.
- **A transform moves an element without resizing anything**, so a `ResizeObserver` is blind to
  it. Track with `animationend`/`transitionend` when a position must follow.

## Diagnosing this class

Counting beats looking. Hook `window.message` in the parent, count `type === 'size'` per
second, and compare against an idle baseline of 1–5:

```js
let n = 0; window.addEventListener('message', e => { if (e.data?.type === 'size') n++; });
setInterval(() => { console.log('size msgs/sec', n); n = 0; }, 1000);
```

Fixed in the kazajhodo/neo_alchemist fork (2026-08-18), pending upstream merge — until that
lands and is tagged, the loop is live for every other project on a released neo_alchemist.

See [[neo-animate-identity-transform-stacking]] for the other transform gotcha.
