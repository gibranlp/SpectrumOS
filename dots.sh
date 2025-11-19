#!/usr/bin/env bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 
# 
#

# Install Bin files
function install_bin(){
    mkdir -p $HOME/.local/bin
    cp -rv ~/SpectrumOS/bin/* $HOME/.local/bin/
    chmod +x $HOME/.local/bin/*
}

# Install variables
function create_local_files(){
    sudo mkdir -pv /usr/local/spectrumos
    sudo chown -R $USER:$USER /usr/local/spectrumos
}

# Install hyprland configs
function install_hyprland_config(){
    mkdir -p $HOME/.config/hypr
    cp -rv ~/SpectrumOS/config/hypr/* $HOME/.config/hypr/
}

# Install ROFI themes
function install_rofi_themes(){
    mkdir -p $HOME/.config/rofi/
    cp -rv ~/SpectrumOS/config/rofi/* $HOME/.config/rofi/
}

# Install SDDM Theme
function install_sddm_theme(){
    sudo mkdir -p /usr/local/spectrumos
    sudo chown -R $USER:$USER /usr/local/spectrumos
    sudo mkdir -p /usr/share/sddm/themes/spectrumos
    sudo cp -rv ~/SpectrumOS/sddm/themes/spectrumos/* /usr/share/sddm/themes/spectrumos/
}

# Install Wal Templates
function install_wal_templates(){
    mkdir -p $HOME/.config/wal/templates
    cp -rv ~/SpectrumOS/config/wal/templates/* $HOME/.config/wal/templates/
}

# Install Waybar config
function install_waybar_config(){
    mkdir -p $HOME/.config/waybar
    cp -rv ~/SpectrumOS/config/waybar/* $HOME/.config/waybar/
}


# Function to display usage information
function usage() {
    echo "Usage: $0 [--bin] [--create-local] [--hypr] [--rofi] [--sddm] [--wal-templates] [--waybar]"
    exit 1
}

# Main script execution
if [ $# -eq 0 ]; then
    usage
fi

for arg in "$@"; do
    case $arg in
        --bin)
            install_bin
            ;;
        --create-local)
            create_local_files
            ;;
        --hypr)
            install_hyprland_config
            ;;
        --rofi)
            install_rofi_themes
            ;;  
        --sddm)
            install_sddm_theme
            ;;
        --wal-templates)
            install_wal_templates
            ;;
        --waybar)
            install_waybar_config
            ;;
    esac
done