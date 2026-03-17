#!/usr/bin/env bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 

# Get the directory where the script is located
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Install Bin files
function install_bin(){
    echo -e "${BLUE}Installing SpectrumOS scripts...${NC}"
    sudo mkdir -p /usr/share/spectrumos/scripts/
    sudo cp -rv "$SCRIPT_DIR"/bin/* /usr/share/spectrumos/scripts/
    sudo chmod +x /usr/share/spectrumos/scripts/*
    echo -e "${GREEN}✓ Scripts installed to /usr/share/spectrumos/scripts/${NC}"
}

# Create local files and directories
function create_local_files(){
    echo -e "${BLUE}Creating local directories...${NC}"
    sudo mkdir -pv /usr/local/spectrumos
    sudo chown -R $USER:$USER /usr/local/spectrumos

    mkdir -p $HOME/.config/cava/
    mkdir -p $HOME/.config/gowall/
    mkdir -p $HOME/.config/hypr
    mkdir -p $HOME/.config/gromit-mpx
    mkdir -p $HOME/.config/rofi
    mkdir -p $HOME/.config/swappy
    mkdir -p $HOME/.config/wal/templates
    mkdir -p $HOME/.config/waybar
    mkdir -p $HOME/.config/kitty
    mkdir -p $HOME/.config/nvim
}

# Install GOWall config
function install_gowall_config(){
    echo -e "${BLUE}Installing GOWall config...${NC}"
    cp -rv "$SCRIPT_DIR"/config/gowall/* $HOME/.config/gowall/
}

# Install hyprland configs
function install_hyprland_config(){
    echo -e "${BLUE}Installing Hyprland configs...${NC}"
    cp -rv "$SCRIPT_DIR"/config/hypr/* $HOME/.config/hypr/
}

# Install Gromit config
function install_gromit(){
    echo -e "${BLUE}Installing Gromit-MPX config...${NC}"
    cp -rv "$SCRIPT_DIR"/config/gromit-mpx/* $HOME/.config/gromit-mpx/
}

# Install Limine Sync Files
function install_limine_sync(){
    echo -e "${BLUE}Installing Limine Sync...${NC}"
    # Copy script
    sudo cp -v "$SCRIPT_DIR"/limine/spectrumos-limine-sync.sh /usr/local/bin/
    sudo chmod +x /usr/local/bin/spectrumos-limine-sync.sh

    # Copy Systemd Service and Path
    sudo cp -v "$SCRIPT_DIR"/limine/spectrumos-limine-sync.service /etc/systemd/system/
    sudo cp -v "$SCRIPT_DIR"/limine/spectrumos-limine-sync.path /etc/systemd/system/

    # Pacman Hooks
    sudo mkdir -p /etc/pacman.d/hooks
    sudo cp "$SCRIPT_DIR"/etc/pacman.d/hooks/95-spectrumos-limine.hook /etc/pacman.d/hooks/
    sudo mkdir -p /etc/kernel
    sudo cp "$SCRIPT_DIR"/etc/kernel/install.conf /etc/kernel/

    # Enable path Watcher
    sudo systemctl daemon-reload
    sudo systemctl enable spectrumos-limine-sync.path
    sudo systemctl start spectrumos-limine-sync.path
    echo -e "${GREEN}✓ Limine sync installed and enabled${NC}"
}

function install_plymouth(){
    echo -e "${BLUE}Installing Plymouth theme...${NC}"
    # Copy theme to Plymouth themes directory
    sudo mkdir -p /usr/share/plymouth/themes/
    sudo cp -rv "$SCRIPT_DIR"/plymouth/themes/spectrumos /usr/share/plymouth/themes/

    # Set the default theme
    sudo plymouth-set-default-theme -R spectrumos

    # Add Plymouth hook to mkinitcpio
    if ! grep -q "plymouth" /etc/mkinitcpio.conf; then
        sudo sed -i 's/HOOKS=(base udev/HOOKS=(base udev plymouth/' /etc/mkinitcpio.conf
        echo "Plymouth hook added to mkinitcpio.conf"
    fi

    sudo mkdir -p /etc/pacman.d/hooks
    sudo cp "$SCRIPT_DIR"/plymouth/plymouth-quit-fix.hook /etc/pacman.d/hooks/plymouth-quit-fix.hook

    # Regenerate initramfs
    sudo mkinitcpio -P
    echo -e "${GREEN}✓ Plymouth theme installed and initramfs regenerated${NC}"
}

# Install ROFI themes
function install_rofi_themes(){
    echo -e "${BLUE}Installing Rofi themes...${NC}"
    cp -rv "$SCRIPT_DIR"/config/rofi/* $HOME/.config/rofi/
}

# Install SDDM Theme
function install_sddm_theme(){
    echo -e "${BLUE}Installing SDDM theme...${NC}"
    sudo mkdir -p /usr/share/sddm/themes/spectrumos
    sudo cp -rv "$SCRIPT_DIR"/sddm/themes/spectrumos/* /usr/share/sddm/themes/spectrumos/

    # Configure SDDM to use the theme
    if [ -f /etc/sddm.conf ]; then
        sudo cp /etc/sddm.conf /etc/sddm.conf.bak
    fi
    sudo cp "$SCRIPT_DIR"/etc/sddm.conf /etc/sddm.conf
}

# Install Spectrum Config Files
function install_spectrum_config(){
    echo -e "${BLUE}Installing SpectrumOS system configs...${NC}"
    sudo mkdir -p /etc/spectrumos
    sudo cp -rv "$SCRIPT_DIR"/etc/spectrumos/* /etc/spectrumos/
    sudo chmod -R 777 /etc/spectrumos
}

# Install Swappy config
function install_swappy_config(){
    echo -e "${BLUE}Installing Swappy config...${NC}"
    cp -rv "$SCRIPT_DIR"/config/swappy/* $HOME/.config/swappy/
}

# Install TLP
function install_tlp(){
    echo -e "${BLUE}Installing TLP config...${NC}"
    sudo cp -v "$SCRIPT_DIR"/etc/tlp.conf /etc/tlp.conf
    sudo systemctl enable tlp.service
    sudo systemctl start tlp.service
}

# Install Wal Templates
function install_wal_templates(){
    echo -e "${BLUE}Installing Wal templates...${NC}"
    cp -rv "$SCRIPT_DIR"/config/wal/templates/* $HOME/.config/wal/templates/
}

# Install Waybar config
function install_waybar_config(){
    echo -e "${BLUE}Installing Waybar configs...${NC}"
    cp -rv "$SCRIPT_DIR"/config/waybar/* $HOME/.config/waybar/
}

# Install Kitty config
function install_kitty_config(){
    echo -e "${BLUE}Installing Kitty config...${NC}"
    cp -rv "$SCRIPT_DIR"/config/kitty/* $HOME/.config/kitty/
}

# Install Neovim config
function install_nvim_config(){
    echo -e "${BLUE}Installing Neovim config...${NC}"
    cp -rv "$SCRIPT_DIR"/config/nvim/* $HOME/.config/nvim/
}

# Install ZSH config
function install_zsh_config(){
    echo -e "${BLUE}Installing ZSH config...${NC}"
    cp -v "$SCRIPT_DIR"/config/zsh/.zshrc $HOME/
}

function install_all(){
    create_local_files
    install_bin
    install_gowall_config
    install_hyprland_config
    install_gromit
    install_limine_sync
    install_plymouth
    install_rofi_themes
    install_sddm_theme
    install_spectrum_config
    install_swappy_config
    install_tlp
    install_wal_templates
    install_waybar_config
    install_kitty_config
    install_nvim_config
    install_zsh_config
    echo -e "${GREEN}✓ All configurations deployed!${NC}"
}

# Function to display usage information
function usage() {
    echo "Usage: $0 [OPTION]"
    echo "Options:"
    echo "  --all            Deploy all configurations"
    echo "  --bin            Install scripts to /usr/share/spectrumos/scripts/"
    echo "  --hypr           Install Hyprland configs"
    echo "  --waybar         Install Waybar configs"
    echo "  --rofi           Install Rofi themes"
    echo "  --sddm           Install SDDM theme"
    echo "  --plymouth       Install Plymouth theme"
    echo "  --limine         Install Limine sync files"
    echo "  --zsh            Install ZSH config"
    echo "  --kitty          Install Kitty config"
    echo "  --nvim           Install Neovim config"
    echo "  --spectrum       Install SpectrumOS system configs"
    exit 1
}

# Main script execution
if [ $# -eq 0 ]; then
    usage
fi

for arg in "$@"; do
    case $arg in
        --all)
            install_all
            ;;
        --bin)
            install_bin
            ;;
        --create-local)
            create_local_files
            ;;
        --gowall)
            install_gowall_config
            ;;
        --gromit)
            install_gromit
            ;;
        --hypr)
            install_hyprland_config
            ;;
        --limine)
            install_limine_sync
            ;;
        --plymouth)
            install_plymouth
            ;;
        --rofi)
            install_rofi_themes
            ;;  
        --sddm)
            install_sddm_theme
            ;;
        --swappy)
            install_swappy_config
            ;;
        --wal-templates)
            install_wal_templates
            ;;
        --waybar)
            install_waybar_config
            ;;
        --kitty)
            install_kitty_config
            ;;
        --nvim)
            install_nvim_config
            ;;
        --zsh)
            install_zsh_config
            ;;
        --spectrum)
            install_spectrum_config
            ;;
        *)
            usage
            ;;
    esac
done