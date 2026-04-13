#!/bin/bash
# _____                    _____ _____ 
#|  _  |___ _ _ _ ___ ___|     |   __|
#|   __| . | | | | -_|  _|  |  |__   |
#|__|  |___|_____|___|_| |_____|_____|
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 
# Power Profile Switcher Script

ROFI_THEME="$HOME/.config/rofi/SOS_Right.rasi"

set_power_profile() {
    # Get current governor
    local current_governor
    current_governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
    
    # Available profiles
    local profiles=("⚡ Performance" "🔋 Powersave" "⚙️ Balanced")
    
    # Build rofi options with current profile indicator
    local options=""
    for profile in "${profiles[@]}"; do
        local profile_lower=$(echo "$profile" | tr '[:upper:]' '[:lower:]')
        if [[ "$current_governor" == "$profile_lower" ]]; then
            options+=" $profile (Current)\n"
        else
            options+="$profile\n"
        fi
    done
    
    # Show rofi menu
    local selected
    selected=$(echo -e "$options" | rofi -dmenu -theme "$ROFI_THEME" -p "⚡ Current 👉🏻 ${current_governor^}")
    
    # Get exit code
    local exit_code=$?
    
    # Check if user cancelled (ESC or closed)
    if [[ $exit_code -ne 0 ]] || [[ -z "$selected" ]]; then
        exit 0
    fi
    
    # Remove " (Current)" if present
    selected="${selected// (Current)/}"
    selected="${selected// /}"
    
    # Convert to lowercase for governor name
    local governor=$(echo "$selected" | tr '[:upper:]' '[:lower:]')
    
    # Handle "Balanced" as it might not exist on all systems
    if [[ "$governor" == "balanced" ]]; then
        # Check if schedutil or ondemand is available
        if [[ -d /sys/devices/system/cpu/cpufreq/schedutil ]]; then
            governor="schedutil"
        elif [[ -d /sys/devices/system/cpu/cpufreq/ondemand ]]; then
            governor="ondemand"
        else
            governor="powersave"
        fi
    fi
    
    # Apply the governor
    echo "$governor" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null
    
    # Get icon based on profile
    local icon=""
    case "$governor" in
        performance)
            icon="⚡"
            ;;
        powersave)
            icon="🔋"
            ;;
        *)
            icon="⚙️"
            ;;
    esac
    
    # Send notification
    notify-send -a "⚡ Power Profile" \
        "Profile Changed" \
        "$icon ${selected}"
}

# Run the function
set_power_profile