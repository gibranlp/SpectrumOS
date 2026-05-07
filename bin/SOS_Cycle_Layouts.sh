#!/bin/bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 
# Cycle Hyprland Layouts Script

CONFIG_FILE="$HOME/.config/hypr/general.conf"

# Get current layout
CURRENT_LAYOUT=$(grep "layout =" "$CONFIG_FILE" | awk '{print $3}')

if [ "$CURRENT_LAYOUT" == "dwindle" ]; then
    NEW_LAYOUT="master"
    ICON="󰕰"
else
    NEW_LAYOUT="dwindle"
    ICON="󰕯"
fi

# Update config file
sed -i "s/layout = .*/layout = $NEW_LAYOUT/" "$CONFIG_FILE"

# Apply changes
hyprctl reload

# Notify
notify-send -a "󰣇 SpectrumOS" "Layout Changed" "Current Layout: $NEW_LAYOUT $ICON" -t 1000
