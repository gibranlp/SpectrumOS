#!/bin/bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 
# Waybar GPU Usage Script

# Get GPU usage
gpu_busy=$(cat /sys/class/drm/card1/device/gpu_busy_percent 2>/dev/null)
if [ -z "$gpu_busy" ]; then
    gpu_busy=$(cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null)
fi

# Get GPU temperature
gpu_temp=""
if command -v nvidia-smi &>/dev/null; then
    gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null)
else
    # Try AMD/Intel via hwmon
    for hwmon in /sys/class/drm/card*/device/hwmon/hwmon*; do
        if [ -f "$hwmon/temp1_input" ]; then
            gpu_temp=$(($(cat "$hwmon/temp1_input") / 1000))
            break
        fi
    done
fi

if [ -n "$gpu_busy" ]; then
    if [ -n "$gpu_temp" ]; then
        echo "{\"text\": \"󰾲 ${gpu_busy}%  ${gpu_temp}°C\", \"tooltip\": \"GPU Usage: ${gpu_busy}%\nGPU Temp: ${gpu_temp}°C\"}"
    else
        echo "{\"text\": \"󰾲 ${gpu_busy}%\", \"tooltip\": \"GPU Usage: ${gpu_busy}%\"}"
    fi
else
    echo "{\"text\": \"󰾲 N/A\", \"tooltip\": \"GPU not found\"}"
fi
