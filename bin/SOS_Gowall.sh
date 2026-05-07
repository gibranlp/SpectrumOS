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
    "melange-light"
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

    # Get script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Read original (pre-gowall) wallpaper path
    ORIGINAL_WALLPAPER=$(cat /var/lib/spectrumos/last_wallpaper 2>/dev/null)
    if [ -z "$ORIGINAL_WALLPAPER" ] || [ ! -f "$ORIGINAL_WALLPAPER" ]; then
        notify-send -a "SpectrumOS" "No wallpaper selected yet" -u critical
        exit 1
    fi

    # Gowall Process Wallpaper (always from original to avoid filter stacking)
    if [ "$GOWALL_SCHEME" != "No Theme" ]; then
        if [ "$GOWALL_SCHEME" == "Inverted" ]; then
            gowall invert "$ORIGINAL_WALLPAPER" --output "$CURRENT_WALLPAPER"
        else
            gowall convert "$ORIGINAL_WALLPAPER" -t "$GOWALL_SCHEME" --output "$CURRENT_WALLPAPER"
        fi
    else
        cp "$ORIGINAL_WALLPAPER" "$CURRENT_WALLPAPER"
    fi

    # Apply wallpaper
    awww img "$CURRENT_WALLPAPER" --transition-type wave --transition-duration "$TRANSITION_DURATION"

    # Pywal
    if [ "$PYWAL_LIGHT_SCHEME" = "Light" ]; then
        wal -l -i "$CURRENT_WALLPAPER" --backend "$PYWAL_BACKEND"
    else
        wal -i "$CURRENT_WALLPAPER" --backend "$PYWAL_BACKEND"
    fi

    # Set colors for GTK using wpgtk
    if command -v wpg &>/dev/null; then
        wpg -a /var/lib/spectrumos/current.png
        wpg -s /var/lib/spectrumos/current.png
        gsettings set org.gnome.desktop.interface gtk-theme "FlatColor"
        gsettings set org.gnome.desktop.interface icon-theme "flattrcolor-dark"
        gsettings set org.gnome.desktop.wm.preferences theme "FlatColor"
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

        # Update GTK3 settings.ini
        mkdir -p "$HOME/.config/gtk-3.0"
        cat > "$HOME/.config/gtk-3.0/settings.ini" << EOF
[Settings]
gtk-icon-theme-name = flattrcolor-dark
gtk-theme-name = FlatColor
gtk-font-name = Sans 10
gtk-cursor-theme-name = Adwaita
gtk-application-prefer-dark-theme = true
EOF

        # Update GTK4/libadwaita
        mkdir -p "$HOME/.config/gtk-4.0"
        if [ -f "$HOME/.cache/wal/gtk4-libadwaita.css" ]; then
            [ -L "$HOME/.config/gtk-4.0/gtk.css" ] && rm "$HOME/.config/gtk-4.0/gtk.css"
            cp "$HOME/.cache/wal/gtk4-libadwaita.css" "$HOME/.config/gtk-4.0/gtk.css"
        fi
    fi

    # Update xsettingsd
    pkill -HUP xsettingsd

    # Update configs
    python "$SCRIPT_DIR/SOS_Gen_Logo.py"
    rm -f /var/lib/spectrumos/colors.conf
    cp "$HOME/.cache/wal/sddm-colors.conf" /var/lib/spectrumos/colors.conf

    mkdir -p "$HOME/.config/dunst"
    mkdir -p "$HOME/.config/cava"
    cp "$HOME/.cache/wal/dunstrc" "$HOME/.config/dunst/dunstrc"
    pkill dunst; dunst &

    cp "$HOME/.cache/wal/cava-config" "$HOME/.config/cava/config"
    pkill -USR1 cava

    [ -f "$HOME/.cache/wal/cmus-theme" ] && cp "$HOME/.cache/wal/cmus-theme" "$HOME/.config/cmus/SpectrumOS.theme"

    "$SCRIPT_DIR/SOS_PywalBrave.sh" &
    "$SCRIPT_DIR/SOS_PywalQT.sh" &
    "$SCRIPT_DIR/SOS_PywalVesktop.sh" &
    "$SCRIPT_DIR/SOS_PywalVSCode.sh" &
    "$SCRIPT_DIR/SOS_PywalVivaldi.sh" &

    pywalfox update &
    walogram -c &

    # Reload waybar
    killall -SIGUSR2 waybar 2>/dev/null || (killall waybar 2>/dev/null; sleep 0.5; waybar &)

    # Send notification
    notify-send -a "SpectrumOS" -t 2000 "Theme Updated!"
}

# Run the function
set_default_wall_theme
set_wallpaper