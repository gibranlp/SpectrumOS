#!/bin/bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# Complete Installation & Configuration Script

set -eo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Log all output to file for debugging
LOG_FILE="/tmp/spectrumos-install-${TIMESTAMP}.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "Install log: $LOG_FILE"

echo -e "${BLUE}🌈 SpectrumOS Master Installer${NC}"
echo "=================================="
echo ""

# --- Initial Checks ---

if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}Please do not run as root${NC}"
    exit 1
fi

# Check Disk Space
FREE_SPACE=$(df -m / | awk 'NR==2 {print $4}')
echo -e "${BLUE}Free disk space: ${FREE_SPACE}MB${NC}"

if [ "$FREE_SPACE" -lt 5000 ]; then
    echo -e "${RED}⚠️ Low disk space detected!${NC}"
    echo -e "${RED}SpectrumOS requires at least 10GB of free space for a full install.${NC}"
    echo -e "${RED}We will try a 'Lite' installation by skipping heavy packages.${NC}"
    SKIP_HEAVY=true
else
    SKIP_HEAVY=false
fi

# --- System Preparation ---

echo -e "${BLUE}Enabling multilib repository...${NC}"
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    sudo sed -i '/^#\[multilib\]/,+1 s/^#//' /etc/pacman.conf
    sudo pacman -Sy
fi

echo -e "${BLUE}Installing base-devel, git and paru...${NC}"
sudo pacman -S --needed --noconfirm base-devel git

if ! command -v paru &> /dev/null; then
    cd /tmp
    git clone https://aur.archlinux.org/paru.git
    cd paru
    makepkg -si --noconfirm
    cd ~
fi

echo -e "${BLUE}Updating system...${NC}"
paru -Syu --noconfirm

# --- Hardware Detection ---

