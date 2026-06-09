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
"    🖼️ Generate Wallpaper (💠 + ⇧ + W)" #4
"    🎲 Set Random Wallpaper (💠 + R)" #5
"    🖼️ Select Wallpaper (💠 + W)" #6
"🎨 Theme Options" #7
"    🌈 Set Gowall Theme" #8
"    🧑‍🎨 Select Pywal Backend" #9
"    🌓 Dark/Light Theme" #10
"🧼 Waybar Options" #11
"    🎭 Select Waybar Theme" #12
"     🎨 Select Waybar Style" #13
"🛠️ Tools" #14
"    🔍 Search Files & Folders (💠 + S)" #15
"    🧮 Calculator (💠 + C)" #16
"    📡 Network Manager (💠 + B)" #17
"    🔵 Bluetooth Manager (💠 + ⬆️ + B)" #18
"    🔊 Audio Manager (💠 + A)" #19
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

    # Wallpaper Options
    4)  /usr/share/spectrumos/scripts/SOS_Spectrum_Launcher.sh;;
    5)  /usr/share/spectrumos/scripts/SOS_Randomize_Wallpaper.sh;;
    6)  /usr/share/spectrumos/scripts/SOS_Select_Wallpaper.sh;;
    
    # Theme Options
    8)  /usr/share/spectrumos/scripts/SOS_Gowall.sh;;
    9)  /usr/share/spectrumos/scripts/SOS_Backends.sh;;
    10)  /usr/share/spectrumos/scripts/SOS_DarkLight.sh ;;

    # Waybar Options
    12) /usr/share/spectrumos/scripts/SOS_Waybar_Theme.sh ;;
    13) /usr/share/spectrumos/scripts/SOS_Waybar_Style.sh ;;
    
    # Tools
    15) /usr/share/spectrumos/scripts/SOS_Search.sh ;;
    16) /usr/share/spectrumos/scripts/SOS_Calculator.sh ;;
    17) /usr/share/spectrumos/scripts/SOS_Wifi.sh ;;
    18) /usr/share/spectrumos/scripts/SOS_Bluetooth.sh ;;
    19) /usr/share/spectrumos/scripts/SOS_Audio.sh ;;
    20) /usr/share/spectrumos/scripts/SOS_Pass_Generator.sh ;;
    21) /usr/share/spectrumos/scripts/SOS_Screenshot.sh ;;
    22) /usr/share/spectrumos/scripts/SOS_Power.sh ;;
    23) /usr/share/spectrumos/scripts/SOS_UpdateBase.sh ;;
    24) /usr/share/spectrumos/scripts/SOS_CleanSystem.sh ;;
    25) alacritty -e btop ;; # Monitor temperature
    
    # Miscellaneous
    27) gromit-mpx ;; # Screen Draw
    28) sleep 0.2 && COLOR=$(hyprpicker -r) && echo "$COLOR" | wl-copy && HEX="${COLOR#\#}" && BRIGHTNESS=$(( (16#${HEX:0:2} * 299 + 16#${HEX:2:2} * 587 + 16#${HEX:4:2} * 114) / 1000 )) && [ $BRIGHTNESS -gt 128 ] && FG="#000000" || FG="#FFFFFF" && notify-send "🖌️ " "$COLOR" -h string:bgcolor:"$COLOR" -h string:fgcolor:"$FG" -h string:frcolor:"$COLOR" -u normal ;;
    29) rofi -modi emoji -show emoji -theme '~/.config/rofi/SOS_Left.rasi' -emoji-format ;;
    30) /usr/share/spectrumos/scripts/SOS_Session.sh ;;
    31) xdg-open "https://github.com/gibranlp/SpectrumOS" ;;
esac
