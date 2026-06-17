#!/usr/bin/env bash
# SpectrumOS Screen Recorder

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
        # Get monitors
        MONITORS=$(hyprctl monitors -j | jq -r '.[] | .name')
        MONITOR_CHOICE=$(echo -e "$MONITORS" | rofi -dmenu -theme "$ROFI_THEME" -p " Select Monitor " -font "$FONT")
        
        if [ -n "$MONITOR_CHOICE" ]; then
            notify-send -a 'Recorder' "Starting recording on $MONITOR_CHOICE..."
            wf-recorder -a -o "$MONITOR_CHOICE" -f "$VIDEO_DIR/recording_$TIMESTAMP.mp4" &
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
