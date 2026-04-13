#!/usr/bin/env bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 
ROFI_THEME="~/.config/rofi/SOS_Right.rasi"
FONT="Courier Prime Medium 13"

# Notification ID for persistent updates
NOTIF_ID=999999
REBOOT_NOTIF_ID=999998

# Detect notification daemon (prefer dunstify for progress bars)
if command -v dunstify &> /dev/null; then
    NOTIF_CMD="dunstify"
else
    NOTIF_CMD="notify-send"
fi

# Use Paru as AUR helper
AUR_HELPER="paru"

# Enhanced notification function with progress bar support
send_notif() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"
    local progress="${4:-}"
    local timeout="${5:-0}"  # 0 = persistent
    
    if [ "$NOTIF_CMD" = "dunstify" ]; then
        if [ -n "$progress" ]; then
            dunstify -a 'SpectrumOS' -r "$NOTIF_ID" -u "$urgency" -t "$timeout" \
                -h int:value:"$progress" "$title" "$message"
        else
            dunstify -a 'SpectrumOS' -r "$NOTIF_ID" -u "$urgency" -t "$timeout" \
                "$title" "$message"
        fi
    else
        notify-send -a 'SpectrumOS' -u "$urgency" -t "$timeout" "$title" "$message"
    fi
}

# Send initial notification
send_notif "System Update" "🔍 Checking for updates with $AUR_HELPER..." "normal"

# Function to get update list
get_updates() {
    if [ "$AUR_HELPER" = "pacman" ]; then
        checkupdates 2>/dev/null
    else
        $AUR_HELPER -Qu 2>/dev/null
    fi
}

# Get list of updates
UPDATE_LIST=$(get_updates)
UPDATE_COUNT=$(echo "$UPDATE_LIST" | grep -c "^")

if [ -z "$UPDATE_LIST" ] || [ "$UPDATE_COUNT" -eq 0 ]; then
    send_notif "System Update" "✅ System is already up to date!" "normal" "" 5000
    exit 0
fi

# Show the list in rofi and ask for confirmation
CHOICE=$(echo -e " Update All ($UPDATE_COUNT packages)\n Cancel\n───────────────────────────\n$UPDATE_LIST" | \
    rofi -dmenu -theme "$ROFI_THEME" -p "󰣇 Updates Available: " -font "$FONT" -lines 15 -i)

# Check user choice
case "$CHOICE" in
    " Update All"*)
        send_notif "System Update" "🚀 Starting update of $UPDATE_COUNT package(s)..." "normal"
        ;;
    " Cancel"|"")
        send_notif "System Update" "❌ Update cancelled" "normal" "" 3000
        exit 0
        ;;
    *)
        # User might have selected a specific package or just cancelled
        exit 0
        ;;
esac

# Create a temporary log file
LOG_FILE="/tmp/spectrum_update_$(date +%s).log"
PROGRESS_FILE="/tmp/spectrum_progress_$(date +%s).tmp"

# Initialize progress tracking
echo "0" > "$PROGRESS_FILE"

# Function to update progress with persistent notification
update_progress() {
    local stage="$1"
    local message="$2"
    local progress="$3"
    
    echo "$progress" > "$PROGRESS_FILE"
    send_notif "System Update - $stage" "$message" "normal" "$progress"
}

# Function to estimate progress from package downloads
estimate_download_progress() {
    local log="$1"
    local total_packages="$2"
    
    # Count downloaded packages
    local downloaded=$(grep -c "downloading" "$log" 2>/dev/null || echo "0")
    
    if [ "$total_packages" -gt 0 ]; then
        echo $((30 + (downloaded * 40 / total_packages)))
    else
        echo "30"
    fi
}

# Update database
update_progress "Preparing" "📥 Updating package database..." 10

if [ "$AUR_HELPER" = "pacman" ]; then
    # Pacman only (no AUR helper)
    sudo pacman -Sy 2>&1 | tee "$LOG_FILE"
    
    update_progress "Upgrading" "⬆️ Upgrading packages..." 50
    sudo pacman -Su --noconfirm 2>&1 | tee -a "$LOG_FILE"
    
    RESULT=$?
