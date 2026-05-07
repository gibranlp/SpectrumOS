#!/bin/bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 

# Vesktop / Vencord Pywal Integration script

# Support for various Vesktop/Vencord installation paths
THEME_DIRS=(
    "$HOME/.config/vesktop/themes"
    "$HOME/.var/app/dev.vencord.Vesktop/config/vesktop/themes"
    "$HOME/.config/Vencord/themes"
    "$HOME/.var/app/dev.vencord.Vesktop/config/Vencord/themes"
)

PYWAL_VESKTOP="$HOME/.cache/wal/vesktop-theme.css"
THEME_NAME="SpectrumOS.theme.css"

# Check if pywal colors were generated
if [ ! -f "$PYWAL_VESKTOP" ]; then
    echo "Pywal Vesktop template not found at $PYWAL_VESKTOP. Running wal to generate it..."
    # Try to find a current wallpaper to trigger wal if cache is missing
    CURRENT_WALLPAPER="/var/lib/spectrumos/current.png"
    if [ -f "$CURRENT_WALLPAPER" ]; then
        wal -i "$CURRENT_WALLPAPER"
    else
        echo "Error: Could not find current wallpaper to generate colors."
        exit 1
    fi
fi

# Update themes in all detected directories
UPDATED=false
for theme_dir in "${THEME_DIRS[@]}"; do
    if [ -d "$(dirname "$theme_dir")" ] || [ -d "$theme_dir" ]; then
        mkdir -p "$theme_dir"
        cp "$PYWAL_VESKTOP" "$theme_dir/$THEME_NAME"
        echo "Vesktop theme updated at: $theme_dir/$THEME_NAME"
        UPDATED=true
    fi
done

if [ "$UPDATED" = true ]; then
    echo "Vesktop theme updated successfully."
else
    echo "No Vesktop/Vencord installation found. Theme not applied."
fi
