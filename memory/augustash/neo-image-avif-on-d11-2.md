# Neo image derivatives are AVIF on Drupal 11.2+, which breaks every link preview

**Symptom.** Link previews break everywhere — iMessage, Slack and most scrapers show either
nothing or a random image grabbed from the page instead of the one the page declares. The site
itself looks perfect: Chrome decodes AVIF, so no image on any page appears wrong, and nobody
opens a share sheet during development. Often first noticed months later as "sharing this page
shows a video thumbnail from halfway down it".

**Cause — and it is DELIBERATE, not a bug.** `NeoImageStyle::getImageStyle()` (neo_image)
appends a conversion effect to **every** dynamic Neo derivative, picking the plugin by core
version:

```php
$effectId = version_compare(\Drupal::VERSION, '11.2.0', '>=') ? 'image_convert_avif' : 'image_convert';
$image_style->addImageEffect(['id' => $effectId, 'data' => ['extension' => 'webp']]);
```

⚠ **Read that as progressive enhancement, because that is what it is.** Core's
`AvifImageEffect` converts to AVIF where the toolkit supports it and falls back to
`configuration['extension']` where it does not — so `extension: webp` is the *fallback*, and
the line means "AVIF where available, WebP otherwise". Below 11.2 the plugin does not exist,
hence the version gate. Nothing is misconfigured.

⚠ **Do not report this to jacerider as a bug.** (Filed that way here on 2026-08-13 and
corrected the next day — the `extension: webp` key reads like a request for WebP if you have
not read `AvifImageEffect`, and it is easy to conclude the module is silently doing the wrong
thing. It is not.) The real gap is narrower: **there is no way to opt one derivative out of
format conversion**, and AVIF is the wrong format for exactly one class of consumer.

**What actually changed.** Below 11.2 these derivatives were WebP, which most scrapers do
read. A minor core bump moved them to AVIF, which most scrapers do not — so a site that shared
correctly for years silently stopped, with nothing in either project's release notes
connecting the two.

**Confirming it.** Look at a rendered URL, not the config — these styles are generated per
request and never appear in `image.style.*`:

```
curl -s https://site/some-page | grep -oE 'og:image" content="[^"]*"'
# …/styles/neo-e--w-1200_h-630/public/whatever.png.avif   ← the .avif suffix is the tell
curl -s -o /dev/null -w '%{content_type}\n' '<that url>'   # image/avif
```

## Why this breaks sharing and nothing else

⚠ **Open Graph has no fallback slot.** A page declares ONE image. A consumer that cannot decode
it discards the declaration and scrapes the page, taking whatever image sits highest — so the
symptom presents as "it picked the wrong image", which sends you hunting for an image-selection
setting that does not exist. The first image is what you get *after* the declared one fails.

The fix is therefore never a backup image. It is a declared image the consumer can read.

## Fixing it

**Route the share image around the Neo pipeline entirely** — this is the fix whether or not
anything changes upstream, and it is the one that cannot regress when the pipeline changes
again:

- A committed PNG/JPEG for the default share card. Not a derivative of anything.
- A plain config image style with **no convert effect** for any contextual image (a product
  photo), so the derivative keeps its source format.
- Point `og_image` / `og_image_url` / `image_src` / `twitter_cards_image` and the schema
  `image` / `logo` tags at those via `hook_metatags_alter()`.

⚠ **Guard the convert-free style with a test.** Adding a convert effect to it later looks like
an optimisation and reinstates the whole fault, invisibly. Assert that no effect's plugin id
contains `convert`.

⚠ **Do NOT switch the site off AVIF globally to fix this.** AVIF is the right format for
on-page images — smaller, and every browser in use reads it. The fault is confined to surfaces
consumed by non-browsers, and narrowing the fix there keeps the payload win.

**Upstream, if raising it with jacerider** ([[repositories]]): frame it as a feature request —
a way to mark a derivative "no conversion" (or to set its output format), so machine-consumed
surfaces can opt out while on-page images keep AVIF. Not a bug report.

Related: [[neo-metatag-description-slogan]] (the same shipped metatag defaults, other half of
the same audit), [[exo-d11-image-formatters]].
