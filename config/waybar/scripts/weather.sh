#!/bin/bash
# Waybar Weather Script
# Automatic location via wttr.in (IP-based)

# ---------- CONFIG ----------
CACHE_FILE="/tmp/waybar_weather_cache.json"
CACHE_TIME=3600    # 5 minutes
TIMEOUT=10
# ----------------------------

# Check cache
if [ -f "$CACHE_FILE" ]; then
    CACHE_AGE=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)))
    if [ "$CACHE_AGE" -lt "$CACHE_TIME" ]; then
        cat "$CACHE_FILE"
        exit 0
    fi
fi

# Fetch main weather (icon + temperature)
weather_data=$(curl -sf --max-time "$TIMEOUT" \
    "https://wttr.in/?format=%c+%t" 2>/dev/null)

# Fallback if main request fails
if [ -z "$weather_data" ]; then
    if [ -f "$CACHE_FILE" ]; then
        cat "$CACHE_FILE"
        exit 0
    fi
    echo '{"text":"","tooltip":"Weather unavailable"}'
    exit 0
fi

# Fetch detailed tooltip
tooltip=$(curl -sf --max-time "$TIMEOUT" \
"https://wttr.in/?format=%l\n%C,+%t+(feels+like+%f)\nHumidity:+%h\nWind:+%w\nPressure:+%P" \
2>/dev/null)

# Tooltip fallback
[ -z "$tooltip" ] && tooltip="$weather_data"

# Build JSON safely
output=$(jq -nc \
    --arg text "$weather_data" \
    --arg tooltip "$tooltip" \
    '{text:$text, tooltip:$tooltip}')

# Output + cache
echo "$output" | tee "$CACHE_FILE"
