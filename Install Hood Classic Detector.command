#!/bin/zsh
# Double-click to install or remove the Hood Classic Detector background service.
cd "${0:A:h}" || exit 1

TITLE="Hood Classic Detector"

ask() {  # ask <message> <button1> <button2>  -> prints the clicked button, empty if cancelled
  osascript - "$1" "$2" "$3" "$TITLE" <<'EOF' 2>/dev/null
on run argv
  try
    set r to display dialog (item 1 of argv) with title (item 4 of argv) buttons {item 2 of argv, item 3 of argv} default button (item 3 of argv) cancel button (item 2 of argv) with icon note
    return button returned of r
  end try
end run
EOF
}

tell() {  # tell <message>
  osascript - "$1" "$TITLE" <<'EOF' >/dev/null 2>&1
on run argv
  display dialog (item 1 of argv) with title (item 2 of argv) buttons {"OK"} default button "OK" with icon note
end run
EOF
}

if launchctl print "gui/$(id -u)/com.hoodclassic.detector" >/dev/null 2>&1; then
  choice=$(ask "The detector is currently installed and running.

Uninstall it? It will stop watching Apple Music and no longer start at login." "Cancel" "Uninstall")
  [[ "$choice" == "Uninstall" ]] || exit 0
  out=$(./service.sh uninstall 2>&1) && tell "Uninstalled. The detector has been stopped and will not start at login." \
    || tell "Something went wrong:

$out"
  exit 0
fi

choice=$(ask "This will set up the Hood Classic Detector to run quietly in the background:

• Starts now and every time you log in to this Mac
• Watches what's playing in Apple Music
• When a song from songs.xlsx plays, it pauses the song, plays the \"certified hood classic\" sound, then resumes
• Installs a small file in ~/Library/LaunchAgents (no admin password needed)
• Logs to ~/Library/Logs/hood-classic-detector.log

The first time, macOS will ask if Python may control Music. Click OK.

You can undo this any time by double-clicking this file again." "Cancel" "Install")
[[ "$choice" == "Install" ]] || exit 0

if out=$(./service.sh install 2>&1); then
  tell "Installed! The detector is running now and will start automatically at login."
else
  tell "Install failed:

$out"
fi
