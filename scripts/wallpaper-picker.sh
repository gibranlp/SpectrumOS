#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
SDDM_WALLPAPER="/usr/share/sddm/wallpapers/current.jpg"
SDDM_COLORS="/var/lib/sddm/.cache/spectrum/Colors.qml"

mkdir -p "$WALLPAPER_DIR"
# This is with sudo, run it separatedly
mkdir -p "SDDM_WALLPAPER"
mkdir -p "SDDM_COLORS"

chmod 777 "$SDDM_WALLPAPER"
chmod 777 "$SDDM_COLORS"


WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.png" \) | rofi -dmenu -i -p "Select Wallpaper" -theme ~/.config/rofi/theme.rasi)

if [ -n "$WALLPAPER" ]; then
    swww img "$WALLPAPER" --transition-type fade --transition-duration 2
    wal -i "$WALLPAPER"
    
    # Copy to system location (needs sudo)
    cp "$WALLPAPER" "$SDDM_WALLPAPER"
    chmod 644 "$SDDM_WALLPAPER"

    # Copy colors for SDDM
    cp ~/.cache/wal/colors-sddm.qml "$SDDM_COLORS"
    chmod 644 "$SDDM_COLORS"

    systemctl --user restart waybar.service
    notify-send "SpectrumOS" "Wallpaper and colors updated!" -i "$WALLPAPER"
fi