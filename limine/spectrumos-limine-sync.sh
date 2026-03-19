#!/bin/bash
# SpectrumOS Limine Sync Script - Enhanced with dynamic ESP detection

# Load ESP_PATH from /etc/default/limine if it exists, otherwise detect it
if [ -f /etc/default/limine ]; then
    source /etc/default/limine
fi

if [ -z "$ESP_PATH" ]; then
    ESP_PATH=$(findmnt -no TARGET /boot || findmnt -no TARGET /efi || echo "/boot")
fi

WALLPAPER_SOURCE="/var/lib/spectrumos/current.png"
WALLPAPER_DEST="$ESP_PATH/spectrumos-wallpaper.jpg"
COLORS_SOURCE="/var/lib/spectrumos/colors.conf"
LIMINE_CONF="$ESP_PATH/limine.conf"
LIMINE_CONF_BACKUP="$ESP_PATH/limine.conf.spectrumos.backup"

# Function to read INI-style config (skips [General] header)
read_color_value() {
    local key="$1"
    local value=$(grep "^${key}=" "$COLORS_SOURCE" | cut -d'=' -f2 | tr -d ' "' | tr -d '%')
    echo "$value"
}

# Function to get machine ID
get_machine_id() {
    if [ -f /etc/machine-id ]; then
        cat /etc/machine-id
    else
        echo ""
    fi
}

# Function to find kernel in systemd-boot structure
find_kernel_systemd_boot() {
    local kernel_type="$1"
    local machine_id=$(get_machine_id)
    
    if [ -z "$machine_id" ]; then
        return 1
    fi
    
    local kernel_dir="$ESP_PATH/${machine_id}/${kernel_type}"
    
    if [ -d "$kernel_dir" ]; then
        local kernel_file=$(find "$kernel_dir" -name "vmlinuz-${kernel_type}*" -type f 2>/dev/null | head -1)
        if [ -n "$kernel_file" ]; then
            basename "$kernel_file"
        fi
    fi
}

# Function to find initramfs in systemd-boot structure
find_initramfs_systemd_boot() {
    local kernel_type="$1"
    local fallback="$2"
    local machine_id=$(get_machine_id)
    
    if [ -z "$machine_id" ]; then
        return 1
    fi
    
    local kernel_dir="$ESP_PATH/${machine_id}/${kernel_type}"
    
    if [ -d "$kernel_dir" ]; then
        if [ "$fallback" = "yes" ]; then
            local initramfs_file=$(find "$kernel_dir" -name "initramfs-${kernel_type}*fallback*" -type f 2>/dev/null | head -1)
        else
            local initramfs_file=$(find "$kernel_dir" -name "initramfs-${kernel_type}*" ! -name "*fallback*" -type f 2>/dev/null | head -1)
        fi
        
        if [ -n "$initramfs_file" ]; then
            basename "$initramfs_file"
        fi
    fi
}

# Function to get latest kernel - checks both traditional and systemd-boot locations
get_latest_kernel() {
    local kernel_type="$1"
    
    # First try: Traditional ESP root location
    if [ -f "$ESP_PATH/vmlinuz-${kernel_type}" ]; then
        echo "vmlinuz-${kernel_type}"
        return 0
    fi
    
    # Second try: systemd-boot structure
    local kernel=$(find_kernel_systemd_boot "$kernel_type")
    if [ -n "$kernel" ]; then
        echo "$kernel"
        return 0
    fi
    
    # Third try: any vmlinuz file in /boot or ESP_PATH
    local kernel_path=$(find /boot "$ESP_PATH" -name "vmlinuz-${kernel_type}*" -type f 2>/dev/null | head -1)
    if [ -n "$kernel_path" ]; then
        basename "$kernel_path"
        return 0
    fi
    
    echo ""
}

