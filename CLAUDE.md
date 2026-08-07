# August Ash — Shared Claude Config

Team-wide conventions and preferences for Claude Code.

## Memory

Two tiers, both committed to git so the whole team benefits. **Both are writable — save
directly to these locations.** Prefer them over Claude's local auto-memory
(`~/.claude/projects/`) for anything worth sharing.

- **Global** — `vendor/augustash/claude-config/memory/{topic}/{specific}.md`. Knowledge that
  transcends any single project; ships into every project requiring this package.
- **Per-project** — `.claude/memory/` in the project repo. Knowledge specific to one codebase.

> **Writing, curating, or auditing a memory? Load the
> [memory-management](skills/memory-management/SKILL.md) skill first.** It owns the decisions
> (does this qualify, which tier, is it really a skill), the index-entry form, the
> commit-and-push steps that finish the write, and the audit process. Reading an existing
> memory needs nothing — just open the file the index points at.

The index below is a **table of contents**, loaded in full every session; bodies load only when
opened. That asymmetry is what lets the corpus grow without the per-session cost growing with
it — so entries are one-line hooks saying *when* a memory fires, never summaries of what it
concluded. `generate-agents.py` enforces the ceiling.

### Current global memories

This is a table of contents, not a digest. Each line says *when the memory
fires*, not what it concluded — enough to decide whether to open the file, and
no more. Open the file the moment a line looks relevant; that's the whole design.

#### Preferences & collaboration

