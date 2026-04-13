#!/usr/bin/env bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 

# Constants
FIELDS="SSID,SECURITY"
FONT="Courier Prime Medium 13"
ROFI_THEME="$HOME/.config/rofi/SOS_Right.rasi"

# Function to forget a saved network
forget_network() {
    # Get list of saved WiFi connections (more robust method)
    SAVED_NETWORKS=$(nmcli -g NAME,TYPE connection show | grep ':802-11-wireless$' | cut -d':' -f1)
    
    # Alternative method if the above doesn't work
    if [ -z "$SAVED_NETWORKS" ]; then
        SAVED_NETWORKS=$(nmcli connection show | awk '$3 == "wifi" || $3 == "802-11-wireless" {print $1}')
    fi
    
    if [ -z "$SAVED_NETWORKS" ]; then
        notify-send -a "WiFi" "WiFi" "No saved networks found"
        return
    fi
    
    # Show rofi menu to select which network to forget
    FORGET_SSID=$(echo "$SAVED_NETWORKS" | rofi -theme "$ROFI_THEME" -dmenu -p "󰆴 SSID: " -font "$FONT" -lines 10)
    
    if [ -n "$FORGET_SSID" ]; then
        nmcli connection delete "$FORGET_SSID"
        if [ $? -eq 0 ]; then
            notify-send -a "WiFi" "WiFi" "Forgot network: $FORGET_SSID"
        else
            notify-send -a "WiFi" "WiFi Error" "Failed to forget network: $FORGET_SSID" -u critical
        fi
    fi
}

