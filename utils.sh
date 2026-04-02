#!/bin/bash
#
# Shared utilities for claude-config scripts.
#

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
