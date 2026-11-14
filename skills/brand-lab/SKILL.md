---
name: brand-lab
description: Build a logo or brand identity as a live, all-vector lab page the owner shapes in their own browser — a mark refined from existing artwork, its colour treatment, a size ladder, one-colour versions, a crown or ornament, and a wordmark chosen from a font board, then shown on every ground. Use when someone is redesigning a logo, mark, shield, crest, monogram or wordmark, or choosing a brand typeface, and wants to steer it by eye. NOT for a website mockup or a client pitch (those are client-report / pitch work), and NOT for a one-off icon export.
---

# Brand lab

A logo is designed by **steering**, not by specification. The owner reacts to what they
see; your job is to put the right thing in front of them fast, at real size, and to make
every change they ask for land everywhere at once. Refined on the Ashen Rayne shield
(eagle, fleur-de-lis crown, Michroma wordmark), November 2026.

---

## 1. The lab is the medium

**One self-contained HTML page, served locally, that the owner keeps open in their own
window.** Not screenshots, not a deck. Everything in it is SVG geometry built by script,
so it scales from a 16px favicon to a billboard.

- **Serve it, don't `open` it.** A tiny server ([templates/brand-lab/serve.py](../../templates/brand-lab/serve.py); widen its POST whitelist per lab) serves the folder with
  `Cache-Control: no-store` and accepts POSTs for the files the page saves. Run it detached
  (`nohup … & disown`), not as a session shell, so it outlives the conversation.
- **Live reload.** The page polls HEAD on its own files once a second and reloads in place
  (keeping scroll) when one changes. The owner never refreshes; never tell them to.
- **Settings persist.** Every slider/select is in one `KEEP` list; values save to
  `settings.json` through the server (and localStorage as a mirror). Read that file to know
  what they set — don't ask. Record the window size in it too (`_view`): test layouts at
  *their* viewport, which is rarely yours.
- **One shared definition, many views.** Build each treatment once into `<defs>` (`<g id>`),
  and have the big stage, the ladder and every board `<use>` it. A fix in one place reaches
  every view, which is what the owner expects.
- **Controls appear, then disappear.** Expose a slider while a decision is open; when they
  say "that's it", bake the value as the default and move the control into a hidden block.
  The panel ends up holding only what's still undecided.

## 2. Vector from the source

- **Start from their artwork, exactly.** Extract curves from the source file rather than
  redrawing. Affinity `.af`: the body is zstd after `#Fil`; curves sit under `PCvD`/`Data0`
  as records of two doubles plus two flag bytes (flag ≥ 1 marks a node). SVG: parse paths
  absolutely (handle relative commands and `m` after `z`).
- **Geometry with booleans, not masks.** Use `skia-pathops` for union/intersect/difference,
  offsets (Minkowski with rotated copies) and cleanup. Masks and filters are for colour, not
  shape.
- **Refine a complex mark in a separate agent process.** A build pipeline with validators:
  symmetric halves mirrored from one side, tips forced to single points, collisions and gaps
  checked, smoothness sweep for bumps and kinks, detached islands removed. The agent works in
  scratch files and **publishes once, when everything passes** — the owner sees each publish
  live, so half-done attempts are noise. When the owner points at a spot ("the second feather
  from centre"), have the agent render the same crop and confirm it's the right edge before
  changing anything; misidentified edges cost whole rounds.

## 3. Colour, light and the split

- **One light source.** Depth comes from a single light the whole mark agrees with. Two
  halves (night/day, dark/light) are built from **parallel palettes** — same stops, same
  rays, mirrored — so they meet exactly at the centre line.
- **Counterchange** reads best at small size: field and figure swap colours across the split.
- **Flipping sides is a mirror, not a recolour.** Swapping palettes left the lighting where it
  was and changed the whole feel. Mirror the finished treatment with `scale(-1 1)` and draw an
  asymmetric figure (a head, a beak) pre-mirrored so it still faces the right way.
- **Brightness without filters.** SVG filters rasterise and go soft at scale. Use grey layers
  with `mix-blend-mode` (multiply to darken, color-dodge to brighten); keep the clip inside the
  mask, because a clip on the layer isolates it and kills the blend.
- **Seams.** Two shapes that meet edge to edge on a line leave a hairline of background at
  normal sizes. Run the first-drawn half a hair past the line (and the rectangles inside it, not
  just the clip) so the second covers the join. Check by scanning pixels at real sizes with the
  art off the pixel grid, not by zooming in (zoom hides it).

## 4. The size ladder and one colour

- **Real pixel sizes**, side by side: colour on dark, colour on light, one colour on white,
  black, the brand colours. Size the top rung to fill its column; let extra grounds side-scroll.
- **Snap every rung to whole device pixels** after layout (centring leaves half pixels that
  blur small art).
- **One colour is a mask**, and it needs a **reversed** version for light ink on dark grounds,
  or the halves swap meaning.
- **Small sizes get simpler marks**, decided by eye: e.g. 30px = the bare split shield with the
  monogram on it, 16px = the monogram alone.

## 5. Ornaments: start from what they own

- Pull ornaments from the owner's existing assets (the fleur-de-lis came from the old badge's
  background pattern) — instant familiarity, and it's theirs.
