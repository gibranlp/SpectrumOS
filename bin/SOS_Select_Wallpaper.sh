#!/bin/bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 
#
# Wallpaper Selection Script

# Load configuration
CONFIG_FILE="/etc/spectrumos/spectrumos.conf"
[ ! -f "$CONFIG_FILE" ] && echo "Missing config" && exit 1
source "$CONFIG_FILE"

# --- Validate Wallpaper Directory -------------------------------------------
if [ -z "$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) 2>/dev/null)" ]; then
    notify-send "SpectrumOS" "No wallpapers found in $WALLPAPER_DIR" -u critical
    exit 1
fi

# --- Launch ROFI With Thumbnail Preview -------------------------------------
PREVIEW=true \
SELECTED=$(rofi \
    -show filebrowser \
    -filebrowser-directory "$WALLPAPER_DIR" \
    -filebrowser-command "echo" \
    -theme "$HOME/.config/rofi/SOS_Wallpaper.rasi" \
    -filebrowser-sorting-method mtime \
    -selected-row 1 \
    -filebrowser-show-hidden false \
    -filebrowser-disable-status true \
    -p "  Select Wallpaper"
)

# Exit on cancel
if [[ -z "$SELECTED" ]]; then
    exit 0
fi

# Full path of selected file  
WALLPAPER="$SELECTED"

# Save selected wallpaper
echo "$WALLPAPER" > "/var/lib/spectrumos/last_wallpaper"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Output processed wallpaper for Gowall  
GOWALL_OUTPUT="/var/lib/spectrumos/current.png"

if [ "$GOWALL_SCHEME" != "No Theme" ]; then
    if [ "$GOWALL_SCHEME" == "Inverted" ]; then
        gowall invert "$WALLPAPER" --output "$GOWALL_OUTPUT"
    else
        gowall convert "$WALLPAPER" -t "$GOWALL_SCHEME" --output "$GOWALL_OUTPUT"
    fi
else
    cp "$WALLPAPER" "$GOWALL_OUTPUT"
fi

# Set wallpaper with awww
awww img "$GOWALL_OUTPUT" --transition-type wave --transition-duration "$TRANSITION_DURATION"

# Set Colors with pywal
if [ "$PYWAL_LIGHT_SCHEME" = "Light" ]; then
    wal -l -i "$GOWALL_OUTPUT" --backend "$PYWAL_BACKEND"
else
    wal -i "$GOWALL_OUTPUT" --backend "$PYWAL_BACKEND"
fi 

# Set colors for GTK using wpgtk
if command -v wpg &>/dev/null; then
    wpg -a "$WALLPAPER"
    wpg -s "$WALLPAPER"
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

    # Update GTK4/libadwaita (GTK4 doesn't support themes, only CSS overrides)
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

# Send notification with thumbnail
notify-send -a "SpectrumOS" -t 2000 "Wallpaper changed!" -i "$WALLPAPER"