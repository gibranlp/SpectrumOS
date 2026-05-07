#!/bin/bash
# SpectrumOS Limine Sync Script - Enhanced with dynamic discovery and robust updates

# Load overrides if they exist
[ -f /etc/default/limine ] && source /etc/default/limine

# 1. Dynamic Discovery of limine.conf and ESP_PATH
find_limine_conf() {
    local locations=(
        "/boot/limine/limine.conf"
        "/boot/efi/EFI/limine/limine.conf"
        "/boot/efi/limine/limine.conf"
        "/efi/limine/limine.conf"
        "/boot/limine.conf"
        "/efi/limine.conf"
    )

    for loc in "${locations[@]}"; do
        if [ -f "$loc" ]; then
            echo "$loc"
            return 0
        fi
    done

    # Fallback to slow search if common locations fail
    local found=$(find /boot /efi -name "limine.conf" -type f 2>/dev/null | head -1)
    if [ -n "$found" ]; then
        echo "$found"
        return 0
    fi

    return 1
}

LIMINE_CONF=$(find_limine_conf)
if [ -z "$LIMINE_CONF" ]; then
    echo "❌ Error: Could not find limine.conf"
    exit 1
fi

# Detect ESP_PATH based on where limine.conf is located
detect_esp_path() {
    if [ -n "$ESP_PATH" ] && [ -d "$ESP_PATH" ]; then
        echo "$ESP_PATH"
        return 0
    fi

    local mount_point=$(df --output=target "$LIMINE_CONF" | tail -1)
    if [ -n "$mount_point" ] && [ "$mount_point" != "/" ]; then
        echo "$mount_point"
        return 0
    fi

    findmnt -no TARGET /boot || findmnt -no TARGET /efi || echo "/boot"
}

ESP_PATH=$(detect_esp_path)
WALLPAPER_SOURCE="/var/lib/spectrumos/current.png"
WALLPAPER_DEST="$ESP_PATH/spectrumos-wallpaper.jpg"
LOGO_SOURCE="/var/lib/spectrumos/logo.png"
LOGO_DEST="$ESP_PATH/spectrumos-logo.png"
COLORS_SOURCE="/var/lib/spectrumos/colors.conf"
LIMINE_CONF_BACKUP="${LIMINE_CONF}.spectrumos.backup"

echo "Using Limine Config: $LIMINE_CONF"
echo "Using ESP Path: $ESP_PATH"

# 2. Helper Functions for Safe Config Updates

update_limine_key() {
    local key="$1"
    local value="$2"
    
    if grep -q "^${key}:" "$LIMINE_CONF"; then
        sed -i "s|^${key}:.*|${key}: ${value}|" "$LIMINE_CONF"
    else
        # Add after the first few lines of header if possible, otherwise at top
        if grep -q "timeout:" "$LIMINE_CONF"; then
            sed -i "/timeout:/a ${key}: ${value}" "$LIMINE_CONF"
        else
            sed -i "1i ${key}: ${value}" "$LIMINE_CONF"
        fi
    fi
}

update_entry_val() {
    local entry="$1"
    local key="$2"
    local value="$3"
    
    # Escape slash for sed
    local escaped_entry=$(echo "$entry" | sed 's/\//\\\//g')
    # This uses a range to target only the block for the specific entry
    sed -i "/^${escaped_entry}$/,/^\// { s|^[[:space:]]*${key}:.*|    ${key}: ${value}| }" "$LIMINE_CONF"
}

read_color_value() {
    local key="$1"
    [ ! -f "$COLORS_SOURCE" ] && return 1
    local value=$(grep "^${key}=" "$COLORS_SOURCE" | cut -d'=' -f2 | tr -d ' "' | tr -d '%')
    echo "$value"
}

get_root_uuid() {
    findmnt -no UUID /
}

get_root_fstype() {
    findmnt -no FSTYPE /
}

get_root_flags() {
    local options=$(findmnt -no OPTIONS /)
    local subvol=$(echo "$options" | grep -o 'subvol=[^,]*')
    if [ -n "$subvol" ]; then
        echo "rootflags=$subvol"
    fi
}

