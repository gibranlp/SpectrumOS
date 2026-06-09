#!/usr/bin/env python3
import argparse
import random
import os
import sys
import colorsys
from PIL import Image, ImageDraw, ImageColor

def generate_spectrum(mode, output_path, width=3840, height=2160, seed=None):
    if seed is not None:
        random.seed(seed)
    
    # Create 4K dark grey canvas
    img = Image.new("RGB", (width, height), "#222222")
    draw = ImageDraw.Draw(img)

    num_steps = 10
    
    # Randomize starting color in HSV
    h = random.random() # 0.0 to 1.0
    s = random.uniform(0.7, 0.9) # 70% to 90% saturation
    v = random.uniform(0.8, 1.0) # 80% to 100% value
    
    # Defined "Steps" based on user's sample
    h_step = -0.016
    s_step = 0.015
    v_step = -0.06
    
    # Base dimensions for the shapes (wider as requested)
    shape_w = 450
    shape_h = 1200
    
    # Adjust dimensions for specific modes if needed
    if mode == "circles":
        shape_h = 450 # Keep it square for circles

    step_x = 220 
    
    # Calculate total width of the group to center it
    total_w = ((num_steps - 1) * step_x) + shape_w
    start_x = (width - total_w) // 2
    start_y = (height - shape_h) // 2

    # Draw shapes in reverse order so the first one on the left is on top
    for i in range(num_steps - 1, -1, -1):
        x = start_x + (i * step_x)
        y = start_y

        # Calculate current color
        curr_h = (h + (i * h_step)) % 1.0
        curr_s = max(0, min(1, s + (i * s_step)))
        curr_v = max(0, min(1, v + (i * v_step)))
        
        # Convert HSV to RGB
        rgb = colorsys.hsv_to_rgb(curr_h, curr_s, curr_v)
        color_tuple = tuple(int(c * 255) for c in rgb)

        if mode == "pills":
            radius = shape_w // 2
            draw.rounded_rectangle([x, y, x + shape_w, y + shape_h], radius=radius, fill=color_tuple)
        elif mode == "rectangles":
            draw.rectangle([x, y, x + shape_w, y + shape_h], fill=color_tuple)
        elif mode == "circles":
            draw.ellipse([x, y, x + shape_w, y + shape_h], fill=color_tuple)
        elif mode == "triangles":
            points = [(x + shape_w // 2, y), (x, y + shape_h), (x + shape_w, y + shape_h)]
            draw.polygon(points, fill=color_tuple)

    try:
        img.save(output_path, "PNG")
        print(f"Generated: {output_path}")
    except Exception as e:
        print(f"Error saving image to {output_path}: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["pills", "rectangles", "circles", "triangles"], default="pills")
    parser.add_argument("--output", required=True)
    parser.add_argument("--seed", type=int, help="Seed for reproducibility")
    parser.add_argument("--width", type=int, default=3840, help="Width of the generated image")
    parser.add_argument("--height", type=int, default=2160, help="Height of the generated image")
    args = parser.parse_args()
    
    generate_spectrum(args.mode, args.output, args.width, args.height, args.seed)
