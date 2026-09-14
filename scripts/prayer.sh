#!/usr/bin/env bash

# Prayer Times for Waybar - Magelang, Jawa Tengah, Indonesia
# API: Aladhan (method 20 = Kemenag RI)
# Coordinates: -7.482000, 110.215167
# Icons: Nerd Font weather range (nf-weather-*) - same as weather.sh

CACHE_FILE="/tmp/waybar_prayer_cache"
CACHE_DATE_FILE="/tmp/waybar_prayer_cache_date"
TODAY=$(date +%Y-%m-%d)

# Dynamic clock icon: nf-weather-time_1..12 (U+E38A-E395)
# Same icon set as weather.sh - BMP range, confirmed working
# Formula: U+E389 + hour_12 (1-12)
get_clock_icon() {
    local hour_24="$1"
    local hour_12=$(( hour_24 % 12 ))
    [ $hour_12 -eq 0 ] && hour_12=12
    # E38A = time_1, E38B = time_2, ..., E395 = time_12
    printf "%b" "\ue$(printf '%03x' $(( 0x389 + hour_12 )))"
}

# Per-prayer icons: nf-weather range (BMP, same style as weather module)
get_prayer_icon() {
    local name="$1"
    case "$name" in
        Fajr)    printf "%b" "\ue32b" ;;  # nf-weather-night_clear        (pre-dawn moon)
        Dhuhr)   printf "%b" "\ue30d" ;;  # nf-weather-day_sunny           (noon sun)
        Asr)     printf "%b" "\ue302" ;;  # nf-weather-day_cloudy          (afternoon)
        Maghrib) printf "%b" "\ue383" ;;  # nf-weather-sunset              (dusk)
        Isha)    printf "%b" "\ue32b" ;;  # nf-weather-night_clear         (night moon)
        *)       printf "%b" "\ue33d" ;;  # nf-weather-na
    esac
}

# Prayer names in English
get_prayer_name() {
    local name="$1"
    case "$name" in
        Fajr)    echo "Fajr" ;;
        Dhuhr)   echo "Dhuhr" ;;
        Asr)     echo "Asr" ;;
        Maghrib) echo "Maghrib" ;;
        Isha)    echo "Isha" ;;
        *)       echo "$name" ;;
    esac
}

# Load from cache if still same day
if [ -f "$CACHE_DATE_FILE" ] && [ "$(cat "$CACHE_DATE_FILE")" = "$TODAY" ] && [ -f "$CACHE_FILE" ]; then
    DATA=$(cat "$CACHE_FILE")
else
    DATA=$(curl -sf --max-time 10 \
        "https://api.aladhan.com/v1/timings/$(date +%d-%-m-%Y)?latitude=-7.482000&longitude=110.215167&method=20" \
        2>/dev/null)

    if [ -z "$DATA" ]; then
        echo "{\"text\": \"${MAIN_ICON} N/A\", \"tooltip\": \"Prayer times unavailable\", \"class\": \"unavailable\"}"
        exit 0
    fi

    echo "$DATA" > "$CACHE_FILE"
    echo "$TODAY" > "$CACHE_DATE_FILE"
fi

# Parse prayer times
FAJR=$(echo "$DATA"    | jq -r '.data.timings.Fajr')
DHUHR=$(echo "$DATA"   | jq -r '.data.timings.Dhuhr')
ASR=$(echo "$DATA"     | jq -r '.data.timings.Asr')
MAGHRIB=$(echo "$DATA" | jq -r '.data.timings.Maghrib')
ISHA=$(echo "$DATA"    | jq -r '.data.timings.Isha')

# Strip timezone suffix if present e.g. "04:16 (WIB)" -> "04:16"
FAJR="${FAJR%% (*}"
DHUHR="${DHUHR%% (*}"
ASR="${ASR%% (*}"
MAGHRIB="${MAGHRIB%% (*}"
ISHA="${ISHA%% (*}"

