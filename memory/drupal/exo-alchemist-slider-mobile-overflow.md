---
name: exo_alchemist slider mobile overflow (flex min-width: auto)
description: Mobile-only slider overflow caused by flex item refusing to shrink below Swiper's intrinsic width
type: project
---

When an exo_alchemist component uses the `slider` enhancement (Swiper-based) and slides are wider than the viewport on mobile — but work at large breakpoints — the cause is almost always default flex `min-width: auto` upstream of the slider.

**The chain:**

1. `.exo-component-wrapper` is `display: flex`, with `.exo-component-wrapper > .exo-component { flex: 1 1 auto }` (defined in `exo-alchemist.property.css`).
2. The slider markup contains `.swiper-wrapper` (`display: flex`) with N slides each carrying `.swiper-slide { flex-shrink: 0; width: 100% }` from `swiper-bundle.min.css`.
3. With `flex-shrink: 0`, each slide's intrinsic min-width resolves to the parent width. The flex container's intrinsic min-width becomes ~N × viewport.
4. Default `min-width: auto` on the `.exo-component` flex item refuses to shrink below this intrinsic size. The component inflates to N × viewport (e.g. ~1600px on a 375px mobile viewport for 5 slides).
5. `.swiper`'s `overflow: hidden` doesn't save us — by the time the browser would clip, the *parent* is already too wide.
6. Swiper's JS measures the inflated parent at init and writes `style="width: 1600px"` on every `.swiper-slide`. `flex-shrink: 0` then locks that width in for the lifetime of the page.

**Fix:**

```scss
.exo-component-wrapper-<component-name> > .exo-component {
  min-width: 0;
}
```

Letting the flex item shrink below intrinsic content size is the standard remedy for the Flexbox+overflow:hidden interaction. Apply it scoped to the affected component (or globally to all `.exo-component-wrapper > .exo-component` if every slider component is affected). Harmless when the slider isn't active.

**Symptoms to recognize:**

- Slider renders correctly at large breakpoint, broken on mobile.
- Whole component overflows horizontally; title text outside the slider is also clipped (because the *component itself* is too wide, not just the slider contents).
- DevTools: parent wrapper sized correctly (~viewport), but the `.exo-component-<name>` child is many times wider.
- `.ee--slider-item` / `.swiper-slide` has an inline `width` matching that inflated parent measurement, persisting after the parent later shrinks (because of `flex-shrink: 0`).

**Why:** debugged on sisal `features_icon` slider (5 slides). At mobile, `.exo-component-features-icon` measured 1600px while `.exo-component-wrapper-features-icon` was 375px. CSS-tracing surfaced no explicit `width: 1600` rule — it was the flex intrinsic-min-width loop. `min-width: 0` resolved it; on next page load Swiper re-measured at 375px and slides sized correctly.

**How to apply:** when a slider on an exo_alchemist component overflows the viewport on mobile only, jump to this fix before chasing slide margins, swiper settings, or breakpoint configs. Confirm via DevTools that the component itself (the `.exo-component-<name>`) is wider than its wrapper before applying.
