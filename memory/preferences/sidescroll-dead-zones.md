---
name: Chrome outside a horizontal scroller creates dead zones, and the scroll cue sits in one
description: native sidescroll silently does nothing over part of a strip — the affordance is usually in the dead zone; also the rule that a plain vertical wheel must never be hijacked
type: feedback
---

**If a strip sidescrolls, every sidescroll gesture the platform offers should work over the
whole bar.** It usually doesn't, and the failure is silent.

A horizontal gesture acts on the nearest **horizontally scrollable** ancestor of whatever the
pointer is over. Any furniture placed *outside* the scrolling element — a decorative edge, a
sticky label, a `»` scroll cue — is a dead zone: the gesture finds no horizontal scroller,
walks up to the page, and nothing moves.

**The cue is normally in the dead zone**, which is the cruel part: it has to sit outside the
scroller or it scrolls away with the content, so the one thing telling the reader "there is
more this way" is the worst place to try it.

Fix by forwarding from the outer wrapper to the scroller, and forward **only gestures that
are already horizontal** — a `deltaX` (trackpad swipe, tilt wheel) or wheel-with-shift. Hand
the gesture back at either end rather than swallowing it, or the page freezes whenever the
pointer rests on the strip.

## ⚠ Never turn a plain vertical wheel into a sidescroll

Kaza's rule, 2026-08-01, after it was tried and reverted the same day. Normal scrolling
belongs to the page: hijack it and the reader scrolls, the pointer happens to be over a strip,
and the page stops while the strip slides. That is an annoyance, not an affordance.

Nothing needs adding anyway — trackpad swipe, shift+wheel and tilt wheels are all horizontal
gestures the browser already applies. **The job is coverage, not mechanism**, and no OS should
be special-cased.

## Diagnosing

Don't reason about it — ask the page what the pointer actually hits, at several points across
the bar:

```js
document.elementFromPoint(x, y)   // then walk parents for overflow-x auto/scroll
```

A centre hit that returns the scroller while the edges return its wrapper *is* the bug.

## The other half: a scroller made entirely of links can't be dragged

Click-and-drag implementations normally refuse to start on `<a>`/`<button>` so links stay
clickable. A nav row that is *nothing but* links therefore has no drag at all — every press is
refused. Allowing drags to start on a link is safe when the implementation already swallows
the click after a real drag past a threshold; leave form controls excluded.

Related trap: a drag-scroll library that documents itself as finding scrollers "by what they
do" may actually carry a hardcoded **allowlist** of selectors. Read the attach call before
believing the docblock — a new scroller gets nothing until it is named.
