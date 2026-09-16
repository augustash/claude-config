---
name: exo_modal draws portrait video into a landscape box, and no modal iframe can go fullscreen
description: "getIframeResponsivePadding() derives the padding-bottom ratio from the larger side, so portrait media gets the inverted ratio and a square one collapses to zero height. The modal iframe also carries no allowfullscreen, so the provider hides its fullscreen button — leaving no way to escape the wrong-shaped box."
type: reference
---

# A vertical video in an exo modal renders as a narrow column

`ExoModal.getIframeResponsivePadding()` picks the ratio off whichever side is larger:

```ts
if (width > height) percent = (height / width) * 100;
if (height > width) percent = (width / height) * 100;   // inverted
return percent;                                          // and 0 when square
```

The padding-bottom trick is **always** `height / width`. Deriving it from the larger side means
a 9:16 video gets `56%` instead of `178%` — a landscape box — and the player pillarboxes the
video into a thin strip down the middle. A square video gets `0`, so the iframe has no height
at all.

## The tell

The report is **"the video is teeny on my phone"**, and it is right: the box is
viewport-width and 16:9, so on a 390px handset the video column ends up ~120px wide. It looks
like a responsive-CSS problem, so the instinct is to go hunting in the theme — but the theme
has nothing to do with it. The number is written inline by exo's own JS.

Check the wrapper, not the stylesheet:

```js
document.querySelector('[class*="-iframe-responsive"]').getAttribute('style')
// padding-bottom: 56.338%;   <-- for a 1400x2485 video. Should be 177.5%.
```

Desktop hides it. A wide viewport makes the same wrong box big enough to look deliberate, so
the bug reads as "someone chose to letterbox it" until someone opens it on a phone.

## Second, independent bug: no fullscreen anywhere

The modal builds its iframe as `'<iframe class="' + this.name + '-iframe"></iframe>'` — no
`allowfullscreen`, no `allow`. The default permissions policy for `fullscreen` is `self`, so a
cross-origin player frame is **denied** the Fullscreen API and Vimeo/YouTube hide the button
rather than offer a dead one. Setting the attribute later doesn't help: it is read when the
frame navigates, and exo assigns `src` before `dialog:beforecreate` fires, so a theme-level
hook is already too late without forcing a reload. It has to be in the markup.

These two compound: the video is in the wrong-shaped box *and* there is no control to escape
it. Fix one without the other and the complaint stands.

## How to find every affected page

The dimensions are in `drupalSettings` on every rendered page, so a crawl of the sitemap
answers "how many" without touching the database:

```
"iframeWidth":"1400px","iframeHeight":"2485px"     # height > width == broken
```

On kow (2026-09-03) that was **84 of the 95** pages carrying a video modal — every one of the
77 How-To Videos, plus seven board articles. Vertical video is the norm for social-first
content now, so expect the majority, not a handful.

**How to apply:** when a client says a video is tiny on mobile, read the responsive wrapper's
inline `padding-bottom` before anything else — if it is under 100% on a portrait video, this is
it. Fix `getIframeResponsivePadding()` to return `(height / width) * 100` unconditionally and
add `allowfullscreen allow="autoplay; fullscreen; picture-in-picture; encrypted-media"` to the
iframe markup. Landscape output is unchanged by the ratio fix, so there is nothing to regress.
Carried on kow as `patches/exo-modal-portrait-video-and-fullscreen.patch` against
jacerider/exo 2.0.19, pending an upstream release — see [[carried-fix-obsolete-check]].
