#!/bin/bash
#
# One-time install for Claude Code shared config.
#
# - Asks for your projects directory (saved locally, never asked again)
# - Runs initial setup
# - Installs a launchd agent that auto-runs setup when the directory changes
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

CONFIG_FILE="$SCRIPT_DIR/.config"
PLIST_NAME="com.augustash.claude-config"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

# Check if already configured
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
  echo "Already configured."
  echo "  Projects directory: $PROJECTS_DIR"
  echo ""
  read -p "Reconfigure? (y/N) " -n 1 -r
  echo ""
  [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
fi

# Resolve true case of a path on macOS (case-insensitive filesystem)
true_case() {
  python3 -c "
import os, sys
path = sys.argv[1]
parts = path.split('/')
resolved = ''
for part in parts:
    if not part:
        resolved = '/'
        continue
    try:
        entries = os.listdir(resolved)
    except PermissionError:
        resolved = os.path.join(resolved, part)
        continue
    matched = False
    for entry in entries:
        if entry.lower() == part.lower():
            resolved = os.path.join(resolved, entry)
            matched = True
            break
    if not matched:
        resolved = os.path.join(resolved, part)
print(resolved)
" "$1"
}

# Resolve a directory input to an absolute path, checking common locations
resolve_projects_dir() {
  local input="$1"

  # Expand ~
  local expanded="${input/#\~/$HOME}"

  # If it's already an absolute path, resolve true case
  if [[ "$expanded" == /* ]] && [[ -d "$expanded" ]]; then
    true_case "$expanded"
    return
  fi

  # Relative name — check common locations
  local capitalized="$(tr '[:lower:]' '[:upper:]' <<< "${expanded:0:1}")${expanded:1}"
  for base in "$HOME" "$HOME/Documents" "/Users/$USER"; do
    for name in "$expanded" "$capitalized"; do
      if [[ -d "$base/$name" ]]; then
        true_case "$base/$name"
        return
      fi
    done
  done

  # Nothing found
  echo ""
}

# Ask for projects directory with validation
while true; do
  echo "Where do you keep your projects?"
  read -p "Projects directory [~/Projects]: " input_dir
  input_dir="${input_dir:-~/Projects}"

  PROJECTS_DIR=$(resolve_projects_dir "$input_dir")

  if [[ -n "$PROJECTS_DIR" ]] && [[ -d "$PROJECTS_DIR" ]]; then
    echo "Found: $PROJECTS_DIR"
    break
  fi

  echo ""
  echo "Could not find \"$input_dir\". Please provide the full path (e.g., /Users/$(whoami)/Projects)."
  echo ""
done

# Save config
cat > "$CONFIG_FILE" <<EOF
PROJECTS_DIR="$PROJECTS_DIR"
EOF
echo "Saved to .config"

# Ensure fzf is available for project selection
require_brew_package "fzf" "multi-select project classification (personal/augustash) during install" || exit 1

# Detect and mark personal projects
echo ""
echo "Detecting project types..."

# Detect framework from ddev config type, fall back to file signatures
detect_framework() {
  local dir="$1"
  local ddev_type=$(grep -E '^\s*type:\s*' "$dir/.ddev/config.yaml" 2>/dev/null | head -1 | sed 's/.*type:\s*//' | tr -d '[:space:]')

  case "$ddev_type" in
    drupal*) echo "drupal"; return ;;
    wordpress) echo "wordpress"; return ;;
    magento*) echo "magento"; return ;;
  esac

  # File signature fallback (no ddev or unrecognized type)
  [[ -f "$dir/wp-config.php" ]] || [[ -d "$dir/wp-content" ]] && echo "wordpress" && return
  [[ -f "$dir/web/core/lib/Drupal.php" ]] || [[ -f "$dir/core/lib/Drupal.php" ]] && echo "drupal" && return
  [[ -f "$dir/bin/magento" ]] || [[ -f "$dir/app/etc/env.php" ]] && echo "magento" && return

  echo ""
}

aai_projects=()
framework_review=()
non_framework=()

