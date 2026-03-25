# Claude Config

Shared Claude Code conventions for August Ash projects.

## Install

```bash
git clone git@github.com:augustash/claude-config.git ~/claude-config && ~/claude-config/install.sh
```

That's it. It will ask for your projects directory, wire up all existing projects, and install a background watcher that automatically configures new projects going forward.

## What it does

- Adds a shared `@import` to each project's `.claude/CLAUDE.md`
- A launchd agent watches your projects directory and auto-configures new ones
- Shared conventions live in `memory/preferences/`

## What's included

- **Memory structure** — How we organize project knowledge using `idea/specific.md` directories
- **DDEV workflow** — Always use `ddev drush` / `ddev wp` for CLI commands

## Per-project memories

Each project stores its own context at `.claude/memory/` in the project repo. These are committed and shared with the team. See [memory structure](memory/preferences/memory-structure.md) for conventions.

## Reconfigure

Run `~/claude-config/install.sh` again to change your projects directory.
