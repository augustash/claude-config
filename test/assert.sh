#!/bin/bash
#
# Tiny assertion helpers for the claude-config test harness.
# Each assertion increments a counter and prints pass/fail with colored output.
# The caller is expected to init ASSERT_PASS=0 / ASSERT_FAIL=0 and to inspect
# ASSERT_FAIL at the end to determine exit status.
#

ASSERT_PASS=${ASSERT_PASS:-0}
ASSERT_FAIL=${ASSERT_FAIL:-0}

if [[ -t 1 ]]; then
  _green=$'\e[32m'; _red=$'\e[31m'; _dim=$'\e[2m'; _reset=$'\e[0m'
else
  _green=""; _red=""; _dim=""; _reset=""
fi

_pass() {
  ASSERT_PASS=$((ASSERT_PASS + 1))
  echo "  ${_green}PASS${_reset} $1"
}

_fail() {
  ASSERT_FAIL=$((ASSERT_FAIL + 1))
  echo "  ${_red}FAIL${_reset} $1"
  [[ -n "${2:-}" ]] && echo "       ${_dim}$2${_reset}"
}

assert_file_exists() {
  local path="$1" msg="${2:-file exists: $1}"
  [[ -e "$path" ]] && _pass "$msg" || _fail "$msg" "expected to exist: $path"
}

assert_file_missing() {
  local path="$1" msg="${2:-file missing: $1}"
  [[ ! -e "$path" ]] && _pass "$msg" || _fail "$msg" "expected NOT to exist: $path"
}

assert_file_contains() {
  local path="$1" needle="$2" msg="${3:-$path contains $needle}"
  if [[ ! -f "$path" ]]; then
    _fail "$msg" "file does not exist: $path"
    return
  fi
  grep -qF "$needle" "$path" && _pass "$msg" || _fail "$msg" "missing substring: $needle"
}

assert_file_not_contains() {
  local path="$1" needle="$2" msg="${3:-$path does NOT contain $needle}"
  if [[ ! -f "$path" ]]; then
    _pass "$msg"
    return
  fi
  grep -qF "$needle" "$path" && _fail "$msg" "unexpected substring: $needle" || _pass "$msg"
}

assert_file_equals() {
  local path="$1" expected="$2" msg="${3:-$path matches expected content}"
  if [[ ! -f "$path" ]]; then
    _fail "$msg" "file does not exist: $path"
    return
  fi
  local actual
  actual="$(cat "$path")"
  if [[ "$actual" == "$expected" ]]; then
    _pass "$msg"
  else
    _fail "$msg" "expected: $(printf %q "$expected") | got: $(printf %q "$actual")"
  fi
}
