#!/bin/bash
#
# Sets up Claude Code shared config for all projects.
#
# Usage:
#   ~/claude-config/setup.sh                    # scans ~/Projects/
#   ~/claude-config/setup.sh ~/Work ~/Clients   # scans specific directories
#
# What it does:
#   - Ensures each project's CLAUDE.md imports the shared config
#   - Only modifies projects that have a .git directory
#   - Non-destructive: won't overwrite existing content
#   - Idempotent: safe to re-run
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

COUNT_FILE="$SCRIPT_DIR/.dircount"

# Regenerate the global AGENTS.md from CLAUDE.md. Idempotent: skips the write
# when content is unchanged, so this is cheap to call on every setup pass.
# Runs before the dircount early-exit so memory changes to CLAUDE.md flow
# through even when no projects were added/removed.
if [[ -x "$SCRIPT_DIR/generate-agents.py" ]]; then
  "$SCRIPT_DIR/generate-agents.py" >/dev/null || \
    echo "Warning: generate-agents.py failed; continuing." >&2
fi

# Directories to scan for projects (default: ~/Projects)
if [[ $# -gt 0 ]]; then
  SCAN_DIRS=("$@")
else
  SCAN_DIRS=("$HOME/Projects")
fi

# Quick check: if directory count hasn't changed, nothing to do
current_count=0
for scan_dir in "${SCAN_DIRS[@]}"; do
  scan_dir="${scan_dir/#\~/$HOME}"
  [[ -d "$scan_dir" ]] && current_count=$((current_count + $(ls -1d "$scan_dir"/*/ 2>/dev/null | wc -l)))
done

if [[ -f "$COUNT_FILE" ]] && [[ "$(cat "$COUNT_FILE")" == "$current_count" ]]; then
  exit 0
fi

# Skip the claude-config repo itself
SELF_DIR="$(cd "$SCRIPT_DIR" && pwd)"

added=0
skipped=0
not_git=0
personal=0
pruned=0
non_site=0

for scan_dir in "${SCAN_DIRS[@]}"; do
  scan_dir="${scan_dir/#\~/$HOME}"

  if [[ ! -d "$scan_dir" ]]; then
    echo "Warning: $scan_dir does not exist, skipping."
    continue
  fi

  for project_dir in "$scan_dir"/*/; do
    [[ ! -d "$project_dir" ]] && continue

    # Resolve to absolute path
    project_dir="$(cd "$project_dir" && pwd)"

    # Skip self
    [[ "$project_dir" == "$SELF_DIR" ]] && continue

    # Only process git repos
    if [[ ! -d "$project_dir/.git" ]]; then
      not_git=$((not_git + 1))
      continue
    fi

    # Personal projects: skip and prune any stale import line.
    if [[ -f "$project_dir/.claude/.personal" ]]; then
      personal=$((personal + 1))
      project_name=$(basename "$project_dir")
      for candidate in "$project_dir/.claude/CLAUDE.md" "$project_dir/CLAUDE.md"; do
        if prune_import "$candidate" "$CLAUDE_IMPORT_LINE"; then
          echo "  Pruned CLAUDE.md import from $project_name"
          pruned=$((pruned + 1))
        fi
      done
      if prune_import "$project_dir/AGENTS.md" "$AGENTS_IMPORT_LINE"; then
        echo "  Pruned AGENTS.md pointer from $project_name"
        pruned=$((pruned + 1))
      fi
      continue
    fi

    # Only apply to actual sites. Modules, themes, libraries, tools don't
    # belong in shared claude-config territory.
    if is_module_type "$(composer_type "$project_dir/composer.json")" \
       || ! is_site "$project_dir"; then
      non_site=$((non_site + 1))
      continue
    fi

    project_name=$(basename "$project_dir")
    claude_md="$project_dir/.claude/CLAUDE.md"
    did_something=0

    # CLAUDE.md import lives at .claude/CLAUDE.md, but a legacy root-level
    # CLAUDE.md with the import also counts as already-configured — skip
    # adding in that case rather than writing a second copy.
    if [[ -f "$project_dir/CLAUDE.md" ]] && grep -qF "$CLAUDE_IMPORT_LINE" "$project_dir/CLAUDE.md" 2>/dev/null; then
      :
    elif add_import "$claude_md" "$CLAUDE_IMPORT_LINE"; then
      echo "  Added CLAUDE.md import to $project_name"
      did_something=1
    fi

    # AGENTS.md pointer: repo-root convention honored by Cursor/Codex/Aider/etc.
    # Small reference line — real content lives at ~/claude-config/AGENTS.md
    # so other tools read one source of truth rather than a local copy.
    if add_import "$project_dir/AGENTS.md" "$AGENTS_IMPORT_LINE"; then
      echo "  Added AGENTS.md pointer to $project_name"
      did_something=1
    fi

    if (( did_something )); then
      added=$((added + 1))
    else
      skipped=$((skipped + 1))
    fi
  done
done

# Save current count for next run
echo "$current_count" > "$COUNT_FILE"

echo ""
echo "Done. Added: $added | Pruned: $pruned | Already configured: $skipped | Skipped (not git): $not_git | Skipped (non-site): $non_site | Skipped (personal): $personal"
