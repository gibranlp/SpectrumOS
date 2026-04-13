#!/usr/bin/env python3
import json
import os

import cairosvg
from PIL import Image

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

# Layer size from cairosvg output
LAYER_W = 250
LAYER_H = 250

# X offsets (color7 is front at offset 0)
offsets = [-28, -24, -20, -16, -12, -8, -4, 0]

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

    # Convert SVG → PNG
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

# Save output
out_file = os.path.expanduser("~/SpectrumOS.png")
logo.save(out_file, "PNG")
print(f"Generated {out_file}")