# Function to copy kernel files to ESP root for Limine
copy_kernel_to_boot() {
    local kernel_type="$1"
    local machine_id=$(get_machine_id)
    
    if [ -z "$machine_id" ]; then
        echo "⚠ Could not get machine ID"
        return 1
    fi
    
    # Often kernels are installed to /boot by mkinitcpio, but Limine needs them in ESP root
    # If /boot is not the ESP, we copy from /boot to ESP_PATH
    local src_dir="/boot"
    if [ "$ESP_PATH" = "/boot" ]; then
        # If /boot IS the ESP, they might be in the machine-id dir (systemd-boot style)
        src_dir="$ESP_PATH/${machine_id}/${kernel_type}"
    fi
    
    if [ ! -d "$src_dir" ]; then
        echo "⚠ Source directory not found: $src_dir"
        return 1
    fi
    
    # Find and copy kernel
    local src_kernel=$(find "$src_dir" -name "vmlinuz-${kernel_type}*" -type f 2>/dev/null | head -1)
    if [ -n "$src_kernel" ]; then
        cp "$src_kernel" "$ESP_PATH/vmlinuz-${kernel_type}"
        echo "✓ Copied kernel: $(basename $src_kernel) -> $ESP_PATH/vmlinuz-${kernel_type}"
    else
        echo "⚠ Kernel not found in $src_dir"
        return 1
    fi
    
    # Find and copy regular initramfs
    local src_initramfs=$(find "$src_dir" -name "initramfs-${kernel_type}*" ! -name "*fallback*" -type f 2>/dev/null | head -1)
    if [ -n "$src_initramfs" ]; then
        cp "$src_initramfs" "$ESP_PATH/initramfs-linux-zen.img"
        echo "✓ Copied initramfs: $(basename $src_initramfs) -> $ESP_PATH/initramfs-linux-zen.img"
    fi
    
    # Find and copy fallback initramfs
    local src_fallback=$(find "$src_dir" -name "initramfs-${kernel_type}*fallback*" -type f 2>/dev/null | head -1)
    if [ -n "$src_fallback" ]; then
        cp "$src_fallback" "$ESP_PATH/initramfs-linux-zen-fallback.img"
        echo "✓ Copied fallback: $(basename $src_fallback) -> $ESP_PATH/initramfs-linux-zen-fallback.img"
    fi
}

# Function to get root UUID
get_root_uuid() {
    findmnt -no UUID /
}

# Function to clean auto-generated entries
clean_limine_conf() {
    # Create a backup if it doesn't exist
    if [ ! -f "$LIMINE_CONF_BACKUP" ]; then
        cp "$LIMINE_CONF" "$LIMINE_CONF_BACKUP"
    fi
    
    # We want to keep the auto-generated entries but ensure they have quiet splash
    # and use our theme colors if possible.
    # Actually, it's better to let limine-mkinitcpio do its thing but ensure
    # our SpectrumOS entries are at the top and correct.
    echo "Ensuring quiet splash in all entries..."
    sed -i 's/cmdline: \(.*\) root=/cmdline: \1 quiet splash root=/g' "$LIMINE_CONF"
    # Clean up double quiet splash
    sed -i 's/quiet splash quiet splash/quiet splash/g' "$LIMINE_CONF"
    
    # Ensure all entries have quiet splash if they don't have it
    sed -i '/cmdline:/ { /quiet splash/ ! s/cmdline: /&quiet splash / }' "$LIMINE_CONF"
}

# Function to update SpectrumOS kernel entries
update_spectrumos_entries() {
    local root_uuid=$(get_root_uuid)
    local root_fstype=$(findmnt -no FSTYPE /)
    
    # Copy kernel files to ESP root
    echo "Copying kernel files to $ESP_PATH for Limine..."
    copy_kernel_to_boot "linux-zen"
    
    local zen_kernel="vmlinuz-linux-zen"
    local zen_initramfs="initramfs-linux-zen.img"
    local zen_fallback="initramfs-linux-zen-fallback.img"
    
    echo "Updating Limine config:"
    echo "  Kernel: $zen_kernel"
    echo "  Initramfs: $zen_initramfs"
    echo "  Root UUID: $root_uuid"
    echo "  Root FSTYPE: $root_fstype"
    
    # Update SpectrumOS entry
    sed -i "/^\/SpectrumOS$/,/^\//s|path: boot():/vmlinuz-.*|path: boot():/$zen_kernel|" "$LIMINE_CONF"
    sed -i "/^\/SpectrumOS$/,/^\//s|module_path: boot():/initramfs-.*|module_path: boot():/$zen_initramfs|" "$LIMINE_CONF"
    sed -i "/^\/SpectrumOS$/,/^\//s|root=UUID=[^ ]*|root=UUID=$root_uuid|" "$LIMINE_CONF"
    sed -i "/^\/SpectrumOS$/,/^\//s|rootfstype=[^ ]*|rootfstype=$root_fstype|" "$LIMINE_CONF"
    
    # Update SpectrumOS Fallback entry
    sed -i "/^\/SpectrumOS (Fallback)$/,/^\//s|path: boot():/vmlinuz-.*|path: boot():/$zen_kernel|" "$LIMINE_CONF"
    sed -i "/^\/SpectrumOS (Fallback)$/,/^\//s|module_path: boot():/initramfs-.*|module_path: boot():/$zen_fallback|" "$LIMINE_CONF"
    sed -i "/^\/SpectrumOS (Fallback)$/,/^\//s|root=UUID=[^ ]*|root=UUID=$root_uuid|" "$LIMINE_CONF"
    sed -i "/^\/SpectrumOS (Fallback)$/,/^\//s|rootfstype=[^ ]*|rootfstype=$root_fstype|" "$LIMINE_CONF"
    
    # Ensure quiet splash is present
    clean_limine_conf
    
    echo "✓ Kernel entries updated"
}

