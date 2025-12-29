#!/bin/bash
# Weather script for Waybar
# Uses wttr.in for weather information

# Set your location (city name or coordinates)
LOCATION="PlayadelCarmen"  # Change this to your location

# Get weather data
weather_data=$(curl -sf "wttr.in/${LOCATION}?format=%c+%t")

if [ -z "$weather_data" ]; then
    echo '{"text":"","tooltip":"Weather unavailable"}'
    exit 0
fi

# Get detailed info for tooltip
tooltip=$(curl -sf "wttr.in/${LOCATION}?format=%C,+%t+(%f)\nHumidity:+%h\nWind:+%w\nPressure:+%P")

# Output JSON for waybar
echo "{\"text\":\"${weather_data}\",\"tooltip\":\"${tooltip}\"}"