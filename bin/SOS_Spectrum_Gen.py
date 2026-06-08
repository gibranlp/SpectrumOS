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
