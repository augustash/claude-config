# Claude Config

Shared AI assistant conventions and memory for August Ash projects, distributed as a composer package.

Designed for agentic / CLI-style AI tools (Claude Code, Cursor, Codex, Aider, Windsurf, Zed) that read `AGENTS.md` and can follow pointers into a vendor directory. Not yet supported: GitHub Copilot and JetBrains AI Assistant — they're workspace-scoped and expect self-contained instructions files (`.github/copilot-instructions.md` etc.). We'll address it if/when it becomes a blocker.

## Install

In any augustash project:

```bash
composer require augustash/claude-config
```

That's it. A composer plugin wires the project on install:

- Adds `@vendor/augustash/claude-config/CLAUDE.md` to the project's `.claude/CLAUDE.md`
- Adds an `AGENTS.md` pointer to `vendor/augustash/claude-config/AGENTS.md`
- Prunes any legacy `~/claude-config/` references left behind by the previous global-clone setup

## Remove

```bash
composer remove augustash/claude-config
```

The plugin prunes its import lines from `.claude/CLAUDE.md` and `AGENTS.md` before the package is uninstalled. Composer cleans up `vendor/augustash/claude-config/` on its own.

## Authoring shared memory

Memory lives inside this package. To add or update a shared memory:

1. Clone this repo somewhere (it doesn't matter where — it's a composer package, not a global tool anymore).
2. Edit or add files under `memory/{topic}/{specific}.md`.
3. Update the `### Current global memories` index in `CLAUDE.md`.
4. Run `python3 generate-agents.py` so `AGENTS.md` stays in sync.
5. Commit and push.
6. Run `composer update augustash/claude-config` in any project that needs the new content.

**Don't edit files inside a project's `vendor/augustash/claude-config/`** — composer overwrites them.

## Shared conventions

The full index lives in [CLAUDE.md](CLAUDE.md). Examples of what's there:

- DDEV workflow — always `ddev drush` / `ddev wp`, never run CLI tools on the host
- Test tags — every custom PHPUnit/Nightwatch test carries the `aai` umbrella tag plus a module sub-tag
- Follow site conventions — scan how a domain is handled in the codebase before writing in it; surface divergence
- Comment style — concise; skip comments when the code is obvious, explain the WHY when it isn't
- Drupal caching — known pitfalls around session poisoning, lazy builders without BigPipe, and Exo component cache

## Memory organization

Memories follow an `{idea}/{specific}.md` pattern — the directory is the broad topic, the file is the specific detail. Top-level categories:

- `preferences/` — collaboration style, workflow conventions, cross-cutting posture
- `drupal/`, `wordpress/` — platform-specific knowledge
- `augustash/` — internal modules and reusable code

### Shared vs per-project

Two tiers, both committed to git so the whole team benefits:

- **Shared** (`vendor/augustash/claude-config/memory/`) — knowledge that applies across multiple augustash projects. Authored in this repo, distributed via composer.
- **Per-project** (`.claude/memory/` in the project repo) — knowledge specific to one codebase. Examples: that project's payment gateway quirks, a non-obvious cron schedule, why a particular module was patched in place of an upstream fix.

## Migrating from the old global-clone install

If you previously ran the launchd-based installer, after switching:

```bash
# Stop and remove the old launchd watcher
launchctl bootout gui/$(id -u)/com.augustash.claude-config 2>/dev/null || true
rm -f ~/Library/LaunchAgents/com.augustash.claude-config.plist

# Optional: drop the old global clone (no longer used)
rm -rf ~/claude-config
```

In each project, `composer require augustash/claude-config` will auto-prune the old `~/claude-config/` references on first install.

## Tests

```bash
composer install
composer test
```

PHPUnit covers the plugin's add/prune behavior and the wire/prune flows on a temp project root.