# Exit if wallpaper source doesn't exist
if [ ! -f "$WALLPAPER_SOURCE" ]; then
    echo "Wallpaper source not found at $WALLPAPER_SOURCE"
fi

# Copy wallpaper to boot if it exists
if [ -f "$WALLPAPER_SOURCE" ]; then
    # Ensure it's a real JPEG for Limine
    if command -v convert &> /dev/null; then
        convert "$WALLPAPER_SOURCE" "$WALLPAPER_DEST"
        echo "✓ Wallpaper converted and synced to boot partition"
    else
        cp "$WALLPAPER_SOURCE" "$WALLPAPER_DEST"
        echo "✓ Wallpaper synced to boot partition"
    fi
fi

# Update Limine colors if colors.conf exists
if [ -f "$COLORS_SOURCE" ]; then
    echo "Reading colors from $COLORS_SOURCE"
    
    # Read colors using the INI reader function
    background=$(read_color_value "background")
    foreground=$(read_color_value "foreground")
    color0=$(read_color_value "color0")
    color1=$(read_color_value "color1")
    color2=$(read_color_value "color2")
    color3=$(read_color_value "color3")
    color4=$(read_color_value "color4")
    color5=$(read_color_value "color5")
    color6=$(read_color_value "color6")
    color7=$(read_color_value "color7")
    
    # Remove # from colors (Limine wants RRGGBB, not #RRGGBB)
    bg=$(echo "$background" | sed 's/#//')
    fg=$(echo "$foreground" | sed 's/#//')
    c0=$(echo "$color0" | sed 's/#//')
    c1=$(echo "$color1" | sed 's/#//')
    c2=$(echo "$color2" | sed 's/#//')
    c3=$(echo "$color3" | sed 's/#//')
    c4=$(echo "$color4" | sed 's/#//')
    c5=$(echo "$color5" | sed 's/#//')
    c6=$(echo "$color6" | sed 's/#//')
    c7=$(echo "$color7" | sed 's/#//')
    
    # Check if we got valid colors
    if [ -n "$bg" ] && [ -n "$fg" ]; then
        echo "Applying colors:"
        echo "  Background: #$bg"
        echo "  Foreground: #$fg"
        
        # Update colors in Limine config (88 prefix adds transparency to background)
        sed -i "s/^term_background:.*/term_background: 88$bg/" "$LIMINE_CONF"
        sed -i "s/^backdrop:.*/backdrop: $bg/" "$LIMINE_CONF"
        sed -i "s/^term_foreground:.*/term_foreground: $fg/" "$LIMINE_CONF"
        sed -i "s/^term_foreground_bright:.*/term_foreground_bright: $fg/" "$LIMINE_CONF"
        sed -i "s/^term_background_bright:.*/term_background_bright: $bg/" "$LIMINE_CONF"
        
        # Update palette with pywal colors (8 colors: 0-7)
        sed -i "s|^term_palette:.*|term_palette: $c0;$c1;$c2;$c3;$c4;$c5;$c6;$c7|" "$LIMINE_CONF"
        sed -i "s|^term_palette_bright:.*|term_palette_bright: $c0;$c1;$c2;$c3;$c4;$c5;$c6;$c7|" "$LIMINE_CONF"
        
        echo "✓ Colors applied successfully"
    else
        echo "⚠ Warning: Could not read colors properly"
    fi
else
    echo "⚠ Colors config not found at $COLORS_SOURCE"
fi

# Clean auto-generated entries and update kernel paths
echo ""
echo "Cleaning auto-generated Arch Linux entries..."
clean_limine_conf

echo "Updating SpectrumOS kernel entries..."
update_spectrumos_entries

echo ""
echo "✓ Limine config synced successfully!"
echo "  Config: $LIMINE_CONF"
echo "  Backup: $LIMINE_CONF_BACKUP"