for d in "$PROJECTS_DIR"/*/; do
  [[ -d "$d/.git" ]] || continue
  [[ "$(cd "$d" && pwd)" == "$SCRIPT_DIR" ]] && continue
  name="$(basename "$d")"
  framework=$(detect_framework "$d")
  site=$(grep -E '^\s*-\s*(DDEV_PANTHEON_SITE|PANTHEON_SITE)=' "$d/.ddev/config.yaml" 2>/dev/null | head -1 | sed 's/.*=//')

  if [[ -n "$site" ]] && [[ "$site" == aai* ]]; then
    # aai prefix = augustash, no review needed
    aai_projects+=("$name")
  elif [[ -n "$framework" ]]; then
    # Has a known framework but no aai prefix — likely augustash, ask which are personal
    framework_review+=("$name|$framework|${site:--}")
  else
    # No known framework — likely personal, ask which are augustash
    non_framework+=("$name")
  fi
done

echo "  Auto-detected ${#aai_projects[@]} augustash projects (aai* prefix)"

# Review framework projects without aai prefix
if [[ ${#framework_review[@]} -gt 0 ]]; then
  echo ""
  echo "Found ${#framework_review[@]} Drupal/WordPress/Magento projects without aai prefix."

  # Build display labels
  fw_labels=()
  for entry in "${framework_review[@]}"; do
    proj="${entry%%|*}"
    rest="${entry#*|}"
    fw="${rest%%|*}"
    site="${rest##*|}"
    fw_labels+=("$proj ($fw, site: $site)")
  done

  selected=$(multi_select "Are any of these personal projects? Tab to select, Enter to confirm" "${fw_labels[@]}") || true

  if [[ -n "$selected" ]]; then
    while IFS= read -r line; do
      proj="${line%% (*}"
      mkdir -p "$PROJECTS_DIR/$proj/.claude"
      touch "$PROJECTS_DIR/$proj/.claude/.personal"
      echo "  Marked $proj as personal"
    done <<< "$selected"
  fi
fi

# Review non-framework projects (likely personal, ask which are augustash)
if [[ ${#non_framework[@]} -gt 0 ]]; then
  echo ""
  echo "Found ${#non_framework[@]} non-Drupal/WordPress/Magento projects (assumed personal)."

  selected=$(multi_select "Are any of these augustash projects? Tab to select, Enter to confirm" "${non_framework[@]}") || true

  # Mark ALL as personal first
  for proj in "${non_framework[@]}"; do
    mkdir -p "$PROJECTS_DIR/$proj/.claude"
    touch "$PROJECTS_DIR/$proj/.claude/.personal"
  done

  # Remove marker for any the dev says are augustash
  if [[ -n "$selected" ]]; then
    while IFS= read -r proj; do
      rm -f "$PROJECTS_DIR/$proj/.claude/.personal"
      echo "  Marked $proj as augustash"
    done <<< "$selected"
  fi
fi

# Configure Claude Code permissions
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"

if [[ -f "$CLAUDE_SETTINGS" ]]; then
  # Merge permissions into existing settings
  python3 -c "
import json, sys

with open(sys.argv[1]) as f:
    settings = json.load(f)

perms = settings.setdefault('permissions', {})
allow = perms.setdefault('allow', [])

rules = [
    'Read(~/claude-config/**)',
    'Edit(~/claude-config/**)',
    'Write(~/claude-config/**)',
    'Read(${PROJECTS_DIR}/**)',
    'Edit(${PROJECTS_DIR}/**)',
    'Write(${PROJECTS_DIR}/**)',
]

for rule in rules:
    if rule not in allow:
        allow.append(rule)

with open(sys.argv[1], 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
" "$CLAUDE_SETTINGS"
else
  cat > "$CLAUDE_SETTINGS" <<SETTINGS
{
  "permissions": {
    "allow": [
      "Read(~/claude-config/**)",
      "Edit(~/claude-config/**)",
      "Write(~/claude-config/**)",
      "Read(${PROJECTS_DIR}/**)",
      "Edit(${PROJECTS_DIR}/**)",
      "Write(${PROJECTS_DIR}/**)"
    ]
  }
}
SETTINGS
fi

echo "Claude Code permissions configured."

# Run initial setup
echo ""
echo "Running initial setup..."
"$SCRIPT_DIR/setup.sh" "$PROJECTS_DIR"

# Generate and install launchd plist
cat > "$PLIST_DEST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SCRIPT_DIR/setup.sh</string>
        <string>$PROJECTS_DIR</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>$PROJECTS_DIR</string>
    </array>
    <key>StandardOutPath</key>
    <string>$SCRIPT_DIR/.last-run.log</string>
    <key>StandardErrorPath</key>
    <string>$SCRIPT_DIR/.last-run.log</string>
</dict>
</plist>
EOF

# Load the agent (unload first if already loaded)
launchctl bootout "gui/$(id -u)/$PLIST_NAME" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_DEST"

echo ""
echo "Done! Launchd agent installed."
echo "  Watching: $PROJECTS_DIR"
echo "  Setup will run automatically when new projects are added."
echo "  Log: $SCRIPT_DIR/.last-run.log"
