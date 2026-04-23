#!/bin/bash
#
# Shared utilities for claude-config scripts.
#

# Lines written into downstream projects to wire up the shared config.
# Keep as single-line strings so prune_import's exact-line match still works.
CLAUDE_IMPORT_LINE="@~/claude-config/CLAUDE.md"
AGENTS_IMPORT_LINE="See \`~/claude-config/AGENTS.md\` for shared augustash team conventions."

# Ensure Homebrew is installed, offer to install if not
require_brew() {
  if command -v brew &>/dev/null; then
    return 0
  fi

  echo ""
  echo "Homebrew is not installed. It's required for installing dependencies."
  read -p "Install Homebrew? (y/N) " -n 1 -r
  echo ""

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for the rest of this session
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  else
    echo "Homebrew is required. Please install it manually: https://brew.sh"
    return 1
  fi
}

# Ensure a brew package is installed, offer to install if not
require_brew_package() {
  local package="$1"
  local reason="$2"

  if command -v "$package" &>/dev/null; then
    return 0
  fi

  require_brew || return 1

  echo ""
  echo "$package is not installed."
  [[ -n "$reason" ]] && echo "  Needed for: $reason"
  read -p "Install $package via Homebrew? (y/N) " -n 1 -r
  echo ""

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    brew install "$package"
  else
    echo "$package is required. Please install it manually: brew install $package"
    return 1
  fi
}

# Multi-select using fzf. Prints selected items to stdout (one per line).
# Usage: multi_select "header" item1 item2 item3 ...
multi_select() {
  local header="$1"
  shift
  printf '%s\n' "$@" | fzf --multi --header="$header" --header-first --reverse --height=~50%
}

# Extract the top-level "type" string from a composer.json.
# Usage: composer_type <composer.json>
# Prints the type value (e.g. "project", "drupal-module") or nothing.
composer_type() {
  local file="$1" content
  [[ -f "$file" ]] || return 0
  content=$(< "$file")
  if [[ "$content" =~ \"type\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  fi
}

# True if the given composer "type" marks a non-site asset (module, theme,
# library, etc.) that should never receive shared claude-config.
# Drupal profiles count as modules per project convention.
# Usage: is_module_type <type>
is_module_type() {
  case "$1" in
    drupal-module|drupal-custom-module|drupal-theme|drupal-profile|\
    drupal-library|drupal-drush|drupal-recipe|\
    library|metapackage|\
    wordpress-plugin|wordpress-theme|\
    magento-module|magento-module2|magento-theme) return 0 ;;
  esac
  return 1
}

# True if the given directory looks like a deployable site (vs a module/tool).
# Signals considered: ddev config, wp-config, Drupal core files, Magento entry
# points, Pantheon codeserver remote, or a composer.json with type=project.
# Usage: is_site <dir> [origin]
is_site() {
  local d="$1" origin="${2-}"
  [[ -f "$d/.ddev/config.yaml" ]] && return 0
  [[ -f "$d/wp-config.php" ]] && return 0
  [[ -d "$d/wp-content" ]] && return 0
  [[ -f "$d/web/core/lib/Drupal.php" ]] && return 0
  [[ -f "$d/core/lib/Drupal.php" ]] && return 0
  [[ -f "$d/bin/magento" ]] && return 0
  [[ -f "$d/app/etc/env.php" ]] && return 0

  if [[ -z "$origin" ]]; then
    origin=$(git -C "$d" remote get-url origin 2>/dev/null || true)
  fi
  case "$origin" in
    *codeserver.dev.*@codeserver.dev.*) return 0 ;;
  esac

  if [[ "$(composer_type "$d/composer.json")" == "project" ]]; then
    return 0
  fi

  return 1
}

# Extract the github org from a remote URL, empty if not github.
# Usage: github_org <origin>
github_org() {
  local origin="$1" rest org=""
  case "$origin" in
    *github.com[:/]*)
      rest="${origin##*github.com[:/]}"
      org="${rest%%/*}"
      ;;
  esac
  printf '%s' "$org"
}