echo -e "${BLUE}Detecting hardware...${NC}"
CPU_VENDOR=$(grep -m 1 'vendor_id' /proc/cpuinfo | awk '{print $3}')
UCODE_PKG=""
if [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
    UCODE_PKG="amd-ucode"
    echo -e "${GREEN}✓ AMD CPU detected${NC}"
elif [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
    UCODE_PKG="intel-ucode"
    echo -e "${GREEN}✓ Intel CPU detected${NC}"
fi

GPU_PKGS=()
IS_VM=false
if lspci | grep -i "vga" | grep -iq "nvidia"; then
    echo -e "${GREEN}✓ NVIDIA GPU detected${NC}"
    GPU_PKGS=("nvidia-dkms" "nvidia-utils" "lib32-nvidia-utils" "nvidia-settings")
elif lspci | grep -i "vga" | grep -iq "amd"; then
    echo -e "${GREEN}✓ AMD GPU detected${NC}"
    GPU_PKGS=("mesa" "lib32-mesa" "vulkan-radeon" "lib32-vulkan-radeon" "libva-mesa-driver" "lib32-libva-mesa-driver" "mesa-vdpau" "lib32-mesa-vdpau" "xf86-video-amdgpu")
elif lspci | grep -i "vga" | grep -iq "intel"; then
    echo -e "${GREEN}✓ Intel GPU detected${NC}"
    GPU_PKGS=("mesa" "lib32-mesa" "vulkan-intel" "lib32-vulkan-intel" "intel-media-driver" "libva-intel-driver" "lib32-libva-intel-driver")
elif lspci | grep -i "vga" | grep -iqE "virtio|vmware|vmwgfx|virtualbox|vbox"; then
    echo -e "${YELLOW}⚠ Virtual machine GPU detected — installing mesa only${NC}"
    GPU_PKGS=("mesa" "lib32-mesa" "mesa-utils")
    IS_VM=true
else
    echo -e "${YELLOW}⚠ GPU not recognized — installing generic mesa${NC}"
    GPU_PKGS=("mesa" "lib32-mesa")
fi

# Skip heavy gaming packages in a VM unless explicitly overridden
if [ "$IS_VM" = true ] && [ "$SKIP_HEAVY" = false ]; then
    echo -e "${YELLOW}VM detected — skipping gaming packages (use FORCE_GAMING=true to override)${NC}"
    [ "${FORCE_GAMING:-false}" = false ] && SKIP_HEAVY=true
fi

# --- Package Lists ---

SYSTEM_PKGS=(
    "limine" "limine-mkinitcpio-hook" "plymouth" "tlp" "tlp-rdw" "acpi" "acpi_call" "cpupower"
    "hyprland" "hyprpaper" "hypridle" "hyprlock" "hyprpicker" "xdg-desktop-portal-hyprland" "xdg-desktop-portal-gtk" "neovim"
    "qt5-wayland" "qt6-wayland" "qt5ct" "qt6ct" "kvantum" "waybar" "rofi-wayland" "dunst" "libnotify"
    "awww" "swappy" "grim" "slurp" "wl-clipboard" "cliphist" "brightnessctl" "pamixer" "playerctl" "nwg-displays"
    "kitty" "zsh" "zsh-completions" "zsh-syntax-highlighting" "zsh-autosuggestions" "starship" "fzf" "zoxide" "eza" "bat" "fd" "ripgrep" "thefuck"
    "networkmanager" "network-manager-applet" "bluez" "bluez-utils" "blueman" "pavucontrol" "pipewire" "pipewire-pulse" "pipewire-alsa" "pipewire-jack" "wireplumber" "libldac" "gvfs" "gvfs-mtp" "gvfs-smb" "gvfs-nfs" "tumbler" "file-roller" "unzip" "unrar" "p7zip" "rsync" "wget" "curl" "btop" "htop" "aur/neofetch" "locate" "imagemagick"
    "thunar" "thunar-volman" "thunar-archive-plugin" "yazi" "ranger" "ntfs-3g"
    "sddm" "qt5-graphicaleffects" "qt5-quickcontrols2" "qt5-svg"
    "cava" "polkit-gnome" "gromit-mpx" "xsettingsd"
)

THEMING_PKGS=(
    "aur/python-pywal16" "aur/python-pywalfox" "aur/colorz" "python-colorthief" "aur/python-haishoku" "aur/gowall" "aur/walogram-git" "python-pillow" "python-cairosvg" "papirus-icon-theme" "breeze-gtk" "breeze-icons" "aur/adwaita-qt5" "aur/adwaita-qt6" "aur/bibata-cursor-theme"
)
# Add themix only if space allows (it is massive, used for GTK/QT theme generation)
if [ "$SKIP_HEAVY" = false ]; then
    THEMING_PKGS+=("aur/themix-full-git")
fi

FONTS_PKGS=(
    "otf-font-awesome" "ttf-jetbrains-mono-nerd" "ttf-firacode-nerd" "noto-fonts" "noto-fonts-emoji"
)

GAMING_PKGS=()
if [ "$SKIP_HEAVY" = false ]; then
    GAMING_PKGS=(
        "steam" "lutris" "wine-staging" "winetricks" "gamemode" "lib32-gamemode" "mangohud" "lib32-mangohud" "gamescope" "vkbasalt" "goverlay" "proton-ge-custom"
    )
fi

APPS_PKGS=(
    "firefox" "docker" "docker-compose" "jdk-openjdk" "nodejs" "npm" "python" "python-pip" "hugo" "telegram-desktop" "discord" "aur/zapzap" "extra/bitwarden" "gimp" "kdenlive" "mpv" "vlc" "imv" "feh" "kdeconnect" "yt-dlp" "transmission-gtk" "extra/gemini-cli" "aur/claude-code" "archiso"
)
# Skip some very large apps if space is tight
if [ "$SKIP_HEAVY" = false ]; then
    APPS_PKGS+=("aur/google-chrome" "aur/visual-studio-code-bin")
fi

# --- Package Installation ---

echo -e "${BLUE}Cleaning caches to maximize space...${NC}"
sudo pacman -Scc --noconfirm || true
rm -rf ~/.cache/paru/* || true
# The "Hammer" approach: Force remove jack2/lib32-jack2 ignoring dependencies
# This is safe because we are immediately replacing them with pipewire-jack
if pacman -Qi jack2 &> /dev/null; then
    echo -e "${BLUE}Force removing jack2...${NC}"
    sudo pacman -Rdd --noconfirm jack2 || true
fi
if pacman -Qi lib32-jack2 &> /dev/null; then
    echo -e "${BLUE}Force removing lib32-jack2...${NC}"
    sudo pacman -Rdd --noconfirm lib32-jack2 || true
fi

# Preemptively install pipewire replacements
echo -e "${BLUE}Installing Pipewire-JACK replacements...${NC}"
sudo pacman -S --needed --noconfirm pipewire-jack lib32-pipewire-jack

echo -e "${BLUE}Installing all packages...${NC}"
# Pre-install limine-mkinitcpio-hook separately: its .install script has an interactive
# read prompt that --noconfirm does not suppress; piping yes answers it automatically.
echo -e "${BLUE}Pre-installing limine and limine-mkinitcpio-hook...${NC}"
yes | paru -S --needed limine limine-mkinitcpio-hook

# We install drivers and microcode first to satisfy dependencies and avoid provider prompts
echo -e "${BLUE}Step 1: Drivers and Hardware Support...${NC}"
DRIVER_PKGS=("${GPU_PKGS[@]}")
[ -n "$UCODE_PKG" ] && DRIVER_PKGS+=("$UCODE_PKG")
if [ "${#DRIVER_PKGS[@]}" -gt 0 ]; then
    paru -S --needed --noconfirm "${DRIVER_PKGS[@]}"
else
    echo -e "${YELLOW}No drivers to install — skipping Step 1${NC}"
fi

echo -e "${BLUE}Step 2: System and Desktop Environment...${NC}"
paru -S --needed --noconfirm "${SYSTEM_PKGS[@]}"

echo -e "${BLUE}Step 3: Theming and Fonts...${NC}"
paru -S --needed --noconfirm "${THEMING_PKGS[@]}" "${FONTS_PKGS[@]}"

# Install local fonts
if [ -d "$SCRIPT_DIR/fonts" ]; then
    echo -e "${BLUE}Installing local fonts from $SCRIPT_DIR/fonts...${NC}"
    sudo mkdir -p /usr/local/share/fonts/SpectrumOS
    sudo cp -v "$SCRIPT_DIR"/fonts/* /usr/local/share/fonts/SpectrumOS/
    fc-cache -fv
    echo -e "${GREEN}✓ Local fonts installed${NC}"
fi

echo -e "${BLUE}Step 4: Gaming and Applications...${NC}"
paru -S --needed --noconfirm "${GAMING_PKGS[@]}" "${APPS_PKGS[@]}"

# --- Configuration Deployment ---

echo -e "${BLUE}Deploying SpectrumOS configurations...${NC}"

# Use dots.sh for all configuration deployment to ensure consistency
if [ -f "$SCRIPT_DIR/dots.sh" ]; then
    bash "$SCRIPT_DIR/dots.sh" --all
else
    echo -e "${RED}Error: dots.sh not found in $SCRIPT_DIR${NC}"
    exit 1
fi

# Auto-configure Nvidia env vars if Nvidia GPU detected
if [[ "${GPU_PKGS[*]}" == *"nvidia"* ]]; then
    echo -e "${BLUE}Nvidia GPU detected — enabling Hyprland Nvidia env vars...${NC}"
    HYPR_ENV="$HOME/.config/hypr/env.conf"
    sed -i 's/^# env = LIBVA_DRIVER_NAME,nvidia/env = LIBVA_DRIVER_NAME,nvidia/' "$HYPR_ENV"
    sed -i 's/^# env = GBM_BACKEND,nvidia-drm/env = GBM_BACKEND,nvidia-drm/' "$HYPR_ENV"
    sed -i 's/^# env = __GLX_VENDOR_LIBRARY_NAME,nvidia/env = __GLX_VENDOR_LIBRARY_NAME,nvidia/' "$HYPR_ENV"
    sed -i 's/^# env = WLR_NO_HARDWARE_CURSORS,1/env = WLR_NO_HARDWARE_CURSORS,1/' "$HYPR_ENV"
    echo -e "${GREEN}✓ Nvidia env vars configured${NC}"
fi

# --- Services & Finalization ---

echo -e "${BLUE}Enabling services...${NC}"
sudo systemctl enable NetworkManager bluetooth sddm tlp docker
sudo usermod -aG docker $USER

# Finalize Theming
echo -e "${BLUE}Initializing SpectrumOS theme...${NC}"
mkdir -p "$HOME/Pictures/Wallpapers"
DEFAULT_WALLPAPER="$SCRIPT_DIR/sddm/themes/spectrumos/Previews/Mockup.jpg"
if [ -f "$DEFAULT_WALLPAPER" ]; then
    cp "$DEFAULT_WALLPAPER" "$HOME/Pictures/Wallpapers/SpectrumOS_Default.jpg"
    sudo mkdir -p /var/lib/spectrumos
    sudo chown -R $USER:$USER /var/lib/spectrumos
    convert "$DEFAULT_WALLPAPER" /var/lib/spectrumos/current.png
    
    # Generate initial colors (skip setting wallpaper as no Wayland session yet)
    echo -e "${BLUE}Generating initial color palette...${NC}"
    wal -i /var/lib/spectrumos/current.png -n || echo "Warning: Initial Pywal generation failed, will retry on first boot."

    # Copy pywal-generated configs to their target locations for first boot
    if [ -f "$HOME/.cache/wal/dunstrc" ]; then
        mkdir -p "$HOME/.config/dunst"
        cp "$HOME/.cache/wal/dunstrc" "$HOME/.config/dunst/dunstrc"
        echo -e "${GREEN}✓ Initial dunst config deployed${NC}"
    fi
    if [ -f "$HOME/.cache/wal/cava-config" ]; then
        mkdir -p "$HOME/.config/cava"
        cp "$HOME/.cache/wal/cava-config" "$HOME/.config/cava/config"
        echo -e "${GREEN}✓ Initial cava config deployed${NC}"
    fi
    if [ -f "$HOME/.cache/wal/sddm-colors.conf" ]; then
        cp "$HOME/.cache/wal/sddm-colors.conf" /var/lib/spectrumos/colors.conf
        echo -e "${GREEN}✓ Initial SDDM colors deployed${NC}"
    fi

    # Copy Limine theme from dotfiles and apply generated colors
    echo -e "${BLUE}Applying Limine theme from dotfiles...${NC}"
    ESP=$(findmnt -no TARGET /boot || findmnt -no TARGET /efi || echo "/boot")
    if [ -f "$SCRIPT_DIR/limine/limine.conf.example" ]; then
        sudo cp -v "$SCRIPT_DIR/limine/limine.conf.example" "$ESP/limine.conf"
        echo -e "${GREEN}✓ Limine theme copied to $ESP/limine.conf${NC}"
        if [ -x /usr/local/bin/spectrumos-limine-sync.sh ]; then
            sudo /usr/local/bin/spectrumos-limine-sync.sh || echo "Warning: Limine sync failed, will retry on first boot."
        fi
    else
        echo "Warning: limine.conf.example not found in $SCRIPT_DIR/limine/"
    fi

    # Generate SpectrumOS Logo for hyprlock
    if [ -f "$SCRIPT_DIR/bin/SOS_Gen_Logo.py" ]; then
        echo -e "${BLUE}Generating SpectrumOS Logo...${NC}"
        python "$SCRIPT_DIR/bin/SOS_Gen_Logo.py" || echo "Warning: Logo generation failed."
    fi
fi

# Shell Setup
[ "$SHELL" != "/usr/bin/zsh" ] && sudo chsh -s /usr/bin/zsh $USER
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    # RUNZSH=no prevents oh-my-zsh from starting a new shell; KEEP_ZSHRC=yes
    # prevents it from overwriting the .zshrc deployed by dots.sh above.
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}
mkdir -p "$ZSH_CUSTOM/plugins"
[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

# Redeploy ZSH config after oh-my-zsh (it may have overwritten .zshrc)
if [ -f "$SCRIPT_DIR/config/zsh/.zshrc" ]; then
    echo -e "${BLUE}Re-deploying .zshrc after oh-my-zsh installation...${NC}"
    cp "$SCRIPT_DIR/config/zsh/.zshrc" "$HOME/.zshrc"
fi

echo ""
echo -e "${GREEN}=================================="
echo "✓ SpectrumOS Installation Complete!"
echo "==================================${NC}"
echo ""
echo "Please reboot your system to apply all changes."
echo ""
