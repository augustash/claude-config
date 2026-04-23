---
name: install/setup internals
description: Non-obvious wiring behind install.sh, setup.sh, and utils.sh — pitfalls and design decisions a fresh session would re-hit otherwise.
type: project
---

# install.sh / setup.sh / utils.sh internals

## Shell compatibility

`#!/bin/bash` resolves to **macOS bash 3.2**. Consequences:

- **No associative arrays** (`declare -A` errors). Store sets as space-separated strings and match with `case " $set " in *" $key "*)` pattern.
- **`set -eo pipefail` + `grep` returning 1** (no match) kills the script silently. Every grep pipeline in user code needs `|| true` at the end, or the whole pipeline wrapped. This bit us repeatedly — a project with no `.ddev/config.yaml` had an empty grep result which aborted install.sh on the first iteration, hundreds of projects in.
- `[[ cond ]] && cmd` does NOT trigger `set -e` when `cond` is false, despite common belief. But `[[ cond ]] || [[ cond2 ]] && cmd && return` chains are genuinely ambiguous — prefer explicit `if … then … fi`.

## Classification model

install.sh sorts every project in `$PROJECTS_DIR` into five buckets:

1. **Module / library / theme** — composer.json `"type"` is in `is_module_type`. Skipped entirely; no `.claude/` created.
2. **Non-site** — no ddev config, no wp-config, no Drupal/Magento entry points, no Pantheon codeserver remote, no `"type": "project"` composer. Skipped.
3. **Auto-personal** — non-augustash github origin, or composer name namespace matches a personal org discovered in the pre-scan. Gets `.claude/.personal` marker.
4. **Auto-augustash** — aai Pantheon site, augustash github origin, augustash production composer dep (non-`ddev-*`), or Pantheon codeserver remote (fallback). No marker; gets the import.
5. **Unknown** — non-github non-Pantheon remote (e.g. drupal.org clone). User picks in fzf.

The pantheon codeserver → augustash fallback is intentional: the user has hundreds of Pantheon-hosted augustash sites vs ≈3 personal Pantheon sites, and the personal ones are distinguishable by composer name namespace. If that assumption ever breaks (a dev with mostly personal Pantheon sites), the classifier degrades — they'd need to mark personals in fzf.

## Why two passes in install.sh

**Pass 1** walks every origin to collect "personal github orgs" (any github origin that isn't `augustash`). This set is then used in **pass 2** to identify personal Pantheon sites whose codeserver remote hides ownership but whose composer `"name"` namespace matches a personal org. Can't be done in one pass because alphabetic iteration processes Pantheon projects before the github-origin projects that reveal the personal org names.

## Marker semantics

- `.claude/.personal` — user declared this personal; do not apply shared claude-config.
- `.claude/.opt-in` — personal but wants shared config anyway. Overrides the personal-skip in setup.sh.

setup.sh's behavior per marker combination:

| `.personal` | `.opt-in` | Action |
|---|---|---|
| absent | — | Apply import if site, skip if non-site |
| present | absent | Skip, and prune any stale import |
| present | present | Apply import (opt-in wins) |

## Clean-slate sweep

Every install run wipes `.personal`, `.opt-in`, and any existing import line from every project before reclassifying. This makes install idempotent and corrects drift — but it temporarily pollutes git diffs in ~150 project repos. setup.sh re-adds imports immediately after, so net content doesn't change for projects that stayed in the same bucket. Projects that *changed* bucket see a real diff.

`install.sh` deletes `.dircount` before invoking setup.sh so the full sweep runs (setup.sh normally short-circuits when the project count is unchanged).

## Testing

`test/run.sh` covers setup.sh only — builds a fixture tree under `test/workdir/` (gitignored), runs setup.sh, asserts outcomes. Uses composer.json with `"type": "project"` to flag fixtures as sites.

**install.sh is not automated** because `multi_select` uses fzf, which requires a real TTY; piping input doesn't work cleanly. The interactive flow is manually smoke-tested. setup.sh is where the actual file mutations happen, so the value of testing it is high; install.sh is mostly classification + prompts.

The fzf post-selection confirmation exists because `fzf --multi` returns the highlighted line when you hit Enter without Tab-selecting anything — so an accidental Enter silently marks whatever was at the top of the list. The extra "Confirm? (Y/n)" lets the user bail.

## utils.sh helpers worth knowing

- `prune_import` — removes a specific line from a CLAUDE.md, deletes the file if only that line remained, and strips trailing blank lines. Pure bash read loop (no grep+awk pipeline) for small-file speed and no pipefail surface.
- `composer_type` / `is_module_type` — top-level `"type"` extraction from composer.json via bash regex on `$(< file)`. First-occurrence match is good enough for well-formed composer.json.
- `is_site` / `is_augustash` / `is_personal_origin` / `is_personal_composer` — classification predicates. All accept an optional pre-fetched `$origin` to avoid redundant `git remote` calls across the two passes.
