#!/bin/bash
#
# Test harness for setup.sh.
# Builds a fixture tree under test/workdir/projects, runs setup.sh against
# it, then asserts the end-state of each scenario.
#
# Usage:
#   test/run.sh            # run once, exit non-zero on failure
#   test/run.sh --keep     # leave workdir in place for inspection
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKDIR="$SCRIPT_DIR/workdir"
PROJECTS_DIR="$WORKDIR/projects"
IMPORT_LINE="@~/claude-config/CLAUDE.md"

KEEP=0
[[ "${1:-}" == "--keep" ]] && KEEP=1

source "$SCRIPT_DIR/assert.sh"
source "$SCRIPT_DIR/fixtures.sh"

echo "Building fixture at $PROJECTS_DIR"
build_fixture "$PROJECTS_DIR"

# setup.sh uses $SCRIPT_DIR/.dircount for its quick-exit check. Tests must
# always exercise the full loop, so strip it before and after.
DIRCOUNT_FILE="$REPO_DIR/.dircount"
DIRCOUNT_BACKUP=""
if [[ -f "$DIRCOUNT_FILE" ]]; then
  DIRCOUNT_BACKUP=$(mktemp)
  cp "$DIRCOUNT_FILE" "$DIRCOUNT_BACKUP"
fi
rm -f "$DIRCOUNT_FILE"

echo ""
echo "Running setup.sh against fixture..."
echo "----"
"$REPO_DIR/setup.sh" "$PROJECTS_DIR"
echo "----"

# Restore the real .dircount so a subsequent launchd-triggered run is honest.
rm -f "$DIRCOUNT_FILE"
if [[ -n "$DIRCOUNT_BACKUP" ]]; then
  mv "$DIRCOUNT_BACKUP" "$DIRCOUNT_FILE"
fi

echo ""
echo "Assertions:"

# 1. aai project → gets import
assert_file_equals "$PROJECTS_DIR/augustash-aai/.claude/CLAUDE.md" \
  "$IMPORT_LINE" \
  "augustash-aai: .claude/CLAUDE.md is just the import line"

# 2. plain augustash → gets import
assert_file_equals "$PROJECTS_DIR/augustash-plain/.claude/CLAUDE.md" \
  "$IMPORT_LINE" \
  "augustash-plain: .claude/CLAUDE.md is just the import line"

# 3. already-configured → left alone (still contains import, nothing appended)
assert_file_equals "$PROJECTS_DIR/augustash-existing-import/.claude/CLAUDE.md" \
  "$IMPORT_LINE" \
  "augustash-existing-import: file unchanged (single import line)"

# 4. mixed content → existing content preserved, import appended
assert_file_contains "$PROJECTS_DIR/augustash-mixed-content/.claude/CLAUDE.md" \
  "Project-specific notes." \
  "augustash-mixed-content: original content preserved"
assert_file_contains "$PROJECTS_DIR/augustash-mixed-content/.claude/CLAUDE.md" \
  "$IMPORT_LINE" \
  "augustash-mixed-content: import appended"

# 5. personal-clean → skipped, no CLAUDE.md created
assert_file_missing "$PROJECTS_DIR/personal-clean/.claude/CLAUDE.md" \
  "personal-clean: no CLAUDE.md created"
assert_file_exists "$PROJECTS_DIR/personal-clean/.claude/.personal" \
  "personal-clean: .personal marker preserved"

# 6. personal-stale-import → import-only file pruned → deleted
assert_file_missing "$PROJECTS_DIR/personal-stale-import/.claude/CLAUDE.md" \
  "personal-stale-import: stale import-only CLAUDE.md was removed"
assert_file_exists "$PROJECTS_DIR/personal-stale-import/.claude/.personal" \
  "personal-stale-import: .personal marker preserved"

# 7. personal-mixed-stale → import removed, other content preserved
assert_file_exists "$PROJECTS_DIR/personal-mixed-stale/.claude/CLAUDE.md" \
  "personal-mixed-stale: CLAUDE.md retained"
assert_file_contains "$PROJECTS_DIR/personal-mixed-stale/.claude/CLAUDE.md" \
  "Personal notes." \
  "personal-mixed-stale: user content preserved"
assert_file_not_contains "$PROJECTS_DIR/personal-mixed-stale/.claude/CLAUDE.md" \
  "$IMPORT_LINE" \
  "personal-mixed-stale: import line pruned"

# 8. personal + opt-in, no existing file → treated like augustash
assert_file_equals "$PROJECTS_DIR/personal-optin-clean/.claude/CLAUDE.md" \
  "$IMPORT_LINE" \
  "personal-optin-clean: import added despite .personal (opt-in honored)"

# 9. personal + opt-in + existing import → left alone
assert_file_equals "$PROJECTS_DIR/personal-optin-existing/.claude/CLAUDE.md" \
  "$IMPORT_LINE" \
  "personal-optin-existing: file unchanged"

# 10. not-a-repo → nothing created
assert_file_missing "$PROJECTS_DIR/not-a-repo/.claude/CLAUDE.md" \
  "not-a-repo: no CLAUDE.md created"
assert_file_missing "$PROJECTS_DIR/not-a-repo/.claude" \
  "not-a-repo: no .claude dir created"

# 11. drupal-module → skipped, no .claude dir created
assert_file_missing "$PROJECTS_DIR/drupal-module-thing/.claude" \
  "drupal-module-thing: no .claude dir created"

# 12. library → skipped
assert_file_missing "$PROJECTS_DIR/lib-thing/.claude" \
  "lib-thing: no .claude dir created"

# 13. non-site tool dir → skipped
assert_file_missing "$PROJECTS_DIR/just-a-tool/.claude" \
  "just-a-tool: no .claude dir created"

echo ""
echo "Result: ${ASSERT_PASS} passed, ${ASSERT_FAIL} failed"

if [[ $KEEP -eq 0 ]]; then
  rm -rf "$WORKDIR"
else
  echo "Workdir kept at: $WORKDIR"
fi

[[ $ASSERT_FAIL -eq 0 ]]
