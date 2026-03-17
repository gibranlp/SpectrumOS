#!/bin/bash
# SpectrumOS Installation Script
# Installs all dependencies and software for SpectrumOS
# Focused on AMD CPU/GPU and Gaming

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

echo -e "${BLUE}🌈 SpectrumOS Installation Script${NC}"
echo "=================================="
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}Please do not run as root${NC}"
    exit 1
fi

# Enable multilib
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    echo -e "${BLUE}Enabling multilib repository...${NC}"
    sudo sed -i '/^#\[multilib\]/,+1 s/^#//' /etc/pacman.conf
    sudo pacman -Sy
    echo -e "${GREEN}✓ multilib enabled${NC}"
else
    echo -e "${GREEN}✓ multilib already enabled${NC}"
fi

# Install base-devel and git
echo -e "${BLUE}Installing base-devel and git...${NC}"
sudo pacman -S --needed --noconfirm base-devel git

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

# Package lists
SYSTEM_PKGS=(
    # Boot & Hardware
    "amd-ucode"
    "limine"
    "limine-mkinitcpio-hook"
    "plymouth"
    "tlp"
    "tlp-rdw"
    "acpi"
    "acpi_call"
    "cpupower"
    
    # AMD Graphics
    "mesa"
    "lib32-mesa"
    "vulkan-radeon"
    "lib32-vulkan-radeon"
    "libva-mesa-driver"
    "lib32-libva-mesa-driver"
    "mesa-vdpau"
    "lib32-mesa-vdpau"
    "xf86-video-amdgpu"
    
    # Desktop Environment
    "hyprland"
    "hyprpaper"
    "hypridle"
    "hyprlock"
    "hyprpicker"
    "xdg-desktop-portal-hyprland"
    "xdg-desktop-portal-gtk"
    "qt5-wayland"
    "qt6-wayland"
    "qt5ct"
    "qt6ct"
    "kvantum"
    "waybar"
    "rofi-wayland"
    "dunst"
    "libnotify"
    "swww"
    "swappy"
    "grim"
    "slurp"
    "wl-clipboard"
    "cliphist"
    "brightnessctl"
    "pamixer"
    "playerctl"
    "nwg-display"
    
    # Shell & Terminal
    "kitty"
    "zsh"
    "zsh-completions"
    "zsh-syntax-highlighting"
    "zsh-autosuggestions"
    "starship"
    "fzf"
    "zoxide"
    "eza"
    "bat"
    "fd"
    "ripgrep"
    "thefuck"
    
    # System Utilities
    "networkmanager"
    "network-manager-applet"
    "bluez"
    "bluez-utils"
    "blueman"
    "pavucontrol"
    "pipewire"
    "pipewire-pulse"
    "pipewire-alsa"
    "pipewire-jack"
    "wireplumber"
    "libldac"
    "gvfs"
    "gvfs-mtp"
    "gvfs-smb"
    "gvfs-nfs"
    "tumbler"
    "file-roller"
    "unzip"
    "unrar"
    "p7zip"
    "rsync"
    "wget"
    "curl"
    "btop"
    "htop"
    "neofetch"
    "locate"
    "imagemagick"
    
    # File Manager
    "thunar"
    "thunar-volman"
    "thunar-archive-plugin"
    "yazi"
    "ranger"
    "ntfs-3g"
    
    # Display Manager
    "sddm"
    "qt5-graphicaleffects"
    "qt5-quickcontrols2"
    "qt5-svg"
)

THEMING_PKGS=(
    "python-pywal16"
    "python-pywalfox"
    "colorz"
    "python-colorthief"
    "python-haishoku"
    "python-modern-colorthief"
    "gowall"
    "walogram"
    "themix-full-git"
    "python-pillow"
    "python-cairosvg"
    "papirus-icon-theme"
    "breeze-gtk"
    "breeze-icons"
    "adwaita-qt5"
    "adwaita-qt6"
    "bibata-cursor-theme"
)

FONTS_PKGS=(
    "otf-font-awesome"
    "ttf-jetbrains-mono-nerd"
    "ttf-firacode-nerd"
    "noto-fonts"
    "noto-fonts-emoji"
)

GAMING_PKGS=(
    "steam"
    "lutris"
    "wine-staging"
    "winetricks"
    "gamemode"
    "lib32-gamemode"
    "mangohud"
    "lib32-mangohud"
    "gamescope"
    "vkbasalt"
    "goverlay"
    "proton-ge-custom"
)

APPS_PKGS=(
    "firefox"
    "google-chrome"
    "visual-studio-code-bin"
    "docker"
    "docker-compose"
    "nodejs"
    "npm"
    "python"
    "python-pip"
    "hugo"
    "telegram-desktop"
    "discord"
    "whatsapp-for-linux"
    "bitwarden"
    "gimp"
    "kdenlive"
    "mpv"
    "vlc"
    "imv"
    "feh"
    "kdeconnect"
    "yt-dlp"
    "transmission-gtk"
    "gemini-cli"
    "claude-code"
    "archiso"
)

echo -e "${BLUE}Installing System packages...${NC}"
yay -S --needed --noconfirm "${SYSTEM_PKGS[@]}"

echo -e "${BLUE}Installing Theming packages...${NC}"
yay -S --needed --noconfirm "${THEMING_PKGS[@]}"

echo -e "${BLUE}Installing Fonts...${NC}"
yay -S --needed --noconfirm "${FONTS_PKGS[@]}"

echo -e "${BLUE}Installing Gaming packages...${NC}"
yay -S --needed --noconfirm "${GAMING_PKGS[@]}"

echo -e "${BLUE}Installing Apps...${NC}"
yay -S --needed --noconfirm "${APPS_PKGS[@]}"

# Enable services
echo -e "${BLUE}Enabling services...${NC}"
sudo systemctl enable NetworkManager
sudo systemctl enable bluetooth
sudo systemctl enable sddm
sudo systemctl enable tlp
sudo systemctl enable docker

# Docker setup
sudo usermod -aG docker $USER
echo -e "${GREEN}✓ Added $USER to docker group${NC}"

# Set ZSH as default shell
if [ "$SHELL" != "/usr/bin/zsh" ]; then
    echo -e "${BLUE}Setting ZSH as default shell...${NC}"
    sudo chsh -s /usr/bin/zsh $USER
fi

# Install oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo -e "${BLUE}Installing oh-my-zsh...${NC}"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install zsh plugins
echo -e "${BLUE}Installing zsh plugins...${NC}"
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}
mkdir -p "$ZSH_CUSTOM/plugins"

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# Run setup scripts
echo -e "${BLUE}Creating directory structure...${NC}"
bash "$SCRIPT_DIR/setup-dirs.sh"

echo -e "${BLUE}Deploying configurations...${NC}"
bash "$SCRIPT_DIR/dots.sh" --all

echo ""
echo -e "${GREEN}=================================="
echo "✓ SpectrumOS Installation Complete!"
echo "==================================${NC}"
echo ""
echo "Please reboot your system to apply all changes."
echo ""