# Function to show the menu and handle user input
show_menu() {
    # Send notification that we're loading
    notify-send -a "WiFi" "WiFi" "Loading networks..." -t 4000
    
    # Automatically select the first available WiFi device
    SELECTED_DEVICE=$(nmcli device | awk '$2 == "wifi" {print $1; exit}')

    if [ -z "$SELECTED_DEVICE" ]; then
        notify-send -a "WiFi" "WiFi Error" "No WiFi device found" -u critical
        exit 1
    fi

    # Get available WiFi networks for the selected device
    LIST=$(nmcli --fields "$FIELDS" device wifi list ifname "$SELECTED_DEVICE" | sed '/^--/d')
    RWIDTH=$(( $(echo "$LIST" | awk '{print length($0)}' | sort -nr | head -n1) + 2 ))
    LINENUM=$(echo "$LIST" | wc -l)
    KNOWNCON=$(nmcli connection show)
    CONSTATE=$(nmcli -fields WIFI g)
    CURRSSID=$(nmcli -t -f active,ssid dev wifi ifname "$SELECTED_DEVICE" | awk -F: '$1 ~ /^yes/ {print $2}')

    # Determine highline for currently connected SSID
    if [ -n "$CURRSSID" ]; then
        HIGHLINE=$(echo "$LIST" | awk -F"[[:space:]]{2,}" -v ssid="$CURRSSID" '$1 == ssid {print NR}' | head -n1)
        # Adjust for the extra menu items at the top
        HIGHLINE=$((HIGHLINE + 3))
    else
        HIGHLINE=0
    fi

    # Determine number of lines for rofi menu
    if [ "$LINENUM" -gt 8 ] && [[ "$CONSTATE" == *"enabled"* ]]; then
        LINENUM=11  # 8 networks + 3 menu options
    elif [[ "$CONSTATE" == *"disabled"* ]]; then
        LINENUM=3
    else
        LINENUM=$((LINENUM + 3))
    fi

    # Toggle WiFi text
    if [[ "$CONSTATE" == *"enabled"* ]]; then
        TOGGLE=" Toggle Wifi Off"
    else
        TOGGLE=" Toggle Wifi On"
    fi

    # Show rofi menu with additional options
    CHENTRY=$(echo -e "$TOGGLE\n Refresh List\n Forget Network\n$LIST" | rofi -theme "$ROFI_THEME" -dmenu -p "󱛃 SSID: " -lines "$LINENUM" -a "$HIGHLINE" -font "$FONT" -width -"$RWIDTH")

    # Check if user cancelled
    if [ -z "$CHENTRY" ]; then
        exit 0
    fi

    # Extract chosen SSID
    CHSSID=$(echo "$CHENTRY" | sed 's/[[:space:]]\{2,\}/|/g' | awk -F "|" '{print $1}')

    # Handle user input
    case "$CHENTRY" in
        " Toggle Wifi Off")
            nmcli radio wifi off
            notify-send -a "WiFi" "WiFi" "WiFi turned off"
            show_menu
            ;;
        
        " Toggle Wifi On")
            nmcli radio wifi on
            notify-send -a "WiFi" "WiFi" "WiFi turned on"
            sleep 2  # Give it time to scan for networks
            show_menu
            ;;
        
        " Refresh List")
            nmcli device wifi rescan ifname "$SELECTED_DEVICE"
            notify-send -a "WiFi" "WiFi" "Refreshing network list..."
            sleep 2  # Give it time to rescan
            show_menu
            ;;
        
        " Forget Network")
            forget_network
            show_menu
            ;;
        
        *)
            # Check if SSID is already known
            if [[ "$CHSSID" == "*" ]]; then
                CHSSID=$(echo "$CHENTRY" | sed 's/[[:space:]]\{2,\}/|/g' | awk -F "|" '{print $3}')
            fi
            
            # If SSID is in the known connections list, just connect
            if echo "$KNOWNCON" | grep -q "$CHSSID"; then
                nmcli con up "$CHSSID" ifname "$SELECTED_DEVICE"
                if [ $? -eq 0 ]; then
                    notify-send -a "WiFi" "WiFi" "Connected to $CHSSID"
                else
                    notify-send -a "WiFi" "WiFi Error" "Failed to connect to $CHSSID" -u critical
                fi
            else
                # New network - check if it requires a password
                SECURITY=$(echo "$CHENTRY" | sed 's/[[:space:]]\{2,\}/|/g' | awk -F "|" '{print $2}')
                
                # If the entry is not in the list (user typed it), assume it needs password
                if ! echo "$LIST" | grep -q "$CHSSID"; then
                    # User entered a custom SSID
                    WIFIPASS=$(rofi -theme "$ROFI_THEME" -dmenu -password -p "󰟵 $CHSSID: " -lines 0 -font "$FONT")
                    
                    if [ -n "$WIFIPASS" ]; then
                        nmcli dev wifi con "$CHSSID" password "$WIFIPASS" ifname "$SELECTED_DEVICE"
                        if [ $? -eq 0 ]; then
                            notify-send -a "WiFi" "WiFi" "Connected to $CHSSID"
                        else
                            notify-send -a "WiFi" "WiFi Error" "Failed to connect to $CHSSID" -u critical
                        fi
                    else
                        # Try without password (open network)
                        nmcli dev wifi con "$CHSSID" ifname "$SELECTED_DEVICE"
                        if [ $? -eq 0 ]; then
                            notify-send -a "WiFi" "WiFi" "Connected to $CHSSID"
                        else
                            notify-send -a "WiFi" "WiFi Error" "Failed to connect to $CHSSID" -u critical
                        fi
                    fi
                elif [[ "$SECURITY" =~ "WPA" ]] || [[ "$SECURITY" =~ "WEP" ]]; then
                    # Network from list that requires password
                    WIFIPASS=$(rofi -theme "$ROFI_THEME" -dmenu -password -p "󰟵 $CHSSID: " -lines 0 -font "$FONT")
                    
                    if [ -n "$WIFIPASS" ]; then
                        nmcli dev wifi con "$CHSSID" password "$WIFIPASS" ifname "$SELECTED_DEVICE"
                        if [ $? -eq 0 ]; then
                            notify-send -a "WiFi" "WiFi" "Connected to $CHSSID"
                        else
                            notify-send -a "WiFi" "WiFi Error" "Failed to connect to $CHSSID" -u critical
                        fi
                    fi
                else
                    # Open network from list
                    nmcli dev wifi con "$CHSSID" ifname "$SELECTED_DEVICE"
                    if [ $? -eq 0 ]; then
                        notify-send -a "WiFi" "WiFi" "Connected to $CHSSID"
                    else
                        notify-send -a "WiFi" "WiFi Error" "Failed to connect to $CHSSID" -u critical
                    fi
                fi
            fi
            ;;
    esac
}

# Show the menu for the first time
show_menu