#!/usr/bin/env bash

# Weather script for Waybar using Open-Meteo API
# Returns icon + temperature + location
# Uses Nerd Font icons via unicode escape

# ==============================================================================
# Configuration
# ==============================================================================

LATITUDE="-7.482000"
LONGITUDE="110.215167"
TIMEZONE="Asia/Jakarta"
CITY="Magelang"
REGION="Jawa Tengah, Indonesia"

# Function to output fallback JSON on error
fallback() {
    local msg="${1:-Weather unavailable}"
    echo "{\"text\": \"\ue33d N/A\", \"tooltip\": \"${msg}\", \"class\": \"unknown\"}"
    exit 0
}

# Check dependency
if ! command -v jq &>/dev/null; then
    fallback "Dependency 'jq' is missing"
fi

if ! command -v curl &>/dev/null; then
    fallback "Dependency 'curl' is missing"
fi

# ==============================================================================
# Weather Code & Icon Mapping (WMO Code from Open-Meteo)
# ==============================================================================
get_icon() {
    local code="$1"
    case "$code" in
        0)                                      echo "\ue30d" ;;  # nf-weather-day_sunny (Clear sky)
        1|2)                                    echo "\ue302" ;;  # nf-weather-day_cloudy (Mainly clear, Partly cloudy)
        3)                                      echo "\ue312" ;;  # nf-weather-cloudy (Overcast)
        45|48)                                  echo "\ue313" ;;  # nf-weather-fog (Fog)
        51|53|55|56|57)                         echo "\ue308" ;;  # nf-weather-rain (Drizzle)
        61|63|65|66|67|80|81|82)                echo "\ue308" ;;  # nf-weather-rain (Rain / Showers)
        71|73|75|77|85|86)                      echo "\ue318" ;;  # nf-weather-snow (Snow)
        95|96|99)                               echo "\ue31d" ;;  # nf-weather-thunderstorm (Thunderstorm)
        *)                                      echo "\ue33d" ;;  # nf-weather-na (?)
    esac
}

get_desc() {
    local code="$1"
    case "$code" in
        0)              echo "Clear sky" ;;
        1)              echo "Mainly clear" ;;
        2)              echo "Partly cloudy" ;;
        3)              echo "Overcast" ;;
        45|48)          echo "Fog" ;;
        51|53|55)       echo "Drizzle" ;;
        56|57)          echo "Freezing drizzle" ;;
        61|63|65)       echo "Rain" ;;
        66|67)          echo "Freezing rain" ;;
        71|73|75|77)    echo "Snow" ;;
        80|81|82)       echo "Rain showers" ;;
        85|86)          echo "Snow showers" ;;
        95|96|99)       echo "Thunderstorm" ;;
        *)              echo "Unknown" ;;
    esac
}

# ==============================================================================
# Fetch weather from Open-Meteo API (silent, 5s timeout, standard SSL)
# ==============================================================================
API_URL="https://api.open-meteo.com/v1/forecast?latitude=${LATITUDE}&longitude=${LONGITUDE}&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&timezone=${TIMEZONE}"

DATA=$(curl -sf --max-time 5 "$API_URL" 2>/dev/null)

if [ -z "$DATA" ]; then
    fallback "Weather unavailable (API error or offline)"
fi

# Parse values from JSON response
TEMP=$(echo "$DATA" | jq -r '.current.temperature_2m // empty' 2>/dev/null)
FEELS=$(echo "$DATA" | jq -r '.current.apparent_temperature // empty' 2>/dev/null)
HUMIDITY=$(echo "$DATA" | jq -r '.current.relative_humidity_2m // empty' 2>/dev/null)
CODE=$(echo "$DATA" | jq -r '.current.weather_code // empty' 2>/dev/null)
WIND=$(echo "$DATA" | jq -r '.current.wind_speed_10m // empty' 2>/dev/null)

if [ -z "$TEMP" ] || [ -z "$CODE" ]; then
    fallback "Weather data unavailable"
fi

# Round temperature for integer comparison and clean display
TEMP_ROUND=$(printf "%.0f" "$TEMP" 2>/dev/null || echo "${TEMP%.*}")
FEELS_ROUND=$(printf "%.0f" "$FEELS" 2>/dev/null || echo "${FEELS%.*}")

DESC=$(get_desc "$CODE")
ICON=$(printf "%b" "$(get_icon "$CODE")")

# Determine class for CSS styling
if [ "$TEMP_ROUND" -ge 35 ]; then
    CLASS="hot"
elif [ "$TEMP_ROUND" -le 10 ]; then
    CLASS="cold"
else
    CLASS="normal"
fi

# Format location string
if [ -n "$CITY" ] && [ -n "$REGION" ]; then
    LOCATION="${CITY}, ${REGION}"
elif [ -n "$CITY" ]; then
    LOCATION="${CITY}"
else
    LOCATION="${LATITUDE}, ${LONGITUDE}"
fi

echo "{\"text\": \"${ICON} ${TEMP_ROUND}°  ${LOCATION}\", \"tooltip\": \"📍 ${LOCATION}\\n${DESC}\\n🌡 Terasa: ${FEELS_ROUND}°C\\n💧 Kelembaban: ${HUMIDITY}%\\n🌬 Angin: ${WIND} km/h\", \"class\": \"${CLASS}\"}"
