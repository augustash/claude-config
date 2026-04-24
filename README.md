# Claude Config

Built and designed around Claude, but contains shared ai conventions.

Intent of shared context and conventions for August Ash projects.

## Install

```bash
git clone git@github.com:augustash/claude-config.git ~/claude-config && ~/claude-config/install.sh
```

Install will ask for your projects directory, wire up existing projects, and add a launchd watcher that auto-configures new ones going forward.

## What it does

- Adds a shared `@import` to each project's `.claude/CLAUDE.md`
- Adds an `AGENTS.md` pointer so Cursor, Codex, Aider, and other `AGENTS.md`-aware tools get the same context
- Classifies projects before wiring — non-site repos, modules, and anything marked personal are skipped
- A launchd watcher sweeps the projects directory and keeps new projects in sync

### Scope

Designed for agentic / CLI-style AI tools (Claude Code, Cursor, Codex, Aider, Windsurf, Zed) that read `AGENTS.md` and can follow pointers into `~/claude-config/`. **Not yet supported:** GitHub Copilot and JetBrains AI Assistant — they're workspace-scoped and expect self-contained instructions files (`.github/copilot-instructions.md` etc.). We'll address it if/when it becomes a blocker.

## Managing projects

The watcher handles the common case. To override, use the CLI:

```bash
~/claude-config/bin/claude-config add <project>
~/claude-config/bin/claude-config remove <project>
```

Tracking inside `<project>/.claude/`:

- `.personal` — project is personal, not augustash. Watcher skips it and memories stay project-local (never promoted to global). `remove` sets this; `add` clears it.

## Shared conventions

The full index lives in [CLAUDE.md](CLAUDE.md). A few examples of what's in there:

- **DDEV workflow** — always `ddev drush` / `ddev wp`, never run CLI tools on the host
- **Test tags** — every custom PHPUnit/Nightwatch test carries the `aai` umbrella tag plus a module sub-tag, so the team can run slices cleanly
- **Follow site conventions** — scan how a domain is handled in the codebase before writing in it; surface divergence from established patterns
- **Comment style** — keep it concise; skip comments when the code is obvious, explain the WHY when it isn't
- **Drupal caching** — known pitfalls around session poisoning, lazy builders without BigPipe, and Exo component cache

## Memory organization

Memories follow an `{idea}/{specific}.md` pattern — the directory is the broad topic, the file is the specific detail. Top-level categories in this repo:

- `preferences/` — collaboration style, workflow conventions, cross-cutting posture
- `drupal/`, `wordpress/` — platform-specific knowledge
- `augustash/` — internal modules and reusable code

### Global vs per-project

Two tiers, both committed to git so the whole team benefits:

- **Global** (`~/claude-config/memory/`) — knowledge that applies across multiple augustash projects. Examples: how DDEV is used everywhere, the `aai` test tag convention, the Varnish cache-busting plugin for WooCommerce Pantheon, internal modules like `drupal_cache_protection`.
- **Per-project** (`.claude/memory/` in the project repo) — knowledge specific to one codebase. Examples: this project's payment gateway quirks, a non-obvious cron schedule, why a particular module was patched in place of an upstream fix.

## Reconfigure

Run `~/claude-config/install.sh` again to change your projects directory.