# 3. Kernel and Initramfs Sync
copy_kernel_to_boot() {
    local kernel_type="$1"
    # Find newest kernel in /boot
    local src_kernel=$(find /boot -name "vmlinuz-${kernel_type}*" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -f2- -d" ")
    
    if [ -n "$src_kernel" ]; then
        local dest_kernel="$ESP_PATH/vmlinuz-${kernel_type}"
        if [ "$src_kernel" != "$dest_kernel" ]; then
            cp "$src_kernel" "$dest_kernel"
            echo "✓ Copied newest kernel to $dest_kernel"
        fi
    fi
    
    # Find newest initramfs
    local src_initramfs=$(find /boot -name "initramfs-${kernel_type}*" ! -name "*fallback*" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -f2- -d" ")
    if [ -n "$src_initramfs" ]; then
        local dest_initramfs="$ESP_PATH/initramfs-linux-zen.img"
        if [ "$src_initramfs" != "$dest_initramfs" ]; then
            cp "$src_initramfs" "$dest_initramfs"
            echo "✓ Copied newest initramfs to $dest_initramfs"
        fi
    fi

    # Find newest fallback initramfs
    local src_fallback=$(find /boot -name "initramfs-${kernel_type}*fallback*" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -f2- -d" ")
    if [ -n "$src_fallback" ]; then
        local dest_fallback="$ESP_PATH/initramfs-linux-zen-fallback.img"
        if [ "$src_fallback" != "$dest_fallback" ]; then
            cp "$src_fallback" "$dest_fallback"
            echo "✓ Copied newest fallback initramfs to $dest_fallback"
        fi
    fi
    
    # Find newest microcode
    local src_ucode=$(find /boot -name "*ucode.img" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -f2- -d" ")
    if [ -n "$src_ucode" ]; then
        local dest_ucode="$ESP_PATH/$(basename "$src_ucode")"
        if [ "$src_ucode" != "$dest_ucode" ]; then
            cp "$src_ucode" "$dest_ucode"
            echo "✓ Copied newest microcode to $dest_ucode"
        fi
    fi
}

ensure_spectrumos_entries() {
    local root_uuid=$(get_root_uuid)
    local root_fstype=$(get_root_fstype)
    local root_flags=$(get_root_flags)
    local ucode_file=$(find "$ESP_PATH" -maxdepth 1 -name "*ucode.img" -type f 2>/dev/null | head -1)
    local ucode_module=""
    [ -n "$ucode_file" ] && ucode_module="boot():/$(basename "$ucode_file"), "

    # Backup before destructive change
    [ ! -f "${LIMINE_CONF}.bak" ] && cp "$LIMINE_CONF" "${LIMINE_CONF}.bak"
    
    # Remove ALL entries (everything from the first line starting with /)
    sed -i '/^\//,$d' "$LIMINE_CONF"

    echo -e "\n/SpectrumOS" >> "$LIMINE_CONF"
    echo "    comment: SpectrumOS Feel the Power of the Color Spectrum!" >> "$LIMINE_CONF"
    echo "    protocol: linux" >> "$LIMINE_CONF"
    echo "    path: boot():/vmlinuz-linux-zen" >> "$LIMINE_CONF"
    echo "    cmdline: root=UUID=$root_uuid zswap.enabled=0 rw rootfstype=$root_fstype $root_flags quiet splash" >> "$LIMINE_CONF"
    [ -n "$ucode_file" ] && echo "    module_path: boot():/$(basename "$ucode_file")" >> "$LIMINE_CONF"
    echo "    module_path: boot():/initramfs-linux-zen.img" >> "$LIMINE_CONF"
    echo "✓ SpectrumOS entry added"

    # Add Recovery entry using the UKI (which is known to work)
    if [ -f "$ESP_PATH/EFI/Linux/arch-linux-zen.efi" ]; then
        echo -e "\n/SpectrumOS (Recovery)" >> "$LIMINE_CONF"
        echo "    comment: Safe boot using Unified Kernel Image" >> "$LIMINE_CONF"
        echo "    protocol: efi" >> "$LIMINE_CONF"
        echo "    path: boot():/EFI/Linux/arch-linux-zen.efi" >> "$LIMINE_CONF"
        echo "    cmdline: root=UUID=$root_uuid zswap.enabled=0 rw rootfstype=$root_fstype $root_flags quiet splash" >> "$LIMINE_CONF"
        echo "✓ Recovery entry added"
    fi
}

