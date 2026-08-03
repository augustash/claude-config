# August Ash — team conventions for AI assistants

Shared context for AI coding assistants (Cursor, Codex, Aider, Claude Code, and any tool that reads `AGENTS.md`) working on augustash projects. When a task touches one of the topics below, read the referenced file before proceeding — the team has accumulated conventions and hard-won lessons there that generic defaults won't match.

These files are authoritative and kept current by the team. Prefer conventions here over generic defaults. When you learn something worth sharing, update or add a file in the `augustash/claude-config` repo's `memory/` directory and commit it — everyone on the team benefits on their next `composer update`.

> *Generated from `CLAUDE.md`. Don't edit this file directly — edit `CLAUDE.md` and rerun `generate-agents.py`.*

## Preferences & collaboration

- **Mission** — `vendor/augustash/claude-config/memory/preferences/mission.md`  
  how Claude stewards this corpus; read first, it shapes how every other memory is written
- **Follow site conventions** — `vendor/augustash/claude-config/memory/preferences/follow-site-conventions.md`  
  scan how a domain is already handled here before writing in it
- **Memory structure** — `vendor/augustash/claude-config/memory/preferences/memory-structure.md`  
  topic/specific.md layout and organization rules
- **Reference scripts, don't embed** — `vendor/augustash/claude-config/memory/preferences/reference-scripts-not-embeds.md`  
  scripts live in templates/ and are linked by path, never pasted into a note
- **DDEV workflow** — `vendor/augustash/claude-config/memory/preferences/ddev-workflow.md`  
  always use ddev for CLI commands
- **ddev Mutagen sync lag** — `vendor/augustash/claude-config/memory/preferences/ddev-mutagen-sync-lag.md`  
  a file written inside the container reads stale on the host, so the command looks like it failed
- **Memory audit process** — `vendor/augustash/claude-config/memory/preferences/memory-audit.md`  
  audit triggers and the `last_audit` daily floor
- **Leave stopwords out of method names** — `vendor/augustash/claude-config/memory/preferences/method-naming.md`  
  no `a`/`an`/`the`/`to`; also trips Drupal's ValidFunctionName sniff
- **Style rules cover as much ground as possible** — `vendor/augustash/claude-config/memory/preferences/style-rules-cover-ground.md`  
  before scoping a style fix to one page or instance; Kaza's rule on uniformity
- **Use scale classes, not arbitrary Tailwind values** — `vendor/augustash/claude-config/memory/preferences/tailwind-no-arbitrary-values.md`  
  Cyle's rule: no bracket utilities like `text-[2rem]`, snap to the scale
- **Check mobile on every CSS change** — `vendor/augustash/claude-config/memory/preferences/mobile-breakpoint-check.md`  
  before calling any CSS done; Neo previews each component at its breakpoints, so look rather than reason
- **Tables sidescroll, never restack into records** — `vendor/augustash/claude-config/memory/preferences/table-sidescroll-default.md`  
  reach for a scroll cue, not a mobile card layout, whenever a table meets a narrow screen
- **Sidescroll dead zones** — `vendor/augustash/claude-config/memory/preferences/sidescroll-dead-zones.md`  
  a strip that scrolls over its middle but not its edges, or won't drag; also: never hijack a plain vertical wheel
- **Comment style** — `vendor/augustash/claude-config/memory/preferences/comments.md`  
  concise; explain the WHY, skip the obvious
- **Commit messages** — `vendor/augustash/claude-config/memory/preferences/commit-messages.md`  
  subject + a tight WHY; diagnosis belongs in the PR, not the commit
- **Run cex before commit rounds** — `vendor/augustash/claude-config/memory/preferences/cex-before-commit.md`  
  before drawing commit boundaries on a Drupal project; the first export after a gap carries other sessions' config
- **Load the design skill when the work has to match something** — `vendor/augustash/claude-config/memory/preferences/use-design-skill.md`  
  when design judgment is left; skip it for prescriptive handed-over values
- **Scratch context** — `vendor/augustash/claude-config/memory/preferences/scratch-context.md`  
  ~/.claude/scratch/ for temporary cross-project context
- **Git merge over rebase** — `vendor/augustash/claude-config/memory/preferences/git-merge-not-rebase.md`  
  `pull --no-rebase` by default
- **Commit handoff** — `vendor/augustash/claude-config/memory/preferences/commit-handoff.md`  
  who commits what: Claude owns shared memory, dev owns project work
