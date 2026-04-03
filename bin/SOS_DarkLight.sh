#!/bin/bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 
# Set Dark/Light Theme Script

ROFI_THEME="$HOME/.config/rofi/SOS_Left.rasi"
set_pywal_scheme() {
    local config_file="/etc/spectrumos/spectrumos.conf"
    local schemes=("Dark" "Light")
    
    # Get current scheme from config
    local current_scheme
    current_scheme=$(grep "^PYWAL_LIGHT_SCHEME=" "$config_file" | cut -d'"' -f2)
    
    # Build rofi options
    local options=""
    for scheme in "${schemes[@]}"; do
        options+="$scheme\n"
    done
    
    # Show rofi menu
    local selected
    selected=$(echo -e "$options" | rofi -dmenu -theme "$ROFI_THEME" -p "🌓 Current 👉🏻 ${current_scheme}")
    
    # Get exit code
    local exit_code=$?
    
    # Check if user cancelled (ESC or closed)
    if [[ $exit_code -ne 0 ]] || [[ -z "$selected" ]]; then
        exit 0
    fi

    # Validate selection against known-good list
    local valid=false
    for s in "${schemes[@]}"; do
        [[ "$selected" == "$s" ]] && valid=true && break
    done
    if [[ "$valid" != true ]]; then
        notify-send -a "SpectrumOS" "Invalid scheme selection" -u critical
        exit 1
    fi

    # Update config file
    sudo sed -i "s/^PYWAL_LIGHT_SCHEME=.*/PYWAL_LIGHT_SCHEME=\"$selected\"/" "$config_file"
    
    # Send notification
    notify-send -a "󰣇 SpectrumOS" \
                "Pywal Scheme: " \
                " $selected"
}

# Set new colors with same wallpaper
function set_wallpaper(){
    # Load configuration
    CONFIG_FILE="/etc/spectrumos/spectrumos.conf"
    [ ! -f "$CONFIG_FILE" ] && echo "Missing config" && exit 1
    source "$CONFIG_FILE"
    
    # Apply wallpaper
    awww img "$CURRENT_WALLPAPER" --transition-type wave --transition-duration "$TRANSITION_DURATION"

    # Pywal
    if [ "$PYWAL_LIGHT_SCHEME" = "Light" ]; then
        wal -l -i "$CURRENT_WALLPAPER" --backend "$PYWAL_BACKEND"
    else
        wal -i "$CURRENT_WALLPAPER" --backend "$PYWAL_BACKEND"
    fi

    # Update configs
    python /usr/share/spectrumos/scripts/SOS_Gen_Logo.py
    rm -f /var/lib/spectrumos/colors.conf
    cp "$HOME/.cache/wal/sddm-colors.conf" /var/lib/spectrumos/colors.conf

    mkdir -p "$HOME/.config/dunst"
    mkdir -p "$HOME/.config/cava"
    cp "$HOME/.cache/wal/dunstrc" "$HOME/.config/dunst/dunstrc"
    pkill dunst; dunst &

    cp "$HOME/.cache/wal/cava-config" "$HOME/.config/cava/config"
    pkill -USR1 cava

    pywalfox update
    walogram -c

    pkill xsettingsd
    xsettingsd &

    hyprctl reload

    # restart waybar last
    pkill waybar
    waybar &

    # Send notification with thumbnail
    notify-send "Theme Updated!"

    /usr/share/spectrumos/scripts/SOS_Regenerate.sh

}

# Run the function
set_pywal_scheme
set_wallpaper