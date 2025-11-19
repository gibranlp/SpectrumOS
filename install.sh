#!/bin/bash
# SpectrumOS Installation Script
# Installs all dependencies and software for SpectrumOS

set -e

echo "🌈 SpectrumOS Installation Script"
echo "=================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}Please do not run as root${NC}"
    exit 1
fi

# Check if yay is installed
if ! command -v yay &> /dev/null; then
    echo -e "${BLUE}Installing yay (AUR helper)...${NC}"
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ~
    echo -e "${GREEN}✓ yay installed${NC}"
else
    echo -e "${GREEN}✓ yay already installed${NC}"
fi

echo ""
echo -e "${BLUE}Updating system...${NC}"
yay -Syu --noconfirm

echo ""
echo -e "${BLUE}Installing Hyprland ecosystem...${NC}"
yay -S --needed --noconfirm \
    hyprland \
    hyprpaper \
    hypridle \
    hyprlock \
    xdg-desktop-portal-hyprland \
    xdg-desktop-portal-gtk \
    qt5-wayland \
    qt6-wayland

echo ""
echo -e "${BLUE}Installing Waybar and dependencies...${NC}"
yay -S --needed --noconfirm \
    waybar \
    otf-font-awesome \
    ttf-jetbrains-mono-nerd \
    ttf-firacode-nerd \
    noto-fonts \
    noto-fonts-emoji \
    poddl

echo ""
echo -e "${BLUE}Installing terminal and launcher...${NC}"
yay -S --needed --noconfirm \
    kitty \
    wofi \
    mako \
    dunst

echo ""
echo -e "${BLUE}Installing pywal and theming tools...${NC}"
yay -S --needed --noconfirm \
    python-pywal16 \
    imagemagick \
    swww \
    wpaperd \
    python-pywalfox

echo ""
echo -e "${BLUE}Installing utilities...${NC}"
yay -S --needed --noconfirm \
    grim \
    slurp \
    swappy \
    wl-clipboard \
    cliphist \
    brightnessctl \
    pamixer \
    playerctl \
    btop \
    htop \
    neofetch \
    walogram

echo ""
echo -e "${BLUE}Installing file managers...${NC}"
yay -S --needed --noconfirm \
    thunar \
    thunar-volman \
    thunar-archive-plugin \
    gvfs \
    gvfs-mtp \
    file-roller \
    ranger \
    yazi \
    ntfs-3g

echo ""
echo -e "${BLUE}Installing development tools...${NC}"
yay -S --needed --noconfirm \
    visual-studio-code-bin \
    docker \
    docker-compose \
    nodejs \
    npm \
    python \
    python-pip \
    hugo \
    xsel

echo ""
echo -e "${BLUE}Installing communication apps...${NC}"
yay -S --needed --noconfirm \
    telegram-desktop \
    discord \
    whatsapp-for-linux

echo ""
echo -e "${BLUE}Installing productivity apps...${NC}"
yay -S --needed --noconfirm \
    bitwarden \
    firefox

echo ""
echo -e "${BLUE}Installing media tools...${NC}"
yay -S --needed --noconfirm \
    gimp \
    kdenlive \
    transmission-cli \
    yt-dlp \
    mpv \
    imv \
    feh \ 
    kdeconnect

echo ""
echo -e "${BLUE}Installing system tools...${NC}"
yay -S --needed --noconfirm \
    networkmanager \
    network-manager-applet \
    bluez \
    bluez-utils \
    blueman \
    pavucontrol \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    pipewire-jack \
    wireplumber

echo ""
echo -e "${BLUE}Installing SDDM and themes...${NC}"
yay -S --needed --noconfirm \
    sddm \
    qt5-graphicaleffects \
    qt5-quickcontrols2 \
    qt5-svg

echo ""
echo -e "${BLUE}Installing fonts and themes...${NC}"
yay -S --needed --noconfirm \
    papirus-icon-theme \
    breeze-gtk \
    breeze-icons \
    adwaita-qt5 \
    adwaita-qt6

echo ""
echo -e "${BLUE}Installing additional utilities...${NC}"
yay -S --needed --noconfirm \
    ripgrep \
    fd \
    eza \
    bat \
    fzf \
    zoxide \
    starship \
    thefuck \
    unzip \
    unrar \
    p7zip \
    rsync \
    wget \
    curl

# Enable services
echo ""
echo -e "${BLUE}Enabling services...${NC}"
sudo systemctl enable NetworkManager
sudo systemctl enable bluetooth
sudo systemctl enable sddm

# Docker setup
echo ""
echo -e "${BLUE}Setting up Docker...${NC}"
sudo systemctl enable docker
sudo usermod -aG docker $USER
echo -e "${GREEN}✓ Added $USER to docker group${NC}"

echo ""
echo -e "${GREEN}=================================="
echo "✓ Installation Complete!"
echo "==================================${NC}"
echo ""
echo "Next steps:"
echo "1. Reboot your system"
echo "2. Run ./setup-configs.sh to deploy SpectrumOS configs"
echo ""
echo -e "${BLUE}Note: You may need to logout/login for docker group to take effect${NC}"
