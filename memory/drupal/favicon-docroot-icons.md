---
name: Favicon 404 cluster with the icons all present
description: A large icon-only 404 cluster on a site using jacerider/real_favicon — the generated set exists, it just isn't where browsers actually ask for it
type: reference
---

A log audit turning up thousands of 404s on `/favicon.ico`, `/apple-touch-icon*.png` and
`/android-chrome-*.png` is usually **not** a missing-asset problem. On msp it was ~980/day,
**39% of every 404 on the site**, while the complete generated set sat happily at
`/sites/default/files/favicon/<id>/` returning 200 the whole time. Don't go hunting for the
images; check where they're being *requested* from.

Two independent causes, and they need different fixes:

**1. `jacerider/real_favicon` relocates the assets but not the manifests.** It extracts the
realfavicongenerator package into `public://favicon/<entity-id>` (hardcoded — `RealFavicon.php`
`$directory = 'public://favicon'`, no config for it) and rewrites the `href`/`content` of the
`<link>` tags it injects via `normalizePath()`. It does **not** rewrite paths *inside* the
files it extracted, so `site.webmanifest` and `browserconfig.xml` still carry the generator's
original docroot-relative paths (`/android-chrome-192x192.png`, `/mstile-150x150.png`). The
site therefore serves a manifest that 404s its own icons. Working as written, not
misconfigured — so it reproduces on every site using the module.

**2. Browsers probe the docroot regardless of any markup.** `/favicon.ico` and the
`apple-touch-icon` family are fetched by convention whether or not a `<link>` points anywhere.
Nothing in Drupal or the module can suppress these, and on msp they were the *larger* share —
6,385 of 8,849 over nine days, versus 2,464 manifest-driven.

**Why:** cause 2 makes the obvious fix the wrong one. Patching the module to rewrite the
manifests looks like the root-cause fix and addresses only ~28% of the volume; it was
considered and deliberately rejected on msp (2026-08-03).

**How to apply:** copy the generated set to the **docroot**, which fixes both causes at once —
the manifest's existing paths become correct, and the convention probes resolve. Pull the files
from the live files mount so branding matches exactly:

```
web/favicon.ico
web/android-chrome-192x192.png    web/android-chrome-256x256.png
web/apple-touch-icon.png          web/apple-touch-icon-precomposed.png
web/apple-touch-icon-120x120.png  web/apple-touch-icon-120x120-precomposed.png
web/apple-touch-icon-152x152.png  web/apple-touch-icon-152x152-precomposed.png
web/mstile-150x150.png
```

Notes that save a round of debugging:

- Root `web/` static files are **not** gitignored (only `robots.txt` and the contrib/core dirs
  are — see [[pantheon-robots-txt]]), so these commit normally. D10's scaffold ships no
  `favicon.ico`, so nothing overwrites it.
- The `120x120`/`152x152`/`-precomposed` variants aren't in the generator's package; make them
  with `sips -Z <n> apple-touch-icon.png --out <name>` and copy for `-precomposed`. iOS asks
  for those sizes specifically.
- ⚠ **These copies don't track the source.** Re-saving the real_favicon config entity
  re-extracts to the files directory and leaves the docroot untouched, so a rebrand silently
  drifts. Re-copy when the favicon entity changes.
- Ignore `apple-touch-icon-240x240*` — not an Apple size, it's bot traffic.

Verify with a status sweep over each path rather than eyeballing a browser tab; a cached
favicon will lie to you.
