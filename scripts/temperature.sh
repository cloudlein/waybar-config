#!/usr/bin/env bash

# Combined CPU & iGPU Temperature script for Waybar
# Format can be:
#   "text"       -> CPU 55° | iGPU 50°
#   "weather"    ->  CPU 55° | iGPU 50°
#   "icons"      ->  55° | 󰢮 50°
#   "weather_raw"->  55° | 50°

MODE="${1:-text}"

# Find CPU hwmon
HWMON_CPU=""
for h in /sys/class/hwmon/hwmon*; do
    [ -f "$h/name" ] || continue
    name=$(<"$h/name")
    if [[ "$name" == "k10temp" || "$name" == "coretemp" || "$name" == "zenpower" ]]; then
        HWMON_CPU="$h"
        CPU_NAME="$name"
        break
    fi
done

# Find GPU hwmon
HWMON_GPU=""
for h in /sys/class/hwmon/hwmon*; do
    [ -f "$h/name" ] || continue
    name=$(<"$h/name")
    if [[ "$name" == "amdgpu" || "$name" == "nouveau" || "$name" == "i915" ]]; then
        HWMON_GPU="$h"
        GPU_NAME="$name"
        break
    fi
done

# Read CPU Temperature
CPU_TEMP="N/A"
CPU_VAL=0
TCTL=""
TCCD1=""

if [ -n "$HWMON_CPU" ]; then
    for lbl in "$HWMON_CPU"/temp*_label; do
        [ -f "$lbl" ] || continue
        label=$(<"$lbl")
        inp="${lbl%_label}_input"
        if [[ "$label" == "Tctl" || "$label" == "Package id 0" ]]; then
            if [ -f "$inp" ]; then
                raw=$(<"$inp")
                CPU_VAL=$(( raw / 1000 ))
                CPU_TEMP="${CPU_VAL}°"
                TCTL="${CPU_VAL}°C"
            fi
        elif [[ "$label" == "Tccd1" ]]; then
            if [ -f "$inp" ]; then
                TCCD1="$(( $(<"$inp") / 1000 ))°C"
            fi
        fi
    done
    if [ "$CPU_TEMP" == "N/A" ] && [ -f "$HWMON_CPU/temp1_input" ]; then
        CPU_VAL=$(( $(<"$HWMON_CPU/temp1_input") / 1000 ))
        CPU_TEMP="${CPU_VAL}°"
        TCTL="${CPU_VAL}°C"
    fi
fi

# Read GPU Temperature
GPU_TEMP="N/A"
GPU_VAL=0
EDGE=""
JUNCTION=""

if [ -n "$HWMON_GPU" ]; then
    for lbl in "$HWMON_GPU"/temp*_label; do
        [ -f "$lbl" ] || continue
        label=$(<"$lbl")
        inp="${lbl%_label}_input"
        if [[ "$label" == "edge" ]]; then
            if [ -f "$inp" ]; then
                raw=$(<"$inp")
                GPU_VAL=$(( raw / 1000 ))
                GPU_TEMP="${GPU_VAL}°"
                EDGE="${GPU_VAL}°C"
            fi
        elif [[ "$label" == "junction" ]]; then
            if [ -f "$inp" ]; then
                JUNCTION="$(( $(<"$inp") / 1000 ))°C"
            fi
        fi
    done
    if [ "$GPU_TEMP" == "N/A" ] && [ -f "$HWMON_GPU/temp1_input" ]; then
        GPU_VAL=$(( $(<"$HWMON_GPU/temp1_input") / 1000 ))
        GPU_TEMP="${GPU_VAL}°"
        EDGE="${GPU_VAL}°C"
    fi
fi

# Determine CSS class based on maximum temperature
MAX_TEMP=$(( CPU_VAL > GPU_VAL ? CPU_VAL : GPU_VAL ))
if [ "$MAX_TEMP" -ge 80 ]; then
    CLASS="hot"
elif [ "$MAX_TEMP" -le 40 ] && [ "$MAX_TEMP" -gt 0 ]; then
    CLASS="cold"
else
    CLASS="normal"
fi

# Format Text
WI_THERM=$(printf "%b" "\ue350")
case "$MODE" in
    weather)
        TEXT="${WI_THERM} CPU ${CPU_TEMP} | iGPU ${GPU_TEMP}"
        ;;
    icons)
        TEXT=" ${CPU_TEMP} | 󰢮 ${GPU_TEMP}"
        ;;
    weather_raw)
        TEXT="${WI_THERM} ${CPU_TEMP} | ${GPU_TEMP}"
        ;;
    text|*)
        TEXT="CPU ${CPU_TEMP} | iGPU ${GPU_TEMP}"
        ;;
esac

TOOLTIP="🖥 CPU: ${TCTL:-${CPU_TEMP}} (${CPU_NAME:-unknown})"
[ -n "$TCCD1" ] && TOOLTIP="${TOOLTIP}\n   ↳ Tccd1: ${TCCD1}"
TOOLTIP="${TOOLTIP}\n🎮 iGPU: ${EDGE:-${GPU_TEMP}} (${GPU_NAME:-unknown})"
[ -n "$JUNCTION" ] && TOOLTIP="${TOOLTIP}\n   ↳ Junction: ${JUNCTION}"

echo "{\"text\": \"${TEXT}\", \"tooltip\": \"${TOOLTIP}\", \"class\": \"${CLASS}\"}"
