#!/bin/bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 
# Waybar Cava Visualizer Script

# Define the bar characters
bar_chars=(" " "▂" "▃" "▄" "▅" "▆" "▇" "█")

# Create a temporary config for cava
config_file="/tmp/waybar_cava_config"
cat > "$config_file" <<EOF
[general]
bars = 24
[input]
method = pulse
source = auto
[output]
method = raw
data_format = ascii
ascii_max_range = 7
bar_delimiter = 32
EOF

# Run cava and transform output to bars
# We use a faster way to process the output
cava -p "$config_file" | while read -r line; do
    output=""
    for val in $line; do
        # Ensure val is a number to avoid errors
        if [[ "$val" =~ ^[0-9]+$ ]]; then
            output+="${bar_chars[$val]}"
        fi
    done
    echo "$output"
done
