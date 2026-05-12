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

**Commit handoff convention.** Steps 1–3 are Claude's job and happen automatically as part of every shared-memory edit — generating `AGENTS.md` is not an optional follow-up, it's part of the write. Step 4 (commit + push) is also Claude's job for this repo specifically, because it's a self-contained shared package other projects depend on, so leaving local-only edits would defeat the purpose. This differs from project-level work, where the developer commits. Always show the diff before committing so the developer can flag anything off before it propagates.

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

Update existing memories rather than creating duplicates. Remove what's outdated. Keep files focused and concise.

### Maintenance

**Passive:** Every shared-memory save is a curator pass — scan the relevant topic dir for existing coverage, normalize shape and voice, reconcile any contradictions in one place, and keep the index in sync. See [mission.md → Steward role at write time](memory/preferences/mission.md) for the full posture.

**Active audit:** Opportunistic — triggered by signals like a memory-heavy session, stale refs surfacing, or dev request. Daily pre-check as a floor so the corpus never drifts more than 24h. See [memory audit process](memory/preferences/memory-audit.md).

### Current global memories

- [Mission](memory/preferences/mission.md) — shared team resource, proactive guidance, watch-and-suggest posture, Claude as steward at write time (read first; informs how other memories should be written)
- [Follow site conventions](memory/preferences/follow-site-conventions.md) — scan how a domain is handled in the codebase before writing in it; surface divergence from established patterns
- [Memory structure](memory/preferences/memory-structure.md) — idea/specific.md pattern, organization conventions
- [DDEV workflow](memory/preferences/ddev-workflow.md) — Always use ddev for CLI commands
- [Drupal caching](memory/drupal/caching.md) — Cache debugging, session poisoning, lazy builders without BigPipe, Exo component cache
- [Drupal PHPUnit testing](memory/drupal/phpunit-testing.md) — Setup and running PHPUnit kernel/unit tests in DDEV
- [Drupal Nightwatch testing](memory/drupal/nightwatch-testing.md) — Selenium setup, W3C patch, yarn install, tag-scoped runs. Patch lives at vendor/augustash/claude-config/patches/
- [Test tag/group convention](memory/drupal/test-tags.md) — `aai` umbrella + module sub-tag on every custom test (PHPUnit + Nightwatch)
- [Cross-project patches](memory/drupal/patches.md) — index of local .patch files + vetted remote URLs to reuse across projects
- [Augustash repositories](memory/augustash/repositories.md) — GitHub orgs (augustash, jacerider) to check before building from scratch
- [drupal_cache_protection](memory/augustash/drupal_cache_protection.md) — Tracking param strip/redirect (Google/HubSpot ads, utm_*); facets + search submodules; origin-side strip is the right tool on CF Pro/Free since edge-strip is Enterprise-only
- [Internal package distribution](memory/augustash/internal-package-distribution.md) — Distribute internal augustash composer packages via dev-master + prefer-source, no tags; place in require-dev
- [ddev-drupal Pantheon site var](memory/augustash/ddev-drupal-pantheon-site-var.md) — augustash/ddev-drupal exports Pantheon site as `PANTHEON_SITE` (older) or `DDEV_PANTHEON_SITE` (newer) in `.ddev/config.yaml`; grep both
- [Memory audit process](memory/preferences/memory-audit.md) — opportunistic triggers with a daily-floor pre-check, per-dev settings, self-refining
- [Comment style](memory/preferences/comments.md) — Concise; skip comments when the code is obvious, explain the WHY when it isn't
- [Scratch context](memory/preferences/scratch-context.md) — ~/.claude/scratch/ for temporary cross-project context; offer proactively on project switches
- [Git merge over rebase](memory/preferences/git-merge-not-rebase.md) — Default to `git pull --no-rebase` when integrating remote work; only rebase when explicitly asked
- [Commit handoff](memory/preferences/commit-handoff.md) — Claude commits + pushes shared claude-config memory; dev reviews + commits + pushes all project work
- [WooCommerce Pantheon cache](memory/wordpress/woocommerce-pantheon-cache.md) — ash-woocommerce-cookies plugin for Varnish cache-busting fix
- [Pantheon robots.txt](memory/drupal/pantheon-robots-txt.md) — Custom disallow rules via Composer scaffold append
- [Cloudflare tracking params](memory/drupal/cloudflare-tracking-params.md) — Tracking param handling via ash_facet_protection, not CF cache rules
- [Cachetags garbage collection](memory/drupal/cachetags-garbage-collection.md) — cachetags table has no GC, needs periodic truncation; build a module
- [Exo optional link field](memory/drupal/exo-alchemist-optional-link.md) — `required: FALSE` is a no-op; use `cleanup: FALSE` + `title_type: 'optional'` and check `link.url` in twig
- [Exo modifier checkbox + class](memory/drupal/exo-alchemist-modifier-checkbox.md) — Try built-in `modifier_globals.status` flag first (instance-level, auto class); custom YAML modifier + PascalCase handler only when built-in doesn't fit
- [Exo slider mobile overflow](memory/drupal/exo-alchemist-slider-mobile-overflow.md) — Slider component overflows on mobile only? Flex `min-width: auto` + Swiper's intrinsic-width markup; fix with `min-width: 0` on `.exo-component`
- [Test reminders](memory/preferences/test-reminders.md) — Surface existing tests when modifying covered code; flag coverage gaps on new or substantial changes
- [Vimeo background=1 embed param](memory/drupal/vimeo-background-param.md) — `background=1` can 403 player URL looking like privacy issue; replace with explicit autoplay/controls/loop/muted/autopause/playsinline params
- [LiveChat widget click-trap](memory/drupal/livechat-click-trap.md) — third-party rules (e.g. ConvertCart's `cc-ftr-menu`) force `#chat-widget-container`'s height beyond its bubble, the empty area then traps clicks; presents as "menu broken in normal Chrome/Edge, fine in private/Safari"; fix with higher-specificity CSS or JS observer
