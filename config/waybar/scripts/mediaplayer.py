#!/usr/bin/env python3
# Media Player script for Waybar
# Shows currently playing media from playerctl

import json
import subprocess
import sys


def get_player_info():
    try:
        # Get player status
        status = subprocess.check_output(
            ["playerctl", "status"],
            stderr=subprocess.DEVNULL
        ).decode("utf-8").strip()
        
        # Get metadata
        artist = subprocess.check_output(
            ["playerctl", "metadata", "artist"],
            stderr=subprocess.DEVNULL
        ).decode("utf-8").strip()
        
        title = subprocess.check_output(
            ["playerctl", "metadata", "title"],
            stderr=subprocess.DEVNULL
        ).decode("utf-8").strip()
        
        player = subprocess.check_output(
            ["playerctl", "metadata", "playerName"],
            stderr=subprocess.DEVNULL
        ).decode("utf-8").strip().lower()
        
        # Format output
        if artist and title:
            text = f"{artist} - {title}"
        elif title:
            text = title
        else:
            text = "No media playing"
        
        # Determine icon based on player
        icon = "spotify" if "spotify" in player else "default"
        
        # Status symbol
        if status == "Playing":
            symbol = ""
        elif status == "Paused":
            symbol = ""
        else:
            symbol = ""
        
        output = {
            "text": f"{symbol} {text}",
            "tooltip": f"{player.capitalize()}: {status}",
            "class": player,
            "alt": status
        }
        
        print(json.dumps(output))
        
    except subprocess.CalledProcessError:
        # No player running
        output = {
            "text": "",
            "tooltip": "No media player",
            "class": "stopped",
            "alt": "stopped"
        }
        print(json.dumps(output))
    except Exception as e:
        print(json.dumps({"text": "", "tooltip": str(e)}))

if __name__ == "__main__":
    get_player_info()