else
    # Using paru or another AUR helper
    $AUR_HELPER -Syu --noconfirm 2>&1 | tee "$LOG_FILE" &
    AUR_PID=$!
    
    # Monitor the update process with enhanced progress tracking
    local current_stage=""
    local download_started=false
    
    while kill -0 $AUR_PID 2>/dev/null; do
        # Check for specific update stages in the log
        if grep -q "resolving dependencies" "$LOG_FILE" && [ "$current_stage" != "resolving" ]; then
            current_stage="resolving"
            update_progress "Dependencies" "🔗 Resolving dependencies..." 15
            
        elif grep -q "looking for conflicting packages" "$LOG_FILE" && [ "$current_stage" != "conflicts" ]; then
            current_stage="conflicts"
            update_progress "Conflicts" "⚠️ Checking for conflicts..." 20
            
        elif grep -q -E "Packages \([0-9]+\)|Total Download Size" "$LOG_FILE" && [ "$current_stage" != "downloading" ]; then
            current_stage="downloading"
            download_started=true
            update_progress "Download" "📦 Downloading packages..." 30
            
        elif [ "$download_started" = true ] && grep -q "downloading" "$LOG_FILE"; then
            # Update download progress dynamically
            local dl_progress=$(estimate_download_progress "$LOG_FILE" "$UPDATE_COUNT")
            update_progress "Download" "📦 Downloading packages... ($dl_progress%)" "$dl_progress"
            
        elif grep -q "checking package integrity" "$LOG_FILE" && [ "$current_stage" != "integrity" ]; then
            current_stage="integrity"
            update_progress "Verification" "🔐 Checking package integrity..." 70
            
        elif grep -q "loading package files" "$LOG_FILE" && [ "$current_stage" != "loading" ]; then
            current_stage="loading"
            update_progress "Loading" "📂 Loading package files..." 75
            
        elif grep -q "checking for file conflicts" "$LOG_FILE" && [ "$current_stage" != "file_conflicts" ]; then
            current_stage="file_conflicts"
            update_progress "Conflicts" "🔍 Checking for file conflicts..." 80
            
        elif grep -q -E "upgrading|installing|removing" "$LOG_FILE" && [ "$current_stage" != "installing" ]; then
            current_stage="installing"
            update_progress "Installing" "⚙️ Installing packages..." 85
        fi
        
        sleep 1.5
    done
    
    wait $AUR_PID
    RESULT=$?
fi

# Clean package cache (optional)
update_progress "Cleanup" "🧹 Cleaning package cache..." 95

if [ "$AUR_HELPER" = "pacman" ]; then
    sudo pacman -Sc --noconfirm 2>&1 | tee -a "$LOG_FILE"
else
    $AUR_HELPER -Sc --noconfirm 2>&1 | tee -a "$LOG_FILE"
fi

# Check result and send final notification
if [ $RESULT -eq 0 ]; then
    # Count how many packages were updated
    UPDATED=$(grep -E "upgraded|installed|removed" "$LOG_FILE" | tail -n 1 | grep -oP '\d+(?= upgraded)' || echo "$UPDATE_COUNT")
    
    if [ "$UPDATED" -gt 0 ]; then
        send_notif "System Update Complete" "✅ Successfully updated $UPDATED package(s)!" "normal" "100" 8000
    else
        send_notif "System Update Complete" "✅ Update completed successfully!" "normal" "100" 8000
    fi
    
    # Check if reboot is needed
    if [ -f /var/run/reboot-required ] || grep -q "linux" "$LOG_FILE"; then
        # Send a separate persistent critical notification for reboot with action button
        sleep 1
        if [ "$NOTIF_CMD" = "dunstify" ]; then
            # Show notification with reboot button (persistent, stays until dismissed)
            ACTION=$(dunstify -a 'SpectrumOS' -r "$REBOOT_NOTIF_ID" -u critical -t 0 \
                -A "reboot,🔄 Reboot Now" \
                "⚠️ Reboot Required" \
                "Kernel updated - system reboot recommended\n\nClick to reboot or dismiss this notification")
            
            # Handle the action response
            if [ "$ACTION" = "reboot" ]; then
                sudo systemctl reboot
            fi
        else
            # Fallback for notify-send (no action buttons, but persistent)
            notify-send -a 'SpectrumOS' -u critical -t 0 \
                "⚠️ Reboot Required" \
                "Kernel updated - system reboot recommended\n\nPlease reboot your system manually"
        fi
    fi
else
    send_notif "System Update Failed" "❌ Update failed! Check logs for details." "critical" "" 10000
fi

# Clean up temporary files
rm -f "$LOG_FILE" "$PROGRESS_FILE"

exit $RESULT