# Convert HH:MM to total seconds since midnight (strip leading zeros to avoid octal)
time_to_sec() {
    local t="$1"
    local h=${t%%:*}
    local m=${t##*:}
    h=$(echo "$h" | sed 's/^0*//')
    m=$(echo "$m" | sed 's/^0*//')
    [ -z "$h" ] && h=0
    [ -z "$m" ] && m=0
    echo $(( (h * 60 + m) * 60 ))
}

# Current time in seconds
NOW_H=$(date +%-H)
NOW_M=$(date +%-M)
NOW_S=$(date +%-S)
NOW_SEC=$(( NOW_H * 3600 + NOW_M * 60 + NOW_S ))

FAJR_SEC=$(time_to_sec "$FAJR")
DHUHR_SEC=$(time_to_sec "$DHUHR")
ASR_SEC=$(time_to_sec "$ASR")
MAGHRIB_SEC=$(time_to_sec "$MAGHRIB")
ISHA_SEC=$(time_to_sec "$ISHA")

# Determine next prayer
NEXT_PRAYER=""
NEXT_TIME=""
NEXT_SEC=0

if [ $NOW_SEC -lt $FAJR_SEC ]; then
    NEXT_PRAYER="Fajr";    NEXT_TIME="$FAJR";    NEXT_SEC=$FAJR_SEC
elif [ $NOW_SEC -lt $DHUHR_SEC ]; then
    NEXT_PRAYER="Dhuhr";   NEXT_TIME="$DHUHR";   NEXT_SEC=$DHUHR_SEC
elif [ $NOW_SEC -lt $ASR_SEC ]; then
    NEXT_PRAYER="Asr";     NEXT_TIME="$ASR";     NEXT_SEC=$ASR_SEC
elif [ $NOW_SEC -lt $MAGHRIB_SEC ]; then
    NEXT_PRAYER="Maghrib"; NEXT_TIME="$MAGHRIB"; NEXT_SEC=$MAGHRIB_SEC
elif [ $NOW_SEC -lt $ISHA_SEC ]; then
    NEXT_PRAYER="Isha";    NEXT_TIME="$ISHA";    NEXT_SEC=$ISHA_SEC
else
    NEXT_PRAYER="Fajr";    NEXT_TIME="$FAJR";    NEXT_SEC=$((FAJR_SEC + 86400))  # tomorrow
fi

# Compute countdown with seconds
DIFF_SEC=$((NEXT_SEC - NOW_SEC))
[ $DIFF_SEC -lt 0 ] && DIFF_SEC=$((DIFF_SEC + 86400))

DIFF_H=$((DIFF_SEC / 3600))
DIFF_M=$(( (DIFF_SEC % 3600) / 60 ))
DIFF_S=$((DIFF_SEC % 60))

if [ $DIFF_H -gt 0 ]; then
    COUNTDOWN="${DIFF_H}h ${DIFF_M}m ${DIFF_S}s"
elif [ $DIFF_M -gt 0 ]; then
    COUNTDOWN="${DIFF_M}m ${DIFF_S}s"
else
    COUNTDOWN="${DIFF_S}s"
fi

# CSS class based on urgency (in minutes for threshold check)
DIFF_MIN=$(( DIFF_SEC / 60 ))
if [ $DIFF_MIN -le 10 ]; then
    CLASS="urgent"
elif [ $DIFF_MIN -le 30 ]; then
    CLASS="warning"
else
    CLASS="normal"
fi

# Icons and labels
NEXT_ICON=$(get_prayer_icon "$NEXT_PRAYER")
NEXT_LABEL=$(get_prayer_name "$NEXT_PRAYER")

ICON_FAJR=$(get_prayer_icon "Fajr")
ICON_DHUHR=$(get_prayer_icon "Dhuhr")
ICON_ASR=$(get_prayer_icon "Asr")
ICON_MAGHRIB=$(get_prayer_icon "Maghrib")
ICON_ISHA=$(get_prayer_icon "Isha")

# Main bar icon: dynamic clock face for next prayer's hour
NEXT_HOUR=$(echo "$NEXT_TIME" | cut -d: -f1 | sed 's/^0*//')
[ -z "$NEXT_HOUR" ] && NEXT_HOUR=0
MAIN_ICON=$(get_clock_icon "$NEXT_HOUR")

# Bar text: dynamic clock icon + prayer name + time + countdown
TEXT="${MAIN_ICON} ${NEXT_LABEL} ${NEXT_TIME} (${COUNTDOWN})"

# Tooltip: full schedule for today
MAP=$(printf "%b" "\uf041")   # fa-map-marker (FA4, U+F041 - reliable)
TOOLTIP="${MAP} Magelang, Central Java\n"
TOOLTIP+="━━━━━━━━━━━━━━━━━━\n"
TOOLTIP+="${ICON_FAJR}  Fajr    : ${FAJR}\n"
TOOLTIP+="${ICON_DHUHR}  Dhuhr   : ${DHUHR}\n"
TOOLTIP+="${ICON_ASR}  Asr     : ${ASR}\n"
TOOLTIP+="${ICON_MAGHRIB}  Maghrib : ${MAGHRIB}\n"
TOOLTIP+="${ICON_ISHA}  Isha    : ${ISHA}\n"
TOOLTIP+="━━━━━━━━━━━━━━━━━━\n"
TOOLTIP+="${NEXT_ICON}  ${NEXT_LABEL} in ${COUNTDOWN} (at ${NEXT_TIME})"

echo "{\"text\": \"${TEXT}\", \"tooltip\": \"${TOOLTIP}\", \"class\": \"${CLASS}\"}"
