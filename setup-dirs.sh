#!/bin/bash
# SpectrumOS Directory Structure Setup Script
# Run this to create all necessary directories and set permissions

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Creating SpectrumOS directory structure...${NC}"

# 1. System Config Directory (/etc/spectrumos)
# Owned by user so dynamic scripts can update settings if needed
echo -e "${BLUE}Setting up /etc/spectrumos...${NC}"
sudo mkdir -p /etc/spectrumos
sudo chown -R $USER:$USER /etc/spectrumos
sudo chmod 755 /etc/spectrumos

# 2. Runtime State Directory (/var/lib/spectrumos)
# Must be writable by user for wallpaper/color updates
echo -e "${BLUE}Setting up /var/lib/spectrumos...${NC}"
sudo mkdir -p /var/lib/spectrumos
sudo chown -R $USER:$USER /var/lib/spectrumos
sudo chmod -R 755 /var/lib/spectrumos

# 3. System Assets Directory (/usr/share/spectrumos)
# Read-only for users, owned by root (scripts and wallpapers here)
echo -e "${BLUE}Setting up /usr/share/spectrumos...${NC}"
sudo mkdir -p /usr/share/spectrumos/{wallpapers,themes,scripts}
sudo chown -R $USER:$USER /usr/share/spectrumos
sudo chmod -R 755 /usr/share/spectrumos

# 4. User Config Directory (~/.config/spectrumos)
echo -e "${BLUE}Setting up ~/.config/spectrumos...${NC}"
mkdir -p ~/.config/spectrumos
chmod 755 ~/.config/spectrumos

echo -e "${GREEN}✓ SpectrumOS directory structure created!${NC}"
echo ""
echo "Structure:"
echo "  /etc/spectrumos/              - System configuration files (User writable)"
echo "  /usr/share/spectrumos/        - System assets (wallpapers, themes, scripts)"
echo "  /var/lib/spectrumos/          - Runtime state (current wallpaper, colors)"
echo "  ~/.config/spectrumos/         - User configuration overrides"