- **Confirm before live terminus** — `vendor/augustash/claude-config/memory/preferences/confirm-before-live-terminus.md`  
  always confirm before terminus against `.live`/`.test`
- **Local config in settings.local.php** — `vendor/augustash/claude-config/memory/preferences/local-config-in-settings-local.md`  
  dev-only overrides never go through `cset`/UI
- **Log audit** — `vendor/augustash/claude-config/memory/preferences/log-audit.md`  
  how to run a server-log review; never exfiltrate log contents
- **Test reminders** — `vendor/augustash/claude-config/memory/preferences/test-reminders.md`  
  surface existing tests when changing covered code, flag coverage gaps
- **Trust contrib tests** — `vendor/augustash/claude-config/memory/preferences/trust-contrib-tests.md`  
  cover only the seam we own; never hit a live external API
- **No time-based test waits** — `vendor/augustash/claude-config/memory/preferences/no-time-based-test-waits.md`  
  wait on the condition, never a fixed delay
- **Transactional email on our account** — `vendor/augustash/claude-config/memory/preferences/transactional-email-on-our-account.md`  
  before pointing a site at the client's existing ESP, or treating the subscription fee as the deciding factor
- **Proactively clean up cruft** — `vendor/augustash/claude-config/memory/preferences/proactive-cleanup.md`  
  offer to fix warnings and dead code near the work, in its own commit

## Drupal

- **Drupal caching** — `vendor/augustash/claude-config/memory/drupal/caching.md`  
  cache debugging, session poisoning, Exo component cache, Redis compress_length
- **D11.4 symfony/runtime allow-plugin** — `vendor/augustash/claude-config/memory/drupal/d11-symfony-runtime.md`  
  every web request WSODs after a 11.4 bump while drush still works fine
- **Cross-version DB pull** — `vendor/augustash/claude-config/memory/drupal/cross-version-db-pull.md`  
  older prod DB into newer code; `updatedb` dies on an unknown `router.alias` column
- **config_ignore over a config_split module deadlocks deploy** — `vendor/augustash/claude-config/memory/drupal/config-split-ignore-collision.md`  
  `cim` aborts with "depends on the Y module that will not be installed"
- **An active split whose modules aren't installed empties its folder on export** — `vendor/augustash/claude-config/memory/drupal/config-split-export-wipes-folder.md`  
  `cex` silently blanks the split folder, and the status you'd check to rule it out lies
- **A redirect never fires while its source path still has an alias** — `vendor/augustash/claude-config/memory/drupal/redirect-shadowed-by-alias.md`  
  a correct 301 sits in the table unreachable; retiring a node is three steps, not two
- **Gating a Drupal file takes three things** — `vendor/augustash/claude-config/memory/drupal/private-file-gate.md`  
  a restricted file still downloads though `file_managed` says `private://`; also after any migration whose source had private files
- **BigPipe is not viable on Pantheon** — `vendor/augustash/claude-config/memory/drupal/bigpipe-pantheon.md`  
  lazy_builder is a no-op there; also how to actually diagnose whether a page caches
- **GTranslate integration** — `vendor/augustash/claude-config/memory/drupal/gtranslate-integration.md`  
  choosing hosted-subdomain vs the subdirectory addon, which saturates PHP-FPM
- **Cache bin that survives drush cr** — `vendor/augustash/claude-config/memory/drupal/persistent-cache-bin.md`  
  keeping a warm store from being wiped by a full cache flush
- **Short edge TTL vs tag-purge for volatile pages** — `vendor/augustash/claude-config/memory/drupal/edge-ttl-vs-tag-purge.md`  
  giving ONE page a short external Cache-Control, and why TTL beats tag-purge
- **Search API / Solr convention** — `vendor/augustash/claude-config/memory/drupal/search-api-solr-convention.md`  
  standard index/server names and the DDEV Solr build
- **Drupal PHPUnit testing** — `vendor/augustash/claude-config/memory/drupal/phpunit-testing.md`  
  DDEV setup; D9/10 and D11 phpunit.xml are not interchangeable; PHPUnit 11 metadata changes
- **Drupal Nightwatch testing** — `vendor/augustash/claude-config/memory/drupal/nightwatch-testing.md`  
  Selenium setup and tag-scoped runs; the W3C patch breaks D11 updates
- **Playwright UI test writing** — `vendor/augustash/claude-config/memory/drupal/playwright-testing.md`  
  serial runs, condition waits, warm caches first