- **Let them shape curves by hand.** A drag editor in the page (Photoshop-style points and
  handles, arrow keys to nudge, saved to JSON) beats rounds of auto-fitting. Draw one half and
  mirror it. Model each piece as the fewest curves on the fewest shared points.
- **Even gaps** between pieces: make one piece's edge a true offset of its neighbour's, and show
  that offset as a dashed guide in the editor so a dragged edge has something exact to follow.

## 6. The wordmark

- **Font board**: every candidate as the full lockup (word, mark, word) and the monogram, on
  black and white. Click to **remove** (not to like) — it's a funnel. Persist the removals.
- **Draw letters as vector** from installed fonts ([templates/brand-lab/vector_letters.py](../../templates/brand-lab/vector_letters.py),
  fontTools + pathops, a worked example to adapt): trim to cap height and baseline when a face throws strokes past them; expand
  TrueType `qCurveTo` runs (implied on-curve points halfway between handles) or the outlines
  break. Web fonts can be laid out live by measuring with canvas (`measureText` gives advance,
  ink edges, cap height) — load them explicitly with `document.fonts.load` first.
- **Lockups**: centred (word · mark · word), mark beside the name, the words stacked beside the
  mark (lines one letter-gap apart, the same visible space as between two letters), the mark over the
  name, the monogram. The mark is the unit: letter cap height as a
  share of the mark's height, and an offset up or down — both sliders until settled.
- **Spacing**: start optical (sample each letter's edges across its height; open areas count
  only to a set depth, so a Y or A doesn't read as a gap); match word widths when words stack;
  then give the owner a drag editor with the words one above the other, end lines that run the
  full height, and a small live preview beside it. Their eye is the final say.
- **Fix the letters themselves** when a bar is off: align crossbars to the face's other middle
  bars, match arm lengths. A letter can need a **variant** where it meets a specific neighbour
  (an A beside an R matches the R's bar, not the H's).
- **Monogram letters touching the split**: place by ink edges, then tuck the second letter a
  pixel under the first so no soft seam shows between them.
- **Show it on every ground**, colour and one colour, before anyone falls in love with it on
  black alone. A **blind A/B** (pairs, random order, no names, tally at the end) settles a close
  call between finalists.
- **Licensing**: check every candidate font's licence before it becomes the mark (OFL faces can
  be modified for artwork; commercial faces need a logo licence).

## 7. Sharing it

- Build a **review page** from the lab (`publish.py`): only the sections meant for the viewer,
  settings and data baked in, nothing needing the local server, `noindex`. Build to a local
  preview first; **commit and push only after the owner has seen the final state and said go.**

## Pitfalls that cost rounds

- Testing at your viewport instead of theirs.
- A CSS `display` rule overriding the `hidden` attribute (add `[hidden]{display:none}`), and
  tests that check the flag instead of what's on screen.
- Shared gradient ids: the first copy may sit in a hidden element that won't render; give each
  instance its own id.
- Content sizing itself from its container while the container sizes from it (container-query
  units on a grid item): break the loop with `minmax(0,1fr)` / `min-width:0`.
- A sub-agent "fixing" the wrong edge — confirm against the owner's crop first.
- Units: saved positions from one font (1000/em) applied to another (2048/em).
- Replacing a block of the page's script wholesale and taking a loader with it: saved settings
  silently stop applying. Re-check that every saved file still loads after a big edit.
