# August Ash — team conventions for AI assistants

Shared context for AI coding assistants (Cursor, Codex, Aider, Claude Code, and any tool that reads `AGENTS.md`) working on augustash projects. When a task touches one of the topics below, read the referenced file before proceeding — the team has accumulated conventions and hard-won lessons there that generic defaults won't match.

These files are authoritative and kept current by the team. Prefer conventions here over generic defaults. When you learn something worth sharing, update or add a file in the `augustash/claude-config` repo's `memory/` directory and commit it — everyone on the team benefits on their next `composer update`.

> *Generated from `CLAUDE.md`. Don't edit this file directly — edit `CLAUDE.md` and rerun `generate-agents.py`.*

## Preferences & collaboration

- **Mission** — `vendor/augustash/claude-config/memory/preferences/mission.md`  
  how Claude stewards this corpus; read first, it shapes how every other memory is written
- **Follow site conventions** — `vendor/augustash/claude-config/memory/preferences/follow-site-conventions.md`  
  scan how a domain is already handled here before writing in it
- **Check what already exists before writing code we maintain** — `vendor/augustash/claude-config/memory/preferences/prefer-existing-tooling.md`  
  before building a cron, queue, cleanup or expiry mechanism; and before reporting a setting as unconfigured
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
- **A defect nobody can see still gets fixed** — `vendor/augustash/claude-config/memory/preferences/fix-what-nobody-sees.md`  
  before dismissing a sub-pixel or off-screen flaw as too small to bother with, or filing it as an acceptable quirk
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
- **Deliverables are HTML files, not Claude artifacts** — `vendor/augustash/claude-config/memory/preferences/deliverables-as-html-files.md`  
  before publishing a report, audit or findings page for a client or the team
- **Scratch context** — `vendor/augustash/claude-config/memory/preferences/scratch-context.md`  
  ~/.claude/scratch/ for temporary cross-project context
- **Git merge over rebase** — `vendor/augustash/claude-config/memory/preferences/git-merge-not-rebase.md`  
  `pull --no-rebase` by default
- **Fix modules on develop** — `vendor/augustash/claude-config/memory/preferences/module-fixes-on-develop.md`  
  before branching, committing or writing a commit message in a module clone; the rules differ from the consuming project
- **Commit handoff** — `vendor/augustash/claude-config/memory/preferences/commit-handoff.md`  
  who commits what: Claude owns shared memory, dev owns project work
- **Confirm before live terminus** — `vendor/augustash/claude-config/memory/preferences/confirm-before-live-terminus.md`  
  always confirm before terminus against `.live`/`.test`
- **Local config in settings.local.php** — `vendor/augustash/claude-config/memory/preferences/local-config-in-settings-local.md`  
  dev-only overrides never go through `cset`/UI
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
- **Prove code is dead against its consumers** — `vendor/augustash/claude-config/memory/preferences/prove-code-is-dead.md`  
  before deleting code that looks dead, or concluding a change is a no-op because saved state is unchanged

## Cloudflare

- **WAF rules silently break SSL renewal** — `vendor/augustash/claude-config/memory/cloudflare/waf-blocks-acme-renewal.md`  
  before adding or reviewing any WAF/geo/bot rule; the site looks fine for two months, then every browser rejects it
- **Free Bot Fight Mode can't be skipped by any WAF rule** — `vendor/augustash/claude-config/memory/cloudflare/bot-fight-mode-unskippable.md`  
  an API client gets 403 + HTML while the origin log shows nothing; the skip rule exempting it is a no-op
- **Cloudflare WAF and event tool** — `vendor/augustash/claude-config/memory/cloudflare/waf-rule-tool.md`  
  before hand-rolling Cloudflare API calls, when a valid token reads as Invalid API Token, or for Free-plan rate limiting limits

## Drupal

- **Drupal caching** — `vendor/augustash/claude-config/memory/drupal/caching.md`  
  cache debugging, session poisoning, Exo component cache, Redis compress_length
- **D11.4 symfony/runtime allow-plugin** — `vendor/augustash/claude-config/memory/drupal/d11-symfony-runtime.md`  
  every web request WSODs after a 11.4 bump while drush still works fine
- **A stored NULL placeholder WSODs every order page on D11** — `vendor/augustash/claude-config/memory/drupal/commerce-log-null-placeholder-d11.md`  
  admin order pages 500 right after a D11 deploy, old and new alike; the data is far older than the outage