- **Update-hook testing** — `vendor/augustash/claude-config/memory/drupal/update-hook-testing.md`  
  when an update hook deserves an update-path test and when it doesn't
- **Test tag/group convention** — `vendor/augustash/claude-config/memory/drupal/test-tags.md`  
  `aai` vs `ar` umbrella tag + module sub-tag, and how to tell which a site is
- **Cross-project patches** — `vendor/augustash/claude-config/memory/drupal/patches.md`  
  index of reusable local .patch files and vetted remote URLs
- **Pantheon robots.txt** — `vendor/augustash/claude-config/memory/drupal/pantheon-robots-txt.md`  
  custom disallow rules via Composer scaffold append
- **Favicon 404 cluster with the icons all present** — `vendor/augustash/claude-config/memory/drupal/favicon-docroot-icons.md`  
  thousands of icon 404s while the generated set sits there serving 200s; don't patch the module
- **Pantheon Quicksilver cache warmer** — `vendor/augustash/claude-config/memory/drupal/pantheon-quicksilver-cache-warmer.md`  
  deploy hook that pre-curls heavy pages to beat the cold-cache dogpile
- **Cron off-path page_cache re-prime** — `vendor/augustash/claude-config/memory/drupal/page-cache-cron-reprime.md`  
  keeping an uncacheable form page warm through a mid-day cache eviction
- **Cloudflare tracking params** — `vendor/augustash/claude-config/memory/drupal/cloudflare-tracking-params.md`  
  handle in drupal_cache_protection, not CF cache rules
- **Cachetags garbage collection** — `vendor/augustash/claude-config/memory/drupal/cachetags-garbage-collection.md`  
  the cachetags table has no GC and grows unbounded
- **Exo optional link field** — `vendor/augustash/claude-config/memory/drupal/exo-alchemist-optional-link.md`  
  `required: FALSE` is a no-op on a link field
- **Exo modifier checkbox + class** — `vendor/augustash/claude-config/memory/drupal/exo-alchemist-modifier-checkbox.md`  
  adding a per-instance toggle that emits a class
- **Exo slider mobile overflow** — `vendor/augustash/claude-config/memory/drupal/exo-alchemist-slider-mobile-overflow.md`  
  a slider that overflows on mobile only
- **exo_icon breaks kernel tests** — `vendor/augustash/claude-config/memory/drupal/exo-icon-kernel-tests.md`  
  enabling exo_icon in a KernelTestBase fatals on a missing `node_type`
- **eXo image formatters — D11.4 constructor break** — `vendor/augustash/claude-config/memory/drupal/exo-d11-image-formatters.md`  
  images or an eXo Gallery field WSOD after a 11.4 bump; ArgumentCountError *or* TypeError on constructor arg #11
- **Vimeo background=1 embed param** — `vendor/augustash/claude-config/memory/drupal/vimeo-background-param.md`  
  a 403 on the player URL that looks like a privacy setting
- **LiveChat widget click-trap** — `vendor/augustash/claude-config/memory/drupal/livechat-click-trap.md`  
  "menu broken in normal Chrome, fine in private" from an oversized chat container

## Augustash internal modules

- **Augustash repositories** — `vendor/augustash/claude-config/memory/augustash/repositories.md`  
  GitHub orgs to check before building anything from scratch
- **Neo module skills sync** — `vendor/augustash/claude-config/memory/augustash/neo-skills-sync.md`  
  after bumping a neo module, the project's `.claude/skills/` copies still hold the old text
- **Alchemist layout Save needs a second click** — `vendor/augustash/claude-config/memory/augustash/neo-alchemist-layout-save-confirm.md`  
  edits sit in a draft behind a confirm modal; reads exactly like a persistence bug
- **neo_alchemist seeds props with schema examples** — `vendor/augustash/claude-config/memory/augustash/neo-alchemist-example-seeding.md`  
  content on the page nobody authored; editors see repeater rows they never created
- **neo_alchemist heading anchors derive from the title** — `vendor/augustash/claude-config/memory/augustash/neo-alchemist-heading-anchor-override.md`  
  a stored anchor is ignored, so re-wording a heading silently moves its id
- **Saving a neo_component wipes every prop plugin on the shape** — `vendor/augustash/claude-config/memory/augustash/neo-alchemist-plugin-settings-wipe.md`  
  before removing one plugin programmatically, or when one you never touched disappears
