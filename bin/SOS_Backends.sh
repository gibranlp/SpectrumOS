#!/bin/bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 
# Set Pywal Backend Script

ROFI_THEME="$HOME/.config/rofi/SOS_Left.rasi"

# Set pywal backend
set_pywal_backend() {
    local config_file="/etc/spectrumos/spectrumos.conf"
    local backends=("wal" "haishoku" "colorz" "colorthief")
    
    # Get current backend from config
    local current_backend
    current_backend=$(grep "^PYWAL_BACKEND=" "$config_file" | cut -d'"' -f2)
    
    # Build rofi options
    local options=""
    for backend in "${backends[@]}"; do
        options+="$backend\n"
    done
    
    # Show rofi menu
    local selected
    selected=$(echo -e "$options" | rofi -dmenu -theme "$ROFI_THEME" -p "🧑‍🎨 Current 👉🏻 ${current_backend^}")
    
    # Get exit code
    local exit_code=$?
    
    # Check if user cancelled (ESC or closed)
    if [[ $exit_code -ne 0 ]] || [[ -z "$selected" ]]; then
        exit 0
    fi

    # Validate selection against known-good list
    local valid=false
    for b in "${backends[@]}"; do
        [[ "$selected" == "$b" ]] && valid=true && break
    done
    if [[ "$valid" != true ]]; then
        notify-send -a "SpectrumOS" "Invalid backend selection" -u critical
        exit 1
    fi

    # Update config file
    sudo sed -i "s/^PYWAL_BACKEND=.*/PYWAL_BACKEND=\"$selected\"/" "$config_file"
    
    # Send notification
    notify-send -a "󰣇 SpectrumOS" \
                "Pywal Backend: " \
                " $selected"
}
# Set new colors with same wallpaper
function set_wallpaper(){
    # Load configuration
    CONFIG_FILE="/etc/spectrumos/spectrumos.conf"
    [ ! -f "$CONFIG_FILE" ] && echo "Missing config" && exit 1
    source "$CONFIG_FILE"

    # Get script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    GOWALL_OUTPUT="/var/lib/spectrumos/current.png"

    # Pywal
    if [ "$PYWAL_LIGHT_SCHEME" = "Light" ]; then
        wal -l -i "$GOWALL_OUTPUT" --backend "$PYWAL_BACKEND"
    else
        wal -i "$GOWALL_OUTPUT" --backend "$PYWAL_BACKEND"
    fi

    # Apply Colors and Update Configs
    "$SCRIPT_DIR/SOS_Apply_Colors.sh" "$GOWALL_OUTPUT"

    # Send notification with thumbnail
    notify-send -t 1000 "Color Scheme Updated!"
}


# Run the function
set_pywal_backend
set_wallpaper