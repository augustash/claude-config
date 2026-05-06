# August Ash — team conventions for AI assistants

Shared context for AI coding assistants (Cursor, Codex, Aider, Claude Code, and any tool that reads `AGENTS.md`) working on augustash projects. When a task touches one of the topics below, read the referenced file before proceeding — the team has accumulated conventions and hard-won lessons there that generic defaults won't match.

These files are authoritative and kept current by the team. Prefer conventions here over generic defaults. When you learn something worth sharing, update or add a file under `~/claude-config/memory/` and commit it — everyone on the team benefits.

> *Generated from `CLAUDE.md`. Don't edit this file directly — edit `CLAUDE.md` and rerun `generate-agents.py` (or let `setup.sh` do it).*

## Preferences & collaboration

- **Mission** — `~/claude-config/memory/preferences/mission.md`  
  shared team resource, proactive guidance, watch-and-suggest posture (read first; informs how other memories should be written)
- **Follow site conventions** — `~/claude-config/memory/preferences/follow-site-conventions.md`  
  scan how a domain is handled in the codebase before writing in it; surface divergence from established patterns
- **Memory structure** — `~/claude-config/memory/preferences/memory-structure.md`  
  idea/specific.md pattern, organization conventions
- **DDEV workflow** — `~/claude-config/memory/preferences/ddev-workflow.md`  
  Always use ddev for CLI commands
- **Memory audit process** — `~/claude-config/memory/preferences/memory-audit.md`  
  event-driven (not scheduled), per-dev settings, self-refining
- **Comment style** — `~/claude-config/memory/preferences/comments.md`  
  Concise; skip comments when the code is obvious, explain the WHY when it isn't
- **Scratch context** — `~/claude-config/memory/preferences/scratch-context.md`  
  ~/.claude/scratch/ for temporary cross-project context; offer proactively on project switches
- **Test reminders** — `~/claude-config/memory/preferences/test-reminders.md`  
  Surface existing tests when modifying covered code; flag coverage gaps on new or substantial changes

## Drupal

- **Drupal caching** — `~/claude-config/memory/drupal/caching.md`  
  Cache debugging, session poisoning, lazy builders without BigPipe, Exo component cache
- **Drupal PHPUnit testing** — `~/claude-config/memory/drupal/phpunit-testing.md`  
  Setup and running PHPUnit kernel/unit tests in DDEV
- **Drupal Nightwatch testing** — `~/claude-config/memory/drupal/nightwatch-testing.md`  
  Selenium setup, W3C patch, yarn install, tag-scoped runs. Patch lives at ~/claude-config/patches/
- **Test tag/group convention** — `~/claude-config/memory/drupal/test-tags.md`  
  `aai` umbrella + module sub-tag on every custom test (PHPUnit + Nightwatch)
- **Cross-project patches** — `~/claude-config/memory/drupal/patches.md`  
  index of local .patch files + vetted remote URLs to reuse across projects
- **Pantheon robots.txt** — `~/claude-config/memory/drupal/pantheon-robots-txt.md`  
  Custom disallow rules via Composer scaffold append
- **Cloudflare tracking params** — `~/claude-config/memory/drupal/cloudflare-tracking-params.md`  
  Tracking param handling via ash_facet_protection, not CF cache rules
- **Cachetags garbage collection** — `~/claude-config/memory/drupal/cachetags-garbage-collection.md`  
  cachetags table has no GC, needs periodic truncation; build a module
- **Exo optional link field** — `~/claude-config/memory/drupal/exo-alchemist-optional-link.md`  
  `required: FALSE` is a no-op; use `cleanup: FALSE` + `title_type: 'optional'` and check `link.url` in twig
- **Exo modifier checkbox + class** — `~/claude-config/memory/drupal/exo-alchemist-modifier-checkbox.md`  
  Try built-in `modifier_globals.status` flag first (instance-level, auto class); custom YAML modifier + PascalCase handler only when built-in doesn't fit
- **Exo slider mobile overflow** — `~/claude-config/memory/drupal/exo-alchemist-slider-mobile-overflow.md`  
  Slider component overflows on mobile only? Flex `min-width: auto` + Swiper's intrinsic-width markup; fix with `min-width: 0` on `.exo-component`
- **Vimeo background=1 embed param** — `~/claude-config/memory/drupal/vimeo-background-param.md`  
  `background=1` can 403 player URL looking like privacy issue; replace with explicit autoplay/controls/loop/muted/autopause/playsinline params
- **LiveChat widget click-trap** — `~/claude-config/memory/drupal/livechat-click-trap.md`  
  third-party rules (e.g. ConvertCart's `cc-ftr-menu`) force `#chat-widget-container`'s height beyond its bubble, the empty area then traps clicks; presents as "menu broken in normal Chrome/Edge, fine in private/Safari"; fix with higher-specificity CSS or JS observer

## Augustash internal modules

- **Augustash repositories** — `~/claude-config/memory/augustash/repositories.md`  
  GitHub orgs (augustash, jacerider) to check before building from scratch
- **drupal_cache_protection** — `~/claude-config/memory/augustash/drupal_cache_protection.md`  
  Tracking param middleware; facets submodule for bot protection; suggest when paid ads or drupal/facets present

## WordPress

- **WooCommerce Pantheon cache** — `~/claude-config/memory/wordpress/woocommerce-pantheon-cache.md`  
  ash-woocommerce-cookies plugin for Varnish cache-busting fix