- [Mission](memory/preferences/mission.md) — how Claude stewards this corpus; read first, it shapes how every other memory is written
- [Follow site conventions](memory/preferences/follow-site-conventions.md) — scan how a domain is already handled here before writing in it
- [Memory structure](memory/preferences/memory-structure.md) — topic/specific.md layout and organization rules
- [Reference scripts, don't embed](memory/preferences/reference-scripts-not-embeds.md) — scripts live in templates/ and are linked by path, never pasted into a note
- [DDEV workflow](memory/preferences/ddev-workflow.md) — always use ddev for CLI commands
- [ddev Mutagen sync lag](memory/preferences/ddev-mutagen-sync-lag.md) — a file written inside the container reads stale on the host, so the command looks like it failed
- [Memory audit process](memory/preferences/memory-audit.md) — audit triggers and the `last_audit` daily floor
- [Leave stopwords out of method names](memory/preferences/method-naming.md) — no `a`/`an`/`the`/`to`; also trips Drupal's ValidFunctionName sniff
- [Style rules cover as much ground as possible](memory/preferences/style-rules-cover-ground.md) — before scoping a style fix to one page or instance; Kaza's rule on uniformity
- [Use scale classes, not arbitrary Tailwind values](memory/preferences/tailwind-no-arbitrary-values.md) — Cyle's rule: no bracket utilities like `text-[2rem]`, snap to the scale
- [Check mobile on every CSS change](memory/preferences/mobile-breakpoint-check.md) — before calling any CSS done; Neo previews each component at its breakpoints, so look rather than reason
- [Tables sidescroll, never restack into records](memory/preferences/table-sidescroll-default.md) — reach for a scroll cue, not a mobile card layout, whenever a table meets a narrow screen
- [Sidescroll dead zones](memory/preferences/sidescroll-dead-zones.md) — a strip that scrolls over its middle but not its edges, or won't drag; also: never hijack a plain vertical wheel
- [Comment style](memory/preferences/comments.md) — concise; explain the WHY, skip the obvious
- [Commit messages](memory/preferences/commit-messages.md) — subject + a tight WHY; diagnosis belongs in the PR, not the commit
- [Run cex before commit rounds](memory/preferences/cex-before-commit.md) — before drawing commit boundaries on a Drupal project; the first export after a gap carries other sessions' config
- [Load the design skill when the work has to match something](memory/preferences/use-design-skill.md) — when design judgment is left; skip it for prescriptive handed-over values
- [Scratch context](memory/preferences/scratch-context.md) — ~/.claude/scratch/ for temporary cross-project context
- [Git merge over rebase](memory/preferences/git-merge-not-rebase.md) — `pull --no-rebase` by default
- [Commit handoff](memory/preferences/commit-handoff.md) — who commits what: Claude owns shared memory, dev owns project work
- [Confirm before live terminus](memory/preferences/confirm-before-live-terminus.md) — always confirm before terminus against `.live`/`.test`
- [Local config in settings.local.php](memory/preferences/local-config-in-settings-local.md) — dev-only overrides never go through `cset`/UI
- [Log audit](memory/preferences/log-audit.md) — how to run a server-log review; never exfiltrate log contents
- [Test reminders](memory/preferences/test-reminders.md) — surface existing tests when changing covered code, flag coverage gaps
- [Trust contrib tests](memory/preferences/trust-contrib-tests.md) — cover only the seam we own; never hit a live external API
- [No time-based test waits](memory/preferences/no-time-based-test-waits.md) — wait on the condition, never a fixed delay
- [Transactional email on our account](memory/preferences/transactional-email-on-our-account.md) — before pointing a site at the client's existing ESP, or treating the subscription fee as the deciding factor
- [Proactively clean up cruft](memory/preferences/proactive-cleanup.md) — offer to fix warnings and dead code near the work, in its own commit

#### Drupal

- [Drupal caching](memory/drupal/caching.md) — cache debugging, session poisoning, Exo component cache, Redis compress_length
- [D11.4 symfony/runtime allow-plugin](memory/drupal/d11-symfony-runtime.md) — every web request WSODs after a 11.4 bump while drush still works fine
- [Cross-version DB pull](memory/drupal/cross-version-db-pull.md) — older prod DB into newer code; `updatedb` dies on an unknown `router.alias` column
- [Admin theme change orphans theme-keyed config](memory/drupal/admin-theme-keyed-config.md) — the new admin theme "looks wrong": forms sprawl onto two rows, panels render unstyled
- [config_ignore over a config_split module deadlocks deploy](memory/drupal/config-split-ignore-collision.md) — `cim` aborts with "depends on the Y module that will not be installed"
- [An active split whose modules aren't installed empties its folder on export](memory/drupal/config-split-export-wipes-folder.md) — `cex` silently blanks the split folder, and the status you'd check to rule it out lies
- [A DB push makes cim uninstall the whole dev split at once](memory/drupal/config-split-db-push-mass-uninstall.md) — `cim` dies "terminated abnormally" and half-applied after pushing a local DB to Pantheon; re-running walks it forward
- [A redirect never fires while its source path still has an alias](memory/drupal/redirect-shadowed-by-alias.md) — a correct 301 sits in the table unreachable; retiring a node is three steps, not two
- [Gating a Drupal file takes three things](memory/drupal/private-file-gate.md) — a restricted file still downloads though `file_managed` says `private://`; also after any migration whose source had private files
- [BigPipe is not viable on Pantheon](memory/drupal/bigpipe-pantheon.md) — lazy_builder is a no-op there; also how to actually diagnose whether a page caches
- [GTranslate integration](memory/drupal/gtranslate-integration.md) — choosing hosted-subdomain vs the subdirectory addon, which saturates PHP-FPM
- [Cache bin that survives drush cr](memory/drupal/persistent-cache-bin.md) — keeping a warm store from being wiped by a full cache flush
- [Short edge TTL vs tag-purge for volatile pages](memory/drupal/edge-ttl-vs-tag-purge.md) — giving ONE page a short external Cache-Control, and why TTL beats tag-purge
- [Search API / Solr convention](memory/drupal/search-api-solr-convention.md) — standard index/server names and the DDEV Solr build
- [Drupal PHPUnit testing](memory/drupal/phpunit-testing.md) — DDEV setup; D9/10 and D11 phpunit.xml are not interchangeable; PHPUnit 11 metadata changes
- [Drupal Nightwatch testing](memory/drupal/nightwatch-testing.md) — Selenium setup and tag-scoped runs; the W3C patch breaks D11 updates
- [Playwright UI test writing](memory/drupal/playwright-testing.md) — serial runs, condition waits, warm caches first
- [Update-hook testing](memory/drupal/update-hook-testing.md) — when an update hook deserves an update-path test and when it doesn't
- [Test tag/group convention](memory/drupal/test-tags.md) — `aai` vs `ar` umbrella tag + module sub-tag, and how to tell which a site is
- [Cross-project patches](memory/drupal/patches.md) — index of reusable local .patch files and vetted remote URLs
- [Pantheon robots.txt](memory/drupal/pantheon-robots-txt.md) — custom disallow rules via Composer scaffold append
- [Favicon 404 cluster with the icons all present](memory/drupal/favicon-docroot-icons.md) — thousands of icon 404s while the generated set sits there serving 200s; don't patch the module
- [Pantheon Quicksilver cache warmer](memory/drupal/pantheon-quicksilver-cache-warmer.md) — deploy hook that pre-curls heavy pages to beat the cold-cache dogpile
- [Cron off-path page_cache re-prime](memory/drupal/page-cache-cron-reprime.md) — keeping an uncacheable form page warm through a mid-day cache eviction
- [Cloudflare tracking params](memory/drupal/cloudflare-tracking-params.md) — handle in drupal_cache_protection, not CF cache rules
- [Cachetags garbage collection](memory/drupal/cachetags-garbage-collection.md) — the cachetags table has no GC and grows unbounded
- [A node access rebuild permanently caches every listing empty](memory/drupal/node-access-rebuild-empties-listings.md) — listings show their empty message while the content plainly exists; reads as content loss or a stalled search index
- [Exo optional link field](memory/drupal/exo-alchemist-optional-link.md) — `required: FALSE` is a no-op on a link field
- [Exo modifier checkbox + class](memory/drupal/exo-alchemist-modifier-checkbox.md) — adding a per-instance toggle that emits a class
- [Exo slider mobile overflow](memory/drupal/exo-alchemist-slider-mobile-overflow.md) — a slider that overflows on mobile only
- [exo_icon breaks kernel tests](memory/drupal/exo-icon-kernel-tests.md) — enabling exo_icon in a KernelTestBase fatals on a missing `node_type`
- [eXo image formatters — D11.4 constructor break](memory/drupal/exo-d11-image-formatters.md) — images or an eXo Gallery field WSOD after a 11.4 bump; ArgumentCountError *or* TypeError on constructor arg #11
- [Vimeo background=1 embed param](memory/drupal/vimeo-background-param.md) — a 403 on the player URL that looks like a privacy setting
- [LiveChat widget click-trap](memory/drupal/livechat-click-trap.md) — "menu broken in normal Chrome, fine in private" from an oversized chat container
- [LiveChat from your own trigger](memory/drupal/livechat-custom-launcher.md) — putting chat in a menu instead of the floating bubble; also a chat window that opens with its title bar off-screen

#### Augustash internal modules

- [Augustash repositories](memory/augustash/repositories.md) — GitHub orgs to check before building anything from scratch
- [Neo module skills sync](memory/augustash/neo-skills-sync.md) — after bumping a neo module, the project's `.claude/skills/` copies still hold the old text
- [Alchemist layout Save needs a second click](memory/augustash/neo-alchemist-layout-save-confirm.md) — edits sit in a draft behind a confirm modal; reads exactly like a persistence bug
- [neo_alchemist seeds props with schema examples](memory/augustash/neo-alchemist-example-seeding.md) — content on the page nobody authored; editors see repeater rows they never created
- [The 'default' option discards stored media values](memory/augustash/neo-alchemist-option-default-discards-value.md) — an image/file/video prop you demonstrably wrote renders the component's example instead; storage looks correct
- [neo_alchemist heading anchors derive from the title](memory/augustash/neo-alchemist-heading-anchor-override.md) — a stored anchor is ignored, so re-wording a heading silently moves its id
- [Saving a neo_component wipes every prop plugin on the shape](memory/augustash/neo-alchemist-plugin-settings-wipe.md) — before removing one plugin programmatically, or when one you never touched disappears
- [neo_color scheme tokens and the :root bake](memory/augustash/neo-color-scheme-token-resolution.md) — a custom property declared at `:root` won't recolor inside a scheme
- [Neo's base.css out-ranks the theme on form buttons](memory/augustash/neo-base-css-button-specificity.md) — a theme rule on a submit button half-applies, with no `!important` and nothing visibly overriding it
- [Neo component-spacing ramp is bottom-heavy](memory/augustash/neo-component-spacing-ramp.md) — sections read as run together on mobile while desktop looks right
- [neo spacing is a token plus an application](memory/augustash/neo-component-spacing-collapse.md) — same `spacing` value reads as a bigger gap inside a region; choosing `my-` vs `py-component`
- [neo_icon renders an empty span for a style-prefixed id](memory/augustash/neo-icon-id-prefix.md) — an icon silently renders empty; also before pasting what `neoi-list` prints
- [drupal_cache_protection](memory/augustash/drupal_cache_protection.md) — tracking-param strip/redirect, facets + search submodules
- [recently_read (augustash fork)](memory/augustash/recently-read.md) — a fork we own; never re-sync with upstream, the divergence is the point
- [Internal package distribution](memory/augustash/internal-package-distribution.md) — dev-master + prefer-source, no tags; the dirty-vendor and `--no-dev` deploy traps; a vendor clone claiming it's "N commits ahead"
- [Pantheon Secrets](memory/augustash/pantheon-secrets.md) — terminus secrets vs the legacy secrets.json, and why PEM keys need base64
- [ddev-drupal Pantheon site var](memory/augustash/ddev-drupal-pantheon-site-var.md) — three generations of site/env var names in `.ddev/config.yaml`; grep all forms
- [ddev db pull guard](memory/augustash/ddev-db-pull-guard.md) — hesitating to `ddev restart` in case the post-start pull clobbers your local database; it won't
- [ddev-wordpress WP Engine gate](memory/augustash/ddev-wordpress-wpengine-gate.md) — what it rewrites in wp-config.php and .gitignore on every composer update
- [WP Engine git deploy](memory/augustash/wpengine-git-deploy.md) — reconcile live plugin drift before deploying or the push reverts it
- [ddev-setup post-update-cmd wiring](memory/augustash/ddev-setup-post-update-cmd.md) — the hook set via `ddev composer config --json` fails to autoload
- [New Relic audit tool](memory/augustash/newrelic-audit-tool.md) — NerdGraph puller + report generator for Pantheon worker-saturation exhibits

#### WordPress

- [WooCommerce Pantheon cache](memory/wordpress/woocommerce-pantheon-cache.md) — the ash-woocommerce-cookies plugin for the Varnish cache-busting fix
- [WooCommerce purchase gate seams](memory/wordpress/woocommerce-purchase-gate-seams.md) — forcing login before purchase takes four hooks, only one of them a real rule
- [LearnDash closed-course button URL](memory/wordpress/learndash-closed-course-button-url.md) — a closed course's buy button points at live from every other environment
- [WP security-header CSP silently breaks analytics](memory/wordpress/rsssl-csp-enforce-analytics.md) — analytics cliffs overnight while the site looks fine; two header plugins intersect
- [Pass CSP Evaluator on WordPress with nonce + strict-dynamic](memory/wordpress/csp-nonce-strict-dynamic.md) — clearing the `script-src` HIGH without a host allowlist, and where WP leaks un-nonced inline scripts
- [AIOSEO writes llms.txt as a static file](memory/wordpress/aioseo-llms-txt-static-file.md) — production serves your local .ddev.site URLs; also any plugin generating a file into the web root

---

## Skills

A **skill** is a procedure Claude loads on demand — a multi-step job with its own method,
traps and deliverable. Distinct from memory, which is knowledge to recall; the
[memory-management](skills/memory-management/SKILL.md) skill (§3) has the test for telling
them apart when a note starts growing steps.

Canonical copies live in `vendor/augustash/claude-config/skills/{name}/SKILL.md`, versioned
with this package, so a refinement made on one project reaches every project on the next
`composer update augustash/claude-config`. Any tool a skill drives belongs in `templates/`,
referenced by path — never pasted into the skill body (see
[reference-scripts-not-embeds](memory/preferences/reference-scripts-not-embeds.md)).

**Installing into a project.** Claude Code only discovers skills in the project's
`.claude/skills/`, so a skill in this package is not live until it's copied:

```
cp -R vendor/augustash/claude-config/skills/content-audit .claude/skills/
```

**Except [memory-management](skills/memory-management/SKILL.md), which the Plugin seeds into
every project** (`ALWAYS_ON_SKILLS`). It's stack-agnostic, and the Plugin already wires the
memory-audit SessionStart hook everywhere unconditionally — a reminder to run an audit whose
procedure lives only in that skill. Shipping one without the other was half a mechanism.
Adding anything else to that list needs the same argument, not just broad usefulness.

Copy per skill — don't symlink `.claude/skills` at this package's `skills/` directory. That
directory is shared: the neo/jacerider modules ship their own skills into it
(see [neo-skills-sync](memory/augustash/neo-skills-sync.md)), and a symlink would leave
nowhere for them to land.

Commit that copy with the project. **Adoption is manual; staying current is not** — the
composer Plugin's `syncSkills()` refreshes every *already-adopted* copy on each
`composer update augustash/claude-config`, prints which ones changed, and leaves skills the
project never adopted alone (a WordPress project shouldn't inherit the Drupal upgrade skill).
The package copy is canonical, so a local edit to a project copy gets overwritten — refine it
here instead. Commit the refreshed copy with the bump.

Because adoption is per-project and nothing back-fills it, a skill is present wherever someone
once ran that `cp` and absent everywhere else — which reads as a skill that goes missing at
random rather than one that was never installed. If `/<name>` comes back `Unknown skill`, that's
the reason; the procedure is still on disk at `vendor/augustash/claude-config/skills/<name>/`
and can just be read directly.

This only covers *this* package's skills. The neo/jacerider modules still have the manual
gotcha (see [neo-skills-sync](memory/augustash/neo-skills-sync.md)).

**Writing one.** Same commit-handoff rule as memory: Claude writes, indexes and pushes.
Update the index below, and keep the `description:` frontmatter explicit about when the skill
applies *and when it doesn't* — it's the only thing loaded until the skill fires.

**Skills are Claude's domain, the same way memory is.** Claude owns writing, refining,
reorganising and committing them — no need to ask, and no need to be asked. Showing the diff
is optional transparency, not a review gate. The maintenance expectation mirrors
[memory audit](memory/preferences/memory-audit.md):

- **Passive.** Any session that exercises a skill is a chance to sharpen it. When a
  better pattern emerges, a stated preference generalises, or a mistake is worth not
  repeating, fold it in *during that session* while the detail is fresh — don't defer
  it to a cleanup pass that never comes.
- **Active.** During a memory audit, give the skills the same pass: are they still
  accurate, has one grown two topics that want splitting, is anything now wrong?
- **Capture the corrections, not just the wins.** A skill that records only what
  worked is half a skill. The errors — what was assumed, mis-measured or phrased
  badly, and how it was caught — are what stop the next session repeating them.

Owning them doesn't mean deciding alone. Ask when a judgement call would genuinely
benefit from the team's view — whether a pattern generalises or was one client's
taste, whether two skills should merge, what a convention *should* be rather than
what it happened to be once. A skill built on a guess is worse than a question.

### Current skills

One index, and it lives here — adding a skill means adding a bullet below, never opening a
second Skills section elsewhere in this file.

Same rule as the memory index: a line per skill, saying when it fires. The
authoritative trigger is each SKILL.md's own `description:` frontmatter — that's
what Claude Code actually loads for discovery, so keep it sharp there.

- [client-report](skills/client-report/SKILL.md) — writing an evidence-led client report or rebuild pitch and shipping it as a branded HTML page
- [content-audit](skills/content-audit/SKILL.md) — reducing a legacy CMS's content before migrating it, plus the overlap sweeps for both sides of the migration
- [content-migration-to-components](skills/content-migration-to-components/SKILL.md) — building a page out of migrated content: what shape it is, reuse/extend/build-new, and verifying the result
- [drupal-11-upgrade](skills/drupal-11-upgrade/SKILL.md) — running a D10→D11 upgrade on Pantheon, built around the failures that report success
- [memory-management](skills/memory-management/SKILL.md) — writing, curating, or auditing a memory: qualification, tier, index-entry form, and the commit steps
