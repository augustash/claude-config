#!/usr/bin/env bash
# Installs release-watch as a launchd job that runs each weekday morning.
#
#   install.sh            weekdays at 07:30
#   install.sh 08:15      weekdays at another time
#   install.sh --remove   uninstall
#
# A Mac asleep at that time runs the job when it wakes. The job points at the script where
# it sits now, so re-run this if the claude-config checkout it lives in moves.
set -euo pipefail

label=com.augustash.release-watch
plist=$HOME/Library/LaunchAgents/$label.plist
script=$(cd "$(dirname "$0")" && pwd)/release-watch.py
log=${XDG_CACHE_HOME:-$HOME/.cache}/release-watch/launchd.log

launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
if [ "${1:-}" = --remove ]; then
  rm -f "$plist"
  echo "Removed $label."
  exit 0
fi

time=${1:-07:30}
hour=$((10#${time%%:*})); minute=$((10#${time##*:}))
python=$(command -v python3)
mkdir -p "$(dirname "$log")" "$(dirname "$plist")"

days=''
for d in 1 2 3 4 5; do
  days+="<dict><key>Weekday</key><integer>$d</integer><key>Hour</key><integer>$hour</integer><key>Minute</key><integer>$minute</integer></dict>"
done

cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key>
  <array><string>$python</string><string>-I</string><string>$script</string></array>
  <key>StartCalendarInterval</key>
  <array>$days</array>
  <key>EnvironmentVariables</key>
  <dict><key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string></dict>
  <key>StandardOutPath</key><string>$log</string>
  <key>StandardErrorPath</key><string>$log</string>
</dict>
</plist>
EOF

launchctl bootstrap "gui/$(id -u)" "$plist"
printf 'Installed: weekdays at %02d:%02d, running %s\n' "$hour" "$minute" "$script"
cat <<'EOF'

To show the alert in the Claude Code status line, add this before its final printf:

  rw=${XDG_CACHE_HOME:-$HOME/.cache}/release-watch/status
  [ -s "$rw" ] && out="$out · $(cat "$rw")"

Run it now:   launchctl kickstart gui/$(id -u)/com.augustash.release-watch
EOF