# 4. Main Sync Logic

# Create backup if needed
[ ! -f "$LIMINE_CONF_BACKUP" ] && cp "$LIMINE_CONF" "$LIMINE_CONF_BACKUP"

# Ensure global branding
update_limine_key "interface_branding" "SpectrumOS"
update_limine_key "interface_branding_color" "2"
update_limine_key "hash_mismatch_panic" "no"
update_limine_key "timeout" "5"
update_limine_key "graphics_resolution" "1920x1080"

# SYNC WALLPAPER
if [ -f "$WALLPAPER_SOURCE" ]; then
    if command -v convert &> /dev/null; then
        convert "$WALLPAPER_SOURCE" "$WALLPAPER_DEST"
    else
        cp "$WALLPAPER_SOURCE" "$WALLPAPER_DEST"
    fi
    echo "✓ Wallpaper synced to $WALLPAPER_DEST"
    update_limine_key "wallpaper" "boot():/$(basename "$WALLPAPER_DEST")"
    update_limine_key "wallpaper_style" "stretched"
fi

# SYNC LOGO
if [ -f "$LOGO_SOURCE" ]; then
    cp "$LOGO_SOURCE" "$LOGO_DEST"
    echo "✓ Logo synced to $LOGO_DEST"
    update_limine_key "interface_branding_logo" "boot():/$(basename "$LOGO_DEST")"
fi

# SYNC COLORS
if [ -f "$COLORS_SOURCE" ]; then
    bg=$(read_color_value "background" | sed 's/#//')
    fg=$(read_color_value "foreground" | sed 's/#//')
    c2=$(read_color_value "color2" | sed 's/#//')
    
    if [ -n "$bg" ] && [ -n "$fg" ]; then
        update_limine_key "term_background" "88$bg"
        update_limine_key "backdrop" "$bg"
        update_limine_key "term_foreground" "$fg"
        update_limine_key "term_foreground_bright" "ffffff"
        update_limine_key "term_background_bright" "$bg"

        # Explicit Menu Colors
        update_limine_key "menu_background" "66$bg"
        update_limine_key "menu_foreground" "$fg"
        if [ -n "$c2" ]; then
            update_limine_key "menu_highlight_background" "$c2"
        else
            update_limine_key "menu_highlight_background" "$fg"
        fi
        update_limine_key "menu_highlight_foreground" "ffffff"
        
        # Palette (0-7)
        p=""
        for i in {0..7}; do
            c=$(read_color_value "color$i" | sed 's/#//')
            [ -z "$p" ] && p="$c" || p="$p;$c"
        done
        update_limine_key "term_palette" "$p"
        update_limine_key "term_palette_bright" "$p"
        echo "✓ Colors synced to limine.conf"
    fi
fi

# SYNC KERNEL AND ENTRIES
copy_kernel_to_boot "linux-zen"
ensure_spectrumos_entries

# Set SpectrumOS as default
# We find the index of /SpectrumOS
entry_index=$(grep "^/" "$LIMINE_CONF" | grep -n "^/SpectrumOS$" | cut -d: -f1)
if [ -n "$entry_index" ]; then
    update_limine_key "default_entry" "$entry_index"
    echo "✓ SpectrumOS set as default entry ($entry_index)"
fi

# WINDOWS DETECTION
windows_efi="$ESP_PATH/EFI/Microsoft/Boot/bootmgfw.efi"
if [ -f "$windows_efi" ] && ! grep -q "^/Windows" "$LIMINE_CONF"; then
    echo -e "\n/Windows\n    comment: Windows Boot Manager\n    protocol: efi\n    path: boot():/EFI/Microsoft/Boot/bootmgfw.efi" >> "$LIMINE_CONF"
    echo "✓ Windows entry added"
fi

echo "✓ Limine sync complete!"
