#!/usr/bin/env bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 

ROFI_THEME="$HOME/.config/rofi/SOS_Recorder.rasi"
FONT="Courier Prime Medium 13"
VIDEO_DIR="$HOME/Videos"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$VIDEO_DIR"

# Check if recording is active
if pgrep -x "wf-recorder" > /dev/null; then
    CHOICE=$(echo -e "🛑 Stop Recording" | rofi -dmenu -theme "$ROFI_THEME" -p " Recorder Active " -font "$FONT" -lines 1)
    if [ "$CHOICE" == "🛑 Stop Recording" ]; then
        pkill -SIGINT wf-recorder
        notify-send -a 'Recorder' "Recording stopped and saved to $VIDEO_DIR"
    fi
    exit 0
fi

# Main Menu
OPTIONS="🖥️ Record Monitor\n📐 Record Area"
ACTION=$(echo -e "$OPTIONS" | rofi -dmenu -theme "$ROFI_THEME" -p " Screen Recorder " -font "$FONT" -lines 2)

case "$ACTION" in
    "🖥️ Record Monitor")
        # Get monitors with descriptions for better UI
        # Format: "Name: Description"
        MONITOR_LIST=$(hyprctl monitors -j | jq -r '.[] | "\(.name): \(.description)"')
        SELECTED_LINE=$(echo -e "$MONITOR_LIST" | rofi -dmenu -theme "$ROFI_THEME" -p " Select Monitor " -font "$FONT")
        
        if [ -n "$SELECTED_LINE" ]; then
            # Extract name (everything before the first colon)
            MONITOR_NAME=$(echo "$SELECTED_LINE" | cut -d':' -f1)
            notify-send -a 'Recorder' "Starting recording on $MONITOR_NAME..."
            wf-recorder -a -o "$MONITOR_NAME" -f "$VIDEO_DIR/recording_$TIMESTAMP.mp4" &
        fi
        ;;
        
    "📐 Record Area")
        GEOM=$(slurp)
        if [ -n "$GEOM" ]; then
            notify-send -a 'Recorder' "Starting area recording..."
            wf-recorder -a -g "$GEOM" -f "$VIDEO_DIR/recording_$TIMESTAMP.mp4" &
        fi
        ;;
esac
