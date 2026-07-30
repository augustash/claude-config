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
- **ddev Mutagen sync lag** — `vendor/augustash/claude-config/memory/preferences/ddev-mutagen-sync-lag.md`  
  files written INSIDE the container (`drush cex`, composer, generators) reach the host seconds later, so reading them back immediately returns the PRE-command content and reads as "the command didn't work". On Drupal that invites blaming config_ignore/split/readonly for a filtering problem that doesn't exist. Verify via `ddev exec cat` (authoritative) or `ddev drush config:status`, not a host-side grep taken in the same breath
- **Memory audit process** — `vendor/augustash/claude-config/memory/preferences/memory-audit.md`  
  opportunistic triggers with a daily-floor pre-check; `last_audit` date tracked in-module (single date, replaced each pass); self-refining
- **Leave stopwords out of method names** — `vendor/augustash/claude-config/memory/preferences/method-naming.md`  
  no `a`/`an`/`the`/`to`, especially in test methods; reads better AND an article before a capitalised word trips `Drupal.NamingConventions.ValidFunctionName` (`BecomesAParagraph` = "not in lowerCamel format")
- **Use scale classes, not arbitrary Tailwind values** — `vendor/augustash/claude-config/memory/preferences/tailwind-no-arbitrary-values.md`  
  **Cyle's rule**, so it holds across every neo project: bracket utilities (`sm:text-[2rem]`, `p-[13px]`, `max-w-[347px]`) are "generally always wrong and custom". They opt the element out of the design scale, so it stops moving when the scale is retuned and bespoke CSS hides inside something that looks systematic. Snap to the nearest real step and take the 1–2px (`2rem`/32px → `text-3xl`/30px); read the scale from the BUILT css, since neo themes redefine `--text-*`. Genuine exceptions (a third-party embed's fixed dimensions) want a comment naming what pins them
- **Comment style** — `vendor/augustash/claude-config/memory/preferences/comments.md`  
  Concise; skip comments when the code is obvious, explain the WHY when it isn't
- **Commit messages** — `vendor/augustash/claude-config/memory/preferences/commit-messages.md`  
  As concise as possible: subject + a tight WHY paragraph; diagnosis/verification/measurements belong in the PR or handoff, not the commit
- **Load the design skill when the work has to match something** — `vendor/augustash/claude-config/memory/preferences/use-design-skill.md`  
  invoke `frontend-design` BEFORE coding whenever design judgment is left: matching another page's treatment, giving a component a role, new UI. **Skip it for prescriptive moves** (a handed-over value like `max-width: 78%`). The failure mode it prevents is matching the wrong thing — read the reference's computed styles and join its selector rather than restating values
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
- **config_ignore over a config_split module deadlocks deploy** — `vendor/augustash/claude-config/memory/drupal/config-split-ignore-collision.md`  
  `cim` aborts with "Configuration X depends on the Y module that will not be installed after import" when an `ignored_config_entities` pattern covers config owned by a module in a split's `module:` list: the split uninstalls the module, the ignore vetoes deleting its config, `ConfigImportSubscriber::validateModules` rejects the pair. Drop the ignore (the split already separates envs; the ignore also blocks split-folder edits from importing). Follow-on: the first reconciliation import can OOM Pantheon's 256MB CLI limit uninstalling a dozen modules at once — uninstalls persist incrementally, so re-run, or front-run a standalone `pm:uninstall`. Recurs on every DB moved from an env where the split was active
- **An active split whose modules aren't installed empties its folder on export** — `vendor/augustash/claude-config/memory/drupal/config-split-export-wipes-folder.md`  
  the export-side twin of the above: `cex` writes a split folder from ACTIVE config, so an active split whose `module:` list isn't installed (normal on a prod-sourced DB that never got a `cim`) silently deletes every file in `config-dev/` as an ordinary export result. Plain `cget …status` reports the STORED `false` and hides the `settings.local.php` override, so it reads as "the split is off, can't be the split" — use `--include-overridden`. Restore from git, `cim`, re-export. Don't blanket-revert: a post-update export mixes this with real removals (D11 dropped `field.settings` outright)
