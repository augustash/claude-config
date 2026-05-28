---
name: Pantheon Quicksilver post-deploy cache warmer
description: Drop-in webphp Quicksilver hook that curls the heaviest pages after a Pantheon deploy, so the post-bounce cold-cache dogpile doesn't hit real users. Swap the URL list per site.
type: reference
---

After a Pantheon deploy the FPM container bounces and APCu (the fast tier of ChainedFastBackend) is empty. The first real requests then race to rebuild Drupal's metadata layer — views data, theme registry, plugin definitions, Exo component/imagine defs, menu tree — from cold. With a small worker pool that dogpile produces slow responses and, on a heavy page, 502/503s for a few minutes until caches settle.

The fix is a **Quicksilver `deploy: after` webphp hook** that curls the heaviest pages once each, sequentially, so the shared caches are warm before real traffic arrives. It's a drop-in: copy the script, swap the `$paths` list. Used on MSP and sisal.

**Key design choices (keep these when adapting):**
- **Live only.** Dev/test/multidev deploys are too frequent and their cold pain isn't user-facing.
- **Hit `pantheonsite.io` origin, not the custom domain.** A Cloudflare-/CDN-fronted custom domain may serve the warm request from the edge and never reach origin, so it wouldn't populate Drupal's caches. The platform URL goes straight to origin.
- **Sequential, with timeout headroom.** Earlier pages populate shared caches (theme registry, views data, plugin defs) that later pages reuse. Set `CURLOPT_TIMEOUT` above your slowest cold page.
- **Scope is deploy-time only.** A mid-day cache purge (commerce cache-tag invalidation, cron flush) colliding with a traffic burst is *not* covered — that's an app-level concern (e.g. paging a heavy page so even a cold render is cheap). A deploy is "on us"; warming it is the cheap, predictable win.

**Drop-in script:** [`templates/pantheon-quicksilver-cache-warmer.php`](../../templates/pantheon-quicksilver-cache-warmer.php) in this package. Copy it to `web/private/scripts/cache_warm.php` and swap the `$paths` list — everything else (live guard, origin URL, curl loop, logging) is reusable as-is.

**Wiring** (`pantheon.yml`; with `web_docroot: true` the script path is relative to the web docroot, so `private/scripts/...` → `web/private/scripts/...`):

```yaml
workflows:
  deploy:
    after:
      - type: webphp
        description: Warm critical Drupal caches after deploy
        script: private/scripts/cache_warm.php
```

To pick the URL list, mine the nginx access log for the most-requested cacheable pages (status 200, strip query strings, drop assets/`/api`/`/sites`/`/user`/`/admin`/`/cart`/`/checkout`/`/search`/healthcheck).
