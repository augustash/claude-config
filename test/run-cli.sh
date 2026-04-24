#!/bin/bash
#
# Test harness for bin/claude-config.
# Reuses the setup.sh fixture tree, then exercises `claude-config add` and
# `claude-config remove` against representative scenarios and asserts the
# resulting marker/file state.
#
# Usage:
#   test/run-cli.sh            # run once, exit non-zero on failure
#   test/run-cli.sh --keep     # leave workdir in place for inspection
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKDIR="$SCRIPT_DIR/workdir-cli"
PROJECTS_DIR="$WORKDIR/projects"
CLI="$REPO_DIR/bin/claude-config"

KEEP=0
[[ "${1:-}" == "--keep" ]] && KEEP=1

source "$SCRIPT_DIR/assert.sh"
source "$SCRIPT_DIR/fixtures.sh"

echo "Building fixture at $PROJECTS_DIR"
build_fixture "$PROJECTS_DIR"

run_cli() {
  # Absolute path bypasses .config, so tests don't depend on the installed
  # config of whoever's running them.
  "$CLI" "$@"
}

echo ""
echo "Running CLI add/remove against fixture..."
echo "----"

# --- ADD scenarios ---

# 1. Clean augustash site — imports appear, no markers touched.
run_cli add "$PROJECTS_DIR/augustash-plain" >/dev/null

# 2. Non-site dir (just-a-tool) — add bypasses the is_site skip.
run_cli add "$PROJECTS_DIR/just-a-tool" >/dev/null

# 3. Personal project — .personal marker cleared, imports written.
run_cli add "$PROJECTS_DIR/personal-clean" >/dev/null

# 4. Not a git repo — add still works (no git gating on explicit invocation).
run_cli add "$PROJECTS_DIR/not-a-repo" >/dev/null

# 5. Already wired project — idempotent, no changes.
run_cli add "$PROJECTS_DIR/augustash-existing-import" >/dev/null

# --- REMOVE scenarios ---

# 6. Remove from a wired augustash site — both files pruned, .personal set.
run_cli remove "$PROJECTS_DIR/augustash-existing-import" >/dev/null

# 7. Remove from mixed-content project — only import/pointer lines go; the
#    rest of each file is preserved. .personal is set.
run_cli remove "$PROJECTS_DIR/augustash-mixed-content" >/dev/null

# 8. Remove from a not-yet-wired project — still marks .personal so the
#    watcher won't add it going forward.
run_cli remove "$PROJECTS_DIR/lib-thing" >/dev/null

echo "----"
echo ""
echo "Assertions:"

# 1. augustash-plain add → both files, no .personal created.
assert_file_equals "$PROJECTS_DIR/augustash-plain/.claude/CLAUDE.md" \
  "$CLAUDE_IMPORT_LINE" \
  "add augustash-plain: CLAUDE.md is the import line"
assert_file_equals "$PROJECTS_DIR/augustash-plain/AGENTS.md" \
  "$AGENTS_IMPORT_LINE" \
  "add augustash-plain: AGENTS.md is the pointer line"
assert_file_missing "$PROJECTS_DIR/augustash-plain/.claude/.personal" \
  "add augustash-plain: no .personal marker"

# 2. just-a-tool add → imports written despite non-site classification.
assert_file_equals "$PROJECTS_DIR/just-a-tool/.claude/CLAUDE.md" \
  "$CLAUDE_IMPORT_LINE" \
  "add just-a-tool: import written (bypasses non-site skip)"
assert_file_equals "$PROJECTS_DIR/just-a-tool/AGENTS.md" \
  "$AGENTS_IMPORT_LINE" \
  "add just-a-tool: pointer written (bypasses non-site skip)"

# 3. personal-clean add → .personal cleared, imports written.
assert_file_missing "$PROJECTS_DIR/personal-clean/.claude/.personal" \
  "add personal-clean: .personal marker cleared"
assert_file_equals "$PROJECTS_DIR/personal-clean/.claude/CLAUDE.md" \
  "$CLAUDE_IMPORT_LINE" \
  "add personal-clean: import written"
assert_file_equals "$PROJECTS_DIR/personal-clean/AGENTS.md" \
  "$AGENTS_IMPORT_LINE" \
  "add personal-clean: pointer written"

# 4. not-a-repo add → imports written even without .git.
assert_file_equals "$PROJECTS_DIR/not-a-repo/.claude/CLAUDE.md" \
  "$CLAUDE_IMPORT_LINE" \
  "add not-a-repo: import written without git"
assert_file_equals "$PROJECTS_DIR/not-a-repo/AGENTS.md" \
  "$AGENTS_IMPORT_LINE" \
  "add not-a-repo: pointer written without git"

# 5. augustash-existing-import add (then later remove) — during add pass it
#    stayed as a single import line (idempotent). We assert post-remove below.

# 6. augustash-existing-import remove → files pruned, .personal present.
assert_file_missing "$PROJECTS_DIR/augustash-existing-import/.claude/CLAUDE.md" \
  "remove augustash-existing-import: import-only CLAUDE.md removed"
assert_file_missing "$PROJECTS_DIR/augustash-existing-import/AGENTS.md" \
  "remove augustash-existing-import: pointer-only AGENTS.md removed"
assert_file_exists "$PROJECTS_DIR/augustash-existing-import/.claude/.personal" \
  "remove augustash-existing-import: .personal marker set"

# 7. augustash-mixed-content remove → lines pruned, other content preserved.
assert_file_exists "$PROJECTS_DIR/augustash-mixed-content/.claude/CLAUDE.md" \
  "remove augustash-mixed-content: CLAUDE.md retained"
assert_file_contains "$PROJECTS_DIR/augustash-mixed-content/.claude/CLAUDE.md" \
  "Project-specific notes." \
  "remove augustash-mixed-content: user content preserved"
assert_file_not_contains "$PROJECTS_DIR/augustash-mixed-content/.claude/CLAUDE.md" \
  "$CLAUDE_IMPORT_LINE" \
  "remove augustash-mixed-content: import line pruned"
assert_file_contains "$PROJECTS_DIR/augustash-mixed-content/AGENTS.md" \
  "Project-specific agent notes." \
  "remove augustash-mixed-content: AGENTS.md content preserved"
assert_file_not_contains "$PROJECTS_DIR/augustash-mixed-content/AGENTS.md" \
  "$AGENTS_IMPORT_LINE" \
  "remove augustash-mixed-content: pointer line pruned"
assert_file_exists "$PROJECTS_DIR/augustash-mixed-content/.claude/.personal" \
  "remove augustash-mixed-content: .personal marker set"

# 8. lib-thing remove → no imports existed; .personal still written so the
#    watcher leaves it alone going forward.
assert_file_exists "$PROJECTS_DIR/lib-thing/.claude/.personal" \
  "remove lib-thing: .personal marker set on unwired project"

echo ""
echo "Result: ${ASSERT_PASS} passed, ${ASSERT_FAIL} failed"

if [[ $KEEP -eq 0 ]]; then
  rm -rf "$WORKDIR"
else
  echo "Workdir kept at: $WORKDIR"
fi

[[ $ASSERT_FAIL -eq 0 ]]