- **BigPipe is not viable on Pantheon** — `vendor/augustash/claude-config/memory/drupal/bigpipe-pantheon.md`  
  BigPipe is off on Pantheon, so lazy_builder is a no-op. But the cache impact is narrower than it looks: anonymous page_cache + Pantheon Varnish ignore bubbled max-age 0, so most sites cache fine despite scary headers. Diagnose via `x-drupal-cache`/`x-cache` HIT, not `x-drupal-cache-max-age`. AJAX-placeholder strategy module belongs under drupal_cache_protection if/when needed.
- **GTranslate integration — prefer hosted subdomain** — `vendor/augustash/claude-config/memory/drupal/gtranslate-integration.md`  
  Default to hosted subdomain (CNAME each language to `{server}.tdn.gtranslate.net`); zero app load. The self-hosted subdirectory PHP addon is a synchronous per-request TDN proxy with no curl timeout — it saturates PHP-FPM (Pantheon = 6 workers) and serves empty cached 200s. Only argument for subdirectory is SEO. No DNS control → reuse mymspconnect's off-request store rebuild, never a kernel.request fetch. Reference build: reell.com.
- **Cache bin that survives drush cr** — `vendor/augustash/claude-config/memory/drupal/persistent-cache-bin.md`  
  Keep a warm store bin from being wiped by drupal_flush_all_caches: untagged bin (omit `cache.bin`; only when cron/dedicated-tag owns freshness — msp flights board) vs decorator backend that no-ops deleteAll/invalidateAll but stays tagged so real content-tag invalidation still works (mymspconnect gtranslate store). Pick by who owns freshness.
