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
"    ✅ Todo List (Todoist) (💠 + T)" #3
"    📝 Notes (Obsidian) (💠 + N)" #4
"🖼️ Wallpaper Options" #5
"    🎲 Set Random Wallpaper (💠 + R)" #6
"    🖼️ Select Wallpaper (💠 + W)" #7
"🎨 Theme Options" #8
"    🌈 Set Gowall Theme" #9
"    🧑‍🎨 Select Pywal Backend" #10
"    🌓 Dark/Light Theme" #11
"🧼 Waybar Options" #12
"    🎭 Select Waybar Theme" #13
"     🎨 Select Waybar Style" #14
"🛠️ Tools" #15
"    🔍 Search Files & Folders (💠 + S)" #16
"    🧮 Calculator (💠 + C)" #17
"    📡 Network Manager (💠 + B)" #18
"    🔵 Bluetooth Manager (💠 + ⬆️ + B)" #19
"    🔑 Password Generator (💠 + G)" #20
"    📸 Screenshot (prtnsc)" #21
"    ⚡ Power Profiles" #22
"    🔄 Update Base System" #23
"    🧽 System Cleaner" #24
"    🌡️ Monitor Temperature (💠 + ⬆️ + O)" #25
"📦 Miscellaneous" #26
"    ✏️ Screen Draw" #27
"    🎨 Pick Color" #28
"    😀 Emojis (💠 + V)" #29
"🔌 Session Menu (💠 + X)" #30
"💖 Support SpectrumOS" #31
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
    # Special Workspaces
    3) sh -c "hyprctl dispatch workspace 'name:todoist' && (pgrep -x 'todoist' > /dev/null && hyprctl dispatch focuswindow 'todoist' || ~/Applications/todoist &)" ;;
    4) sh -c "hyprctl dispatch workspace 'name:obsidian' && (pgrep -x 'obsidian' > /dev/null && hyprctl dispatch focuswindow 'obsidian' || ~/Applications/obsidian &)" ;;

    # Wallpaper Options
    6)  /usr/share/spectrumos/scripts/SOS_Randomize_Wallpaper.sh;;
    7)  /usr/share/spectrumos/scripts/SOS_Select_Wallpaper.sh;;
    
    # Theme Options
    9)  /usr/share/spectrumos/scripts/SOS_Gowall.sh;;
    10)  /usr/share/spectrumos/scripts/SOS_Backends.sh;;
    11)  /usr/share/spectrumos/scripts/SOS_DarkLight.sh ;;

    # Waybar Options
    13) /usr/share/spectrumos/scripts/SOS_Waybar_Theme.sh ;;
    14) /usr/share/spectrumos/scripts/SOS_Waybar_Style.sh ;;
    
    # Tools
    16) /usr/share/spectrumos/scripts/SOS_Search.sh ;;
    17) /usr/share/spectrumos/scripts/SOS_Calculator.sh ;;
    18) /usr/share/spectrumos/scripts/SOS_Wifi.sh ;;
    19) /usr/share/spectrumos/scripts/SOS_Bluetooth.sh ;;
    20) /usr/share/spectrumos/scripts/SOS_Pass_Generator.sh ;;
    21) /usr/share/spectrumos/scripts/SOS_Screenshot.sh ;;
    22) /usr/share/spectrumos/scripts/SOS_Power.sh ;;
    23) /usr/share/spectrumos/scripts/SOS_UpdateBase.sh ;;
    24) /usr/share/spectrumos/scripts/SOS_CleanSystem.sh ;;
    
    # Miscellaneous
    28) sleep 0.2 && COLOR=$(hyprpicker -r) && echo "$COLOR" | wl-copy && HEX="${COLOR#\#}" && BRIGHTNESS=$(( (16#${HEX:0:2} * 299 + 16#${HEX:2:2} * 587 + 16#${HEX:4:2} * 114) / 1000 )) && [ $BRIGHTNESS -gt 128 ] && FG="#000000" || FG="#FFFFFF" && notify-send "🖌️ " "$COLOR" -h string:bgcolor:"$COLOR" -h string:fgcolor:"$FG" -h string:frcolor:"$COLOR" -u normal ;;
    29) rofi -modi emoji -show emoji -theme '~/.config/rofi/SOS_Left.rasi' -emoji-format ;;
    # Monitor temperature
    25) kitty -e btop ;;
    # Screen Draw (gromit-mpx)
    27) gromit-mpx ;;
    30) /usr/share/spectrumos/scripts/SOS_Session.sh ;;
    # Support SpectrumOS
    31) xdg-open "https://github.com/gibranlp/SpectrumOS" ;;
esac
