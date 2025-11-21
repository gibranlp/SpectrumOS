#!/bin/bash
# SpectrumOS Directory Structure Setup Script
# Run this to create all necessary directories and set permissions

echo "Creating SpectrumOS directory structure..."

# Create system directories
sudo mkdir -p /etc/spectrumos
sudo mkdir -p /usr/share/spectrumos/{wallpapers,themes,scripts}
sudo mkdir -p /var/lib/spectrumos

# Create user config directory
mkdir -p ~/.config/spectrumos

echo "Setting permissions..."

# /var/lib/spectrumos should be writable by user (for wallpaper/color updates)
sudo chown -R $USER:$USER /var/lib/spectrumos
sudo chmod 755 /var/lib/spectrumos

# /etc/spectrumos readable by all, writable by root
sudo chmod 755 /etc/spectrumos

# /usr/share/spectrumos readable by all
sudo chmod -R 755 /usr/share/spectrumos

# User config owned by user
chmod 755 ~/.config/spectrumos

echo "SpectrumOS directory structure created!"
echo ""
echo "Structure:"
echo "  /etc/spectrumos/              - System configuration files"
echo "  /usr/share/spectrumos/        - System assets (wallpapers, themes, scripts)"
echo "  /var/lib/spectrumos/          - Runtime state (current wallpaper, colors)"
echo "  ~/.config/spectrumos/         - User configuration overrides"