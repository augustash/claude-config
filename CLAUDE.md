# August Ash — Shared Claude Config

Team-wide conventions and preferences for Claude Code.

## Memory

Two shared memory tiers, both committed to git so the whole team benefits. **Both are writable — save directly to these locations.** Prefer these over Claude's local auto-memory (`~/.claude/projects/`) for any knowledge worth sharing.

### Global — `vendor/augustash/claude-config/memory/`

Knowledge that transcends any single project. Augustash internal modules and reusable code, cross-project debugging approaches, team tooling conventions, shared patterns. Lives inside this composer package and ships into every project that requires it.

Organize as `{topic}/{specific}.md` — see [memory structure](memory/preferences/memory-structure.md).

**Writing shared memory.** `vendor/augustash/claude-config/` is a real git working copy (the project installs the package via composer's prefer-source). To save a shared memory:

1. Write or edit the file under `vendor/augustash/claude-config/memory/{topic}/{specific}.md`.
2. Update the `### Current global memories` index in `vendor/augustash/claude-config/CLAUDE.md` to match.
3. Run `python3 vendor/augustash/claude-config/generate-agents.py` so `AGENTS.md` stays in sync with the index.
4. From inside `vendor/augustash/claude-config/`: `git add -A && git commit -m "..." && git push`. Other projects pick up the change on their next `composer update augustash/claude-config`.

**Commit handoff convention.** Steps 1–3 are Claude's job and happen automatically as part of every shared-memory edit — generating `AGENTS.md` is not an optional follow-up, it's part of the write. Step 4 (commit + push) is also Claude's job for this repo specifically, because it's a self-contained shared package other projects depend on, so leaving local-only edits would defeat the purpose. This differs from project-level work, where the developer commits. Memory is Claude-owned and committed autonomously (see [memory-audit.md → Ownership](memory/preferences/memory-audit.md)) — showing the diff first is optional transparency, not a required review gate.

Sanity-check before writing:

- If `vendor/augustash/claude-config/.git` is missing (the package was installed via dist instead of source), don't write — edits will be clobbered on the next composer run. Surface that and ask the user to reinstall with `composer reinstall augustash/claude-config --prefer-source` first.
- If `git status` inside the vendor copy shows `HEAD detached` (the project still uses a tagged version constraint), commits won't push to a branch. This package is distributed via `dev-master`, not tagged releases — surface that and ask the user to switch their project's constraint to `dev-master` and run `composer update augustash/claude-config` first.

### Per-project — `.claude/memory/` in the project repo

Knowledge specific to this codebase — integration details, architectural decisions, non-obvious configuration.

### Qualification

The test: **given a clear, direct prompt, would a fresh session still need to do real work to arrive at this understanding?** Ignore how the current session went — messy communication and high token spend don't mean the knowledge is complex. What matters is whether the knowledge *itself* was non-trivial to discover.

Worth saving:
- **Cross-system synthesis** — understanding required connecting dots across multiple files, services, or external docs that a fresh session would need to re-traverse.
- **Non-obvious reasoning** — the "why" behind a choice isn't in the code. A future session would make the wrong call without it.
- **External context** — API behaviors, vendor quirks, team decisions that live outside the codebase.

Not worth saving: anything a fresh session could resolve with a grep, a read, or a quick command — even if this session took a long time to get there.

**Choosing a tier:** if the knowledge would help on a different augustash project, it's global. If it only matters in this codebase, it's per-project. When in doubt, per-project — it can be promoted later.

**Memory vs. skill:** memory is knowledge Claude should *recall* (a gotcha, a decision, a vendor quirk). A **skill** is a *procedure Claude should follow* — a multi-step job with its own method, traps and deliverable, worth loading only when that job comes up. If you find yourself writing a memory with numbered steps and a tool to run, it's a skill. See [Skills](#skills) below.

Update existing memories rather than creating duplicates. Remove what's outdated. Keep files focused and concise.

### Index entries are hooks, not summaries

The index below is loaded into **every session, in full, forever**; the memory
bodies are loaded only when opened. That asymmetry is the entire design — it's
what lets the corpus grow without the per-session cost growing with it.

So an index line pays rent on every session that never needs it, and its only
job is to make the decision *"is this worth opening?"* Write the **trigger** —
the symptom, the task, the thing you'd be staring at — not the finding:

> ✅ `— a correct 301 sits in the table unreachable; retiring a node is three steps, not two`
> ❌ `— retiring a node is THREE steps: unpublish, redirect, delete the alias. RedirectRequestSubscriber runs processInbound() before findMatchingRedirect(), so … [+400 chars]`

The long form is worse *as an index*, not merely more expensive: it front-loads
the conclusion and buries the trigger, so the thing being pattern-matched
against sits forty words deep. Aim for **one line, ~120 characters** after the
em dash. If it needs more, that's the body's job — and being unable to name the
trigger in a line is a sign the memory itself is unfocused.

Resist restating the fix here "so it's already loaded." It isn't a shortcut; it
is the cost, paid every session, whether or not the memory is ever used.

### Maintenance

**Passive:** Every shared-memory save is a curator pass — scan the relevant topic dir for existing coverage, normalize shape and voice, reconcile any contradictions in one place, and keep the index in sync. See [mission.md → Steward role at write time](memory/preferences/mission.md) for the full posture.

**Active audit:** Opportunistic — triggered by signals like a memory-heavy session, stale refs surfacing, or dev request. Daily pre-check as a floor so the corpus never drifts more than 24h. See [memory audit process](memory/preferences/memory-audit.md).

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
- [Use scale classes, not arbitrary Tailwind values](memory/preferences/tailwind-no-arbitrary-values.md) — Cyle's rule: no bracket utilities like `text-[2rem]`, snap to the scale
- [Comment style](memory/preferences/comments.md) — concise; explain the WHY, skip the obvious
- [Commit messages](memory/preferences/commit-messages.md) — subject + a tight WHY; diagnosis belongs in the PR, not the commit
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
- [Proactively clean up cruft](memory/preferences/proactive-cleanup.md) — offer to fix warnings and dead code near the work, in its own commit

#### Drupal

- [Drupal caching](memory/drupal/caching.md) — cache debugging, session poisoning, Exo component cache, Redis compress_length
- [D11.4 symfony/runtime allow-plugin](memory/drupal/d11-symfony-runtime.md) — every web request WSODs after a 11.4 bump while drush still works fine
- [Cross-version DB pull](memory/drupal/cross-version-db-pull.md) — older prod DB into newer code; `updatedb` dies on an unknown `router.alias` column
- [config_ignore over a config_split module deadlocks deploy](memory/drupal/config-split-ignore-collision.md) — `cim` aborts with "depends on the Y module that will not be installed"
- [An active split whose modules aren't installed empties its folder on export](memory/drupal/config-split-export-wipes-folder.md) — `cex` silently blanks the split folder, and the status you'd check to rule it out lies
- [A redirect never fires while its source path still has an alias](memory/drupal/redirect-shadowed-by-alias.md) — a correct 301 sits in the table unreachable; retiring a node is three steps, not two
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
- [Pantheon Quicksilver cache warmer](memory/drupal/pantheon-quicksilver-cache-warmer.md) — deploy hook that pre-curls heavy pages to beat the cold-cache dogpile
- [Cron off-path page_cache re-prime](memory/drupal/page-cache-cron-reprime.md) — keeping an uncacheable form page warm through a mid-day cache eviction
- [Cloudflare tracking params](memory/drupal/cloudflare-tracking-params.md) — handle in drupal_cache_protection, not CF cache rules
- [Cachetags garbage collection](memory/drupal/cachetags-garbage-collection.md) — the cachetags table has no GC and grows unbounded
- [Exo optional link field](memory/drupal/exo-alchemist-optional-link.md) — `required: FALSE` is a no-op on a link field
- [Exo modifier checkbox + class](memory/drupal/exo-alchemist-modifier-checkbox.md) — adding a per-instance toggle that emits a class
- [Exo slider mobile overflow](memory/drupal/exo-alchemist-slider-mobile-overflow.md) — a slider that overflows on mobile only
- [exo_icon breaks kernel tests](memory/drupal/exo-icon-kernel-tests.md) — enabling exo_icon in a KernelTestBase fatals on a missing `node_type`
- [eXo image formatters — D11.4 constructor break](memory/drupal/exo-d11-image-formatters.md) — ArgumentCountError rendering images after a 11.4 bump
- [Vimeo background=1 embed param](memory/drupal/vimeo-background-param.md) — a 403 on the player URL that looks like a privacy setting
- [LiveChat widget click-trap](memory/drupal/livechat-click-trap.md) — "menu broken in normal Chrome, fine in private" from an oversized chat container

#### Augustash internal modules

- [Augustash repositories](memory/augustash/repositories.md) — GitHub orgs to check before building anything from scratch
- [Neo module skills sync](memory/augustash/neo-skills-sync.md) — `composer update` does not refresh the project's `.claude/skills/` copies
- [Alchemist layout Save needs a second click](memory/augustash/neo-alchemist-layout-save-confirm.md) — edits sit in a draft behind a confirm modal; reads exactly like a persistence bug
- [neo_alchemist discards nested markup values](memory/augustash/neo-alchemist-nested-markup.md) — a nested markup prop renders the SDC example instead of stored data
- [neo_alchemist overwrites a nested prop stored FALSE](memory/augustash/neo-alchemist-nested-falsy-value.md) — same symptom, separate cause; a stored `false` is read as never-written
- [neo_alchemist heading anchors derive from the title](memory/augustash/neo-alchemist-heading-anchor-override.md) — a stored anchor is ignored, so re-wording a heading silently moves its id
- [neo_color scheme tokens and the :root bake](memory/augustash/neo-color-scheme-token-resolution.md) — a custom property declared at `:root` won't recolor inside a scheme
- [neo spacing is a token plus an application](memory/augustash/neo-component-spacing-collapse.md) — same `spacing` value reads as a bigger gap inside a region; choosing `my-` vs `py-component`
- [neo_icon renders an empty span for a style-prefixed id](memory/augustash/neo-icon-id-prefix.md) — an icon silently renders empty, reading as "no icon support"
- [drupal_cache_protection](memory/augustash/drupal_cache_protection.md) — tracking-param strip/redirect, facets + search submodules
- [recently_read (augustash fork)](memory/augustash/recently-read.md) — a fork we own; never re-sync with upstream, the divergence is the point
- [Internal package distribution](memory/augustash/internal-package-distribution.md) — dev-master + prefer-source, no tags; the dirty-vendor and `--no-dev` deploy traps
- [Pantheon Secrets](memory/augustash/pantheon-secrets.md) — terminus secrets vs the legacy secrets.json, and why PEM keys need base64
- [ddev-drupal Pantheon site var](memory/augustash/ddev-drupal-pantheon-site-var.md) — three generations of site/env var names in `.ddev/config.yaml`; grep all forms
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

---

## Skills

A **skill** is a procedure Claude loads on demand — a multi-step job with its own method,
traps and deliverable. Distinct from memory, which is knowledge to recall (see
[Memory vs. skill](#memory) above).

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

Copy per skill — don't symlink `.claude/skills` at this package's `skills/` directory. That
directory is shared: the neo/jacerider modules ship their own skills into it
(see [neo-skills-sync](memory/augustash/neo-skills-sync.md)), and a symlink would leave
nowhere for them to land.

Commit that copy with the project. On `composer update augustash/claude-config`, re-copy any
skill whose canonical version changed — there is no automatic sync, the same gotcha the neo
modules have.

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
- [drupal-11-upgrade](skills/drupal-11-upgrade/SKILL.md) — running a D10→D11 upgrade on Pantheon, built around the failures that report success