- **Cross-version DB pull** — `vendor/augustash/claude-config/memory/drupal/cross-version-db-pull.md`  
  older prod DB into newer code; `updatedb` dies on an unknown `router.alias` column
- **Admin theme change orphans theme-keyed config** — `vendor/augustash/claude-config/memory/drupal/admin-theme-keyed-config.md`  
  the new admin theme "looks wrong": forms sprawl onto two rows, panels render unstyled
- **An empty config object kills cim** — `vendor/augustash/claude-config/memory/drupal/cim-empty-config-object.md`  
  `cim` dies on the same op every run with "delete() on null", and `config:delete` insists the config does not exist
- **config_ignore over a config_split module deadlocks deploy** — `vendor/augustash/claude-config/memory/drupal/config-split-ignore-collision.md`  
  `cim` aborts with "depends on the Y module that will not be installed"
- **An active split whose modules aren't installed empties its folder on export** — `vendor/augustash/claude-config/memory/drupal/config-split-export-wipes-folder.md`  
  `cex` silently blanks the split folder, and the status you'd check to rule it out lies
- **A DB push makes cim uninstall the whole dev split at once** — `vendor/augustash/claude-config/memory/drupal/config-split-db-push-mass-uninstall.md`  
  `cim` dies "terminated abnormally" and half-applied after pushing a local DB to Pantheon; re-running walks it forward
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
- **Drupal ajax buttons fire on mousedown** — `vendor/augustash/claude-config/memory/drupal/ajax-buttons-fire-on-mousedown.md`  
  a scripted reproduction comes back clean while the developer hits the bug every single time by hand
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
- **A node access rebuild permanently caches every listing empty** — `vendor/augustash/claude-config/memory/drupal/node-access-rebuild-empties-listings.md`  
  listings show their empty message while the content plainly exists; reads as content loss or a stalled search index
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
- **Every hierarchical select on the site renders empty** — `vendor/augustash/claude-config/memory/drupal/shs-d11-bundle-cache-tags.md`  
  shs options vanish across bundles with the data intact; the form shows no error, the AJAX endpoint 500s
- **Vimeo background=1 embed param** — `vendor/augustash/claude-config/memory/drupal/vimeo-background-param.md`  
  a 403 on the player URL that looks like a privacy setting
- **Serving a background video at more than one size** — `vendor/augustash/claude-config/memory/drupal/responsive-background-video.md`  
  handing a phone a smaller clip than a desktop; also before believing MDN that `media` does nothing on a `<video>` source
- **LiveChat widget click-trap** — `vendor/augustash/claude-config/memory/drupal/livechat-click-trap.md`  
  "menu broken in normal Chrome, fine in private" from an oversized chat container
- **LiveChat from your own trigger** — `vendor/augustash/claude-config/memory/drupal/livechat-custom-launcher.md`  
  putting chat in a menu instead of the floating bubble; also a chat window that opens with its title bar off-screen

## Augustash internal modules

- **Augustash repositories** — `vendor/augustash/claude-config/memory/augustash/repositories.md`  
  GitHub orgs to check before building from scratch; also who a handle is, before naming a module's maintainer
- **Neo module skills sync** — `vendor/augustash/claude-config/memory/augustash/neo-skills-sync.md`  
  after bumping a neo module, the project's `.claude/skills/` copies still hold the old text
- **Alchemist layout Save needs a second click** — `vendor/augustash/claude-config/memory/augustash/neo-alchemist-layout-save-confirm.md`  
  edits sit in a draft behind a confirm modal; reads exactly like a persistence bug
- **neo_alchemist seeds props with schema examples** — `vendor/augustash/claude-config/memory/augustash/neo-alchemist-example-seeding.md`  
  content on the page nobody authored; editors see repeater rows they never created, or examples you deleted still showing as defaults
- **The 'default' option discards stored media values** — `vendor/augustash/claude-config/memory/augustash/neo-alchemist-option-default-discards-value.md`  
  an image/file/video prop you demonstrably wrote renders the component's example instead; storage looks correct
- **neo_alchemist heading anchors derive from the title** — `vendor/augustash/claude-config/memory/augustash/neo-alchemist-heading-anchor-override.md`  
  a stored anchor is ignored, so re-wording a heading silently moves its id
- **Saving a neo_component wipes every prop plugin on the shape** — `vendor/augustash/claude-config/memory/augustash/neo-alchemist-plugin-settings-wipe.md`  
  before removing one plugin programmatically, or when one you never touched disappears
