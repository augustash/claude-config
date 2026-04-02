# August Ash — Shared Claude Config

Team-wide conventions and preferences for Claude Code.

## Memory

Two shared memory tiers, both committed to git so the whole team benefits. **Both are writable — save directly to these locations.** Prefer these over Claude's local auto-memory (`~/.claude/projects/`) for any knowledge worth sharing.

### Global — `~/claude-config/memory/`

Knowledge that transcends any single project. Augustash internal modules and reusable code, cross-project debugging approaches, team tooling conventions, shared patterns.

Organize as `{topic}/{specific}.md` — see [memory structure](memory/preferences/memory-structure.md).

**After any changes to `~/claude-config/` (memory writes, audit cleanup, etc.), pull, commit, and push.** If a pull produces merge conflicts, synthesize — read both versions, understand what each learned, and write the best possible version. That might be one side, a merge of both, or something better that neither had alone.

### Per-project — `.claude/memory/` in the project repo

Knowledge specific to this codebase — integration details, architectural decisions, non-obvious configuration.

**Personal projects:** If `.claude/.personal` exists, the project is personal (not augustash). Memories stay project-local — never promote to global. The marker is set during install.

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

**Passive:** When saving or encountering memories during normal work, keep them concise and focused. If a memory is verbose, outdated, or now obvious from the code, tidy or remove it on the spot. Claude normalizes quality — regardless of how information was communicated, memories should be clean and direct.

**Active audit:** Weekly on Fridays. See [memory audit process](memory/preferences/memory-audit.md). Check `~/claude-config/.settings.json` for per-dev preferences (this file is gitignored — local to each developer).

### Current global memories

- [Memory structure](memory/preferences/memory-structure.md) — idea/specific.md pattern, organization conventions
- [DDEV workflow](memory/preferences/ddev-workflow.md) — Always use ddev for CLI commands
- [Drupal caching](memory/drupal/caching.md) — Cache debugging, session poisoning, lazy builders without BigPipe, Exo component cache
- [Drupal PHPUnit testing](memory/drupal/phpunit-testing.md) — Setup and running PHPUnit kernel/unit tests in DDEV
- [Augustash repositories](memory/augustash/repositories.md) — GitHub orgs (augustash, jacerider) to check before building from scratch
- [Memory audit process](memory/preferences/memory-audit.md) — Weekly Friday audit, per-dev settings, self-refining
- [WooCommerce Pantheon cache](memory/wordpress/woocommerce-pantheon-cache.md) — ash-woocommerce-cookies plugin for Varnish cache-busting fix
