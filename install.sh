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
  read -p "Projects directory (e.g., ~/Projects): " input_dir

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
