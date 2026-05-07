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

# Apply Colors and Update Configs
"$SCRIPT_DIR/SOS_Apply_Colors.sh" "$WALLPAPER"

# Send notification with thumbnail
notify-send -a "SpectrumOS" -t 2000 "Wallpaper changed!" -i "$WALLPAPER"