---
name: Serving a background video at more than one size
description: How to hand a phone a smaller video than a desktop, and the one thing that decides whether declarative source-media is enough or JS is required.
type: reference
---

Two mechanisms, and the choice between them is about **how many axes** vary.

## One axis — use `<source media>`, it really does work

A `<source>` inside `<video>` whose media query does not match is skipped, and if nothing
matches the element ends at `networkState === 3` (NETWORK_NO_SOURCE) having fetched
**nothing**. That is the whole payload win: a phone downloads no video at all, and the
`poster` carries the slot.

```twig
<video poster="…" data-video-reveal muted loop playsinline preload="metadata">
  <source src="…/clip.webm" type="video/webm" media="(min-width: 48rem)">
  <source src="…/clip.mp4"  type="video/mp4"  media="(min-width: 48rem)">
</video>
```

⚠ **MDN says the `media` attribute is "not allowed" outside `<picture>`, and that reads as
"it does not work" — it is not the same claim.** It is a *content-model conformance* rule; the
media element's own resource selection algorithm consults `media` regardless. Measured in
**Chrome 151** (2026-08-18): a never-matching query selected no source and reached
NETWORK_NO_SOURCE; an always-matching one selected normally.

⚠ **Only Chrome was measured.** Re-run the probe rather than trusting this line for another
engine — build a `<video>`, append a `<source>` with `media="(min-width: 99999px)"`, call
`load()`, and read `networkState`. Cheap and decisive.

⚠ Ordering is the codec preference, not the size gate: the browser takes the **first** source
it can play, so put the better codec first and repeat the same `media` on every entry.

## Two axes — codec as well as size means JS

`<source type>` cannot separate **AV1 from H.264**: they share the `video/mp4` container, so
the bare MIME type accepts both and a pre-AV1 browser will claim a file it cannot decode. A
`codecs=` parameter can express it, but you are then hardcoding a guess about a profile
string. Ask instead:

```js
const av1 = video.canPlayType('video/mp4; codecs="av01.0.05M.08"') !== '';
```

Once JS is choosing the codec, let it choose the tier too — one decision in one place beats a
declarative gate and a scripted one disagreeing. Ship the `<video>` with `preload="none"` and
**no `<source>` children at all** so nothing is fetched before the choice is made, then append
one and call `load()`. Reduced motion and `navigator.connection.saveData` become early
returns that fetch nothing, and JS-off leaves the poster, which is a correct page.

⚠ Do **not** re-pick on resize: swapping the source of a playing `<video>` restarts it at
frame 0, so dragging a window across a breakpoint cuts the loop. Decide once.

## Encoding, for a clip that is a ground rather than a subject

- **Denoise before encoding** (`hqdn3d=2:1:2:3`). Camera grain is what the encoder spends
  its bits on and none of it survives being a background. This roughly halves the output —
  a bigger lever than the CRF.
- **AV1 (`libsvtav1`) around CRF 46** landed ~40% under H.264 at visually equal quality on
  real footage; VP9 via `libvpx-vp9` single-pass CRF lost to H.264 outright and was dropped.
- **A seamless loop is an encode, not a runtime trick.** Cross-dissolve the last second into
  the first (`xfade` + `concat`) so the file's end matches its start; `loop` then never shows
  a cut. Only viable when the clip's first and last frames are compositionally close — check
  them before committing to it.
- Strip audio (`-an`) and set `-movflags +faststart`.

Playback timing is a separate question — see [[bigpipe-pantheon]] for why "it works locally"
is not evidence, and prefer starting a background clip on reveal rather than on load so a
loop is not already part-spent when it is first seen.
