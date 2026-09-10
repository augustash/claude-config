# Claude Config

Shared AI assistant conventions and memory for August Ash projects, distributed as a composer package.

Designed for agentic / CLI-style AI tools (Claude Code, Cursor, Codex, Aider, Windsurf, Zed) that read `AGENTS.md` and can follow pointers into a vendor directory. Not yet supported: GitHub Copilot and JetBrains AI Assistant — they're workspace-scoped and expect self-contained instructions files (`.github/copilot-instructions.md` etc.). We'll address it if/when it becomes a blocker.

## Install

In the project:

```bash
ddev composer config allow-plugins.augustash/claude-config true && ddev composer config preferred-install.augustash/claude-config source && ddev composer require --dev 'augustash/claude-config:dev-master'
```

The first command whitelists this package's composer plugin in the project's `composer.json`. This package is a `composer-plugin` (it wires up the CLAUDE.md/AGENTS.md pointers), and composer's `allow-plugins` gate blocks any plugin not on the list — so on a project whose `allow-plugins` doesn't already include it, the require aborts with a `PluginManager` error until this is set. The second command writes a per-project preference so composer installs this package via `git clone` instead of zip extract. The vendor copy is then a real git working tree you can author memory in directly. The third pulls the package as a dev dependency and triggers the plugin, which:

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

## Skills

A **skill** is a procedure Claude loads on demand — a multi-step job with its own method, traps
and deliverable. Distinct from memory, which is knowledge to recall.

Claude Code only discovers skills in the project's `.claude/skills/`, so a skill in this package
is not live until it's copied in:

```bash
cp -R vendor/augustash/claude-config/skills/content-audit .claude/skills/
```

Commit that copy with the project. Adoption is manual, but staying current is not — the composer
plugin refreshes every already-adopted copy on each `ddev composer update augustash/claude-config`
and leaves the ones you never adopted alone, so a WordPress project doesn't inherit the Drupal
upgrade skill. The package copy is canonical: a local edit to a project copy gets overwritten, so
refine it here instead. `memory-management` is the exception — the plugin seeds it everywhere.

Because adoption is per-project and nothing back-fills it, a skill is present wherever someone
once ran that `cp` and absent everywhere else. If `/<name>` comes back `Unknown skill`, that's why
— the procedure is still on disk at `vendor/augustash/claude-config/skills/<name>/` and can be
read directly.

- **accessibility-audit** — Test a site's accessibility and produce a defensible record of what was found: an ADA demand letter, a compliance question, a pre-launch check, or a VPAT/remediation scope.
- **client-proposal-review** — A client hands over a set of decisions (a menu, a design round, a feature list) and some of it would make the site worse. Steers them off the bad parts without losing the good, as a short self-contained HTML document.
- **client-report** — An evidence-led client report or rebuild pitch: gather real data, frame it so it sells without overclaiming, ship it as a branded HTML page.
- **content-audit** — Decide what a legacy CMS's content is actually worth migrating: keep/move/consolidate/eliminate per node, find pages that say the same thing in different words, restructure the survivors into the new IA.
- **content-migration-to-components** — Turn the content that survived into a component tree: work out what shape it really is, choose reuse/extend/build-new, re-type legacy markup as data, verify the built page.
- **drupal-11-upgrade** — A D10 → D11 upgrade on Pantheon, from composer constraints to multidev verification. Built around the platform gates and the failure modes that report success.
- **firefox-devtools** — Drive a real Firefox from Claude: console, network, DOM, screenshots, logpoints and profiling on a running site. Needs one-time setup — see below.
- **log-audit** — Establish what actually happened on the wire, through nginx/php-fpm/New Relic logs. Incident-driven (an integration broke, you need a third party's egress IP, you must pin a change to a deploy) or as a recurring health-and-security sweep.
- **memory-management** — Writing, curating or auditing a memory: whether it qualifies, which tier, whether it's really a skill, how to word the index entry, and the commit/push steps that finish the write.
- **site-update** — A routine dependency round on a Drupal or WordPress site, starting at the Pantheon upstream that no package manager will bring you. Owns patch triage for every Drupal skill.

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
