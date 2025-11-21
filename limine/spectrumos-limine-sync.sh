#!/bin/bash
# SpectrumOS Limine Sync Script
WALLPAPER_SOURCE="/var/lib/spectrumos/current.jpg"
WALLPAPER_DEST="/boot/spectrumos-wallpaper.jpg"
COLORS_SOURCE="/var/lib/spectrumos/colors.conf"
LIMINE_CONF="/boot/limine.conf"

# Exit if source doesn't exist
if [ ! -f "$WALLPAPER_SOURCE" ]; then
    exit 0
fi

# Copy wallpaper to boot
cp "$WALLPAPER_SOURCE" "$WALLPAPER_DEST"

# Update Limine colors if colors.conf exists
if [ -f "$COLORS_SOURCE" ]; then
    # Read colors from the conf file
    source "$COLORS_SOURCE"
    
    # Remove # from colors (Limine wants RRGGBB, not #RRGGBB)
    bg=$(echo "$background" | sed 's/#//')
    fg=$(echo "$foreground" | sed 's/#//')
    c1=$(echo "$color1" | sed 's/#//')
    c2=$(echo "$color2" | sed 's/#//')
    c3=$(echo "$color3" | sed 's/#//')
    c4=$(echo "$color4" | sed 's/#//')
    c5=$(echo "$color5" | sed 's/#//')
    c6=$(echo "$color6" | sed 's/#//')
    c7=$(echo "$color7" | sed 's/#//')
    
    # Update colors in Limine config (66 prefix for transparency on background)
    sed -i "s/^term_background:.*/term_background: 88$bg/" "$LIMINE_CONF"
    sed -i "s/^backdrop:.*/backdrop: $bg/" "$LIMINE_CONF"
    sed -i "s/^term_foreground:.*/term_foreground: $fg/" "$LIMINE_CONF"
    sed -i "s/^term_foreground_bright:.*/term_foreground_bright: $fg/" "$LIMINE_CONF"
    sed -i "s/^term_background_bright:.*/term_background_bright: $bg/" "$LIMINE_CONF"
    
    # Update palette with pywal colors
    sed -i "s/^term_palette:.*/term_palette: $bg;$c1;$c2;$c3;$c4;$c5;$c6;$c7/" "$LIMINE_CONF"
    sed -i "s/^term_palette_bright:.*/term_palette_bright: $bg;$c1;$c2;$c3;$c4;$c5;$c6;$c7/" "$LIMINE_CONF"
fi