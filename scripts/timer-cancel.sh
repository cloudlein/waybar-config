#!/usr/bin/env bash
# Cancel timer aktif
rm -f "$HOME/.cache/waybar-timer.json"
rm -f "$HOME/.cache/waybar-timer.notified"
notify-send "Timer dibatalkan" "" 2>/dev/null || true
