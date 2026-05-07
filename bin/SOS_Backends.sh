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

    # Set colors for GTK using wpgtk
    if command -v wpg &>/dev/null; then
        wpg -a "$GOWALL_OUTPUT"
        wpg -s "$GOWALL_OUTPUT"
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

    awww img "$CURRENT_WALLPAPER" --transition-type wave --transition-duration "$TRANSITION_DURATION"

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

    pywalfox update &
    walogram -c &

    # Reload waybar

    pkill waybar
    waybar &

    # Send notification with thumbnail
    notify-send -t 1000 "Color Scheme Updated!"
}


# Run the function
set_pywal_backend
set_wallpaper