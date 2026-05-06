---
name: Vimeo background=1 embed param
description: Vimeo background=1 embed param can 403 the player URL — symptom looks like domain-allowlist privacy but is actually parameter-driven; replace with explicit params
type: project
---

If a Vimeo background video starts 403'ing on `player.vimeo.com/video/...` (including when the URL is opened directly in a browser, not just embedded), and nothing about the site's domain or Vimeo account changed, suspect the **`background=1`** query param appended in a preprocess/handler.

Symptom looks identical to domain-allowlist privacy rejection (Vimeo says "Because of its privacy settings, this video cannot be played here") but the actual cause is `background=1` failing a Vimeo-side check — likely plan-tier or some change Vimeo rolled out to that param's behavior.

**Fix:** Replace `background=1` with explicit equivalents:

```
&autoplay=1&controls=0&loop=1&muted=1&autopause=0&playsinline=1
```

Reference: sisal `web/themes/ash/components/text_media/TextMedia.php` viewAlter (commit 8985aa35, 2026-05-06).

**Why:** This burned an hour chasing Vimeo privacy settings, billing, and account access on sisal because the symptom presented as domain-allowlist privacy (403 on direct player URL with empty referrer is the textbook fingerprint of allowlist privacy). The actual cause was a single embed param.

**How to apply:** When Vimeo background videos suddenly stop working on an augustash site:
1. Before chasing privacy/plan/domain settings, check the embed src for `background=1` and try swapping to the explicit param list above.
2. Grep `background=1` across themes and modules — preprocess functions and component handlers (Exo `viewAlter`, twig preprocess, Layout Builder formatters) are the usual injection points.
3. If a fresh embed without `background=1` works in a browser but the site's embed doesn't, you've confirmed it.
