#!/usr/bin/env bash
# Cancel the active timer

# Remove cache files so the Waybar widget resets to empty state
rm -f "$HOME/.cache/waybar-timer.json"
rm -f "$HOME/.cache/waybar-timer.notified"

# Send a desktop notification to inform the user
notify-send "Timer dibatalkan" "" 2>/dev/null || true
