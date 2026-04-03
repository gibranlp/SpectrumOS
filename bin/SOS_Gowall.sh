#!/bin/bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 
# Set Gowall Theme Script

ROFI_THEME="$HOME/.config/rofi/SOS_Left.rasi"

# Set default Gowal Theme for Wallpaper
set_default_wall_theme() {
    local config_file="/etc/spectrumos/spectrumos.conf"
    local wall_theme=(
    "No Theme"
    "arcdark"
    "atomdark"
    "cat-frappe"
    "cat-latte"
    "catppuccin"
    "cyberpunk"
    "dracula"
    "everforest"
    "github-light"
    "gruvbox"
    "kanagawa"
    "material"
    "melange-dark"
    "melagne-light"
    "monokai"
    "night-owl"
    "nord"
    "oceanic-next"
    "onedark"
    "palenight"
    "rosepine"
    "shades-of-purple"
    "solarized"
    "srcery"
    "sunset-aurant"
    "sunset-saffron"
    "sunset-tangerine"
    "synthwave-84"
    "tokyo-dark"
    "tokyo-moon"
    "tokyo-storm")
    
    # Get current theme from config
    local def_wall_theme
    def_wall_theme=$(grep "^GOWALL_SCHEME=" "$config_file" | cut -d'"' -f2)
    
    # Build rofi options
    local options=""
    for theme in "${wall_theme[@]}"; do
        options+="$theme\n"
    done
    
    # Show rofi menu
    local selected
    selected=$(echo -e "$options" | rofi -dmenu -theme "$ROFI_THEME" -p "🌈 Current 👉🏻 ${def_wall_theme^}")
    
    # Get exit code
    local exit_code=$?
    
    # Check if user cancelled (ESC or closed)
    if [[ $exit_code -ne 0 ]] || [[ -z "$selected" ]]; then
        exit 0
    fi

    # Validate selection against known-good list
    local valid=false
    for t in "${wall_theme[@]}"; do
        [[ "$selected" == "$t" ]] && valid=true && break
    done
    if [[ "$valid" != true ]]; then
        notify-send -a "SpectrumOS" "Invalid theme selection" -u critical
        exit 1
    fi

    # Update config file
    sudo sed -i "s/^GOWALL_SCHEME=.*/GOWALL_SCHEME=\"$selected\"/" "$config_file"
    
    # Send notification
    notify-send -a "󰣇 SpectrumOS" \
                "Wallpaper Theme: " \
                " $selected"
}

# Set new colors with same wallpaper
function set_wallpaper(){
    # Load configuration
    CONFIG_FILE="/etc/spectrumos/spectrumos.conf"
    [ ! -f "$CONFIG_FILE" ] && echo "Missing config" && exit 1
    source "$CONFIG_FILE"

    # Gowall Process Wallpaper
    if [ "$GOWALL_SCHEME" != "No Theme" ]; then
        if [ "$GOWALL_SCHEME" == "Inverted" ]; then
            gowall invert /var/lib/spectrumos/current.png --output /var/lib/spectrumos/current.png 
        else
            gowall convert /var/lib/spectrumos/current.png  -t "$GOWALL_SCHEME" --output /var/lib/spectrumos/current.png 
        fi 
    else
        notify-send "No Theme Selected!"
    fi
    
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
    notify-send -t 1000 "Theme Updated!"

    /usr/share/spectrumos/scripts/SOS_Regenerate.sh

}

# Run the function
set_default_wall_theme
set_wallpaper