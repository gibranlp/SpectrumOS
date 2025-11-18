#!/usr/bin/env bash

# Wallpaper picker with pywal integration
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

# Make sure directory exists
mkdir -p "$WALLPAPER_DIR"

# Use rofi to select wallpaper with custom theme
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.png" \) | rofi -dmenu -i -p "Select Wallpaper" -theme ~/.config/rofi/theme.rasi)

if [ -n "$WALLPAPER" ]; then
    # Set wallpaper with swww
    swww img "$WALLPAPER" --transition-type fade --transition-duration 2
    
    # Generate colors with pywal
    wal -i "$WALLPAPER"
    
    # Restart waybar to apply colors (using systemd)
    systemctl --user restart waybar.service
    
    # Send notification
    notify-send "SpectrumOS" "Wallpaper and colors updated!" -i "$WALLPAPER"
fi