#!/bin/bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 
# Waybar Style Selector Script

ROFI_THEME="$HOME/.config/rofi/SOS_Left.rasi"
WAYBAR_STYLE_DIR="$HOME/.config/waybar/styles"
WAYBAR_SYMLINK="$HOME/.config/waybar/style.css"

# Set waybar style
set_waybar_style() {
    local config_file="/etc/spectrumos/spectrumos.conf"
    local styles=("default" "transparent" "floating" "minimal" "pills")
    
    # Get current style from config
    local current_style
    current_style=$(grep "^WAYBAR_STYLE=" "$config_file" 2>/dev/null | cut -d'"' -f2)
    
    # Default to default if not set
    if [[ -z "$current_style" ]]; then
        current_style="default"
    fi
    
    # Build rofi options with descriptions
    local options=""
    options+="default - Rounded Solid Modules\n"
    options+="transparent - Glass Effect with Blur\n"
    options+="floating - Separated with Shadows\n"
    options+="minimal - Flat Sharp Corners\n"
    options+="pills - Extra Rounded Colorful"
    
    # Show rofi menu
    local selected
    selected=$(echo -e "$options" | rofi -dmenu -theme "$ROFI_THEME" -p "🎨 Current 👉🏻 ${current_style^}" -i)
    
    # Get exit code
    local exit_code=$?
    
    # Check if user cancelled (ESC or closed)
    if [[ $exit_code -ne 0 ]] || [[ -z "$selected" ]]; then
        exit 0
    fi
    
    # Extract style name (before the dash)
    selected=$(echo "$selected" | awk '{print $1}')

    if [[ ! -f "$WAYBAR_STYLE_DIR/${selected}.css" ]]; then
        notify-send -a "SpectrumOS" "Waybar style not found: ${selected}.css" -u critical
        exit 1
    fi

    local valid_styles=("default" "transparent" "floating" "minimal" "pills")
    local valid=false
    for s in "${valid_styles[@]}"; do
        [[ "$selected" == "$s" ]] && valid=true && break
    done
    if [[ "$valid" != true ]]; then
        notify-send -a "SpectrumOS" "Invalid waybar style" -u critical
        exit 1
    fi

    # Update symlink
    ln -sf "$WAYBAR_STYLE_DIR/${selected}.css" "$WAYBAR_SYMLINK"
    
    # Update config file (create line if doesn't exist)
    if grep -q "^WAYBAR_STYLE=" "$config_file" 2>/dev/null; then
        sudo sed -i "s/^WAYBAR_STYLE=.*/WAYBAR_STYLE=\"$selected\"/" "$config_file"
    else
        echo "WAYBAR_STYLE=\"$selected\"" | sudo tee -a "$config_file" > /dev/null
    fi
    
    # Restart waybar
    pkill waybar
    waybar &
    
    # Send notification
    notify-send -a "󰣇 SpectrumOS" \
        "Waybar Style Changed" \
        "Style: ${selected^}"
}

# Run the function
set_waybar_style