- **Short edge TTL vs tag-purge for volatile pages** — `vendor/augustash/claude-config/memory/drupal/edge-ttl-vs-tag-purge.md`  
  A block/render `#cache` max-age never reaches the external Cache-Control (that's the global `system.performance:cache.page.max_age`); to give ONE page a short edge TTL, set the RESPONSE max-age in a response subscriber/middleware, keyed by cache tag. Volatile pages (wait times, parking, checkpoint/flight status) should ride a short TTL, not edge tag-purge — in a Pantheon Global CDN outage both `pantheon_clear_edge_all` and per-tag purges silently die while TTL keeps working. Diagnose with a live `invalidateTags` + `curl -sI` (last-modified/age unchanged = purge not landing); lone-holdout page = Surrogate-Key truncation. Refs: msp `ServicePageCacheSubscriber` (tag-keyed) + `FlightsBoardCacheMiddleware` (warm-bin).
- **Search API / Solr convention** — `vendor/augustash/claude-config/memory/drupal/search-api-solr-convention.md`  
  standard names: index `global`, servers `pantheon_search` (prod) + `local` (DDEV); local server connection injected by settings.local.php against the standardized DDEV Solr Docker build (Solr 8.11 Cloud, `solr_cloud_basic_auth`, `ddev solrcollection` to upload configset). Don't hand-roll off-convention names.
- **Drupal PHPUnit testing** — `vendor/augustash/claude-config/memory/drupal/phpunit-testing.md`  
  Setup and running PHPUnit kernel/unit tests in DDEV. **D9/10 and D11 configs are not interchangeable** (printerClass+listeners vs `<extensions>`; the classes behind each exist only in their own major) — templates for both in `templates/drupal/`; `--migrate-configuration` alone drops HTML output on an upgrade. Commit the config as `phpunit.xml.dist` or the `custom` testsuite exists on one machine only. PHPUnit 11 deprecates doc-comment metadata → `#[Group]`/`#[CoversClass]`/`#[DataProvider]`; provider string keys are now **named arguments**, so snake_case keys stop binding to camelCase params
- **Drupal Nightwatch testing** — `vendor/augustash/claude-config/memory/drupal/nightwatch-testing.md`  
  Selenium setup, yarn install, tag-scoped runs. **W3C patch is D10-only** — #3421202 landed in core (verified 11.4.4), so on D11 it fails to apply and `composer-exit-on-patch-failure` aborts the whole update; drop it during a D10→D11 bump. Patch lives at vendor/augustash/claude-config/patches/
- **Playwright UI test writing** — `vendor/augustash/claude-config/memory/drupal/playwright-testing.md`  
  run resource-heavy tests serially (not parallel), wait on conditions not time, warm caches before timing-sensitive tests
- **Update-hook testing** — `vendor/augustash/claude-config/memory/drupal/update-hook-testing.md`  
  skip update-path tests for trivial idempotent config-merge update hooks; test the behavior instead, reserve UpdatePathTestBase for real data migrations
- **Test tag/group convention** — `vendor/augustash/claude-config/memory/drupal/test-tags.md`  
  umbrella tag of the **company that built the site** + module sub-tag, on every custom test (PHPUnit + Nightwatch + Playwright). `aai` = August Ash; `ar` = AshenRayne, the two-person shop (the dev + Cyle, the jacerider/neo maintainer) that both also work at August Ash. Magnum Dimensions/DMX Power is an `ar` site. Tell them apart by the Pantheon sitename prefix in `.ddev/config.yaml` (`aai-<slug>` / `ar-<slug>`; md is `ar-md`), not by the client name
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
- **A redirect never fires while its source path still has an alias** — `vendor/augustash/claude-config/memory/drupal/redirect-shadowed-by-alias.md`  
  retiring a node is THREE steps: unpublish, redirect, **delete the alias**. `RedirectRequestSubscriber` runs `processInbound()` before `findMatchingRedirect()`, so a live alias resolves `news/…` to `node/N` and the lookup misses — the 301 sits in the table correct and unreachable. Nor does it fall through to `redirect_404`, because a custom `hook_node_access` returning **403** (md: unpublished composed page = "internal") pre-empts the 404. The stored row looks perfect, so verify with an anonymous `curl -sI` asserting 301, never from the table or while logged in. Bulk retire must capture aliases before deleting them or the verify checks nothing
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
- **Neo module skills sync** — `vendor/augustash/claude-config/memory/augustash/neo-skills-sync.md`  
  Neo/jacerider modules ship Claude skills in `<module>/install/skills/`, but `composer update` does NOT update the project's live `.claude/skills/` copies (no auto mechanism). Re-`cp -R` each updated skill-shipping module's skills into `.claude/skills/` and commit with the bump. Lists which neo modules ship skills
- **Alchemist layout Save needs a second click** — `vendor/augustash/claude-config/memory/augustash/neo-alchemist-layout-save-confirm.md`  
  component edits land in a PrivateTempStore **draft**; only the layout toolbar's Save publishes, and it is confirm-modal gated (the dialog's **button pane** Save is the real control). Miss the confirm and stored props never change while the editor form, preview and success message all look right — indistinguishable from a persistence bug, and it sends you hunting a value strip that doesn't exist. Tell-tale: toolbar Save/Revert/Reset enabled = unpublished draft. Revert (also confirm-gated) discards it. Verify against stored data, never the editor UI
- **neo_alchemist discards nested markup values** — `vendor/augustash/claude-config/memory/augustash/neo-alchemist-nested-markup.md`  
  a `type: markup` prop nested inside an `array` never receives its stored value: it renders the parent array's `examples` for that delta, or nothing past the example count. DB is fine, the page is wrong. Tell = sibling `type: string` props at the same nesting level are correct. `MarkupShape`'s `formatted_text` default plugin is `group: providers`, so `childHasOwnValueProvider()` skips `setFieldItemValue()`. Fix excludes it by id (not by `default_plugins` — `media` is one and does source a value). Invisible while instances are still built FROM the examples
