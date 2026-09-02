---
name: component:// and theme:// srcs get NO image style, so the committed file is what ships
description: "neo_image() derives responsive AVIF derivatives only from a managed file. A `component://`, `theme://` or external URL is emitted verbatim — same as pasting the path into src. The twig looks identical either way, so oversized bundled art ships at full weight with nothing in the markup to show it."
type: reference
---

# `component://` srcs bypass image styles entirely

`neo_image()` / `neo_image_style()` produce derivatives by running an **image style** over a
managed file. An image style is a file-system operation on `public://` — so it has nothing to
act on when the source is:

- `component://images/foo.jpg` — art bundled inside a component folder
- `theme://…` — art in the theme directory
- `https://…` — any external URL

Those are emitted **verbatim**, exactly as if the path were typed into `src`. No resize, no
AVIF, no `<picture>`, no `srcset`.

## The tell

Nothing in the twig. The call is character-for-character the same whether the src is a media
file or bundled art:

```twig
{{ neo_image(row.image.src, {lg: {op: 'focal', width: 1200, height: 800}}, row.image.alt) }}
```

Media file → `<picture>` with `…/styles/neo-f--w-1200_h-800/public/x.jpg.avif` and
`loading="lazy"`. Bundled art → a bare `<img src="/themes/front/components/…/foo.jpg">` at
whatever the file happens to be. The op arguments are silently inert.

So the symptom is never a broken image — it is **weight**. Images that load visibly slowly, or
a `naturalWidth` far larger than the slot. Check `naturalWidth` against the rendered CSS width;
a 3840 in a 574px box is the signature.

## Why it bites hardest on `examples:`

Component `examples:` are exactly where non-managed srcs live, so demo art is the usual victim
— and demo art is the least likely thing anyone profiles. On md (2026-08-17) a hero's ten
example images were wallhaven originals up to 6144×3456; the set totalled **71MB** against a
card whose real slot is 574×512. The twig requested `focal` crops at 768/1024/1200 and every
one of them was ignored.

## What to do

**Size bundled art on disk — it is the only lever.** Whatever is committed is what the browser
downloads:

```
magick src.jpg -resize 1200x900^ -gravity center -extent 1200x900 \
  -strip -interlace Plane -quality 82 out.jpg
```

Target the slot's real rendered width (measure it; do not guess from the container), ×2 for
retina. The 71MB set above came to 2.1MB at 1200×900.

Real editor content is unaffected — it arrives as a managed file from the media library and
does get the full responsive/AVIF/focal treatment. **Don't read the weight of a component's
examples as the weight of a real placement**, in either direction.

## Related

`loading="lazy"` is applied to every image neo_image renders, including the LCP one. Override
it on a hero via the 5th argument — `neo_image(src, sizes, alt, '', {fetchpriority: 'high',
loading: 'eager'})` — which does reach the `<img>`, not just the `<picture>`.
