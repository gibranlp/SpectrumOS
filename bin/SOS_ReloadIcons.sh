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

# Function to pick closest Papirus color based on pywal color1
get_papirus_color() {
    local color="${color1#\#}"  # Remove # if present
    
    # Extract RGB values (simple approximation)
    local r=$((16#${color:0:2}))
    local g=$((16#${color:2:2}))
    local b=$((16#${color:4:2}))
    
    # Simple hue-based mapping
    if [ $r -gt $g ] && [ $r -gt $b ]; then
        if [ $g -gt $b ]; then
            echo "orange"
        else
            echo "red"
        fi
    elif [ $g -gt $r ] && [ $g -gt $b ]; then
        if [ $r -gt $b ]; then
            echo "yellow"
        else
            echo "green"
        fi
    elif [ $b -gt $r ] && [ $b -gt $g ]; then
        if [ $r -gt $g ]; then
            echo "violet"
        else
            echo "blue"
        fi
    else
        # Grayscale
        echo "grey"
    fi
}

PAPIRUS_COLOR=$(get_papirus_color)
papirus-folders -C "$PAPIRUS_COLOR" --theme Papirus-Dark