#!/bin/bash
# SpectrumOS Spectrum Generator Launcher

# Load configuration
CONFIG_FILE="/etc/spectrumos/spectrumos.conf"
[ ! -f "$CONFIG_FILE" ] && echo "Missing config" && exit 1
source "$CONFIG_FILE"

# Define options
OPTIONS="󰄭 Spectrum Logo\n󰄭 Spectrum Pills\n󰄭 Spectrum Rectangles\n󰄭 Spectrum Circles\n󰄭 Spectrum Triangles"

# Show Rofi menu
CHOICE=$(echo -e "$OPTIONS" | rofi -dmenu -i -p "  Generate Wallpaper" -theme "$HOME/.config/rofi/SOS_Left.rasi")

case "$CHOICE" in
    *"Pills"*)
        MODE="pills"
        ;;
    *"Rectangles"*)
        MODE="rectangles"
        ;;
    *"Circles"*)
        MODE="circles"
        ;;
    *"Triangles"*)
        MODE="triangles"
        ;;
    *"Logo"*)
        MODE="logo"
        ;;
    *)
        exit 0
        ;;
esac

# Generate unique filename
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
WALL_DIR=$(eval echo "$WALLPAPER_DIR")
mkdir -p "$WALL_DIR"
WALLPAPER="$WALL_DIR/spectrum_$TIMESTAMP.png"

# Run generator
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$MODE" = "logo" ]; then
    if ! "$SCRIPT_DIR/SOS_Gen_Logo.py" --wallpaper --output "$WALLPAPER"; then
        notify-send -a "SpectrumOS" -u critical "Generator Failed!" "Could not create logo wallpaper."
        exit 1
    fi
else
    if ! "$SCRIPT_DIR/SOS_Spectrum_Gen.py" --mode "$MODE" --output "$WALLPAPER"; then
        notify-send -a "SpectrumOS" -u critical "Generator Failed!" "Could not create $MODE wallpaper."
        exit 1
    fi
fi

# Apply Wallpaper
echo "$WALLPAPER" > "/var/lib/spectrumos/last_wallpaper"

# Gowall Process
if [ "$GOWALL_SCHEME" != "No Theme" ]; then
    gowall convert "$WALLPAPER" -t "$GOWALL_SCHEME" --output "/var/lib/spectrumos/current.png"
else
    cp "$WALLPAPER" "/var/lib/spectrumos/current.png"
fi

# Set Colors with pywal
# If a palette source exists (from Logo generator), use it for extraction
PALETTE_SOURCE="/tmp/spectrum_palette.png"
if [ -f "$PALETTE_SOURCE" ]; then
    # Apply Gowall to the palette source too if active
    if [ "$GOWALL_SCHEME" != "No Theme" ]; then
        gowall convert "$PALETTE_SOURCE" -t "$GOWALL_SCHEME" --output "$PALETTE_SOURCE"
    fi
    WAL_SOURCE="$PALETTE_SOURCE"
else
    WAL_SOURCE="/var/lib/spectrumos/current.png"
fi

# Pywal extraction (no wallpaper update -n)
if [ "$PYWAL_LIGHT_SCHEME" = "Light" ]; then
    wal -l -i "$WAL_SOURCE" --backend "$PYWAL_BACKEND" -n
else
    wal -i "$WAL_SOURCE" --backend "$PYWAL_BACKEND" -n
fi 

# Apply Colors and Update Configs (passed palette source for wpg)
"$SCRIPT_DIR/SOS_Apply_Colors.sh" "$WALLPAPER" "$WAL_SOURCE"

# Set wallpaper with awww (SINGLE UPDATE AT THE END)
awww img "/var/lib/spectrumos/current.png" --transition-type wave --transition-duration "$TRANSITION_DURATION"

# Cleanup palette source
rm -f "$PALETTE_SOURCE"

# Send notification
notify-send -a "SpectrumOS" "Wallpaper Generated!" "New $MODE spectrum wallpaper created and applied." -i "$WALLPAPER"
