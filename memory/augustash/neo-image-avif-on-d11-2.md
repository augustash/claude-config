# Every Neo image derivative becomes AVIF on Drupal 11.2+

**Symptom.** Link previews break everywhere — iMessage, Slack and most scrapers show either
nothing or a random image grabbed from the page instead of the one the page declares. The site
itself looks perfect: Chrome decodes AVIF, so no image on any page appears wrong, and nobody
opens a share sheet during development. Often first noticed months later as "sharing this page
shows a video thumbnail from halfway down it".

**Cause.** `NeoImageStyle::getImageStyle()` (neo_image) appends a conversion effect to **every**
dynamic Neo derivative, and picks the plugin by core version:

```php
$effectId = version_compare(\Drupal::VERSION, '11.2.0', '>=') ? 'image_convert_avif' : 'image_convert';
$image_style->addImageEffect(['id' => $effectId, 'data' => ['extension' => 'webp']]);
```

⚠ **The `extension` key is not the format being requested.** Core's `AvifImageEffect`
(`image_convert_avif`) converts to AVIF whenever the toolkit supports it and only falls back to
`configuration['extension']` when it does not:

```php
public function getDerivativeExtension($extension) {
  return $this->isAvifSupported() ? 'avif' : $this->configuration['extension'];
}
```

So the code reads as though it asks for WebP, and emits AVIF. Below 11.2 the same line used
plain `image_convert`, which honours `extension` — meaning **a minor-version bump silently
changed the output format of every image on the site**, with nothing in the release notes of
either project connecting the two.

**Confirming it.** Look at a rendered URL, not the config — these styles are generated per
request and never appear in `image.style.*`:

```
curl -s https://site/some-page | grep -oE 'og:image" content="[^"]*"'
# …/styles/neo-e--w-1200_h-630/public/whatever.png.avif   ← the .avif suffix is the tell
curl -s -o /dev/null -w '%{content_type}\n' '<that url>'   # image/avif
```

## Why this breaks sharing specifically, and not the site

⚠ **Open Graph has no fallback slot.** A page declares ONE image. A consumer that cannot decode
it discards the declaration and scrapes the page, taking whatever image sits highest — so the
symptom presents as "it picked the wrong image", which sends you looking for an image-selection
setting that does not exist. The first image is what you get *after* the declared one fails.

The fix is therefore never a backup image. It is a declared image the consumer can read.

## Fixing it

**On the site — route the share image around the Neo pipeline entirely.** A committed PNG for
the default card, plus a plain config image style with **no convert effect** for any
contextual image (a product photo), so the derivative keeps its source format. Point
`og_image` / `og_image_url` / `image_src` / `twitter_cards_image` and the schema `image`/`logo`
tags at those via `hook_metatags_alter()`. This cannot regress when the pipeline changes again
— and it already changed once, silently.

⚠ **Guard the style with a test.** Adding a convert effect to it later looks like an
optimisation and reinstates the whole fault, invisibly. Assert no effect's plugin id contains
`convert`.

**Upstream — it is jacerider's module** ([[repositories]]), so a PR beats a carried patch. The
minimal correct change is to stop conflating the two plugins: use `image_convert` when WebP is
what is wanted, and reserve `image_convert_avif` for where AVIF is genuinely intended.

⚠ **Do not "fix" this by setting a site-wide non-AVIF default.** AVIF is the right format for
on-page images — it is smaller and every browser in use reads it. The problem is confined to
the surfaces consumed by non-browsers, and narrowing the fix to those keeps the payload win.

Related: [[neo-metatag-description-slogan]] (the same shipped metatag defaults, other half of
the same audit), [[exo-d11-image-formatters]].
