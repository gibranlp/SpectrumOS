#!/bin/bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
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

# Ensure directories exist
mkdir -p "$WALLPAPER_DIR"
sudo mkdir -p "$(dirname "$GOWALL_OUTPUT")"
sudo chown -R $USER:$USER "$(dirname "$GOWALL_OUTPUT")"

# Random wallpaper selection with fallback
SELECTED=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -printf "%f\n" | shuf -n 1)

if [ -z "$SELECTED" ]; then
    echo "No wallpapers in $WALLPAPER_DIR, checking /usr/share/backgrounds"
    SELECTED=$(find /usr/share/backgrounds -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -printf "%f\n" | shuf -n 1)
    WALLPAPER_DIR="/usr/share/backgrounds"
fi

if [ -z "$SELECTED" ]; then
    echo "Error: No wallpapers found in $WALLPAPER_DIR or /usr/share/backgrounds"
    # Create a solid color fallback if no images found
    WALLPAPER="/tmp/spectrumos_fallback.png"
    convert -size 1920x1080 xc:"#130915" "$WALLPAPER"
else
    WALLPAPER="$WALLPAPER_DIR/$SELECTED"
fi

# Gowall Process Wallpaper
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

# Apply wallpaper
swww img "$CURRENT_WALLPAPER" --transition-type wave --transition-duration "$TRANSITION_DURATION"

# Pywal
if [ "$PYWAL_LIGHT_SCHEME" = "Light" ]; then
    wal -l -i "$GOWALL_OUTPUT" --backend "$PYWAL_BACKEND"
else
    wal -i "$GOWALL_OUTPUT" --backend "$PYWAL_BACKEND"
fi

# Update configs
python /usr/share/spectrumos/scripts/SOS_Gen_Logo.py
rm -f /var/lib/spectrumos/colors.conf
cp "$HOME/.cache/wal/sddm-colors.conf" /var/lib/spectrumos/colors.conf

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
dunstify -a "SpectrumOS" -t 1000 "Wallpaper and colors updated!" -i "$WALLPAPER"

/usr/share/spectrumos/scripts/SOS_Regenerate.sh




