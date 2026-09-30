#!/bin/zsh
# Launch the headless ("solo") firefox-devtools MCP server with a profile owned
# by the Claude session that started it.
#
# --autoProfile gives every session ONE shared profile, so two live sessions
# lock each other out ("Process (pid=N) unexpectedly closed with status 0").
# Instead each session gets solo-<claude pid>; this script is exec'd by Claude,
# so $PPID is that session. Profiles whose owner has exited are reaped here,
# along with any Firefox still running on them.
#
# Register (user scope), passing any extra server flags after the script:
#   claude mcp add firefox-solo --scope user -- \
#     ~/.local/share/firefox-devtools-mcp-patched/firefox-solo.sh
set -u

SERVER="${FIREFOX_MCP_SERVER:-$HOME/.local/share/firefox-devtools-mcp-patched/node_modules/@mozilla/firefox-devtools-mcp/dist/index.js}"
FIREFOX="${FIREFOX_PATH:-/Applications/Firefox Developer Edition.app/Contents/MacOS/firefox}"
BASE="$HOME/.firefox-devtools-mcp"
# Detached (no Claude parent): own the profile ourselves so it is never
# reaped out from under us, and never collides with a real session's.
OWNER=$PPID
[[ $OWNER == 1 ]] && OWNER=$$
PROFILE="$BASE/solo-$OWNER"

mkdir -p "$BASE"
for dir in "$BASE"/solo-*(N/); do
  pid=${dir##*-}
  kill -0 "$pid" 2>/dev/null && continue
  pkill -f -- "--profile $dir" 2>/dev/null
  rm -rf "$dir"
done
mkdir -p "$PROFILE"

exec node "$SERVER" \
  --tools pages snapshot input network console screenshot utilities script \
  --headless \
  --firefoxPath "$FIREFOX" \
  --viewport 1440x900 \
  --profilePath "$PROFILE" \
  "$@"
