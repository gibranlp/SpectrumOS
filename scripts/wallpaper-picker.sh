#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
SDDM_WALLPAPER="/home/gibranlp/.cache/wal/sddm-wallpaper.jpg"

mkdir -p "$WALLPAPER_DIR"

WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.png" \) | rofi -dmenu -i -p "Select Wallpaper" -theme ~/.config/rofi/theme.rasi)

if [ -n "$WALLPAPER" ]; then
    # Set wallpaper with swww
    swww img "$WALLPAPER" --transition-type fade --transition-duration 2
    
    # Generate colors with pywal
    wal -i "$WALLPAPER"
    
    # Copy wallpaper for SDDM (with proper permissions)
    cp "$WALLPAPER" "$SDDM_WALLPAPER"
    chmod 644 "$SDDM_WALLPAPER"
    
    # Restart waybar
    systemctl --user restart waybar.service
    
    notify-send "SpectrumOS" "Wallpaper and colors updated!" -i "$WALLPAPER"
fi