- **neo_alchemist overwrites a nested prop stored FALSE** — `vendor/augustash/claude-config/memory/augustash/neo-alchemist-nested-falsy-value.md`  
  second, separate cause of the same symptom as the nested-markup one, in the same method: `getChildShapes()` gates on `empty()`, which can't tell a stored `false`/`0`/`''` from a key never written, so the child keeps the SDC **example** for its delta. An unchecked boolean whose example sets it TRUE renders switched ON and the editor UI cannot fix it; deltas past the example count are fine, so it reads as one corrupt row. Fix = `array_key_exists()`, which `resolveChildValues()` in the same class already uses — the `empty()` is the outlier. Regression-check by diffing rendered byte lengths of every composed page
- **neo_alchemist heading anchors derive from the title** — `vendor/augustash/claude-config/memory/augustash/neo-alchemist-heading-anchor-override.md`  
  `HeadingShape` ignores a stored `anchor` and slugs the **title** unless `neo_alchemist.settings:anchor_override_status` is TRUE (off by default, and it hides the anchor field from the form, so this only bites when props are written in code). Anchors that appear to work do so because the title happens to slug to the same string — meaning re-wording a heading silently moves its id and breaks every in-page link to it. Verify by grepping the rendered `id=`, never by a link resolving
- **neo_color scheme tokens and the :root bake** — `vendor/augustash/claude-config/memory/augustash/neo-color-scheme-token-resolution.md`  
  neo INVERTS the primary/base ramps inside a `.scheme-dark` scope (`--color-primary-900` = near-black at root, near-WHITE there), so a component recolors for free — but only if its custom properties are declared INSIDE the scheme. A property declared at `:root` resolves its `var()`s against the root scheme and inherits those fixed colours in unchanged; the tell is that it computes byte-identical at `:root` and at the scoped element. Only `--color-*-500` (+ `-500-content`) is stable across schemes, so ramp refs copied from light-scheme rules flip on you. Also: split a dual-purpose brand alias (`--navy` = title ink AND ground paint) into `--heading-ink` so a scheme can move ink without repainting surfaces; and on a two-colour brand prefer inverting a panel all the way to the ground the brand owns over a partial lift, which invents an off-brand slate
- **neo_icon renders an empty span for a style-prefixed id** — `vendor/augustash/claude-config/memory/augustash/neo-icon-id-prefix.md`  
  ids are stored UNPREFIXED (`exchange-alt`); neo adds the style, emitting `icon-regular-exchange-alt`. A stored `regular-exchange-alt` double-prefixes and renders EMPTY — no error, no log, and the component's `{% if item.icon %}` guard still passes, so the wrapper span emits empty and it reads as "this component doesn't support icons" rather than bad data. Easy to seed when props are written programmatically from a class name. `IconRepository::getIcon()` returns NULL even for good ids — test by rendering the element instead
- **drupal_cache_protection** — `vendor/augustash/claude-config/memory/augustash/drupal_cache_protection.md`  
  Tracking param strip/redirect (Google/HubSpot ads, utm_*); facets + search submodules; origin-side strip is the right tool on CF Pro/Free since edge-strip is Enterprise-only
