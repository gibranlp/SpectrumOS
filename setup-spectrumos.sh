#!/usr/bin/env bash
# Complete SpectrumOS Directory Structure Setup
# Run this on your Arch system to prepare the repository

set -e

REPO_DIR="$HOME/SpectrumOS"

echo "🌈 Setting up SpectrumOS directory structure..."

# Create main directory
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"

# Initialize git if not already done
if [ ! -d ".git" ]; then
    git init
    echo "✓ Git repository initialized"
fi

# Create complete directory structure
echo "Creating directories..."
mkdir -p hosts/laptop
mkdir -p hosts/desktop
mkdir -p modules/graphics
mkdir -p home/hyprland
mkdir -p home/spectrum
mkdir -p home/creative
mkdir -p themes
mkdir -p scripts

echo "✓ Directory structure created"

echo ""
echo "🎨 SpectrumOS directory structure is ready!"
echo ""
echo "📝 Next steps:"
echo ""
echo "1. Save all artifacts to their locations:"
echo "   - flake.nix (root)"
echo "   - hosts/laptop/default.nix"
echo "   - modules/bootloader.nix"
echo "   - modules/hyprland.nix"
echo "   - modules/sddm.nix"
echo "   - modules/graphics/nvidia.nix"
echo "   - modules/graphics/amd.nix"
echo "   - home/common.nix"
echo "   - home/hyprland/hyprland.nix"
echo "   - home/hyprland/waybar.nix"
echo "   - home/hyprland/kitty.nix"
echo "   - home/hyprland/rofi.nix"
echo "   - home/spectrum/pywal.nix"
echo "   - home/creative/gimp.nix"
echo "   - home/creative/kdenlive.nix"
echo ""
echo "2. Update your email in home/common.nix"
echo ""
echo "3. Commit everything:"
echo "   cd $REPO_DIR"
echo "   git add ."
echo "   git commit -m 'Initial SpectrumOS configuration'"
echo ""
echo "4. (Optional) Push to GitHub:"
echo "   git remote add origin https://github.com/gibranlp/SpectrumOS.git"
echo "   git push -u origin main"
echo ""
echo "5. Download NixOS ISO:"
echo "   cd ~/Downloads"
echo "   wget https://channels.nixos.org/nixos-24.11/latest-nixos-minimal-x86_64-linux.iso"
echo ""
echo "6. Create bootable USB"
echo ""
echo "Repository location: $REPO_DIR"