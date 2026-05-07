#!/usr/bin/env bash
# _____             _                 _____ _____
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence

set -eo pipefail

# Get the directory where the script is located
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Helper function to deploy configuration with backup
# Usage: deploy_config <source_dir> <target_dir>
function deploy_config() {
    local src="$1"
    local dest="$2"
    
    echo -e "${BLUE}Deploying: $src -> $dest${NC}"
    mkdir -p "$dest"
    if [ -d "$src" ]; then
        cp -rv "$src/." "$dest/"
    else
        cp -v "$src" "$dest"
    fi
}

# Install Bin files
function install_bin(){
    echo -e "${BLUE}Installing SpectrumOS scripts...${NC}"
    # Create the directory as root (it lives under /usr/share), then immediately
    # hand ownership to the current user so all further operations need no sudo
    # and the user can update scripts in-place without sudo in the future.
    sudo mkdir -p /usr/share/spectrumos/scripts/
    sudo chown -R "$(id -u):$(id -g)" /usr/share/spectrumos/

    # Remove scripts that were deleted from bin/ so they don't linger installed
    local orphans=(SOS_PywalThemix SOS_PywalThemix.sh SOS_PywalGTK SOS_PywalGTK.sh SOS_Regenerate SOS_Regenerate.sh SOS_ReloadIcons SOS_ReloadIcons.sh)
    for f in "${orphans[@]}"; do
        rm -f "/usr/share/spectrumos/scripts/$f"
    done

    cp -rv "$SCRIPT_DIR"/bin/* /usr/share/spectrumos/scripts/
    find /usr/share/spectrumos/scripts/ -name "*.sh" -exec chmod +x {} +
    find /usr/share/spectrumos/scripts/ -name "*.py" -exec chmod +x {} +
    chmod 755 /usr/share/spectrumos/scripts/
    chmod +x /usr/share/spectrumos/scripts/*
    # Create extension-less symlinks so scripts are callable without .sh suffix
    find /usr/share/spectrumos/scripts/ -maxdepth 1 -name "*.sh" | while read f; do
        ln -sf "$f" "${f%.sh}"
    done
    echo -e "${GREEN}✓ Scripts installed to /usr/share/spectrumos/scripts/${NC}"
}

# Create local files and directories
function create_local_files(){
    echo -e "${BLUE}Creating local directories...${NC}"
    sudo mkdir -p /usr/share/spectrumos/{wallpapers,themes,scripts}
    sudo mkdir -p /var/lib/spectrumos
    sudo chown -R $USER:$USER /usr/share/spectrumos /var/lib/spectrumos
    sudo chmod -R 755 /usr/share/spectrumos /var/lib/spectrumos

    mkdir -p $HOME/.config/cava/
    mkdir -p $HOME/.config/cmus/
    mkdir -p $HOME/.config/gowall/
    mkdir -p $HOME/.config/hypr
    mkdir -p $HOME/.config/gromit-mpx
    mkdir -p $HOME/.config/rofi
    mkdir -p $HOME/.config/swappy
    mkdir -p $HOME/.config/wal/templates
    mkdir -p $HOME/.config/waybar
    mkdir -p $HOME/.config/kitty
    mkdir -p $HOME/.config/nvim
    mkdir -p $HOME/.config/xsettingsd

    # Cleanup legacy GTK overrides that conflict with wpgtk
    rm -f $HOME/.config/gtk-3.0/gtk.css
    # We keep gtk-4.0/gtk.css if it's managed by pywal, 
    # but for fresh install we want it clean
    rm -f $HOME/.config/gtk-4.0/gtk.css
}

# Refactored individual install functions
function install_gowall_config() { deploy_config "$SCRIPT_DIR/config/gowall" "$HOME/.config/gowall"; }
function install_hyprland_config() { deploy_config "$SCRIPT_DIR/config/hypr" "$HOME/.config/hypr"; }
function install_gromit() { deploy_config "$SCRIPT_DIR/config/gromit-mpx" "$HOME/.config/gromit-mpx"; }
function install_rofi_themes() { deploy_config "$SCRIPT_DIR/config/rofi" "$HOME/.config/rofi"; }
function install_swappy_config() { deploy_config "$SCRIPT_DIR/config/swappy" "$HOME/.config/swappy"; }
function install_wal_templates() { 
    deploy_config "$SCRIPT_DIR/config/wal/templates" "$HOME/.config/wal/templates"
    # Remove legacy templates that conflict with wpgtk
    rm -f "$HOME/.config/wal/templates/gtk.css"
    rm -f "$HOME/.config/wal/templates/gtk3.css"
}
function install_waybar_config() {
    deploy_config "$SCRIPT_DIR/config/waybar" "$HOME/.config/waybar"
    # Replace hardcoded home path in waybar CSS
    find "$HOME/.config/waybar" -name "*.css" -exec sed -i "s|/home/gibranlp|$HOME|g" {} +
    # Create initial config and style symlinks so waybar starts with the SpectrumOS layout
    ln -sf "$HOME/.config/waybar/configs/Productivity.json" "$HOME/.config/waybar/config"
    ln -sf "$HOME/.config/waybar/styles/default.css" "$HOME/.config/waybar/style.css"
}
function install_kitty_config() { deploy_config "$SCRIPT_DIR/config/kitty" "$HOME/.config/kitty"; }
function install_nvim_config() { deploy_config "$SCRIPT_DIR/config/nvim" "$HOME/.config/nvim"; }
function install_zsh_config() { deploy_config "$SCRIPT_DIR/config/zsh/.zshrc" "$HOME/.zshrc"; }
function install_xsettingsd() { deploy_config "$SCRIPT_DIR/config/xsettingsd" "$HOME/.config/xsettingsd"; }
function install_mimeapps() { deploy_config "$SCRIPT_DIR/config/mimeapps.list" "$HOME/.config/mimeapps.list"; }

function install_wpgtk() {
    if ! command -v wpg &>/dev/null; then
        echo -e "${YELLOW}wpgtk not installed — skipping${NC}"
        return 0
    fi
    echo -e "${BLUE}Initializing wpgtk templates...${NC}"
    wpg-install.sh -gio

    echo -e "${BLUE}Setting initial GTK configuration...${NC}"
    mkdir -p "$HOME/.config/gtk-3.0"
    cat > "$HOME/.config/gtk-3.0/settings.ini" << EOF
[Settings]
gtk-icon-theme-name = flattrcolor-dark
gtk-theme-name = FlatColor
gtk-font-name = Sans 10
gtk-cursor-theme-name = Adwaita
gtk-application-prefer-dark-theme = true
EOF

    mkdir -p "$HOME/.config/gtk-4.0"
    cp "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"

    # Ensure gtk-4.0/gtk.css is a real file if it exists as a symlink from previous attempts
    [ -L "$HOME/.config/gtk-4.0/gtk.css" ] && rm "$HOME/.config/gtk-4.0/gtk.css"

    if [ -f "$HOME/.cache/wal/gtk4-libadwaita.css" ]; then
        cp "$HOME/.cache/wal/gtk4-libadwaita.css" "$HOME/.config/gtk-4.0/gtk.css"
    fi

    echo -e "${GREEN}✓ wpgtk initialized and GTK settings configured${NC}"
}

function install_cmus_config() {
    echo -e "${BLUE}Installing cmus theme...${NC}"
    mkdir -p "$HOME/.config/cmus"
    # Ensure the theme file is in place (it will be updated by pywal via the template)
    if [ -f "$HOME/.cache/wal/cmus-theme" ]; then
        cp "$HOME/.cache/wal/cmus-theme" "$HOME/.config/cmus/SpectrumOS.theme"
    fi
    # Create a basic cmus autosave to set the theme if it doesn't exist
    if [ ! -f "$HOME/.config/cmus/autosave" ]; then
        echo "set color_scheme=SpectrumOS" > "$HOME/.config/cmus/autosave"
    fi
    echo -e "${GREEN}✓ cmus theme installed${NC}"
}

# Install Limine Sync Files
function install_limine_sync(){
    if ! command -v limine &>/dev/null; then
        echo -e "${YELLOW}Limine not installed — skipping${NC}"
        return 0
    fi
    echo -e "${BLUE}Installing Limine Sync...${NC}"

    # Detect ESP Path
    ESP=$(findmnt -no TARGET /boot || findmnt -no TARGET /efi || echo "/boot")
    
    # Create /etc/default/limine if it doesn't exist
    if [ ! -f /etc/default/limine ]; then
        echo "ESP_PATH=\"$ESP\"" | sudo tee /etc/default/limine > /dev/null
        echo "✓ Created /etc/default/limine with ESP_PATH=\"$ESP\""
    fi

    # Ensure /boot/limine/ directory exists and copy the example config if not present
    sudo mkdir -p /boot/limine
    if [ ! -f /boot/limine/limine.conf ]; then
        echo -e "${BLUE}No limine.conf found at /boot/limine/limine.conf, installing default...${NC}"
        sudo cp -v "$SCRIPT_DIR"/limine/limine.conf.example /boot/limine/limine.conf
    fi

    # Copy initial wallpaper to ESP root for Limine (boot():/spectrumos-wallpaper.jpg)
    if [ ! -f "$ESP/spectrumos-wallpaper.jpg" ]; then
        echo -e "${BLUE}Copying initial wallpaper for Limine boot screen...${NC}"
        if [ -f /var/lib/spectrumos/current.png ]; then
            if command -v convert &>/dev/null; then
                sudo convert /var/lib/spectrumos/current.png "$ESP/spectrumos-wallpaper.jpg"
            else
                sudo cp /var/lib/spectrumos/current.png "$ESP/spectrumos-wallpaper.jpg"
            fi
            echo -e "${GREEN}✓ Wallpaper copied to $ESP/spectrumos-wallpaper.jpg${NC}"
        else
            echo -e "${YELLOW}No wallpaper at /var/lib/spectrumos/current.png yet — will be set on first wallpaper change${NC}"
        fi
    fi

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
    sudo systemctl restart spectrumos-limine-sync.path
    echo -e "${GREEN}✓ Limine sync installed and enabled (watching colors.conf)${NC}"

    # Run sync immediately so the wallpaper and colors are applied right now,
    # not only on the next kernel upgrade or colors.conf change.
    if [ -x /usr/local/bin/spectrumos-limine-sync.sh ]; then
        echo -e "${BLUE}Running initial Limine sync...${NC}"
        sudo /usr/local/bin/spectrumos-limine-sync.sh || echo "Warning: Initial Limine sync failed"
    fi
}

function install_plymouth(){
    if ! command -v plymouth &>/dev/null; then
        echo -e "${YELLOW}Plymouth not installed — skipping${NC}"
        return 0
    fi
    echo -e "${BLUE}Installing Plymouth theme...${NC}"
    # Copy theme to Plymouth themes directory
    sudo mkdir -p /usr/share/plymouth/themes/
    sudo cp -rv "$SCRIPT_DIR"/plymouth/themes/spectrumos /usr/share/plymouth/themes/

    # Install Plymouth configuration first (before setting default theme)
    if [ -f "$SCRIPT_DIR/plymouth/plymouthd.defaults" ]; then
        sudo mkdir -p /etc/plymouth
        sudo cp -v "$SCRIPT_DIR/plymouth/plymouthd.defaults" /etc/plymouth/plymouthd.conf
        echo "Plymouth configuration installed to /etc/plymouth/plymouthd.conf"
    fi

    # Detect GPU for early KMS
    GPU_DRIVER=""
    if lspci | grep -i "vga" | grep -iq "nvidia"; then
        GPU_DRIVER="nvidia nvidia_modeset nvidia_uvm nvidia_drm"
    elif lspci | grep -i "vga" | grep -iq "amd"; then
        GPU_DRIVER="amdgpu"
    elif lspci | grep -i "vga" | grep -iq "intel"; then
        GPU_DRIVER="i915"
    elif lspci | grep -i "vga" | grep -iq "virtio"; then
        GPU_DRIVER="virtio_gpu"
    elif lspci | grep -i "vga" | grep -iq "qxl"; then
        GPU_DRIVER="qxl"
    elif lspci | grep -i "vga" | grep -iq "vmware"; then
        GPU_DRIVER="vmwgfx"
    elif lspci | grep -i "vga" | grep -iq "virtualbox"; then
        GPU_DRIVER="vboxvideo"
    elif lspci | grep -i "vga" | grep -iq "bochs"; then
        GPU_DRIVER="bochs"
    fi

    # Add GPU driver to MODULES in mkinitcpio.conf for early KMS
    if [ -n "$GPU_DRIVER" ]; then
        if ! grep -q "MODULES=(.*$GPU_DRIVER.*)" /etc/mkinitcpio.conf; then
            # Read current MODULES content, strip parens, prepend driver, collapse spaces
            CURRENT_MODULES=$(grep "^MODULES=" /etc/mkinitcpio.conf | sed 's/MODULES=(//;s/)//' | xargs)
            if [ -n "$CURRENT_MODULES" ]; then
                NEW_MODULES="$GPU_DRIVER $CURRENT_MODULES"
            else
                NEW_MODULES="$GPU_DRIVER"
            fi
            sudo sed -i "s|^MODULES=.*|MODULES=($NEW_MODULES)|" /etc/mkinitcpio.conf
            echo "Added $GPU_DRIVER to MODULES in mkinitcpio.conf: ($NEW_MODULES)"
        fi
    fi

    # Add and reorder HOOKS in mkinitcpio.conf for early KMS and Plymouth
    if grep -q "^HOOKS=" /etc/mkinitcpio.conf; then
        # plymouth goes right after udev; kms goes after modconf (Arch wiki order)
        CURRENT_HOOKS=$(grep "^HOOKS=" /etc/mkinitcpio.conf | sed 's/HOOKS=(//;s/)//')

        # Remove existing kms and plymouth to re-insert them correctly
        NEW_HOOKS=$(echo "$CURRENT_HOOKS" | sed 's/\bkms\b//g;s/\bplymouth\b//g;s/  / /g;s/^ //;s/ $//')

        # Insert plymouth right after udev (Arch wiki requirement)
        if echo "$NEW_HOOKS" | grep -q "\budev\b"; then
            FINAL_HOOKS=$(echo "$NEW_HOOKS" | sed 's/\budev\b/udev plymouth/')
        else
            # Fallback: just put them at the beginning
            FINAL_HOOKS="base udev plymouth $NEW_HOOKS"
        fi

        # Insert kms after modconf (or before block as fallback) for early KMS
        if echo "$FINAL_HOOKS" | grep -q "\bmodconf\b"; then
            FINAL_HOOKS=$(echo "$FINAL_HOOKS" | sed 's/\bmodconf\b/modconf kms/')
        elif echo "$FINAL_HOOKS" | grep -q "\bblock\b"; then
            FINAL_HOOKS=$(echo "$FINAL_HOOKS" | sed 's/\bblock\b/kms block/')
        else
            FINAL_HOOKS="$FINAL_HOOKS kms"
        fi

        # Clean up double spaces
        FINAL_HOOKS=$(echo "$FINAL_HOOKS" | tr -s ' ')

        sudo sed -i "s/^HOOKS=(.*/HOOKS=($FINAL_HOOKS)/" /etc/mkinitcpio.conf
        echo "Updated HOOKS in mkinitcpio.conf: ($FINAL_HOOKS)"
    fi

    # Set the default theme (no -R here; mkinitcpio runs once at the end with correct config)
    sudo plymouth-set-default-theme spectrumos

    sudo mkdir -p /etc/pacman.d/hooks
    sudo cp "$SCRIPT_DIR"/plymouth/plymouth-quit-fix.hook /etc/pacman.d/hooks/plymouth-quit-fix.hook

    # Apply Plymouth quit delay override now (the pacman hook only fires on future upgrades,
    # not on the initial install that already ran before this script was deployed)
    sudo mkdir -p /etc/systemd/system/plymouth-quit.service.d
    printf '[Service]\nExecStartPre=/usr/bin/sleep 5\n' | sudo tee /etc/systemd/system/plymouth-quit.service.d/override.conf > /dev/null

    # Ensure SDDM waits for Plymouth to finish before starting
    sudo mkdir -p /etc/systemd/system/sddm.service.d
    printf '[Unit]\nAfter=plymouth-quit.service\nWants=plymouth-quit.service\n' | sudo tee /etc/systemd/system/sddm.service.d/plymouth.conf > /dev/null

    sudo systemctl daemon-reload

    # Regenerate initramfs once with all config changes applied
    sudo mkinitcpio -P
    echo -e "${GREEN}✓ Plymouth theme installed and initramfs regenerated${NC}"
}

