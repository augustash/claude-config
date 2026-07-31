---
name: neo_animate hides one component at some viewport heights
description: "A single component stays at opacity 0 forever while its neighbours reveal normally, and WHICH component changes with the window height. neo_animate's two reveal observers share one callback, so the edge observer — whose root is shrunk by 12% of the viewport — retracts elements the ratio observer just revealed. Arming unobserves both, so the retraction is permanent. Fixed by a local patch; upstream PR pending."
type: reference
---

# neo_animate hides one component at some viewport heights

## The tell

One component on a page never appears. Its neighbours are fine. In the DOM it is
present and correctly sized, with `opacity: 0` and no `neo-animate--animated` class.

The distinguishing symptom is that **which component fails moves with the window
height** — a section that is blank at 1350px is fine at 900px, where a different one
goes blank instead. It survives hard reload, cache clears, scrolling onto it, and is
identical anonymous and authenticated.

That combination sends you hunting content bugs — a builder that dropped a section, a
bad prop, a failed render — and the content is always fine.

## Cause

`neo-animate.ts` watches every root two ways, because neither rule covers the whole
range: RATIO (`threshold: 0.12`) can't be satisfied by anything taller than ~8x the
viewport, and EDGE (negative bottom `rootMargin`) can't be reached by an element in
the last 12% of viewport height at the document bottom.

Both observers were wired to the same `onReveal`. An `IntersectionObserverEntry`
exposes **no handle on the observer that produced it**, so the callback cannot tell
them apart — and its retract branch fires on `intersectionRatio === 0`, which is
exactly what the edge observer reports for everything below its trigger line (the
bottom 12% of the viewport, plainly on screen).

So an element arming in that band is revealed by the ratio observer and torn down by
the edge observer moments later. Arming also **unobserves both**, so nothing is left
watching and it can never re-arm. The retraction is terminal.

The rule was already written in a comment above that branch — "Only the ratio observer
is allowed to retract a reveal" — it simply wasn't enforceable as written.

## Fix

Pass the distinction in at construction rather than sharing one callback:

```ts
const handleReveal = (entries: IntersectionObserverEntry[], mayRetract: boolean): void => { … };

observer     = new IntersectionObserver((entries) => handleReveal(entries, true),  { threshold: THRESHOLD });
edgeObserver = new IntersectionObserver((entries) => handleReveal(entries, false), { threshold: 0, rootMargin: EDGE_MARGIN });
```

The stagger pair has the identical flaw, gated on `neo-animate-repeat`: there the edge
observer resets an on-screen item every frame it spends in the band, which reads as a
flicker rather than as a disappearance. Fix both together — one defect in two places.

**Status: local patch, upstream PR pending.** `patches/neo-animate-edge-observer-retract.patch`
on ar-md. Delete this memory and drop the patch once it is released upstream. ⚠ The patch
touches `src/js/neo-animate.ts` only — the browser loads the compiled
`themes/<theme>/dist/neo-animate2.js`, so a rebuild is required after applying or the
patch looks like it failed (see the neo-build skill).

## Don't try to verify this in an automated browser

IntersectionObserver callbacks **do not fire in a backgrounded tab**. Any headless or
MCP-driven tab that isn't foregrounded reports every animated element as unarmed at
`opacity: 0`, which looks exactly like this bug and is not. Both a probe observer and
the module's own will return nothing. Have a human reload at two window heights instead;
that is a one-round-trip check and the automation is not.

First hit: ar-md (md) 2026-07-31, a knowledge article whose 4th section went blank at
1350px and whose 3rd went blank at 900px. Introduced by the commit that added the edge
observer to fix long-page reveals — the pairing was right, the shared callback was not.
