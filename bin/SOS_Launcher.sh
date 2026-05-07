#!/bin/bash
# _____             _                 _____ _____
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence
#
# Smart launcher: opens apps via drun, URLs in Vivaldi

SELF="$(readlink -f "$0")"

if [ "$1" = "--run" ]; then
    input="$2"
    if echo "$input" | grep -qiE '^(https?|ftp)://|^www\.|^[a-zA-Z0-9][a-zA-Z0-9-]*(\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,6}(/.*)?$'; then
        [[ "$input" != *"://"* ]] && input="https://$input"
        vivaldi "$input" &
    else
        eval "$input" &
    fi
else
    rofi -show combi \
        -modes "drun,run,combi" \
        -combi-modes "drun,run" \
        -show-icons \
        -theme "~/.config/rofi/SOS_Left.rasi" \
        -display-drun "󱓞" \
        -display-run "󰖟" \
        -display-combi "󱓞" \
        -run-command "\"$SELF\" --run {cmd}"
fi
