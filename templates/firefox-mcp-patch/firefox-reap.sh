#!/bin/zsh
# List every Firefox an MCP server is driving, name the Claude session that owns
# it, and kill the ones in the way.
#
# Two kinds are matched: the headless Firefox a solo server launched, and the
# geckodriver a --connectExisting server holds on the dev's browser (Marionette
# takes one client, so a stale holder locks every other session out).
#
# Ownership is the process chain: firefox/geckodriver -> MCP node -> claude. A
# chain that reaches launchd (pid 1) before any claude is an orphan. The dev's
# own Firefox is never matched: it runs neither -headless nor an MCP profile.
#
#   firefox-reap.sh            kill orphans; report the rest
#   firefox-reap.sh --others   also kill other live sessions' (keeps this session's)
#   firefox-reap.sh --dry      report only
set -u
MODE=${1:-}

claude_of() {
  local pid=$1 cmd
  while [[ -n $pid && $pid != 1 ]]; do
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    [[ -z $pid || $pid == 1 ]] && break
    cmd=$(ps -o command= -p "$pid" 2>/dev/null)
    if [[ $cmd == *claude* && $cmd != *firefox-devtools-mcp* ]]; then
      print -r -- "$pid"
      return
    fi
  done
  print orphan
}

# Run from Claude's Bash tool, this script's own chain names the calling session.
SELF=$(claude_of $$)

{
  ps -axo pid=,command= | grep -- 'firefox --marionette -headless' | grep -- '.firefox-devtools-mcp' | sed 's/^ */firefox /'
  ps -axo pid=,command= | grep -- 'geckodriver.*--connect-existing' | sed 's/^ */holder  /'
} | grep -v grep |
while read -r kind pid rest; do
  owner=$(claude_of "$pid")
  if [[ $owner == orphan ]]; then
    why="orphan"
  elif [[ $owner == "$SELF" ]]; then
    print "ours     $kind $pid"
    continue
  elif [[ $MODE == --others ]]; then
    why="claude $owner"
  else
    print "in use   $kind $pid owned by claude $owner (--others to kill)"
    continue
  fi
  if [[ $MODE == --dry ]]; then
    print "$why  $kind $pid (would kill)"
  else
    kill "$pid" && print "$why  $kind $pid killed"
  fi
done
