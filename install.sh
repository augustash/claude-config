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
  local ddev_type_line ddev_type=""
  ddev_type_line=$(grep -E '^\s*type:\s*' "$dir/.ddev/config.yaml" 2>/dev/null | head -1 || true)
  if [[ -n "$ddev_type_line" ]]; then
    # Strip through "type:", then read trims surrounding whitespace.
    read -r ddev_type <<< "${ddev_type_line##*type:}"
  fi

  case "$ddev_type" in
    drupal*) echo "drupal"; return ;;
    wordpress) echo "wordpress"; return ;;
    magento*) echo "magento"; return ;;
  esac

  # File signature fallback (no ddev or unrecognized type)
  if [[ -f "$dir/wp-config.php" || -d "$dir/wp-content" ]]; then
    echo "wordpress"; return
  fi
  if [[ -f "$dir/web/core/lib/Drupal.php" || -f "$dir/core/lib/Drupal.php" ]]; then
    echo "drupal"; return
  fi
  if [[ -f "$dir/bin/magento" || -f "$dir/app/etc/env.php" ]]; then
    echo "magento"; return
  fi

  echo ""
}

# Clean slate: wipe prior markers and any existing import lines so this run's
# decisions are authoritative. setup.sh at the end will re-apply imports.
echo "  Clearing prior classification markers..."
for d in "$PROJECTS_DIR"/*/; do
  [[ -d "$d/.git" ]] || continue
  if [[ "$(cd "$d" && pwd)" == "$SCRIPT_DIR" ]]; then continue; fi
  rm -f "$d/.claude/.personal" "$d/.claude/.opt-in"
  for candidate in "$d/.claude/CLAUDE.md" "$d/CLAUDE.md"; do
    prune_import "$candidate" "$CLAUDE_IMPORT_LINE" 2>/dev/null || true
  done
  prune_import "$d/AGENTS.md" "$AGENTS_IMPORT_LINE" 2>/dev/null || true
done

# Pass 1: discover personal github orgs. Any github origin that isn't
# augustash is the dev's own org; we use those same namespaces to recognise
# personal Pantheon sites whose codeserver remotes hide ownership.
personal_orgs=""
for d in "$PROJECTS_DIR"/*/; do
  [[ -d "$d/.git" ]] || continue
  if [[ "$(cd "$d" && pwd)" == "$SCRIPT_DIR" ]]; then continue; fi
  origin=$(git -C "$d" remote get-url origin 2>/dev/null || true)
  case "$origin" in
    *github.com[:/]augustash/*) continue ;;
  esac
  org=$(github_org "$origin")
  if [[ -n "$org" ]]; then
    case " $personal_orgs " in
      *" $org "*) ;;
      *) personal_orgs="${personal_orgs:+$personal_orgs }$org" ;;
    esac
  fi
done

if [[ -n "$personal_orgs" ]]; then
  echo "  Personal orgs detected: $personal_orgs"
fi

# Pass 2: classify every project.
aai_projects=()
auto_personals=()
unknowns=()
unknown_names=()
skipped_modules=0
skipped_nonsite=0

for d in "$PROJECTS_DIR"/*/; do
  [[ -d "$d/.git" ]] || continue
  if [[ "$(cd "$d" && pwd)" == "$SCRIPT_DIR" ]]; then continue; fi
  name="$(basename "$d")"

  origin=$(git -C "$d" remote get-url origin 2>/dev/null || true)
  ctype=$(composer_type "$d/composer.json")

  # Skip modules/libraries — they are not sites that should host claude-config.
  if is_module_type "$ctype"; then
    skipped_modules=$((skipped_modules + 1))
    continue
  fi

  # Skip anything that doesn't look like a deployable site.
  if ! is_site "$d" "$origin"; then
    skipped_nonsite=$((skipped_nonsite + 1))
    continue
  fi

  # Non-augustash github origin → personal.
  # Composer name namespace matches a personal org (covers Pantheon codeserver
  # sites owned by the dev — their UUID remote can't tell us but the composer
  # name can).
  if is_personal_origin "$d" "$origin" || \
     is_personal_composer "$d" "$personal_orgs"; then
    mkdir -p "$d/.claude"
    touch "$d/.claude/.personal"
    auto_personals+=("$name")
    continue
  fi

  if is_augustash "$d" "$origin"; then
    aai_projects+=("$name")
    continue
  fi

  # Pantheon codeserver remotes whose composer names we couldn't match are
  # overwhelmingly augustash work. Default them augustash — personal Pantheon
  # sites have already been caught via is_personal_composer above.
  case "$origin" in
    *codeserver.dev.*@codeserver.dev.*)
      aai_projects+=("$name")
      continue
      ;;
  esac

  # Truly ambiguous (non-github non-Pantheon remote, or no remote at all) —
  # let the user decide in fzf.
  framework=$(detect_framework "$d")
  label="$name"
  [[ -n "$framework" ]] && label="$label ($framework)"
  unknowns+=("$label")
  unknown_names+=("$name")
done

echo "  Auto-detected ${#aai_projects[@]} augustash projects"
echo "  Auto-detected ${#auto_personals[@]} personal projects (non-augustash github origin)"
echo "  Skipped $skipped_modules modules/libraries and $skipped_nonsite non-site directories"

personals=()
if [[ ${#unknowns[@]} -gt 0 ]]; then
  echo ""
  echo "Found ${#unknowns[@]} other project(s) (assumed augustash by default)."
  read -p "Mark any as personal? (y/N) " -n 1 -r
  echo ""

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    selected=$(multi_select "Which are personal? Tab to select, Enter to confirm" "${unknowns[@]}") || true

    # fzf --multi falls back to the highlighted line when no Tab-selections
    # were made. Confirm explicitly so an accidental Enter doesn't silently
    # mark whatever was at the top of the list.
    if [[ -n "$selected" ]]; then
      count=$(printf '%s\n' "$selected" | grep -c .)
      echo ""
      echo "Selected $count project(s) to mark personal:"
      printf '  %s\n' "$selected"
      read -p "Confirm? (Y/n) " -n 1 -r
      echo ""
      if [[ $REPLY =~ ^[Nn]$ ]]; then
        selected=""
      fi
    fi

    if [[ -n "$selected" ]]; then
      while IFS= read -r line; do
        proj="${line%% *}"
        mkdir -p "$PROJECTS_DIR/$proj/.claude"
        touch "$PROJECTS_DIR/$proj/.claude/.personal"
        personals+=("$proj")
        echo "  Marked $proj as personal"
      done <<< "$selected"
    fi
  fi
fi

# Opt-in: personals that should still get shared claude-config
if [[ ${#personals[@]} -gt 0 ]]; then
  echo ""
  read -p "Enable shared claude-config for any of your personal projects? (y/N) " -n 1 -r
  echo ""

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    opt_in=$(multi_select "Which personal projects should use shared claude-config?" "${personals[@]}") || true
    if [[ -n "$opt_in" ]]; then
      while IFS= read -r proj; do
        touch "$PROJECTS_DIR/$proj/.claude/.opt-in"
        echo "  Opted in: $proj"
      done <<< "$opt_in"
    fi
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

# Run initial setup — force a full pass so the prune step sees fresh markers
rm -f "$SCRIPT_DIR/.dircount"
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
echo "Done! Watch agent installed."
echo "  Watching: $PROJECTS_DIR"
echo "  Setup will run automatically when new projects are added."
