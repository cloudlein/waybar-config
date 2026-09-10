#!/usr/bin/env bash

# Waybar Countdown Timer Script
# State file: ~/.cache/waybar-timer.json
# Format: {"end": <epoch>, "label": "<label>"}

STATE_FILE="$HOME/.cache/waybar-timer.json"

# Icon timer menggunakan unicode escape (sama seperti weather)
# \uf017 = nf-fa-clock  |  \ue381 = nf-mdi-timer
ICON=$(printf "%b" "\uf017")

# Jika tidak ada file state — tampilkan 00:00 sebagai default
if [ ! -f "$STATE_FILE" ]; then
    echo "{\"text\": \"${ICON} 00:00\", \"tooltip\": \"Tidak ada timer aktif\\nGunakan: timer <durasi>\\nContoh: timer 25m / timer 1h30m\", \"class\": \"inactive\"}"
    exit 0
fi

END=$(jq -r '.end' "$STATE_FILE" 2>/dev/null)
LABEL=$(jq -r '.label // ""' "$STATE_FILE" 2>/dev/null)

if [ -z "$END" ] || [ "$END" = "null" ]; then
    echo "{\"text\": \"${ICON} 00:00\", \"tooltip\": \"Timer tidak valid\", \"class\": \"inactive\"}"
    exit 0
fi

NOW=$(date +%s)
REMAINING=$((END - NOW))

# Timer sudah habis
if [ "$REMAINING" -le 0 ]; then
    FLAG_FILE="$HOME/.cache/waybar-timer.notified"
    if [ ! -f "$FLAG_FILE" ]; then
        touch "$FLAG_FILE"
        MSG="${LABEL:-Timer}"
        notify-send -u critical -i "alarm-clock" "⏰ Timer Selesai!" "$MSG sudah habis!" 2>/dev/null || true
    fi
    echo "{\"text\": \"${ICON} 00:00\", \"tooltip\": \"${LABEL:-Timer} selesai!\", \"class\": \"done\"}"
    exit 0
fi

# Hitung jam, menit, detik
HOURS=$((REMAINING / 3600))
MINS=$(( (REMAINING % 3600) / 60 ))
SECS=$((REMAINING % 60))

# Format tampilan
if [ "$HOURS" -gt 0 ]; then
    DISPLAY=$(printf "%d:%02d:%02d" "$HOURS" "$MINS" "$SECS")
else
    DISPLAY=$(printf "%02d:%02d" "$MINS" "$SECS")
fi

# Class berdasarkan sisa waktu
if [ "$REMAINING" -le 60 ]; then
    CLASS="urgent"       # < 1 menit: merah
elif [ "$REMAINING" -le 300 ]; then
    CLASS="warning"      # < 5 menit: kuning
else
    CLASS="active"       # normal
fi

TOOLTIP="${LABEL:+$LABEL\n}Sisa: $DISPLAY\nSelesai: $(date -d @"$END" '+%H:%M:%S')"

echo "{\"text\": \"${ICON} ${DISPLAY}\", \"tooltip\": \"${TOOLTIP}\", \"class\": \"${CLASS}\"}"
