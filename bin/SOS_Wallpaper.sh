#!/bin/bash
# SpectrumOS Wallpaper Picker with Rofi
# Shows wallpaper names, you can type to search

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

# Make sure directory exists
mkdir -p "$WALLPAPER_DIR"

# Check if wallpaper directory has images
if [ -z "$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) 2>/dev/null)" ]; then
    notify-send "SpectrumOS" "No wallpapers found in $WALLPAPER_DIR" -u critical
    exit 1
fi

# Get wallpaper files
WALLPAPERS=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -printf "%f\n" | sort)

# Use rofi to select (just filename for cleaner display)
SELECTED=$(echo "$WALLPAPERS" | rofi -dmenu -i -p "Select Wallpaper" -theme-str 'window {width: 50%;}' -theme-str 'listview {lines: 10;}')

# Exit if cancelled
if [ -z "$SELECTED" ]; then
    exit 0
fi

# Get full path
WALLPAPER="$WALLPAPER_DIR/$SELECTED"



# Make sure swww daemon is running
if ! pgrep -x swww-daemon > /dev/null; then
    swww-daemon &
    sleep 1
fi

# Set wallpaper with swww
swww img "$WALLPAPER" --transition-type outer --transition-duration 3

# Generate colors with pywal
wal -i "$WALLPAPER"

#Copy Wallpaper for SDDM
rm /var/lib/spectrumos/current.jpg
rm /var/lib/spectrumos/colors.conf 
cp -v "$WALLPAPER" /var/lib/spectrumos/current.jpg
# Copy Colors generated for sddm
cp $HOME/.cache/wal/sddm-colors.conf /var/lib/spectrumos/colors.conf

# Restart waybar to apply colors
killall waybar
waybar &

# Update Dunst Colors
cp $HOME/.cache/wal/dunstrc $HOME/.config/dunst/dunstrc
pkill dunst
dunst &

# Update pywalfox
pywalfox update

# Update Telegram
walogram -c 

# Send notification with thumbnail
notify-send "Wallpaper and colors updated!" -i "$WALLPAPER"
# Update Hyprland colors
hyprctl reload