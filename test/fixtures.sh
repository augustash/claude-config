#!/bin/bash
#
# Build a reusable fixture tree for exercising setup.sh.
# Each subdirectory represents a scenario the script should handle.
# Call: build_fixture <target_dir>
#

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/utils.sh"

# Turn a directory into a minimal git repo from setup.sh's perspective.
# setup.sh only checks for .git/ existence, so an empty dir is enough.
_fake_git() {
  mkdir -p "$1/.git"
}

# Create a .ddev/config.yaml with a specific PANTHEON_SITE value.
# Presence of .ddev/config.yaml also satisfies the is_site check.
_fake_ddev_pantheon_site() {
  local dir="$1" site="$2"
  mkdir -p "$dir/.ddev"
  cat > "$dir/.ddev/config.yaml" <<YAML
web_environment:
  - PANTHEON_SITE=$site
YAML
}

# Drop a minimal composer.json declaring a given type. Use "project" to
# satisfy is_site; anything else (e.g. drupal-module) triggers the skip path.
_fake_composer() {
  local dir="$1" type="$2"
  cat > "$dir/composer.json" <<JSON
{
  "name": "fixture/$(basename "$dir")",
  "type": "$type"
}
JSON
}

build_fixture() {
  local root="$1"
  rm -rf "$root"
  mkdir -p "$root"

  # 1. aai-prefix augustash project, no existing config.
  #    setup.sh should add the import to .claude/CLAUDE.md.
  local d="$root/augustash-aai"
  _fake_git "$d"
  _fake_ddev_pantheon_site "$d" "aai-example"

  # 2. Plain augustash site: composer type=project → is_site true.
  #    setup.sh should add the import.
  d="$root/augustash-plain"
  _fake_git "$d"
  _fake_composer "$d" "project"

  # 3. Augustash site where both import and pointer are already present.
  #    setup.sh should leave both alone (already-configured skip).
  d="$root/augustash-existing-import"
  _fake_git "$d"
  _fake_composer "$d" "project"
  mkdir -p "$d/.claude"
  echo "$CLAUDE_IMPORT_LINE" > "$d/.claude/CLAUDE.md"
  echo "$AGENTS_IMPORT_LINE" > "$d/AGENTS.md"

  # 4. Augustash site with unrelated existing content in both files.
  #    setup.sh should append the import/pointer with a blank-line separator.
  d="$root/augustash-mixed-content"
  _fake_git "$d"
  _fake_composer "$d" "project"
  mkdir -p "$d/.claude"
  printf 'Project-specific notes.\n' > "$d/.claude/CLAUDE.md"
  printf 'Project-specific agent notes.\n' > "$d/AGENTS.md"

  # 5. Personal site, no import present.
  #    setup.sh should skip it (personal counter++, no file created).
  d="$root/personal-clean"
  _fake_git "$d"
  _fake_composer "$d" "project"
  mkdir -p "$d/.claude"
  touch "$d/.claude/.personal"

  # 6. Personal site with stale pointer-only CLAUDE.md AND AGENTS.md.
  #    setup.sh should prune both → both files deleted entirely.
  d="$root/personal-stale-import"
  _fake_git "$d"
  _fake_composer "$d" "project"
  mkdir -p "$d/.claude"
  touch "$d/.claude/.personal"
  echo "$CLAUDE_IMPORT_LINE" > "$d/.claude/CLAUDE.md"
  echo "$AGENTS_IMPORT_LINE" > "$d/AGENTS.md"

  # 7. Personal site with mixed content + stale import in both files.
  #    setup.sh should strip the import/pointer line but keep the rest.
  d="$root/personal-mixed-stale"
  _fake_git "$d"
  _fake_composer "$d" "project"
  mkdir -p "$d/.claude"
  touch "$d/.claude/.personal"
  printf 'Personal notes.\n\n%s\n' "$CLAUDE_IMPORT_LINE" > "$d/.claude/CLAUDE.md"
  printf 'Personal agent notes.\n\n%s\n' "$AGENTS_IMPORT_LINE" > "$d/AGENTS.md"

  # 8. Not a git repo — setup.sh must skip.
  d="$root/not-a-repo"
  mkdir -p "$d"

  # 9. Module (drupal-module) — setup.sh must skip, no .claude/ created.
  d="$root/drupal-module-thing"
  _fake_git "$d"
  _fake_composer "$d" "drupal-module"

  # 10. Library — setup.sh must skip.
  d="$root/lib-thing"
  _fake_git "$d"
  _fake_composer "$d" "library"

  # 11. Non-site directory (git repo but no composer/ddev/site signals).
  #     setup.sh must skip.
  d="$root/just-a-tool"
  _fake_git "$d"
}