- **neo_color scheme tokens and the :root bake** — `vendor/augustash/claude-config/memory/augustash/neo-color-scheme-token-resolution.md`  
  a custom property declared at `:root` won't recolor inside a scheme
- **Neo's base.css out-ranks the theme on form buttons** — `vendor/augustash/claude-config/memory/augustash/neo-base-css-button-specificity.md`  
  a theme rule on a submit button half-applies, with no `!important` and nothing visibly overriding it
- **Neo component-spacing ramp is bottom-heavy** — `vendor/augustash/claude-config/memory/augustash/neo-component-spacing-ramp.md`  
  sections read as run together on mobile while desktop looks right
- **neo spacing is a token plus an application** — `vendor/augustash/claude-config/memory/augustash/neo-component-spacing-collapse.md`  
  same `spacing` value reads as a bigger gap inside a region; choosing `my-` vs `py-component`
- **neo_icon renders an empty span for a style-prefixed id** — `vendor/augustash/claude-config/memory/augustash/neo-icon-id-prefix.md`  
  an icon silently renders empty; also before pasting what `neoi-list` prints
- **neo_animate hides one component at some viewport heights** — `vendor/augustash/claude-config/memory/augustash/neo-animate-edge-retract.md`  
  a section blank at one window height and fine at another; reads as lost content
- **drupal_cache_protection** — `vendor/augustash/claude-config/memory/augustash/drupal_cache_protection.md`  
  tracking-param strip/redirect, facets + search submodules
- **recently_read (augustash fork)** — `vendor/augustash/claude-config/memory/augustash/recently-read.md`  
  a fork we own; never re-sync with upstream, the divergence is the point
- **Internal package distribution** — `vendor/augustash/claude-config/memory/augustash/internal-package-distribution.md`  
  dev-master + prefer-source, no tags; the dirty-vendor and `--no-dev` deploy traps; a vendor clone claiming it's "N commits ahead"
- **Pantheon Secrets** — `vendor/augustash/claude-config/memory/augustash/pantheon-secrets.md`  
  terminus secrets vs the legacy secrets.json, and why PEM keys need base64
- **ddev-drupal Pantheon site var** — `vendor/augustash/claude-config/memory/augustash/ddev-drupal-pantheon-site-var.md`  
  three generations of site/env var names in `.ddev/config.yaml`; grep all forms
- **ddev db pull guard** — `vendor/augustash/claude-config/memory/augustash/ddev-db-pull-guard.md`  
  hesitating to `ddev restart` in case the post-start pull clobbers your local database; it won't
- **ddev-wordpress WP Engine gate** — `vendor/augustash/claude-config/memory/augustash/ddev-wordpress-wpengine-gate.md`  
  what it rewrites in wp-config.php and .gitignore on every composer update
- **WP Engine git deploy** — `vendor/augustash/claude-config/memory/augustash/wpengine-git-deploy.md`  
  reconcile live plugin drift before deploying or the push reverts it
- **ddev-setup post-update-cmd wiring** — `vendor/augustash/claude-config/memory/augustash/ddev-setup-post-update-cmd.md`  
  the hook set via `ddev composer config --json` fails to autoload
- **New Relic audit tool** — `vendor/augustash/claude-config/memory/augustash/newrelic-audit-tool.md`  
  NerdGraph puller + report generator for Pantheon worker-saturation exhibits

## WordPress

- **WooCommerce Pantheon cache** — `vendor/augustash/claude-config/memory/wordpress/woocommerce-pantheon-cache.md`  
  the ash-woocommerce-cookies plugin for the Varnish cache-busting fix
- **WooCommerce purchase gate seams** — `vendor/augustash/claude-config/memory/wordpress/woocommerce-purchase-gate-seams.md`  
  forcing login before purchase takes four hooks, only one of them a real rule
- **LearnDash closed-course button URL** — `vendor/augustash/claude-config/memory/wordpress/learndash-closed-course-button-url.md`  
  a closed course's buy button points at live from every other environment
- **WP security-header CSP silently breaks analytics** — `vendor/augustash/claude-config/memory/wordpress/rsssl-csp-enforce-analytics.md`  
  analytics cliffs overnight while the site looks fine; two header plugins intersect
- **Pass CSP Evaluator on WordPress with nonce + strict-dynamic** — `vendor/augustash/claude-config/memory/wordpress/csp-nonce-strict-dynamic.md`  
  clearing the `script-src` HIGH without a host allowlist, and where WP leaks un-nonced inline scripts
