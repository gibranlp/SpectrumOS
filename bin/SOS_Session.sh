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
# Session Management Script

# Icons (same order as your Python script)
options=(
    "🔒 Lock"   # lock
    "💤 Suspend"   # suspend
    "🚪 Logout"   # logout
    "♻️ Reboot"   # reboot
    "🚫 Poweroff"   # poweroff
)

# Create a newline-separated list for rofi
menu="$(printf "%s\n" "${options[@]}")"

# Run rofi menu
choice=$(echo -e "$menu" | rofi -dmenu \
    -show-icons \
    -theme ~/.config/rofi/SOS_Right.rasi \
    -p " 🔌 Session")

# Exit if nothing selected
[[ -z "$choice" ]] && exit 0

# Determine index in array
for i in "${!options[@]}"; do
    if [[ "${options[$i]}" == "$choice" ]]; then
        index=$i
        break
    fi
done

# Perform action based on index
case "$index" in
    0) hyprlock ;;
    1) systemctl suspend ;;
    2) exit ;;
    3) systemctl reboot ;;
    4) systemctl poweroff ;;
esac
