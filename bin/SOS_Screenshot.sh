#!/usr/bin/env bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 

ROFI_THEME="$HOME/.config/rofi/SOS_Right.rasi"
FONT="Courier Prime Medium 13"
SCREENSHOT_DIR="$HOME/Pictures"

# Create screenshot directory if it doesn't exist
mkdir -p "$SCREENSHOT_DIR"

# Screenshot options
OPTIONS=" 📐 Area\n 🖥️ Screen\n 🪟 Window\n ⏲️ 5s Screen"

# Show rofi menu
CHOICE=$(echo -e "$OPTIONS" | rofi -dmenu -theme "$ROFI_THEME" -p "  Screenshot: " -font "$FONT" -lines 4)

# Handle user choice
case "$CHOICE" in
    " 📐 Area")
        # Area screenshot with editing
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        TEMP_FILE="/tmp/screenshot_$TIMESTAMP.png"
        
        grim -g "$(slurp)" "$TEMP_FILE" && \
        swappy -f "$TEMP_FILE" -o "$SCREENSHOT_DIR/area_screenshot_$TIMESTAMP.png" && \
        notify-send -a 'Screenshot' "Area screenshot saved!" && \
        rm -f "$TEMP_FILE"
        ;;
        
    " 🖥️ Screen")
        # Full screen screenshot
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        sleep 0.5
        
        grim "$SCREENSHOT_DIR/screenshot_$TIMESTAMP.png" && \
        notify-send -a 'Screenshot' "Screen screenshot saved!"
        ;;
        
    " 🪟 Window")
        # Window screenshot
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        TEMP_FILE="/tmp/window_screenshot_$TIMESTAMP.png"
        
        # Get active window geometry
        WINDOW_GEOM=$(hyprctl -j activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
        
        sleep 0.2
        grim -g "$WINDOW_GEOM" "$TEMP_FILE" && \
        swappy -f "$TEMP_FILE" -o "$SCREENSHOT_DIR/window_screenshot_$TIMESTAMP.png" && \
        notify-send -a 'Screenshot' "Window screenshot saved!" && \
        rm -f "$TEMP_FILE"
        ;;
        
    " 5s Screen")
        # 5 second delayed screenshot
        notify-send -a 'Screenshot' "Screenshot in 5 seconds..."
        sleep 5
        
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        grim "$SCREENSHOT_DIR/screenshot_$TIMESTAMP.png" && \
        notify-send -a 'Screenshot' "Screenshot taken!"
        ;;
        
    *)
        # User cancelled
        exit 0
        ;;
esac