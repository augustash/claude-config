---
name: Cap a full-bleed photo at its own width, backfill with a blurred copy
description: Kaza's treatment for a full-bleed hero photo on screens wider than the image; never let the photo scale up past its pixels.
type: feedback
---

A full-bleed hero photo **stops at its natural width**, centered. Behind it sits a tiny copy of the same
image (around 240px wide, low quality, a few KB), stretched to the full viewport with `cover` and blurred
hard (around 28px). Above the photo's width, the sharp photo's left and right edges fade into the blurred
copy with a horizontal mask (12% each side), so there is no seam. Below that width nothing changes,
because the sharp photo still covers the area.

**Why:** a `cover` background scales up without limit on ultra-wide screens and goes soft or blocky. The
blurred copy is meant to be out of focus, so its poor quality never shows, and it reads as the scene
continuing. Kaza, su proposal 2026-10-30: *"that bg image expansion treatment is great. Love it."*

**How to apply:** use it on any full-width photo band: hero, photo dividers, page headers.

- Two layers inside an `aria-hidden` wrapper: `.soft` set to `inset:-60px` so the blur doesn't leave a
  pale fringe at the edges, and `.sharp` set to `width:min(100%, <natural px>)`, centered with
  `left:50%` and `translateX(-50%)`.
- Apply the mask only in `@media (min-width:<natural px>)`.
- Any overlay gradient and the content each need their own z-index above the layers.
- Hide the layers in print.

Reference: `~/Projects/su-proposal/src/su.src.html`, `.hero-bg`. In Drupal, the soft copy is just a tiny
image style of the same media.
