#!/usr/bin/env bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 
# 
# Audio Control Panel using Rofi

ROFI_THEME="$HOME/.config/rofi/SOS_Right.rasi"
FONT="Courier Prime Medium 13"

# Icons
ICON_VOL="󰕾"
ICON_MUTE="󰝟"
ICON_SINK="󰓃"
ICON_SOURCE="󰍬"
ICON_MIXER="󰓅"
ICON_BACK="󰕌"

# Get current status
get_volume() {
    pamixer --get-volume-human
}

get_sink_name() {
    pamixer --get-default-sink | awk -F '"' '{print $4}'
}

get_source_name() {
    pamixer --get-default-source | awk -F '"' '{print $4}'
}

# Submenu: Select Output (Sink)
select_output() {
    sinks=$(pamixer --list-sinks | tail -n +2 | awk -F '"' '{print $6 " | " $1}')
    current=$(get_sink_name)
    
    # Highlight current sink if possible (rofi doesn't easily support dynamic highlighting by text match in dmenu without -a)
    # But we can just show it in the prompt
    
    chosen=$(echo -e "$sinks\n$ICON_BACK Back" | rofi -dmenu -theme "$ROFI_THEME" -p "󰓃 Output" -font "$FONT")
    
    if [[ "$chosen" == "$ICON_BACK Back" ]] || [[ -z "$chosen" ]]; then
        main_menu
    else
        sink_id=$(echo "$chosen" | awk -F " | " '{print $NF}' | xargs)
        pactl set-default-sink "$sink_id"
        notify-send -a "Audio" "Output switched to:" "$(get_sink_name)"
        select_output
    fi
}

# Submenu: Select Input (Source)
select_input() {
    sources=$(pamixer --list-sources | tail -n +2 | awk -F '"' '{print $6 " | " $1}')
    
    chosen=$(echo -e "$sources\n$ICON_BACK Back" | rofi -dmenu -theme "$ROFI_THEME" -p "󰍬 Input" -font "$FONT")
    
    if [[ "$chosen" == "$ICON_BACK Back" ]] || [[ -z "$chosen" ]]; then
        main_menu
    else
        source_id=$(echo "$chosen" | awk -F " | " '{print $NF}' | xargs)
        pactl set-default-source "$source_id"
        notify-send -a "Audio" "Input switched to:" "$(get_source_name)"
        select_input
    fi
}

# Submenu: Adjust Volume
adjust_volume() {
    vol=$(get_volume)
    options="+5%\n-5%\nToggle Mute\n100%\n75%\n50%\n25%\n0%\n$ICON_BACK Back"
    
    chosen=$(echo -e "$options" | rofi -dmenu -theme "$ROFI_THEME" -p "󰕾 Vol: $vol" -font "$FONT")
    
    case "$chosen" in
        "+5%")
            pamixer -i 5
            adjust_volume
            ;;
        "-5%")
            pamixer -d 5
            adjust_volume
            ;;
        "Toggle Mute")
            pamixer -t
            adjust_volume
            ;;
        "100%")
            pamixer --set-volume 100
            adjust_volume
            ;;
        "75%")
            pamixer --set-volume 75
            adjust_volume
            ;;
        "50%")
            pamixer --set-volume 50
            adjust_volume
            ;;
        "25%")
            pamixer --set-volume 25
            adjust_volume
            ;;
        "0%")
            pamixer --set-volume 0
            adjust_volume
            ;;
        "$ICON_BACK Back")
            main_menu
            ;;
    esac
}

# Main Menu
main_menu() {
    vol=$(get_volume)
    sink=$(get_sink_name)
    source=$(get_source_name)
    
    # Truncate long names
    sink_short=$(echo "$sink" | cut -c1-30)
    source_short=$(echo "$source" | cut -c1-30)
    
    options="$ICON_VOL Volume: $vol\n$ICON_SINK Output: $sink_short\n$ICON_SOURCE Input: $source_short\n$ICON_MIXER Open Mixer (pavucontrol)"
    
    chosen=$(echo -e "$options" | rofi -dmenu -theme "$ROFI_THEME" -p "󰓃 Audio" -font "$FONT")
    
    case "$chosen" in
        *"Volume"*)
            adjust_volume
            ;;
        *"Output"*)
            select_output
            ;;
        *"Input"*)
            select_input
            ;;
        *"Mixer"*)
            pavucontrol &
            ;;
    esac
}

main_menu
