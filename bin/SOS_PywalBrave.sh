#!/bin/bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 

# Brave Pywal Dynamic Integration script

BRAVE_THEME_DIR="$HOME/.cache/spectrumos/brave-theme"
PYWAL_BRAVE="$HOME/.cache/wal/brave-theme.json"

# Check if pywal colors were generated
if [ ! -f "$PYWAL_BRAVE" ]; then
    echo "Pywal Brave template not found at $PYWAL_BRAVE"
    exit 1
fi

# Create theme directory if it doesn't exist
mkdir -p "$BRAVE_THEME_DIR"

# REMOVE existing symlink if it exists to prevent "cat FILE > FILE" emptying it
[ -L "$BRAVE_THEME_DIR/manifest.json" ] && rm "$BRAVE_THEME_DIR/manifest.json"

# Copy and update version to force Brave to reload
NEW_VER=$(date +%Y.%m%d.%H%M%S)
cat "$PYWAL_BRAVE" | sed "s/\"version\": \".*\"/\"version\": \"$NEW_VER\"/" > "$BRAVE_THEME_DIR/manifest.json"

echo "Brave theme updated to version $NEW_VER"

# Force Brave to redraw by toggling system color scheme
CURRENT_SCHEME=$(gsettings get org.gnome.desktop.interface color-scheme)
if [ "$CURRENT_SCHEME" == "'prefer-dark'" ]; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
    sleep 0.1
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
else
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    sleep 0.1
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
fi

# Inform user if not already loaded
if [ ! -f "$HOME/.cache/spectrumos/brave_loaded" ]; then
    dunstify -a "SpectrumOS" -u normal "Brave Dynamic Theme" "1. Go to brave://extensions\n2. Enable Developer Mode\n3. Click 'Load Unpacked'\n4. Select $BRAVE_THEME_DIR"
    touch "$HOME/.cache/spectrumos/brave_loaded"
fi