# True if the origin indicates a personal (non-augustash) project.
# Fires only for github remotes — Pantheon codeserver UUIDs and other
# remotes don't expose ownership so we can't tell.
# Usage: is_personal_origin <dir> [origin]
is_personal_origin() {
  local d="$1" origin="${2-}"
  if [[ -z "$origin" ]]; then
    origin=$(git -C "$d" remote get-url origin 2>/dev/null || true)
  fi
  case "$origin" in
    *github.com[:/]augustash/*) return 1 ;;
    *github.com[:/]*) return 0 ;;
  esac
  return 1
}

# True if the composer.json "name" lives in one of the given namespaces.
# Used to catch personal Pantheon sites — codeserver remotes hide ownership,
# but composer name namespaces don't. Caller passes the list of personal
# github orgs discovered during a pre-scan.
# Usage: is_personal_composer <dir> "org1 org2 ..."
is_personal_composer() {
  local d="$1" orgs="$2" cname ns
  [[ -z "$orgs" ]] && return 1
  [[ -f "$d/composer.json" ]] || return 1
  cname=$(grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]+"' "$d/composer.json" 2>/dev/null | head -1 || true)
  # Take the value after the first '"' following the colon.
  cname="${cname#*:}"
  cname="${cname//\"/}"
  read -r cname <<< "$cname"
  ns="${cname%%/*}"
  [[ -z "$ns" ]] && return 1
  for org in $orgs; do
    [[ "$ns" == "$org" ]] && return 0
  done
  return 1
}

# True if the site is an augustash-owned project (should auto-get shared config).
# Pantheon codeserver remotes are NOT treated as augustash — devs can host
# personal sites on Pantheon too. Requires a stronger signal.
# Usage: is_augustash <dir> [origin]
is_augustash() {
  local d="$1" origin="${2-}"
  if grep -qE '^\s*-\s*(DDEV_PANTHEON_SITE|PANTHEON_SITE)=aai' \
       "$d/.ddev/config.yaml" 2>/dev/null; then
    return 0
  fi

  if [[ -z "$origin" ]]; then
    origin=$(git -C "$d" remote get-url origin 2>/dev/null || true)
  fi
  case "$origin" in
    *github.com[:/]augustash/*) return 0 ;;
  esac

  # Require an augustash production package. ddev-* add-ons are shared dev
  # tooling and appear on personal sites too, so they don't count.
  if [[ -f "$d/composer.json" ]] && \
     grep '"augustash/' "$d/composer.json" 2>/dev/null | \
     grep -vq '"augustash/ddev-'; then
    return 0
  fi

  return 1
}

# Add a shared-config line to a file if not already present. Creates the file
# (and parent directory) when missing; appends with a blank-line separator
# when the file already has content. Returns 0 if the line was added,
# 1 if it was already present.
# Usage: add_import <file> <line>
add_import() {
  local file="$1" line="$2"
  if [[ -f "$file" ]] && grep -qF "$line" "$file" 2>/dev/null; then
    return 1
  fi
  mkdir -p "$(dirname "$file")"
  if [[ -f "$file" ]] && [[ -s "$file" ]]; then
    printf '\n%s\n' "$line" >> "$file"
  else
    printf '%s\n' "$line" > "$file"
  fi
  return 0
}

# Remove a shared-config import line from a CLAUDE.md; delete the file
# if only that line remained. Returns 0 only when a change was made.
# Usage: prune_import <path> <import_line>
prune_import() {
  local file="$1"
  local import_line="$2"
  if [[ ! -f "$file" ]]; then return 1; fi
  if ! grep -qFx "$import_line" "$file" 2>/dev/null; then return 1; fi

  # Rebuild the file without the import line, buffering blank runs so any
  # blank lines that ended up trailing after removal are dropped.
  local out="" buf="" line
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "$import_line" ]]; then
      continue
    fi
    if [[ -z "$line" ]]; then
      buf+=$'\n'
    else
      out+="$buf$line"$'\n'
      buf=""
    fi
  done < "$file"

  if [[ -n "$out" ]]; then
    printf '%s' "$out" > "$file"
  else
    rm -f "$file"
  fi
}