# Install SDDM Theme
function install_sddm_theme(){
    if ! command -v sddm &>/dev/null; then
        echo -e "${YELLOW}SDDM not installed — skipping${NC}"
        return 0
    fi
    echo -e "${BLUE}Installing SDDM theme...${NC}"
    sudo mkdir -p /usr/share/sddm/themes/spectrumos
    sudo cp -rv "$SCRIPT_DIR"/sddm/themes/spectrumos/* /usr/share/sddm/themes/spectrumos/

    # Configure SDDM to use the theme
    if [ -f /etc/sddm.conf ]; then
        sudo cp /etc/sddm.conf /etc/sddm.conf.bak.$TIMESTAMP
    fi
    sudo cp "$SCRIPT_DIR"/etc/sddm.conf /etc/sddm.conf
}

# Install Spectrum Config Files
function install_spectrum_config(){
    echo -e "${BLUE}Installing SpectrumOS system configs...${NC}"
    sudo mkdir -p /etc/spectrumos
    sudo cp -rv "$SCRIPT_DIR"/etc/spectrumos/* /etc/spectrumos/
    # Refined permissions: current user owns it so scripts can update it
    sudo chown -R $USER:$USER /etc/spectrumos
    sudo chmod -R 755 /etc/spectrumos
}

# Install TLP
function install_tlp(){
    if ! command -v tlp &>/dev/null; then
        echo -e "${YELLOW}TLP not installed — skipping${NC}"
        return 0
    fi
    echo -e "${BLUE}Installing TLP config...${NC}"
    if [ -f /etc/tlp.conf ]; then
        sudo cp /etc/tlp.conf /etc/tlp.conf.bak.$TIMESTAMP
    fi
    sudo cp -v "$SCRIPT_DIR"/etc/tlp.conf /etc/tlp.conf
    sudo systemctl enable tlp.service
    sudo systemctl start tlp.service
}

function install_gaming_configs() {
    echo -e "${BLUE}Installing gaming configs...${NC}"
    mkdir -p "$HOME/.config/MangoHud"
    mkdir -p "$HOME/.config/vkbasalt"
    deploy_config "$SCRIPT_DIR/config/gamemode.ini" "$HOME/.config/gamemode.ini"
    deploy_config "$SCRIPT_DIR/config/mangohud/MangoHud.conf" "$HOME/.config/MangoHud/MangoHud.conf"
    deploy_config "$SCRIPT_DIR/config/vkbasalt/vkbasalt.conf" "$HOME/.config/vkbasalt/vkbasalt.conf"
    echo -e "${GREEN}✓ Gaming configs installed${NC}"
}

function install_all(){
    # 1. System foundations — create dirs and hand /usr/share/spectrumos to $USER
    create_local_files

    # 2. SpectrumOS system config — /etc/spectrumos must exist before bin scripts
    #    reference it and before Limine sync reads it
    install_spectrum_config

    # 3. Bin scripts — installed and made executable before any config that calls them
    #    (Hyprland keybindings/autostart reference these paths)
    install_bin

    # 4. Pywal templates — must be in place before Hyprland/Waybar configs are copied
    #    so that template paths resolve correctly on first wal run
    install_wal_templates

    # 5. Hyprland config — depends on bin scripts (step 3) and wal templates (step 4)
    install_hyprland_config

    # 6. Remaining user dotfiles — order within this block does not matter
    install_waybar_config
    install_rofi_themes
    install_gowall_config
    install_gromit
    install_swappy_config
    install_kitty_config
    install_nvim_config
    install_zsh_config
    install_xsettingsd
    install_mimeapps
    install_wpgtk
    install_cmus_config
    install_gaming_configs

    # 7. Display manager — reads pywal sddm-colors.conf written by wal templates
    install_sddm_theme

    # 8. TLP — fast, independent of everything above
    install_tlp

    # 9. Limine sync — installs the path watcher; must come before Plymouth so any
    #    future mkinitcpio.conf changes from Limine are present when initramfs is built
    install_limine_sync

    # 10. Plymouth last — mkinitcpio -P rebuilds initramfs and must run after ALL
    #     MODULES/HOOKS changes (GPU driver, plymouth hook) are finalized
    install_plymouth

    # Cleanup .bak files created during deployment
    echo -e "${BLUE}Cleaning up backup files...${NC}"
    find "$HOME/.config" -name "*.bak.*" -delete
    find "$HOME/.config/wpg" -name "*.bak" -delete

    echo -e "${GREEN}✓ All configurations deployed!${NC}"
}

# Function to display usage information
function usage() {
    echo "Usage: $0 [OPTION]"
    echo "Options:"
    echo "  --all, --al      Deploy all configurations"
    echo "  --bin            Install scripts to /usr/share/spectrumos/scripts/"
    echo "  --wal-templates  Install pywal templates to ~/.config/wal/templates/"
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
    echo "  --xsettingsd     Install xsettingsd config"
    echo "  --cmus           Install cmus theme"
    echo "  --mimeapps       Install mimeapps.list"
    echo "  --wpgtk          Initialize wpgtk templates"
    echo "  --gaming         Install gaming configs (gamemode, mangohud, vkbasalt)"
    echo ""
    echo "  Note: after --bin or --wal-templates, run a wallpaper script"
    echo "  (SOS_Randomize_Wallpaper or SOS_Select_Wallpaper) to regenerate colors."
    exit 1
}

# Main script execution
if [ $# -eq 0 ]; then
    usage
fi

for arg in "$@"; do
    case $arg in
        --all|--al)
            install_all
            ;;
        --bin)
            install_bin
            ;;
        --cmus)
            install_cmus_config
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
        --xsettingsd)
            install_xsettingsd
            ;;
        --mimeapps)
            install_mimeapps
            ;;
        --wpgtk)
            install_wpgtk
            ;;
        --gaming)
            install_gaming_configs
            ;;
        *)
            usage
            ;;
    esac
done
