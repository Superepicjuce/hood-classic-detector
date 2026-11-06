#!/bin/zsh
# Install/uninstall hood_classics.py as a login-time background service (launchd LaunchAgent).
# Usage: ./service.sh install | uninstall | status | logs
set -e

LABEL="com.hoodclassic.detector"
HERE="${0:A:h}"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/hood-classic-detector.log"
DOMAIN="gui/$(id -u)"

case "$1" in
  install)
    PYTHON="$(command -v python3)"
    "$PYTHON" -c "import pandas, openpyxl" 2>/dev/null || {
      echo "pandas/openpyxl missing for $PYTHON. Run: $PYTHON -m pip install pandas openpyxl"; exit 1; }
    mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
    cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$PYTHON</string>
    <string>-u</string>
    <string>$HERE/hood_classics.py</string>
  </array>
  <key>WorkingDirectory</key><string>$HERE</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Background</string>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
EOF
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    launchctl bootstrap "$DOMAIN" "$PLIST"
    echo "Installed and started. Logs: $LOG"
    ;;
  uninstall)
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    rm -f "$PLIST"
    echo "Uninstalled."
    ;;
  status)
    launchctl print "$DOMAIN/$LABEL" | grep -E "state|pid|last exit" || echo "Not running."
    ;;
  logs)
    tail -f "$LOG"
    ;;
  *)
    echo "Usage: $0 install | uninstall | status | logs"; exit 1
    ;;
esac
