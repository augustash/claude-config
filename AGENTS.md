# August Ash — team conventions for AI assistants

Shared context for AI coding assistants (Cursor, Codex, Aider, Claude Code, and any tool that reads `AGENTS.md`) working on augustash projects. When a task touches one of the topics below, read the referenced file before proceeding — the team has accumulated conventions and hard-won lessons there that generic defaults won't match.

These files are authoritative and kept current by the team. Prefer conventions here over generic defaults. When you learn something worth sharing, update or add a file in the `augustash/claude-config` repo's `memory/` directory and commit it — everyone on the team benefits on their next `composer update`.

> *Generated from `CLAUDE.md`. Don't edit this file directly — edit `CLAUDE.md` and rerun `generate-agents.py`.*

## Preferences & collaboration

- **Mission** — `vendor/augustash/claude-config/memory/preferences/mission.md`  
  shared team resource, proactive guidance, watch-and-suggest posture, Claude as steward at write time (read first; informs how other memories should be written)
- **Follow site conventions** — `vendor/augustash/claude-config/memory/preferences/follow-site-conventions.md`  
  scan how a domain is handled in the codebase before writing in it; surface divergence from established patterns
- **Memory structure** — `vendor/augustash/claude-config/memory/preferences/memory-structure.md`  
  idea/specific.md pattern, organization conventions
- **Reference scripts, don't embed** — `vendor/augustash/claude-config/memory/preferences/reference-scripts-not-embeds.md`  
  store scripts as tracked files (templates/) and link by path; never paste code bodies into notes, even small ones
- **DDEV workflow** — `vendor/augustash/claude-config/memory/preferences/ddev-workflow.md`  
  Always use ddev for CLI commands
- **Memory audit process** — `vendor/augustash/claude-config/memory/preferences/memory-audit.md`  
  opportunistic triggers with a daily-floor pre-check; `last_audit` date tracked in-module (single date, replaced each pass); self-refining
- **Comment style** — `vendor/augustash/claude-config/memory/preferences/comments.md`  
  Concise; skip comments when the code is obvious, explain the WHY when it isn't
- **Scratch context** — `vendor/augustash/claude-config/memory/preferences/scratch-context.md`  
  ~/.claude/scratch/ for temporary cross-project context; offer proactively on project switches
- **Git merge over rebase** — `vendor/augustash/claude-config/memory/preferences/git-merge-not-rebase.md`  
  Default to `git pull --no-rebase` when integrating remote work; only rebase when explicitly asked
- **Commit handoff** — `vendor/augustash/claude-config/memory/preferences/commit-handoff.md`  
  Claude commits + pushes shared claude-config memory; dev reviews + commits + pushes all project work
- **Confirm before live terminus** — `vendor/augustash/claude-config/memory/preferences/confirm-before-live-terminus.md`  
  always confirm before `terminus ... {site}.live` or `.test`; can be batched for read-only command lists
- **Local config in settings.local.php** — `vendor/augustash/claude-config/memory/preferences/local-config-in-settings-local.md`  
  temporary/dev config overrides (aggregation, flags) go in settings.local.php, never `cset`/UI, so they can't be exported to live
- **Log audit** — `vendor/augustash/claude-config/memory/preferences/log-audit.md`  
  sequential one-at-a-time review of server logs, grouped nginx-then-php (nginx access → nginx error → php-error → fpm-error → slow → newrelic); analyze locally, never exfiltrate log contents
- **Test reminders** — `vendor/augustash/claude-config/memory/preferences/test-reminders.md`  
  Surface existing tests when modifying covered code; flag coverage gaps on new or substantial changes
- **Trust contrib tests** — `vendor/augustash/claude-config/memory/preferences/trust-contrib-tests.md`  
  Only cover the seam we own; don't re-verify Drupal core/contrib behavior in our suite. External service APIs (payment gateways, Klaviyo, ShareASale) are the sharpest "not ours" case — never hit a live API; substitute the on-site/dummy equivalent (e.g. the `manual` gateway for checkout)
- **No time-based test waits** — `vendor/augustash/claude-config/memory/preferences/no-time-based-test-waits.md`  
  wait on the real condition (element state, response, count), never a fixed delay; time waits are flaky and slow
