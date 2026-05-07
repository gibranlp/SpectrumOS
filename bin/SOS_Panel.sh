#!/bin/bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 
# Control Panel Script  

# Paths
HOME_DIR="$HOME"
ROFI_THEME="$HOME/.config/rofi/SOS_Left.rasi"

# Menu entries (must match Python index numbering)
options=(    
"🚀 App Launcher (💠 + D)" #0
"🔐 App Launcher as Sudo (💠 + U)" #1
"🪟 Special WorkSpaces" #2
"🖼️ Wallpaper Options" #3
"    🎲 Set Random Wallpaper (💠 + R)" #4
"    🖼️ Select Wallpaper (💠 + W)" #5
"🎨 Theme Options" #6
"    🌈 Set Gowall Theme" #7
"    🧑‍🎨 Select Pywal Backend" #8
"    🌓 Dark/Light Theme" #9
"🧼 Waybar Options" #10
"    🎭 Select Waybar Theme" #11
"     🎨 Select Waybar Style" #12
"🛠️ Tools" #13
"    🔍 Search Files & Folders (💠 + S)" #14
"    🧮 Calculator (💠 + C)" #15
"    📡 Network Manager (💠 + B)" #16
"    🔵 Bluetooth Manager (💠 + ⬆️ + B)" #17
"    🔊 Audio Manager (💠 + A)" #18
"    🔑 Password Generator (💠 + G)" #19
"    📸 Screenshot (prtnsc)" #20
"    ⚡ Power Profiles" #21
"    🔄 Update Base System" #22
"    🧽 System Cleaner" #23
"    🌡️ Monitor Temperature (💠 + ⬆️ + O)" #24
"📦 Miscellaneous" #25
"    ✏️ Screen Draw" #26
"    🎨 Pick Color" #27
"    😀 Emojis (💠 + V)" #28
"🔌 Session Menu (💠 + X)" #29
"💖 Support SpectrumOS" #30
)

# Show menu
choice=$(printf "%s\n" "${options[@]}" | rofi -dmenu -i -p "🎨 SpectrumOS" -theme "$ROFI_THEME")
index=$(printf "%s\n" "${options[@]}" | grep -n -F "$choice" | cut -d: -f1)
index=$((index - 1))   # Convert to zero-based index like Python

# No selection
[ -z "$choice" ] && exit 0

# Actions (mirror Python if/elif)
case $index in
    # App launchers
    0) rofi -show drun -show-icons -theme "~/.config/rofi/SOS_Left.rasi" -display-drun "🔍" ;;
    1) rofi -show drun -run-command "pkexec {cmd}" -theme "~/.config/rofi/SOS_Left.rasi" ;;

    # Wallpaper Options
    4)  /usr/share/spectrumos/scripts/SOS_Randomize_Wallpaper.sh;;
    5)  /usr/share/spectrumos/scripts/SOS_Select_Wallpaper.sh;;
    
    # Theme Options
    7)  /usr/share/spectrumos/scripts/SOS_Gowall.sh;;
    8)  /usr/share/spectrumos/scripts/SOS_Backends.sh;;
    9)  /usr/share/spectrumos/scripts/SOS_DarkLight.sh ;;

    # Waybar Options
    11) /usr/share/spectrumos/scripts/SOS_Waybar_Theme.sh ;;
    12) /usr/share/spectrumos/scripts/SOS_Waybar_Style.sh ;;
    
    # Tools
    14) /usr/share/spectrumos/scripts/SOS_Search.sh ;;
    15) /usr/share/spectrumos/scripts/SOS_Calculator.sh ;;
    16) /usr/share/spectrumos/scripts/SOS_Wifi.sh ;;
    17) /usr/share/spectrumos/scripts/SOS_Bluetooth.sh ;;
    18) /usr/share/spectrumos/scripts/SOS_Audio.sh ;;
    19) /usr/share/spectrumos/scripts/SOS_Pass_Generator.sh ;;
    20) /usr/share/spectrumos/scripts/SOS_Screenshot.sh ;;
    21) /usr/share/spectrumos/scripts/SOS_Power.sh ;;
    22) /usr/share/spectrumos/scripts/SOS_UpdateBase.sh ;;
    23) /usr/share/spectrumos/scripts/SOS_CleanSystem.sh ;;
    24) kitty -e btop ;; # Monitor temperature
    
    # Miscellaneous
    26) gromit-mpx ;; # Screen Draw
    27) sleep 0.2 && COLOR=$(hyprpicker -r) && echo "$COLOR" | wl-copy && HEX="${COLOR#\#}" && BRIGHTNESS=$(( (16#${HEX:0:2} * 299 + 16#${HEX:2:2} * 587 + 16#${HEX:4:2} * 114) / 1000 )) && [ $BRIGHTNESS -gt 128 ] && FG="#000000" || FG="#FFFFFF" && notify-send "🖌️ " "$COLOR" -h string:bgcolor:"$COLOR" -h string:fgcolor:"$FG" -h string:frcolor:"$COLOR" -u normal ;;
    28) rofi -modi emoji -show emoji -theme '~/.config/rofi/SOS_Left.rasi' -emoji-format ;;
    29) /usr/share/spectrumos/scripts/SOS_Session.sh ;;
    30) xdg-open "https://github.com/gibranlp/SpectrumOS" ;;
esac
