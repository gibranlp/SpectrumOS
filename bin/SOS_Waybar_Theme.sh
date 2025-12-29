#!/bin/bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 
# Waybar Theme Selector Script

ROFI_THEME="$HOME/.config/rofi/SOS_Left.rasi"
WAYBAR_CONFIG_DIR="$HOME/.config/waybar/configs"
WAYBAR_SYMLINK="$HOME/.config/waybar/config"

# Set waybar theme
set_waybar_theme() {
    local config_file="/etc/spectrumos/spectrumos.conf"
    local themes=("minimal" "multimedia" "productivity" "detailed" "gaming")
    
    # Get current theme from config
    local current_theme
    current_theme=$(grep "^WAYBAR_THEME=" "$config_file" 2>/dev/null | cut -d'"' -f2)
    
    # Default to productivity if not set
    if [[ -z "$current_theme" ]]; then
        current_theme="productivity"
    fi
    
    # Build rofi options with descriptions
    local options=""
    options+="✅ Minimal\n"
    options+="🔊 Multimedia\n"
    options+="👷🏼‍♂ Productivity\n"
    options+="📋 Detailed\n"
    options+="👾 Gaming"
    
    # Show rofi menu
    local selected
    selected=$(echo -e "$options" | rofi -dmenu -theme "$ROFI_THEME" -p "󰕮 Current 👉🏻 ${current_theme^}" -i)
    
    # Get exit code
    local exit_code=$?
    
    # Check if user cancelled (ESC or closed)
    if [[ $exit_code -ne 0 ]] || [[ -z "$selected" ]]; then
        exit 0
    fi
    
    # Extract theme name (before the dash)
    selected=$(echo "$selected" | awk '{print $2}')
    
    # Update symlink
    ln -sf "$WAYBAR_CONFIG_DIR/${selected}.json" "$WAYBAR_SYMLINK"
    
    # Update config file (create line if doesn't exist)
    if grep -q "^WAYBAR_THEME=" "$config_file" 2>/dev/null; then
        sudo sed -i "s/^WAYBAR_THEME=.*/WAYBAR_THEME=\"$selected\"/" "$config_file"
    else
        echo "WAYBAR_THEME=\"$selected\"" | sudo tee -a "$config_file" > /dev/null
    fi
    
    # Restart waybar
    pkill waybar
    waybar &
    
    # Send notification
    notify-send -a "󰣇 SpectrumOS" \
        "Waybar Theme Changed" \
        "Theme: ${selected^}"
}

# Run the function
set_waybar_theme