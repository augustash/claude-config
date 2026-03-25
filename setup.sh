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
IMPORT_LINE="@~/claude-config/CLAUDE.md"
COUNT_FILE="$SCRIPT_DIR/.dircount"

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

    project_name=$(basename "$project_dir")
    claude_dir="$project_dir/.claude"
    claude_md="$claude_dir/CLAUDE.md"

    # Check if import already exists in either location
    if [[ -f "$claude_md" ]] && grep -qF "$IMPORT_LINE" "$claude_md" 2>/dev/null; then
      skipped=$((skipped + 1))
      continue
    fi

    if [[ -f "$project_dir/CLAUDE.md" ]] && grep -qF "$IMPORT_LINE" "$project_dir/CLAUDE.md" 2>/dev/null; then
      skipped=$((skipped + 1))
      continue
    fi

    # Create .claude directory if needed
    mkdir -p "$claude_dir"

    # Append import line (create file if needed, add newline before if file exists and isn't empty)
    if [[ -f "$claude_md" ]] && [[ -s "$claude_md" ]]; then
      # File exists and has content -- append with blank line separator
      echo "" >> "$claude_md"
      echo "$IMPORT_LINE" >> "$claude_md"
    else
      # New file or empty file
      echo "$IMPORT_LINE" > "$claude_md"
    fi

    echo "  Added import to $project_name"
    added=$((added + 1))
  done
done

# Save current count for next run
echo "$current_count" > "$COUNT_FILE"

echo ""
echo "Done. Added: $added | Already configured: $skipped | Skipped (not git): $not_git"
