#!/usr/bin/env python3
import json
import os
import sys
import argparse
import random
import colorsys
import cairosvg
from PIL import Image

# Parse arguments
parser = argparse.ArgumentParser(description="Generate Spectrum Logo or Wallpaper")
parser.add_argument("--output", help="Output path for the generated file")
parser.add_argument("--wallpaper", action="store_true", help="Generate a full-size 4K wallpaper instead of just the logo")
args = parser.parse_args()

# Color list
palette = []

if args.wallpaper:
    # Completely independent random colors for each layer
    for i in range(8):
        h = random.random()
        s = random.uniform(0.7, 0.9)
        v = random.uniform(0.8, 1.0)
        rgb = colorsys.hsv_to_rgb(h, s, v)
        hex_color = '#{:02x}{:02x}{:02x}'.format(int(rgb[0]*255), int(rgb[1]*255), int(rgb[2]*255))
        palette.append(hex_color)
    
    # User requirement: top layer always white
    palette[7] = "#FFFFFF"
else:
    # Read pywal colors
    wal_file = os.path.expanduser("~/.cache/wal/colors.json")
    if not os.path.exists(wal_file):
        print(f"Error: pywal colors not found at {wal_file}. Please run 'wal' first.")
        exit(1)

    with open(wal_file, "r") as f:
        colors = json.load(f)

    # Color list from pywal
    palette = [
        colors["colors"]["color0"],
        colors["colors"]["color1"],
        colors["colors"]["color2"],
        colors["colors"]["color3"],
        colors["colors"]["color4"],
        colors["colors"]["color5"],
        colors["colors"]["color6"],
        colors["colors"]["color7"],   # this one will be front-most
    ]

# SVG path (unchanged)
SVG_PATH = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
 <path d="M31.994-.006c-2.85 6.985-4.568 11.554-7.74 18.332
 1.945 2.062 4.332 4.462 8.2 7.174-4.168-1.715-7-3.437-9.136-5.224
 -4.06 8.47-10.42 20.538-23.327 43.73C10.145 58.15 18 54.54 25.338 53.16
 c-.315-1.354-.494-2.818-.48-4.345l.012-.325c.16-6.5 3.542-11.498 7.547-11.158
 s7.118 5.886 6.957 12.386a18.36 18.36 0 0 1-.409 3.491c7.25 1.418 15.03 5.02
 25.037 10.797l-5.42-10.026c-2.65-2.053-5.413-4.726-11.05-7.62
 3.875 1.007 6.65 2.168 8.8 3.467-17.1-31.84-18.486-36.07-24.35-49.833z"
 fill="@COLOR@" fill-rule="evenodd"/>
</svg>
"""

# Render scale factor
render_scale = 2.5 if args.wallpaper else 1.0

# Layer size from cairosvg output (scaled)
base_layer_size = 250
LAYER_W = int(base_layer_size * render_scale)
LAYER_H = int(base_layer_size * render_scale)

# X offsets (scaled)
base_offsets = [-28, -24, -20, -16, -12, -8, -4, 0]
offsets = [int(o * render_scale) for o in base_offsets]

# Compute canvas width so the leftmost layer never gets clipped
max_left = abs(min(offsets))
IMG_WIDTH = LAYER_W + max_left
IMG_HEIGHT = LAYER_H

# Create final canvas
logo = Image.new("RGBA", (IMG_WIDTH, IMG_HEIGHT), (0, 0, 0, 0))

TEMP_SVGS = []

for i, col in enumerate(palette):
    svg_data = SVG_PATH.replace("@COLOR@", col)
    svg_file = f"/tmp/archlayer_{i}.svg"
    png_file = f"/tmp/archlayer_{i}.png"
    TEMP_SVGS.append(svg_file)

    # Write temporary SVG
    with open(svg_file, "w") as f:
        f.write(svg_data)

    # Convert SVG → PNG at target size
    cairosvg.svg2png(
        url=svg_file,
        write_to=png_file,
        output_width=LAYER_W,
        output_height=LAYER_H
    )

    # Load PNG layer
    layer = Image.open(png_file).convert("RGBA")

    # Horizontal only movement, shifted into visible canvas
    x = offsets[i] + max_left
    y = (IMG_HEIGHT - layer.height) // 2  # perfect vertical center

    # Paste onto final canvas
    logo.paste(layer, (x, y), layer)

# Determine final output path
if args.output:
    out_file = args.output
elif args.wallpaper:
    wall_dir = os.path.expanduser("~/Pictures/Wallpapers")
    os.makedirs(wall_dir, exist_ok=True)
    out_file = os.path.join(wall_dir, "SpectrumOS_Wallpaper.png")
else:
    out_file = os.path.expanduser("~/SpectrumOS.png")

# Generation logic
if args.wallpaper:
    # 4K dark grey canvas
    wallpaper = Image.new("RGB", (3840, 2160), "#222222")
    
    # Center the logo (already at target size)
    x = (3840 - logo.width) // 2
    y = (2160 - logo.height) // 2
    wallpaper.paste(logo, (x, y), logo)
    wallpaper.save(out_file, "PNG")
    print(f"Generated Wallpaper: {out_file}")
else:
    # Save just the logo and update system locations
    logo.save(out_file, "PNG")
    print(f"Generated Logo: {out_file}")

    # Update the system logo for consistency (if not already the output)
    default_logo = os.path.expanduser("~/SpectrumOS.png")
    if out_file != default_logo:
        logo.save(default_logo, "PNG")
        print(f"Updated {default_logo}")

    # Also try to save to global location for Limine/SDDM if we have permissions
    global_logo = "/var/lib/spectrumos/logo.png"
    if out_file != global_logo:
        try:
            os.makedirs(os.path.dirname(global_logo), exist_ok=True)
            logo.save(global_logo, "PNG")
            print(f"Updated {global_logo}")
        except PermissionError:
            pass
        except Exception as e:
            print(f"Note: Could not save global logo: {e}")
