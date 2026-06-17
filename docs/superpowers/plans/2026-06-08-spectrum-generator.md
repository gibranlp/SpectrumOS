# Spectrum Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a rofi-based widget that generates and applies custom 4K "glowing spectrum" wallpapers.

**Architecture:** A Python script uses the Pillow library to generate glowing orbs on a black 3840x2160 canvas. A Bash script provides a Rofi UI and handles the system-wide application of the generated image (wallpaper, pywal, config updates).

**Tech Stack:** Python (Pillow), Bash, Rofi, SpectrumOS Core Utilities (`awww`, `wal`, `gowall`).

---

### Task 1: Implement Python Image Generator

**Files:**
- Create: `bin/SOS_Spectrum_Gen.py`

- [ ] **Step 1: Write the generator script**

```python
#!/usr/bin/env python3
import argparse
import random
import os
from PIL import Image, ImageDraw, ImageFilter, ImageColor

def generate_spectrum(mode, output_path):
    width, height = 3840, 2160
    base = Image.new("RGB", (width, height), (0, 0, 0))
    # We draw orbs on a separate layer to blur them effectively
    orbs_layer = Image.new("RGB", (width, height), (0, 0, 0))
    draw = ImageDraw.Draw(orbs_layer)

    if mode == "spectrum":
        num_orbs = random.randint(15, 25)
        for _ in range(num_orbs):
            x = random.randint(0, width)
            y = random.randint(0, height)
            radius = random.randint(300, 800)
            # Map hue from Yellow (60) to Red (0) based on X position
            # Spectrum: starts on yellow and progressively goes to red
            # Left (0) is Yellow, Right (width) is Red
            hue = int(60 * (1 - (x / width)))
            color = ImageColor.getrgb(f"hsv({hue}, 100%, 100%)")
            
            left_up = (x - radius, y - radius)
            right_down = (x + radius, y + radius)
            draw.ellipse([left_up, right_down], fill=color)
    else: # random mode
        num_orbs = random.randint(10, 20)
        for _ in range(num_orbs):
            x = random.randint(0, width)
            y = random.randint(0, height)
            radius = random.randint(300, 800)
            hue = random.randint(0, 360)
            color = ImageColor.getrgb(f"hsv({hue}, 80%, 100%)")
            
            left_up = (x - radius, y - radius)
            right_down = (x + radius, y + radius)
            draw.ellipse([left_up, right_down], fill=color)

    # Apply heavy blur for the glow effect
    orbs_layer = orbs_layer.filter(ImageFilter.GaussianBlur(radius=150))
    
    # Composite
    final = Image.blend(base, orbs_layer, 0.8)
    final.save(output_path, "PNG")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["random", "spectrum"], default="spectrum")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    
    generate_spectrum(args.mode, args.output)
    print(f"Generated: {args.output}")
```

- [ ] **Step 2: Set executable permissions**

Run: `chmod +x bin/SOS_Spectrum_Gen.py`

- [ ] **Step 3: Test manually**

Run: `./bin/SOS_Spectrum_Gen.py --mode spectrum --output /tmp/test_spectrum.png`
Expected: File `/tmp/test_spectrum.png` created with 3840x2160 dimensions and glowing red/yellow orbs.

---

### Task 2: Implement Rofi Launcher Script

**Files:**
- Create: `bin/SOS_Spectrum_Launcher.sh`

- [ ] **Step 1: Write the launcher script**

```bash
#!/bin/bash
# SpectrumOS Spectrum Generator Launcher

# Load configuration
CONFIG_FILE="/etc/spectrumos/spectrumos.conf"
[ ! -f "$CONFIG_FILE" ] && echo "Missing config" && exit 1
source "$CONFIG_FILE"

# Define options
OPTIONS=" Random Colors\n󰄭 Yellow to Red Spectrum"

# Show Rofi menu
CHOICE=$(echo -e "$OPTIONS" | rofi -dmenu -i -p "  Generate Wallpaper" -theme "$HOME/.config/rofi/SOS_Left.rasi")

case "$CHOICE" in
    *"Random Colors"*)
        MODE="random"
        ;;
    *"Yellow to Red Spectrum"*)
        MODE="spectrum"
        ;;
    *)
        exit 0
        ;;
esac

# Generate unique filename
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
WALLPAPER="$WALLPAPER_DIR/spectrum_$TIMESTAMP.png"

# Run generator
# Assuming script is in same directory or $PATH
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/SOS_Spectrum_Gen.py" --mode "$MODE" --output "$WALLPAPER"

# Apply Wallpaper (Sync with SOS_Select_Wallpaper.sh logic)
echo "$WALLPAPER" > "/var/lib/spectrumos/last_wallpaper"

# Gowall Process
if [ "$GOWALL_SCHEME" != "No Theme" ]; then
    gowall convert "$WALLPAPER" -t "$GOWALL_SCHEME" --output "/var/lib/spectrumos/current.png"
else
    cp "$WALLPAPER" "/var/lib/spectrumos/current.png"
fi

# Set wallpaper with awww
awww img "/var/lib/spectrumos/current.png" --transition-type wave --transition-duration "$TRANSITION_DURATION"

# Set Colors with pywal
if [ "$PYWAL_LIGHT_SCHEME" = "Light" ]; then
    wal -l -i "/var/lib/spectrumos/current.png" --backend "$PYWAL_BACKEND"
else
    wal -i "/var/lib/spectrumos/current.png" --backend "$PYWAL_BACKEND"
fi 

# Apply Colors and Update Configs
"$SCRIPT_DIR/SOS_Apply_Colors.sh" "$WALLPAPER"

# Send notification
notify-send -a "SpectrumOS" "Wallpaper Generated!" "New $MODE wallpaper created and applied." -i "$WALLPAPER"
```

- [ ] **Step 2: Set executable permissions**

Run: `chmod +x bin/SOS_Spectrum_Launcher.sh`

- [ ] **Step 3: Final Test**

Run: `./bin/SOS_Spectrum_Launcher.sh`
Expected: Rofi menu appears, selecting an option generates an image in `~/Pictures/Wallpapers/` and applies it (desktop background changes, terminal colors update).
