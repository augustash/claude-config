# Claude Config

Shared AI assistant conventions and memory for August Ash projects, distributed as a composer package.

Designed for agentic / CLI-style AI tools (Claude Code, Cursor, Codex, Aider, Windsurf, Zed) that read `AGENTS.md` and can follow pointers into a vendor directory. Not yet supported: GitHub Copilot and JetBrains AI Assistant — they're workspace-scoped and expect self-contained instructions files (`.github/copilot-instructions.md` etc.). We'll address it if/when it becomes a blocker.

## Install

In the project:

```bash
ddev composer config preferred-install.augustash/claude-config source && ddev composer require --dev 'augustash/claude-config:dev-master'
```

The first half writes a per-project preference into the project's `composer.json` so composer installs this package via `git clone` instead of zip extract. The vendor copy is then a real git working tree you can author memory in directly. The second half pulls the package as a dev dependency and triggers the plugin, which:

- Adds `@../vendor/augustash/claude-config/CLAUDE.md` to the project's `.claude/CLAUDE.md` (the `../` matters — Claude Code resolves `@` imports relative to the importing file's directory, so a bare `@vendor/...` would look for the non-existent `.claude/vendor/...`)
- Adds an `AGENTS.md` pointer to `vendor/augustash/claude-config/AGENTS.md`
- Prunes any legacy `~/claude-config/` references left behind by the previous global-clone setup, and migrates the superseded bare `@vendor/...` import to the `../vendor/...` form
- Prints a notice if the package was installed via dist (no `.git/`) and tells you how to switch to source

The `dev-master` constraint tracks the `master` branch HEAD rather than a tagged release — this package isn't tagged. Updates flow via `ddev composer update augustash/claude-config`, and the vendor copy stays on the `master` branch so memory authored in `vendor/augustash/claude-config/memory/` can be committed and pushed directly without first checking out a branch. This avoids forcing a tag-and-release cycle just to share memory updates — push to `master`, other projects pull on their next `ddev composer update`.

## Remove

```bash
ddev composer remove augustash/claude-config
```

The plugin prunes its import lines from `.claude/CLAUDE.md` and `AGENTS.md` before the package is uninstalled. Composer cleans up `vendor/augustash/claude-config/` on its own.

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
launchctl bootout gui/$(id -u)/com.augustash.claude-config 2>/dev/null; rm -f ~/Library/LaunchAgents/com.augustash.claude-config.plist; rm -rf ~/claude-config
```

In each project, `ddev composer require augustash/claude-config` will auto-prune the old `~/claude-config/` references on first install.

## Tests

```bash
ddev composer install
ddev composer test
```

PHPUnit covers the plugin's add/prune behavior and the wire/prune flows on a temp project root.
