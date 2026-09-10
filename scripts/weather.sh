#!/usr/bin/env bash

# Weather script for Waybar using wttr.in
# Returns icon + temperature
# Uses Nerd Font icons via unicode escape

get_icon() {
    local code="$1"
    case "$code" in
        113)                                    echo "\ue30d" ;;  # nf-weather-day_sunny         ☀
        116)                                    echo "\ue302" ;;  # nf-weather-day_cloudy        🌤
        119|122)                                echo "\ue312" ;;  # nf-weather-cloudy            ☁
        143|248|260)                            echo "\ue313" ;;  # nf-weather-fog               🌫
        176|263|266|293|296|299|302|305|308|\
        353|356|359)                            echo "\ue308" ;;  # nf-weather-rain              🌧
        179|182|185|227|230|281|284|311|314|\
        317|320|323|326|329|332|335|338|350|\
        362|365|368|371|374|377)               echo "\ue318" ;;  # nf-weather-snow              🌨
        200|386|389|392|395)                   echo "\ue31d" ;;  # nf-weather-thunderstorm      ⛈
        *)                                      echo "\ue33d" ;;  # nf-weather-na               ?
    esac
}

# Fetch weather from wttr.in (silent, 5s timeout)
# Lokasi di-hardcode ke Magelang agar akurat (deteksi IP tidak selalu tepat)
DATA=$(curl -sf --max-time 5 "https://wttr.in/Magelang?format=j1" 2>/dev/null)
# Kalau mau pakai deteksi otomatis berdasarkan IP (tidak akurat):
#   DATA=$(curl -sf --max-time 5 "https://wttr.in/?format=j1" 2>/dev/null)
# Kalau mau pakai GPS (butuh 'gpspipe' dari paket gpsd):
#   LAT=$(gpspipe -w -n 5 2>/dev/null | grep -m1 TPV | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('lat',''))" 2>/dev/null)
#   LON=$(gpspipe -w -n 5 2>/dev/null | grep -m1 TPV | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('lon',''))" 2>/dev/null)
#   DATA=$(curl -sf --max-time 5 "https://wttr.in/${LAT},${LON}?format=j1" 2>/dev/null)

if [ -z "$DATA" ]; then
    echo "{\"text\": \"\ue33d N/A\", \"tooltip\": \"Weather unavailable\", \"class\": \"unknown\"}"
    exit 0
fi

TEMP=$(echo "$DATA" | jq -r '.current_condition[0].temp_C')
FEELS=$(echo "$DATA" | jq -r '.current_condition[0].FeelsLikeC')
HUMIDITY=$(echo "$DATA" | jq -r '.current_condition[0].humidity')
DESC=$(echo "$DATA" | jq -r '.current_condition[0].weatherDesc[0].value')
CODE=$(echo "$DATA" | jq -r '.current_condition[0].weatherCode')
WIND=$(echo "$DATA" | jq -r '.current_condition[0].windspeedKmph')
CITY=$(echo "$DATA" | jq -r '.nearest_area[0].areaName[0].value')
REGION=$(echo "$DATA" | jq -r '.nearest_area[0].region[0].value')

ICON=$(printf "%b" "$(get_icon "$CODE")")

# Determine class for CSS styling
if [ "$TEMP" -ge 35 ]; then
    CLASS="hot"
elif [ "$TEMP" -le 10 ]; then
    CLASS="cold"
else
    CLASS="normal"
fi

echo "{\"text\": \"${ICON} ${TEMP}°  ${CITY}, ${REGION}\", \"tooltip\": \"📍 ${CITY}, ${REGION}\\n${DESC}\\n🌡 Terasa: ${FEELS}°C\\n💧 Kelembaban: ${HUMIDITY}%\\n🌬 Angin: ${WIND} km/h\", \"class\": \"${CLASS}\"}"