- **Proactively clean up cruft** — `vendor/augustash/claude-config/memory/preferences/proactive-cleanup.md`  
  surface/offer to fix non-blocking warnings, dead code, orphaned artifacts near the work; "it still works" isn't good enough; keep cleanup scoped + its own commit

## Drupal

- **Drupal caching** — `vendor/augustash/claude-config/memory/drupal/caching.md`  
  Cache debugging, session poisoning, lazy builders without BigPipe, Exo component cache, Redis compress_length tuning
- **D11.4 symfony/runtime allow-plugin** — `vendor/augustash/claude-config/memory/drupal/d11-symfony-runtime.md`  
  D11.4 adopted Symfony Runtime; `symfony/runtime` allow-plugin must be `true` (not `false`) or `vendor/autoload_runtime.php` never generates and every web request WSODs while drush still bootstraps and hides it. Watch pre-11.4→11.4 bumps carrying a `false` suppression
- **Cross-version DB pull** — `vendor/augustash/claude-config/memory/drupal/cross-version-db-pull.md`  
  pulling an older-Drupal prod DB into newer local code and rebuilding (`cr`/`cim`) before `updatedb` dies on "Unknown column 'alias' in router" (D11.1's `system_update_11201` adds `{router}.alias`, absent in the pulled schema); correct order is `drush deploy` (updatedb→cim→cr). augustash ddev-pantheon-db ≥1.0.5 does this; older = manual `updb` after pull
- **BigPipe is not viable on Pantheon** — `vendor/augustash/claude-config/memory/drupal/bigpipe-pantheon.md`  
  BigPipe is off on Pantheon, so lazy_builder is a no-op. But the cache impact is narrower than it looks: anonymous page_cache + Pantheon Varnish ignore bubbled max-age 0, so most sites cache fine despite scary headers. Diagnose via `x-drupal-cache`/`x-cache` HIT, not `x-drupal-cache-max-age`. AJAX-placeholder strategy module belongs under drupal_cache_protection if/when needed.
- **GTranslate integration — prefer hosted subdomain** — `vendor/augustash/claude-config/memory/drupal/gtranslate-integration.md`  
  Default to hosted subdomain (CNAME each language to `{server}.tdn.gtranslate.net`); zero app load. The self-hosted subdirectory PHP addon is a synchronous per-request TDN proxy with no curl timeout — it saturates PHP-FPM (Pantheon = 6 workers) and serves empty cached 200s. Only argument for subdirectory is SEO. No DNS control → reuse mymspconnect's off-request store rebuild, never a kernel.request fetch. Reference build: reell.com.
- **Cache bin that survives drush cr** — `vendor/augustash/claude-config/memory/drupal/persistent-cache-bin.md`  
  Keep a warm store bin from being wiped by drupal_flush_all_caches: untagged bin (omit `cache.bin`; only when cron/dedicated-tag owns freshness — msp flights board) vs decorator backend that no-ops deleteAll/invalidateAll but stays tagged so real content-tag invalidation still works (mymspconnect gtranslate store). Pick by who owns freshness.
- **Search API / Solr convention** — `vendor/augustash/claude-config/memory/drupal/search-api-solr-convention.md`  
  standard names: index `global`, servers `pantheon_search` (prod) + `local` (DDEV); local server connection injected by settings.local.php against the standardized DDEV Solr Docker build (Solr 8.11 Cloud, `solr_cloud_basic_auth`, `ddev solrcollection` to upload configset). Don't hand-roll off-convention names.
- **Drupal PHPUnit testing** — `vendor/augustash/claude-config/memory/drupal/phpunit-testing.md`  
  Setup and running PHPUnit kernel/unit tests in DDEV
- **Drupal Nightwatch testing** — `vendor/augustash/claude-config/memory/drupal/nightwatch-testing.md`  
  Selenium setup, W3C patch, yarn install, tag-scoped runs. Patch lives at vendor/augustash/claude-config/patches/
- **Playwright UI test writing** — `vendor/augustash/claude-config/memory/drupal/playwright-testing.md`  
  run resource-heavy tests serially (not parallel), wait on conditions not time, warm caches before timing-sensitive tests
- **Update-hook testing** — `vendor/augustash/claude-config/memory/drupal/update-hook-testing.md`  
  skip update-path tests for trivial idempotent config-merge update hooks; test the behavior instead, reserve UpdatePathTestBase for real data migrations
- **Test tag/group convention** — `vendor/augustash/claude-config/memory/drupal/test-tags.md`  
  `aai` umbrella + module sub-tag on every custom test (PHPUnit + Nightwatch)
- **Cross-project patches** — `vendor/augustash/claude-config/memory/drupal/patches.md`  
  index of local .patch files + vetted remote URLs to reuse across projects
- **Pantheon robots.txt** — `vendor/augustash/claude-config/memory/drupal/pantheon-robots-txt.md`  
  Custom disallow rules via Composer scaffold append
- **Pantheon Quicksilver cache warmer** — `vendor/augustash/claude-config/memory/drupal/pantheon-quicksilver-cache-warmer.md`  
  drop-in webphp deploy:after hook that curls heaviest pages post-deploy to beat the cold-cache dogpile; swap the URL list per site
- **Cron off-path page_cache re-prime** — `vendor/augustash/claude-config/memory/drupal/page-cache-cron-reprime.md`  
  uncacheable form-page (CSRF/Turnstile → max-age 0) lives on anon page_cache; a periodic cron eviction dogpiles it (page_cache doesn't coalesce). Cron renders each variant off-path (loopback curl) + overwrites the canonical-cid entry tagless, never deleting → no cold hole. The app-level answer to the mid-day-purge case the deploy warmer punts on
- **Cloudflare tracking params** — `vendor/augustash/claude-config/memory/drupal/cloudflare-tracking-params.md`  
  Tracking param handling via drupal_cache_protection, not CF cache rules
- **Cachetags garbage collection** — `vendor/augustash/claude-config/memory/drupal/cachetags-garbage-collection.md`  
  cachetags table has no GC, needs periodic truncation; build a module
- **Exo optional link field** — `vendor/augustash/claude-config/memory/drupal/exo-alchemist-optional-link.md`  
  `required: FALSE` is a no-op; use `cleanup: FALSE` + `title_type: 'optional'` and check `link.url` in twig
- **Exo modifier checkbox + class** — `vendor/augustash/claude-config/memory/drupal/exo-alchemist-modifier-checkbox.md`  
  Try built-in `modifier_globals.status` flag first (instance-level, auto class); custom YAML modifier + PascalCase handler only when built-in doesn't fit
- **Exo slider mobile overflow** — `vendor/augustash/claude-config/memory/drupal/exo-alchemist-slider-mobile-overflow.md`  
  Slider component overflows on mobile only? Flex `min-width: auto` + Swiper's intrinsic-width markup; fix with `min-width: 0` on `.exo-component`
- **exo_icon breaks kernel tests** — `vendor/augustash/claude-config/memory/drupal/exo-icon-kernel-tests.md`  
  enabling exo_icon in a KernelTestBase (directly or via a module that depends on it) fatals with `Undefined array key "node_type"` (its hook_entity_type_alter assumes a full site); keep `exo_icon()` out of testable logic (return `{icon,text}`, render in preprocess), assert structured output; still declare `exo:exo_icon` in `.info.yml`
- **eXo image formatters — D11.4 constructor break** — `vendor/augustash/claude-config/memory/drupal/exo-d11-image-formatters.md`  
  D11.4 added an 11th arg (`ImageDerivativeUtilities`) to core `ImageFormatter::__construct`; exo formatters subclassing it (`ExoImagineFormatter`, `ExoImageFormatter`) ArgumentCountError on image render (+ untyped `$currentUser`/`$imageStyleStorage` redeclarations fatal on load). Fix = drop the `__construct` override, inject exo services via `create()`/`parent::create()`
- **Vimeo background=1 embed param** — `vendor/augustash/claude-config/memory/drupal/vimeo-background-param.md`  
  `background=1` can 403 player URL looking like privacy issue; replace with explicit autoplay/controls/loop/muted/autopause/playsinline params
- **LiveChat widget click-trap** — `vendor/augustash/claude-config/memory/drupal/livechat-click-trap.md`  
  third-party rules (e.g. ConvertCart's `cc-ftr-menu`) force `#chat-widget-container`'s height beyond its bubble, the empty area then traps clicks; presents as "menu broken in normal Chrome/Edge, fine in private/Safari"; fix with higher-specificity CSS or JS observer

## Augustash internal modules

- **Augustash repositories** — `vendor/augustash/claude-config/memory/augustash/repositories.md`  
  GitHub orgs (augustash, jacerider) to check before building from scratch
- **drupal_cache_protection** — `vendor/augustash/claude-config/memory/augustash/drupal_cache_protection.md`  
  Tracking param strip/redirect (Google/HubSpot ads, utm_*); facets + search submodules; origin-side strip is the right tool on CF Pro/Free since edge-strip is Enterprise-only
- **Internal package distribution** — `vendor/augustash/claude-config/memory/augustash/internal-package-distribution.md`  
  Distribute internal augustash composer packages via dev-master + prefer-source, no tags; place in require-dev. Gotchas: a dirty vendor working tree (e.g. test cache artifacts) makes `composer update` silently skip the package's update hook; and a require-dev plugin's uninstall/prune hook must not mutate a committed, non-gitignored file (a `--no-dev` deploy uninstalls it and Pantheon aborts on the tracked-file change) — gitignore pure output, or gate on `isDevMode()`
- **Pantheon Secrets** — `vendor/augustash/claude-config/memory/augustash/pantheon-secrets.md`  
  Terminus-core secrets (`secret:site:set`) store Pantheon-side, read via `pantheon_get_secret()` (scope=web) — a SEPARATE system from the legacy `files/private/secrets.json` file; app reader should prefer the fn, fall back to the file. `--type`/`--scope` only on create. **Multiline values (PEM keys) fail** the arg parser — store base64, decode on read
- **ddev-drupal Pantheon site var** — `vendor/augustash/claude-config/memory/augustash/ddev-drupal-pantheon-site-var.md`  
  augustash ddev recipes export Pantheon site + env in `.ddev/config.yaml` across 3 generations (`project=`; `PANTHEON_SITE`/`WORKING_ENVIRONMENT`; current `DDEV_PANTHEON_SITE`/`DDEV_PANTHEON_ENVIRONMENT`); grep all forms. `DDEV_` prefix dodges Pantheon's server-side `PANTHEON_ENVIRONMENT` collision; `migratePantheonEnv()` migrates on `-u`. Producers = ddev-drupal/wordpress, consumer = ddev-pantheon-db
- **ddev-wordpress WP Engine gate** — `vendor/augustash/claude-config/memory/augustash/ddev-wordpress-wpengine-gate.md`  
  ddev-wordpress auto-fixes WPE sites on every `composer update`: gates wp-config.php (wrap `DB_*` behind `IS_DDEV_PROJECT`, insert wp-config-ddev.php include before `wp-settings.php`) so ddev creds win, and un-ignores `.ddev/` in the WPE `/*` deny-all .gitignore. Detects via `WPE_APIKEY`/`WPE_CLUSTER_ID`/`PWP_NAME`. Idempotent, production-inert. Git gotcha: need both `!/.ddev/` + `!/.ddev/**`, and `check-ignore -q` misreads negations. Shipped 1.0.31
- **ddev-setup post-update-cmd wiring** — `vendor/augustash/claude-config/memory/augustash/ddev-setup-post-update-cmd.md`  
  wiring the `Augustash\Ddev::postUpdate` hook via `ddev composer config --json '[...]'` mangles the namespace backslashes into a quoted string, so `composer update` dies with `Class "[\"Augustash\Ddev ... is not autoloadable`. Set it scalar or edit composer.json by hand; preserve any existing Pantheon `DrupalComposerManaged` hook
- **New Relic audit tool** — `vendor/augustash/claude-config/memory/augustash/newrelic-audit-tool.md`  
  NerdGraph NRQL puller + HTML/CSV report generator (templates/newrelic/) for Pantheon perf/worker-saturation exhibits; `FROM Metric` retains ~6mo vs `Transaction` ~2wk, no queue-time metric (use FPM max_children logs); report uses median/worst-day + saturating-day counts; complements raw-log audits

## WordPress

- **WooCommerce Pantheon cache** — `vendor/augustash/claude-config/memory/wordpress/woocommerce-pantheon-cache.md`  
  ash-woocommerce-cookies plugin for Varnish cache-busting fix
