#!/bin/bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 

# Vivaldi Pywal Dynamic Integration script

VIVALDI_THEME_DIR="$HOME/Documents/SpectrumOS/Vivaldi"
PYWAL_VIVALDI="$HOME/.cache/wal/vivaldi.css"
PYWAL_THEME_JSON="$HOME/.cache/wal/vivaldi-theme.json"

# Check if pywal colors were generated
if [ ! -f "$PYWAL_VIVALDI" ]; then
    echo "Pywal Vivaldi template not found at $PYWAL_VIVALDI"
    exit 1
fi

# Create theme directory if it doesn't exist
mkdir -p "$VIVALDI_THEME_DIR"

# Copy the generated CSS
cp "$PYWAL_VIVALDI" "$VIVALDI_THEME_DIR/custom.css"

# Create a Vivaldi Theme file (.viv is just a zip) for manual import
if [ -f "$PYWAL_THEME_JSON" ]; then
    TMP_DIR=$(mktemp -d)
    cp "$PYWAL_THEME_JSON" "$TMP_DIR/manifest.json"
    (cd "$TMP_DIR" && zip -r "$VIVALDI_THEME_DIR/SpectrumOS.viv" manifest.json) > /dev/null
    rm -rf "$TMP_DIR"
fi

echo "Vivaldi theme updated"

# Inform user if not already loaded
if [ ! -f "$HOME/.cache/spectrumos/vivaldi_loaded" ]; then
    dunstify -a "SpectrumOS" -u normal "Vivaldi Dynamic Theme" "1. Go to vivaldi://experiments\n2. Enable 'Allow for using CSS modifications'\n3. Go to Settings > Appearance\n4. Select folder: $VIVALDI_THEME_DIR\n5. Restart Vivaldi\n\nFallback: Import $VIVALDI_THEME_DIR/SpectrumOS.viv in Settings > Themes"
    touch "$HOME/.cache/spectrumos/vivaldi_loaded"
fi
