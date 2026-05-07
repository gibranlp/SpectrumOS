#!/bin/bash
# SpectrumOS - Waybar FPS Counter
# Uses hyprctl to get the current refresh rate of the active monitor

fps=$(hyprctl -j monitors | jq '.[] | select(.focused == true) | .refreshRate' | cut -d. -f1)

if [ -n "$fps" ]; then
    echo "{\"text\": \"󰐐 ${fps} FPS\", \"tooltip\": \"Current Refresh Rate: ${fps} Hz\"}"
else
    echo "{\"text\": \"󰐐 N/A\", \"tooltip\": \"Unable to fetch FPS\"}"
fi
