#!/bin/bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 
#                         |___|           |___|    
# SpectrumOS - Password Generator Widget

# Password Parameters
PW_LENGTH=10
CHARS='A-Za-z0-9@#+=_!?'

generate_pw() {
  tr -dc "$CHARS" < /dev/urandom | head -c $PW_LENGTH
  echo
}

ROFI_THEME="${ROFI_THEME:-$HOME/.config/rofi/SOS_Right.rasi}"

menu="rofi -dmenu -theme $ROFI_THEME -p 🔑  PassGen -i"
actions="Regenerate"

pw=$(generate_pw)
while true; do
    choice=$(echo -e "$actions" | $menu -mesg "$pw")
    
    case "$choice" in
        "Regenerate")
            pw=$(generate_pw)
            ;;
        "Copy"|"")
            echo -n "$pw" | xsel -ib
            notify-send -a "󰟵 PassGen" "$pw copied"
            break
            ;;
    esac
done