- **recently_read (augustash fork)** — `vendor/augustash/claude-config/memory/augustash/recently-read.md`  
  a hard fork we OWN, not a patch set: contrib tracked recently-read items in server-side sessions for anon users, forcing a session sitewide and poisoning page cache (it's a sidebar/footer block, so not route-scoped); upstream closed the reports as works-as-intended, so augustash took it over. Never re-sync with upstream — the divergence is the point. Fork uses localStorage + an AJAX endpoint instead. Watch the `recently_read_list` `*_list` tag: see [[cachetags-garbage-collection]]
- **Internal package distribution** — `vendor/augustash/claude-config/memory/augustash/internal-package-distribution.md`  
  Distribute internal augustash composer packages via dev-master + prefer-source, no tags; place in require-dev. Gotchas: a dirty vendor working tree (e.g. test cache artifacts) makes `composer update` silently skip the package's update hook; and a require-dev plugin's uninstall/prune hook must not mutate a committed, non-gitignored file (a `--no-dev` deploy uninstalls it and Pantheon aborts on the tracked-file change) — gitignore pure output, or gate on `isDevMode()`
- **Pantheon Secrets** — `vendor/augustash/claude-config/memory/augustash/pantheon-secrets.md`  
  Terminus-core secrets (`secret:site:set`) store Pantheon-side, read via `pantheon_get_secret()` (scope=web) — a SEPARATE system from the legacy `files/private/secrets.json` file; app reader should prefer the fn, fall back to the file. `--type`/`--scope` only on create. **Multiline values (PEM keys) fail** the arg parser — store base64, decode on read
- **ddev-drupal Pantheon site var** — `vendor/augustash/claude-config/memory/augustash/ddev-drupal-pantheon-site-var.md`  
  augustash ddev recipes export Pantheon site + env in `.ddev/config.yaml` across 3 generations (`project=`; `PANTHEON_SITE`/`WORKING_ENVIRONMENT`; current `DDEV_PANTHEON_SITE`/`DDEV_PANTHEON_ENVIRONMENT`); grep all forms. `DDEV_` prefix dodges Pantheon's server-side `PANTHEON_ENVIRONMENT` collision; `migratePantheonEnv()` migrates on `-u`. Producers = ddev-drupal/wordpress, consumer = ddev-pantheon-db
- **ddev-wordpress WP Engine gate** — `vendor/augustash/claude-config/memory/augustash/ddev-wordpress-wpengine-gate.md`  
  ddev-wordpress auto-fixes WPE sites on every `composer update`: gates wp-config.php (wrap `DB_*` behind `IS_DDEV_PROJECT`, insert wp-config-ddev.php include before `wp-settings.php`) so ddev creds win, and un-ignores `.ddev/` in the WPE `/*` deny-all .gitignore. Detects via `WPE_APIKEY`/`WPE_CLUSTER_ID`/`PWP_NAME`. Idempotent, production-inert. Git gotcha: need both `!/.ddev/` + `!/.ddev/**`, and `check-ignore -q` misreads negations. Shipped 1.0.31
- **WP Engine git deploy** — `vendor/augustash/claude-config/memory/augustash/wpengine-git-deploy.md`  
  augustash WPE sites deploy via git, two branches (`master`→prod, `dev`→staging) pushed to per-install `git@git.wpengine.com:production/<install>.git` remotes (`production/` is literal). **Reconcile live drift before nearly every deploy**: WPE auto-updates plugins on live, so a push would revert them; the ddev-wordpress `pre-push` guard blocks server-newer, and `.githooks/wpe-reconcile <remote>` (≥ 1.0.33) rsyncs the drift down + stages it (a hook can't self-heal the in-flight push, so reconcile is a separate step). `--no-verify` deploys the revert — last resort. See [[ddev-wordpress-wpengine-gate]]
- **ddev-setup post-update-cmd wiring** — `vendor/augustash/claude-config/memory/augustash/ddev-setup-post-update-cmd.md`  
  wiring the `Augustash\Ddev::postUpdate` hook via `ddev composer config --json '[...]'` mangles the namespace backslashes into a quoted string, so `composer update` dies with `Class "[\"Augustash\Ddev ... is not autoloadable`. Set it scalar or edit composer.json by hand; preserve any existing Pantheon `DrupalComposerManaged` hook
- **New Relic audit tool** — `vendor/augustash/claude-config/memory/augustash/newrelic-audit-tool.md`  
  NerdGraph NRQL puller + HTML/CSV report generator (templates/newrelic/) for Pantheon perf/worker-saturation exhibits; `FROM Metric` retains ~6mo vs `Transaction` ~2wk, no queue-time metric (use FPM max_children logs); report uses median/worst-day + saturating-day counts; complements raw-log audits

## WordPress

- **WooCommerce Pantheon cache** — `vendor/augustash/claude-config/memory/wordpress/woocommerce-pantheon-cache.md`  
  ash-woocommerce-cookies plugin for Varnish cache-busting fix
- **WooCommerce purchase gate seams** — `vendor/augustash/claude-config/memory/wordpress/woocommerce-purchase-gate-seams.md`  
  forcing login before purchase needs four hooks: `woocommerce_add_to_cart_validation` is the only real rule; the three buy affordances (single product action at priority 30, loop link filter, LMS/builder button) are UI; plus a `wp_loaded` < 20 intercept for hand-typed `?add-to-cart=` (AJAX posts `product_id` instead, so it needs the validation filter). Return-after-login: read `$_POST['redirect']` directly in the login/registration redirect filters — the filtered value's referer fallback is the login page and loops
- **LearnDash closed-course button URL** — `vendor/augustash/claude-config/memory/wordpress/learndash-closed-course-button-url.md`  
  `course_price_type = closed` bakes an **absolute** buy URL into `sfwd-courses_custom_button_url` postmeta, so every non-production environment's "Take this course" points at live (and even live is stale `http://`). LearnDash only prepends `home_url()` for relative values. Fix at render via `learndash_payment_closed_button`, normalizing scheme + host — never search-replace the DB, the next prod pull undoes it
- **WP security-header CSP silently breaks analytics** — `vendor/augustash/claude-config/memory/wordpress/rsssl-csp-enforce-analytics.md`  
  an enforced CSP whose allowlist omits the GA4 beacon host (often `analytics.google.com`, NOT `google-analytics.com`) cliffs analytics + Google Ads overnight while the site looks fine; `script-src` loads the tag, `connect-src` gates the beacon. Two header plugins enforce the INTERSECTION — never run both (RSSSL Pro vs Headers Security/HSTS; the legacy `X-Content-Security-Policy` is Headers Security's fingerprint). Diagnose via `wp_rsssl_csp_log` + headless netlog `/g/collect`, not the repo. Right-size: **Tier 1** (`default-src 'self'` + scheme-permissive `https:` fetch directives, in reviewed code — `templates/wordpress/csp-tier1.php`) beats a strict host-allowlist on a brochure site. Gitignore `wp-content/rsssl-managed-htaccess.lock`
- **Pass CSP Evaluator on WordPress with nonce + strict-dynamic** — `vendor/augustash/claude-config/memory/wordpress/csp-nonce-strict-dynamic.md`  
  clear Google CSP Evaluator's `script-src` HIGH on WP+GTM WITHOUT a host allowlist: per-request nonce + `'strict-dynamic'`, nonced at BOTH WP's script-printing layer (`wp_inline_script_attributes`/`wp_script_attributes` filters) AND an output buffer. Trust propagates via strict-dynamic (only HTML-present scripts need the nonce; GTM-loaded GA4/Ads tags inherit). Gotcha 1: a nonce covers `<script>` tags only — inline `on*=` handlers / `javascript:` URIs are blocked, fix at source (async-font `onload`→real script). Gotcha 2: the buffer alone MISSES some `wp_add_inline_script` output (escapes the `template_redirect` buffer) — un-nonced under strict-dynamic = blocked; it silently killed Gravity Forms' `gform` bootstrap → invisible form. Nonce at WP's filter layer too. Skip the trusted-types nudge (informational). Validate BOTH: Evaluator green + headless-under-enforcement (GTM/GA/Turnstile/fonts fire). Impl `templates/wordpress/csp-nonce-strict-dynamic.php` (v2); deployed as apf `arrowhead-csp` v2.2
