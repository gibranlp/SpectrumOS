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
#
# Check if rofi or dmenu is installed and set the menu command accordingly
if [[ -n $(command -v rofi) ]]; then
    menu="$(command -v rofi) -dmenu -theme ~/.config/rofi/SOS_Calc.rasi"
elif [[ -n $(command -v dmenu) ]]; then
    menu="$(command -v dmenu)"
else
    # Exit if neither rofi nor dmenu is found
    echo >&2 "Rofi or dmenu not found"
    exit
fi

# Define example operations
# Define example operations
examples="Examples:\n5 + 3\n2 min + 30 s\n2^10\nsqrt(16)\n60 mph -> m/s\n15 km/h * 30 min\ntoCelsius(70 K)"

# Show a menu to input the calculation or select an example
input=$(echo -e "$examples" | $menu -i -p " ")

# Handle the case where the user selects an example
case $input in
    "5 + 3")
        input="5 + 3"
        ;;
    "2 min + 30 s")
        input="2 min + 30 s"
        ;;
    "2^10")
        input="2^10"
        ;;
    "sqrt(16)")
        input="sqrt(16)"
        ;;
    "60 mph -> m/s")
        input="60 mph -> m/s"
        ;;
    "15 km/h * 30 min")
        input="15 km/h * 30 min"
        ;;
    "toCelsius(70 K)")
        input="toCelsius(70 K)"
        ;;
    "Examples:"|"")
        exit
        ;;
esac


# Pass the input to insect to get the calculation result
answer=$(echo "$input" | insect)

# Notify the user with the result using notify-send
notify-send -a "Calculator" "$input  $answer"

# Show a menu with options to copy or clear the result
action=$(echo -e "Copy\nClear" | $menu -i -p " $answer")

# Perform actions based on the selected menu option
case $action in
    "Clear")
        # Restart the script if "Clear" is selected
        $0
        ;;
    "Copy")
        # Copy the result to the clipboard if "Copy" is selected
        echo -n $answer | awk '{$1=$1};1' | xsel -ib
        ;;
    *)
        # Pass the result and selected action as arguments if other options are selected
        $0 "$answer $action"
        ;;
esac
