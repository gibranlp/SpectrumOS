#!/bin/bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 
# Centralized Color Application Script
# Ensures atomic updates for Hyprland to prevent reload errors.

WALLPAPER="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="$HOME/.cache/spectrumos"
HYPR_COLOR_FILE="$CACHE_DIR/colors-hyprland.conf"

mkdir -p "$CACHE_DIR"

# 1. Atomic Hyprland Color Update
# We copy to a temp file then MV to ensure Hyprland never reads a partial file
if [ -f "$HOME/.cache/wal/colors-hyprland.conf" ]; then
    cp "$HOME/.cache/wal/colors-hyprland.conf" "$HYPR_COLOR_FILE.tmp"
    mv "$HYPR_COLOR_FILE.tmp" "$HYPR_COLOR_FILE"
elif [ ! -f "$HYPR_COLOR_FILE" ]; then
    # Fallback for first run if wal hasn't run yet
    touch "$HYPR_COLOR_FILE"
fi

# 2. GTK / wpgtk Integration
if command -v wpg &>/dev/null && [ -n "$WALLPAPER" ]; then
    wpg -a "$WALLPAPER"
    wpg -s "$WALLPAPER"
fi

if [ -n "$WALLPAPER" ]; then
    # Ensure GTK settings are applied
    gsettings set org.gnome.desktop.interface gtk-theme "FlatColor"
    gsettings set org.gnome.desktop.interface icon-theme "flattrcolor-dark"
    gsettings set org.gnome.desktop.wm.preferences theme "FlatColor"
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

    # Update GTK3 settings.ini
    mkdir -p "$HOME/.config/gtk-3.0"
    cat > "$HOME/.config/gtk-3.0/settings.ini" << EOF
[Settings]
gtk-icon-theme-name = flattrcolor-dark
gtk-theme-name = FlatColor
gtk-font-name = Sans 10
gtk-cursor-theme-name = Adwaita
gtk-application-prefer-dark-theme = true
EOF

    # Update GTK4 settings.ini
    mkdir -p "$HOME/.config/gtk-4.0"
    cp "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"

    # Update GTK4/libadwaita CSS
    if [ -f "$HOME/.cache/wal/gtk4-libadwaita.css" ]; then
        [ -L "$HOME/.config/gtk-4.0/gtk.css" ] && rm "$HOME/.config/gtk-4.0/gtk.css"
        cp "$HOME/.cache/wal/gtk4-libadwaita.css" "$HOME/.config/gtk-4.0/gtk.css"
    fi

    # Update GTK3 CSS
    if [ -f "$HOME/.cache/wal/gtk3.css" ]; then
        [ -L "$HOME/.config/gtk-3.0/gtk.css" ] && rm "$HOME/.config/gtk-3.0/gtk.css"
        cp "$HOME/.cache/wal/gtk3.css" "$HOME/.config/gtk-3.0/gtk.css"
    fi
fi

# 3. System Components
pkill -HUP xsettingsd
pkill xdg-desktop-portal-gtk

# Update SDDM colors
cp "$HOME/.cache/wal/sddm-colors.conf" /var/lib/spectrumos/colors.conf 2>/dev/null || true

# Dunst
mkdir -p "$HOME/.config/dunst"
cp "$HOME/.cache/wal/dunstrc" "$HOME/.config/dunst/dunstrc"
pkill dunst; dunst &

# Cava
mkdir -p "$HOME/.config/cava"
cp "$HOME/.cache/wal/cava-config" "$HOME/.config/cava/config"
pkill -USR1 cava 2>/dev/null

# Cmus
[ -f "$HOME/.cache/wal/cmus-theme" ] && cp "$HOME/.cache/wal/cmus-theme" "$HOME/.config/cmus/SpectrumOS.theme"

# 4. App-specific updates (Async)
python3 "$SCRIPT_DIR/SOS_Gen_Logo.py" &
"$SCRIPT_DIR/SOS_PywalBrave.sh" &
"$SCRIPT_DIR/SOS_PywalQT.sh" &
"$SCRIPT_DIR/SOS_PywalVesktop.sh" &
"$SCRIPT_DIR/SOS_PywalVSCode.sh" &
"$SCRIPT_DIR/SOS_PywalVivaldi.sh" &
pywalfox update &
walogram -c &

# 5. Waybar Refresh
killall -SIGUSR2 waybar 2>/dev/null || (killall waybar 2>/dev/null; sleep 0.5; waybar &)
