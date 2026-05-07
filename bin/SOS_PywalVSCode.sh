#!/bin/bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 

# VSCode Pywal Integration script

# Support both VS Code and Code - OSS
VSCODE_PATHS=(
    "$HOME/.config/Code/User/settings.json"
    "$HOME/.config/Code - OSS/User/settings.json"
    "$HOME/.config/VSCodium/User/settings.json"
)

PYWAL_VSCODE="$HOME/.cache/wal/vscode-settings.json"

# Check if pywal colors were generated
if [ ! -f "$PYWAL_VSCODE" ]; then
    echo "Pywal VSCode template not found at $PYWAL_VSCODE. Running wal to generate it..."
    # Try to find a current wallpaper to trigger wal if cache is missing
    CURRENT_WALLPAPER="/var/lib/spectrumos/current.png"
    if [ -f "$CURRENT_WALLPAPER" ]; then
        wal -i "$CURRENT_WALLPAPER"
    else
        echo "Error: Could not find current wallpaper to generate colors."
        exit 1
    fi
fi

update_vscode() {
    local settings_path="$1"
    if [ ! -f "$settings_path" ]; then
        mkdir -p "$(dirname "$settings_path")"
        echo "{}" > "$settings_path"
    fi

    echo "Updating VSCode settings at: $settings_path"

    # Use Python to merge the colors into settings.json safely
    python3 - << EOF
import json
import os

settings_path = os.path.expanduser("$settings_path")
pywal_path = os.path.expanduser("$PYWAL_VSCODE")

try:
    with open(settings_path, 'r') as f:
        # Handle empty files or invalid JSON
        content = f.read().strip()
        if not content:
            settings = {}
        else:
            settings = json.loads(content)
    
    with open(pywal_path, 'r') as f:
        pywal_colors = json.load(f)
    
    # Merge color customizations
    settings['workbench.colorCustomizations'] = pywal_colors.get('workbench.colorCustomizations', {})
    settings['editor.tokenColorCustomizations'] = pywal_colors.get('editor.tokenColorCustomizations', {})
    
    # Ensure a Wal theme is set if not already
    current_theme = settings.get('workbench.colorTheme', '')
    if "Wal" not in current_theme:
        settings['workbench.colorTheme'] = 'Wal'
    
    with open(settings_path, 'w') as f:
        json.dump(settings, f, indent=4)
        
    print(f"Successfully updated {settings_path}")
except Exception as e:
    print(f"Error updating VSCode colors: {e}")
EOF
}

for path in "${VSCODE_PATHS[@]}"; do
    if [ -d "$(dirname "$path")" ]; then
        update_vscode "$path"
    fi
done
