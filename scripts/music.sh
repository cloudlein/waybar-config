#!/usr/bin/env bash
set -euo pipefail

CDP_URL="http://127.0.0.1:9222/json"

# Check Brave playback status via playerctl
STATUS=$(playerctl -p brave status 2>/dev/null || true)
if [[ "$STATUS" != "Playing" ]]; then
    exit 0
fi

# Fetch track metadata
TITLE=$(playerctl -p brave metadata --format '{{ xesam:title }}' 2>/dev/null || true)
ARTIST=$(playerctl -p brave metadata --format '{{ xesam:artist }}' 2>/dev/null || true)
ALBUM=$(playerctl -p brave metadata --format '{{ xesam:album }}' 2>/dev/null || true)

if [[ -z "$TITLE" ]]; then
    TITLE=$(playerctl -p brave metadata --format '{{ title }}' 2>/dev/null || true)
fi

if [[ -z "$TITLE" ]]; then
    exit 0
fi

# Query Brave CDP to verify active tabs
CDP_DATA=$(curl -s --connect-timeout 0.2 --max-time 0.5 "$CDP_URL" 2>/dev/null || true)
if [[ -z "$CDP_DATA" ]]; then
    exit 0
fi

# 1. Reject if playing media matches a regular YouTube tab
IS_REGULAR_YT=$(echo "$CDP_DATA" | jq -r --arg title "$TITLE" '
  [
    .[]
    | select(type == "object" and .type == "page" and .url != null)
    | select((.url | test("^https?://(www\\.)?youtube\\.com")) and (.title != null and ($title != "" and (.title | ascii_downcase | contains($title | ascii_downcase)))))
  ] | length
' 2>/dev/null || echo 0)

if [[ "$IS_REGULAR_YT" -gt 0 ]]; then
    exit 0
fi

# 2. Check if a whitelisted music tab title directly matches
MATCHED_TAB=$(echo "$CDP_DATA" | jq -r --arg title "$TITLE" '
  [
    .[]
    | select(type == "object" and .type == "page" and .url != null)
    | select(.title != null and ($title != "" and (.title | ascii_downcase | contains($title | ascii_downcase))))
    | select(.url | test("spotify\\.com|music\\.youtube\\.com"))
    | .url
  ] | first // empty
' 2>/dev/null || true)

if [[ -n "$MATCHED_TAB" ]]; then
    SOURCE_HOST=$(echo "$MATCHED_TAB" | sed -E 's|^https?://([^/:]+).*|\1|')
else
    # Fallback: Identify active music platform by active player URL in CDP
    SOURCE_HOST=$(echo "$CDP_DATA" | jq -r '
      if any(.[]; (.type == "page" and (.url != null and (.url | test("music\\.youtube\\.com/watch"))))) then
        "music.youtube.com"
      elif any(.[]; (.type == "page" and (.url != null and (.url | test("open\\.spotify\\.com"))))) then
        "open.spotify.com"
      elif any(.[]; (.type == "page" and (.url != null and (.url | test("music\\.youtube\\.com"))))) then
        "music.youtube.com"
      else
        empty
      end
    ' 2>/dev/null || true)
fi

if [[ -z "$SOURCE_HOST" ]]; then
    exit 0
fi

# Set icon and CSS class based on source
if [[ "$SOURCE_HOST" == *"spotify.com"* ]]; then
    ICON=""
    CLASS="spotify"
    SOURCE_NAME="Spotify"
elif [[ "$SOURCE_HOST" == *"music.youtube.com"* ]]; then
    ICON="󰎆"
    CLASS="ytmusic"
    SOURCE_NAME="YouTube Music"
else
    exit 0
fi

# Format display text and tooltip
if [[ -n "$ARTIST" ]]; then
    DISPLAY_TEXT="${ICON} ${ARTIST} - ${TITLE}"
else
    DISPLAY_TEXT="${ICON} ${TITLE}"
fi

TOOLTIP="<b>${SOURCE_NAME}</b>\n<b>Title:</b> ${TITLE}\n<b>Artist:</b> ${ARTIST:-Unknown}\n<b>Album:</b> ${ALBUM:-Unknown}"

# Output JSON for Waybar
jq -nc \
  --arg text "$DISPLAY_TEXT" \
  --arg tooltip "$TOOLTIP" \
  --arg class "$CLASS" \
  '{"text": $text, "tooltip": $tooltip, "class": $class}'
