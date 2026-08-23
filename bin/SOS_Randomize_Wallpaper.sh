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
sudo mkdir -p "$(dirname "$CURRENT_WALLPAPER")"
sudo chown -R $USER:$USER "$(dirname "$CURRENT_WALLPAPER")"

# Random wallpaper selection with fallback
LAST_WALLPAPER_FILE="/var/lib/spectrumos/last_wallpaper"
LAST_WALLPAPER=$(cat "$LAST_WALLPAPER_FILE" 2>/dev/null)

ALL_WALLPAPERS=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) 2>/dev/null)
if [ -z "$ALL_WALLPAPERS" ]; then
    echo "No wallpapers in $WALLPAPER_DIR, checking /usr/share/backgrounds"
    WALLPAPER_DIR="/usr/share/backgrounds"
    ALL_WALLPAPERS=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) 2>/dev/null)
fi

if [ -z "$ALL_WALLPAPERS" ]; then
    echo "Error: No wallpapers found in $WALLPAPER_DIR or /usr/share/backgrounds"
    # Create a solid color fallback if no images found
    WALLPAPER="/tmp/spectrumos_fallback.png"
    if [ ! -f "$WALLPAPER" ]; then
        convert -size 1920x1080 xc:"#130915" "$WALLPAPER"
    fi
else
    # Filter out last wallpaper if more than one wallpaper exists
    if [ -n "$LAST_WALLPAPER" ] && [ "$(echo "$ALL_WALLPAPERS" | wc -l)" -gt 1 ]; then
        WALLPAPER=$(echo "$ALL_WALLPAPERS" | grep -vxF "$LAST_WALLPAPER" | shuf -n 1)
    fi

    # Fallback if filtering failed or was skipped
    if [ -z "$WALLPAPER" ]; then
        WALLPAPER=$(echo "$ALL_WALLPAPERS" | shuf -n 1)
    fi
fi

# Save selected wallpaper
echo "$WALLPAPER" > "$LAST_WALLPAPER_FILE"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Gowall Process Wallpaper
if [ "$GOWALL_SCHEME" != "No Theme" ]; then
    if [ "$GOWALL_SCHEME" == "Inverted" ]; then
        gowall invert "$WALLPAPER" --output "$CURRENT_WALLPAPER" 
    else
        gowall convert "$WALLPAPER" -t "$GOWALL_SCHEME" --output "$CURRENT_WALLPAPER"
    fi 
else
    cp "$WALLPAPER" "$CURRENT_WALLPAPER"
fi

# Apply wallpaper
awww img "$CURRENT_WALLPAPER" --transition-type wave --transition-duration "$TRANSITION_DURATION"

# Pywal
if [ "$PYWAL_LIGHT_SCHEME" = "Light" ]; then
    wal -l -i "$CURRENT_WALLPAPER" --backend "$PYWAL_BACKEND"
else
    wal -i "$CURRENT_WALLPAPER" --backend "$PYWAL_BACKEND"
fi

# Apply Colors and Update Configs
"$SCRIPT_DIR/SOS_Apply_Colors.sh" "$CURRENT_WALLPAPER"

# Send notification with thumbnail
dunstify -a "SpectrumOS" -t 2000 "Wallpaper changed!" -i "$WALLPAPER"




