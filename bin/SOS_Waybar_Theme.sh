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

    # Get current theme from config
    local current_theme
    current_theme=$(grep "^WAYBAR_THEME=" "$config_file" 2>/dev/null | cut -d'"' -f2)

    # Default to productivity if not set
    if [[ -z "$current_theme" ]]; then
        current_theme="Productivity"
    fi

    # Build rofi options with descriptions
    local options=""
    options+="✅ Minimal\n"
    options+="🔊 Multimedia\n"
    options+="👷🏼‍♂ Productivity\n"
    options+="📋 Detailed\n"
    options+="👾 Gaming\n"
    options+="🚫 NoBar"

    # Show rofi menu
    local selected
    selected=$(echo -e "$options" | rofi -dmenu -theme "$ROFI_THEME" -p "󰕮 Current 👉🏻 ${current_theme^}" -i)

    # Get exit code
    local exit_code=$?

    # Check if user cancelled (ESC or closed)
    if [[ $exit_code -ne 0 ]] || [[ -z "$selected" ]]; then
        exit 0
    fi

    # Extract theme name (the second word after the emoji)
    selected=$(echo "$selected" | awk '{print $2}')

    if [[ ! -f "$WAYBAR_CONFIG_DIR/${selected}.json" ]]; then
        notify-send -a "SpectrumOS" "Waybar config not found: ${selected}.json" -u critical
        exit 1
    fi

    # Validate against known themes
    local valid_themes=("Minimal" "Multimedia" "Productivity" "Detailed" "Gaming" "NoBar")
    local valid=false
    for t in "${valid_themes[@]}"; do
        [[ "$selected" == "$t" ]] && valid=true && break
    done
    if [[ "$valid" != true ]]; then
        notify-send -a "SpectrumOS" "Invalid waybar theme" -u critical
        exit 1
    fi

    # Update symlink
    ln -sf "$WAYBAR_CONFIG_DIR/${selected}.json" "$WAYBAR_SYMLINK"

    # Update config file (create line if doesn't exist)
    if grep -q "^WAYBAR_THEME=" "$config_file" 2>/dev/null; then
        sudo sed -i "s/^WAYBAR_THEME=.*/WAYBAR_THEME=\"$selected\"/" "$config_file"
    else
        echo "WAYBAR_THEME=\"$selected\"" | sudo tee -a "$config_file" > /dev/null
    fi

    # Ensure CSS paths are correct for the current user
    find "$HOME/.config/waybar" -name "*.css" -exec sed -i "s|/home/[^/]*\.cache|$HOME/.cache|g" {} +

    # Restart waybar
    killall waybar 2>/dev/null
    sleep 0.5
    (waybar &) > /dev/null 2>&1

    # Send notification
    notify-send -a "󰣇 SpectrumOS" \
        "Waybar Theme Changed" \
        "Theme: ${selected^}"
}

# Run the function
set_waybar_theme