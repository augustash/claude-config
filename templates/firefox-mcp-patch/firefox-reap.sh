#!/bin/zsh
# List every headless Firefox an MCP server started, name the Claude session
# that owns it, and kill only the orphans.
#
# Ownership is the process chain: firefox -> geckodriver -> MCP node -> claude.
# A chain that reaches launchd (pid 1) before any claude process is an orphan
# whose session is gone. A chain that reaches a live claude belongs to that
# session and is left alone, even if it is not ours. The dev's own Firefox is
# never matched: it runs neither --marionette -headless nor an MCP profile.
#
#   firefox-reap.sh          report and kill orphans
#   firefox-reap.sh --dry    report only
set -u
DRY=${1:-}

owner_of() {
  local pid=$1 cmd
  while [[ -n $pid && $pid != 1 ]]; do
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    [[ -z $pid || $pid == 1 ]] && break
    cmd=$(ps -o command= -p "$pid" 2>/dev/null)
    if [[ $cmd == *claude* && $cmd != *firefox-devtools-mcp* ]]; then
      print -r -- "$pid ${${cmd##*--session-id }%% *}"
      return
    fi
  done
  print orphan
}

ps -axo pid=,command= | grep -- 'firefox --marionette -headless' | grep -- '.firefox-devtools-mcp' | grep -v grep |
while read -r pid rest; do
  owner=$(owner_of "$pid")
  if [[ $owner == orphan ]]; then
    if [[ $DRY == --dry ]]; then
      print "orphan   firefox $pid (would kill)"
    else
      kill "$pid" && print "orphan   firefox $pid killed"
    fi
  else
    print "in use   firefox $pid owned by claude ${owner%% *} (session ${owner#* })"
  fi
done
