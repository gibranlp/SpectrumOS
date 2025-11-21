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

# Install Limine Sync Files
function install_limine_sync(){
    # Copy script
    sudo cp -v ~/SpectrumOS/limine/spectrumos-limine-sync.sh /usr/local/bin/
    sudo chmod +x /usr/local/bin/spectrumos-limine-sync.sh

    # Copy Systemd Service and Path
    sudo cp -v ~/SpectrumOS/limine/spectrumos-limine-sync.service /etc/systemd/system/
    sudo cp -v ~/SpectrumOS/limine/spectrumos-limine-sync.path /etc/systemd/system/

    # Enable path Watcher
    sudo systemctl daemon-reload
    sudo systemctl enable spectrumos-limine-sync.path
    sudo systemctl start spectrumos-limine-sync.path
}


function install_plymouth(){
    # Install Plymouth
    yay -S plymouth --noconfirm
    
    # Copy theme to Plymouth themes directory
    sudo cp -rv ~/SpectrumOS/plymouth/themes/spectrumos /usr/share/plymouth/themes/
    
    # Set the default theme
    sudo plymouth-set-default-theme -R spectrumos
    
    # Add Plymouth hook to mkinitcpio
    # Backup original mkinitcpio.conf
    sudo cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.backup
    
    # Check if plymouth is already in HOOKS, if not add it
    if ! grep -q "plymouth" /etc/mkinitcpio.conf; then
        sudo sed -i 's/HOOKS=(base udev/HOOKS=(base udev plymouth/' /etc/mkinitcpio.conf
        echo "Plymouth hook added to mkinitcpio.conf"
    else
        echo "Plymouth hook already present in mkinitcpio.conf"
    fi
    
    # Reload systemd daemon
    sudo systemctl daemon-reload
    
    sudo mkdir -p /etc/pacman.d/hooks
    sudo cp ~/SpectrumOS/plymouth/plymouth-quit-fix.hook /etc/pacman.d/hooks/plymouth-quit-fix.hook

    # Regenerate initramfs
    sudo mkinitcpio -P
    
    # Update GRUB configuration (if using GRUB)
    if [ -f /etc/default/grub ]; then
        sudo cp /etc/default/grub /etc/default/grub.backup
        
        # Add quiet splash to kernel parameters if not present
        if ! grep -q "quiet splash" /etc/default/grub; then
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash /' /etc/default/grub
            echo "Added 'quiet splash' to GRUB parameters"
        fi
        
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        echo "GRUB configuration updated"
    fi
    
    # If using systemd-boot instead
    if [ -d /boot/loader/entries ]; then
        if [ -d /boot/loader/entries ]; then
            echo "Detected systemd-boot. Updating boot entries..."
            
            # Backup all entry files
            sudo cp -r /boot/loader/entries /boot/loader/entries.backup
            
            # Add quiet splash to all entry files if not present
            for entry in /boot/loader/entries/*.conf; do
                if [ -f "$entry" ]; then
                    # Check if quiet splash is already present
                    if ! grep -q "quiet splash" "$entry"; then
                        # Add quiet splash to the options line
                        sudo sed -i '/^options/ s/$/ quiet splash/' "$entry"
                        echo "Added 'quiet splash' to $(basename $entry)"
                    else
                        echo "'quiet splash' already present in $(basename $entry)"
                    fi
                fi
            done
            
            echo "systemd-boot entries updated!"
        fi
    fi
    
    echo "Plymouth installation complete! Reboot to see the boot splash."
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

# Install ZSH config
function install_zsh_config(){
    cp -rv ~/SpectrumOS/config/zsh/.zshrc $HOME/
}


# Function to display usage information
function usage() {
    echo "Usage: $0 [--bin] [--create-local] [--hypr] [--limine][--plymouth] [--rofi] [--sddm] [--wal-templates] [--waybar][--zsh]"
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
        --wal-templates)
            install_wal_templates
            ;;
        --waybar)
            install_waybar_config
            ;;
        --zsh)
            install_zsh_config
            ;;
    esac
done