- **A builder-written value the editor rejects makes a component unsaveable** — `vendor/augustash/claude-config/memory/augustash/neo-alchemist-builder-value-blocks-editor.md`  
  a component renders fine but its save never returns to layout level, naming no field; also before adding an enum
- **Editor chrome must not sit in the preview's document flow** — `vendor/augustash/claude-config/memory/augustash/neo-alchemist-preview-overlay-scroll-loop.md`  
  an Alchemist preview that visibly shakes or rings; also before drawing or animating anything over one
- **A neo_component created in code fatals on the next load** — `vendor/augustash/claude-config/memory/augustash/neo-alchemist-component-create-description.md`  
  a command dies on EntityBase.php after you created a component in code; the create() reported success
- **neo_color scheme tokens and the :root bake** — `vendor/augustash/claude-config/memory/augustash/neo-color-scheme-token-resolution.md`  
  a custom property declared at `:root` won't recolor inside a scheme
- **Neo's base.css out-ranks the theme on form buttons** — `vendor/augustash/claude-config/memory/augustash/neo-base-css-button-specificity.md`  
  a theme rule on a submit button half-applies, with no `!important` and nothing visibly overriding it
- **Neo component-spacing ramp is bottom-heavy** — `vendor/augustash/claude-config/memory/augustash/neo-component-spacing-ramp.md`  
  sections read as run together on mobile while desktop looks right
- **neo spacing is a token plus an application** — `vendor/augustash/claude-config/memory/augustash/neo-component-spacing-collapse.md`  
  same `spacing` value reads as a bigger gap inside a region; choosing `my-` vs `py-component`
- **Neo image derivatives are AVIF on D11.2+** — `vendor/augustash/claude-config/memory/augustash/neo-image-avif-on-d11-2.md`  
  link previews break site-wide after an 11.2 bump while every image still looks right in a browser
- **component:// srcs get no image style** — `vendor/augustash/claude-config/memory/augustash/neo-image-local-src-no-derivatives.md`  
  images that load slowly, or a naturalWidth far bigger than the slot, while the twig plainly asks for a crop
- **A spent neo-animate reveal seals a stacking context** — `vendor/augustash/claude-config/memory/augustash/neo-animate-identity-transform-stacking.md`  
  a sibling won't layer between two children no matter what z-index it gets
- **The `neo:description` token falls back to the site slogan** — `vendor/augustash/claude-config/memory/augustash/neo-metatag-description-slogan.md`  
  every page shares one meta description, or no page has one; also before setting a site slogan
- **neo_icon renders an empty span for a style-prefixed id** — `vendor/augustash/claude-config/memory/augustash/neo-icon-id-prefix.md`  
  an icon silently renders empty; also before pasting what `neoi-list` prints
- **drupal_cache_protection** — `vendor/augustash/claude-config/memory/augustash/drupal_cache_protection.md`  
  tracking-param strip/redirect, facets + search submodules
- **recently_read (augustash fork)** — `vendor/augustash/claude-config/memory/augustash/recently-read.md`  
  a fork we own; never re-sync with upstream, the divergence is the point
- **A carried fix that conflicts may be obsolete** — `vendor/augustash/claude-config/memory/augustash/carried-fix-obsolete-check.md`  
  before resolving a merge conflict on a local fix carried against a fast-moving upstream, or rebasing one forward
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
- **AIOSEO writes llms.txt as a static file** — `vendor/augustash/claude-config/memory/wordpress/aioseo-llms-txt-static-file.md`  
  production serves your local .ddev.site URLs; also any plugin generating a file into the web root
- **terminus wp returns no output at all** — `vendor/augustash/claude-config/memory/wordpress/wp-cli-silent-on-pantheon.md`  
  WP-CLI commands exit 0 printing nothing, or eval-file silently does nothing; check before any destructive run
- **Object Cache Pro survives a database clone** — `vendor/augustash/claude-config/memory/wordpress/object-cache-survives-db-clone.md`  
  wp-admin and get_option() show pre-clone settings, and the site behaves that way too; also before guarding a destructive script on an option
- **AIOSEO nulls its Head object in AJAX and cron** — `vendor/augustash/claude-config/memory/wordpress/aioseo-rest-head-null-ajax-cron.md`  
  WooCommerce product webhooks fail and it reads as a broken scheduler; the queue looks healthy while events silently stop
- **PHP session GC never runs on Pantheon** — `vendor/augustash/claude-config/memory/wordpress/pantheon-session-gc-never-runs.md`  
  the database is mostly one session table; also before reserving a quiet window to rebuild a bloated table
