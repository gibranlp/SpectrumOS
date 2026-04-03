#!/bin/bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 

source "$HOME/.cache/wal/colors.sh"

# Function to convert RGB to HSL and determine color
get_papirus_color() {
    local color="${color1#\#}"  # Remove # if present

    # Extract RGB values and normalize to 0-1
    local r=$((16#${color:0:2}))
    local g=$((16#${color:2:2}))
    local b=$((16#${color:4:2}))

    # Find min and max
    local max=$r
    [ $g -gt $max ] && max=$g
    [ $b -gt $max ] && max=$b

    local min=$r
    [ $g -lt $min ] && min=$g
    [ $b -lt $min ] && min=$b

    local delta=$((max - min))

    # Check for grayscale (low saturation)
    if [ $delta -lt 30 ]; then
        echo "grey"
        return
    fi

    # Calculate hue (approximate, in degrees 0-360)
    local hue=0
    if [ $max -eq $r ]; then
        # Red is max
        hue=$(( (60 * (g - b) / delta + 360) % 360 ))
    elif [ $max -eq $g ]; then
        # Green is max
        hue=$(( 60 * (b - r) / delta + 120 ))
    else
        # Blue is max
        hue=$(( 60 * (r - g) / delta + 240 ))
    fi

    # Map hue to Papirus colors
    # Red: 0-15, 345-360
    # Orange: 16-45
    # Yellow: 46-75
    # Green: 76-165
    # Cyan: 166-195 (using blue-grey as closest)
    # Blue: 196-255
    # Violet: 256-290
    # Magenta/Pink: 291-344 (using red as closest)

    if [ $hue -ge 0 ] && [ $hue -le 15 ]; then
        echo "red"
    elif [ $hue -ge 16 ] && [ $hue -le 45 ]; then
        echo "orange"
    elif [ $hue -ge 46 ] && [ $hue -le 75 ]; then
        echo "yellow"
    elif [ $hue -ge 76 ] && [ $hue -le 165 ]; then
        echo "green"
    elif [ $hue -ge 166 ] && [ $hue -le 195 ]; then
        echo "cyan"
    elif [ $hue -ge 196 ] && [ $hue -le 255 ]; then
        echo "blue"
    elif [ $hue -ge 256 ] && [ $hue -le 290 ]; then
        echo "violet"
    elif [ $hue -ge 291 ] && [ $hue -le 344 ]; then
        echo "red"
    else
        echo "red"
    fi
}

PAPIRUS_COLOR=$(get_papirus_color)
papirus-folders -C "$PAPIRUS_COLOR" --theme Papirus-Dark