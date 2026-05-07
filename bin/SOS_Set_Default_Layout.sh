#!/bin/bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 
# Set Current Layout as Default Script

HYPR_CONFIG="$HOME/.config/hypr/general.conf"
SPEC_CONFIG="/etc/spectrumos/spectrumos.conf"

# Get current layout from Hyprland config
CURRENT_LAYOUT=$(grep "layout =" "$HYPR_CONFIG" | awk '{print $3}')

if [ -z "$CURRENT_LAYOUT" ]; then
    notify-send -a "SpectrumOS" "Error" "Could not detect current layout" -u critical
    exit 1
fi

# 1. Update /etc/spectrumos/spectrumos.conf
if grep -q "^HYPR_LAYOUT=" "$SPEC_CONFIG" 2>/dev/null; then
    sudo sed -i "s/^HYPR_LAYOUT=.*/HYPR_LAYOUT=\"$CURRENT_LAYOUT\"/" "$SPEC_CONFIG"
else
    echo "HYPR_LAYOUT=\"$CURRENT_LAYOUT\"" | sudo tee -a "$SPEC_CONFIG" > /dev/null
fi

# 2. Update the project source if it exists (for dots.sh persistence)
# Find the project root by looking for dots.sh
PROJECT_ROOT=""
if [ -f "$HOME/SpectrumOS/dots.sh" ]; then
    PROJECT_ROOT="$HOME/SpectrumOS"
elif [ -f "$(dirname "$(dirname "$(readlink -f "$0")")")/dots.sh" ]; then
    PROJECT_ROOT="$(dirname "$(dirname "$(readlink -f "$0")")")"
fi

if [ -n "$PROJECT_ROOT" ]; then
    sed -i "s/layout = .*/layout = $CURRENT_LAYOUT/" "$PROJECT_ROOT/config/hypr/general.conf"
    notify-send -a "󰣇 SpectrumOS" "Layout Locked" "Current Layout Saved" -t 2000
else
    notify-send -a "󰣇 SpectrumOS" "Layout Locked" "Current Layout Saved" -t 2000
fi
