#!/bin/bash
# Generate full GTK theme from pywal colors using Themix/oomox
source "$HOME/.cache/wal/colors.sh"

THEME_NAME="Pywal-Theme"
THEMIX_DIR="$HOME/.local/share/themes/$THEME_NAME"

# Strip # from colors (oomox adds it automatically)
bg="${background#\#}"
fg="${foreground#\#}"
c0="${color0#\#}"
c1="${color1#\#}"
c8="${color8#\#}"

# Create oomox color scheme file
mkdir -p "$HOME/.config/oomox/colors"
cat > "$HOME/.config/oomox/colors/pywal" << EOF
NAME=Pywal
BG=$bg
FG=$fg
MENU_BG=$c0
MENU_FG=$fg
SEL_BG=$c1
SEL_FG=$bg
TXT_BG=$bg
TXT_FG=$fg
BTN_BG=$c1
BTN_FG=$bg
HDR_BTN_BG=$c0
HDR_BTN_FG=$fg
ACCENT_BG=$c1
HDR_BG=$c0
HDR_FG=$fg
WM_BORDER_FOCUS=$c1
WM_BORDER_UNFOCUS=$c8
ROUNDNESS=3
SPACING=3
GRADIENT=0.0
GTK3_GENERATE_DARK=True
EOF

echo "Generated oomox config:"
cat "$HOME/.config/oomox/colors/pywal"

# Check if oomox-cli is installed
if ! command -v oomox-cli &> /dev/null; then
    echo "oomox-cli (Themix) not found. Skipping full GTK theme generation."
    exit 0
fi

# Generate the theme
oomox-cli -o "$THEME_NAME" -m all "$HOME/.config/oomox/colors/pywal"

# Set as current theme
gsettings set org.gnome.desktop.interface gtk-theme "$THEME_NAME"
gsettings set org.gnome.desktop.wm.preferences theme "$THEME_NAME"

echo "Full GTK theme generated and applied: $THEME_NAME"