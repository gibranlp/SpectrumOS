#!/usr/bin/env python3
# Media Player script for Waybar
# Shows currently playing media from playerctl
# Supports multiple media players via MPRIS

import json
import subprocess
import sys


def get_player_icon(player_name):
    """Get icon for specific media player"""
    player = player_name.lower()

    # Player-specific icons
    icons = {
        'spotify': '',
        'firefox': '',
        'chrome': '',
        'chromium': '',
        'brave': '',
        'vlc': '󰕼',
        'mpv': '',
        'mopidy': '',
        'rhythmbox': '󰓃',
        'clementine': '',
        'audacious': '󰐹',
        'kdeconnect': '󰂱',
        'plasma-browser-integration': '',
        'youtube': '',
        'youtubemusic': '',
    }

    # Check for matches
    for key, icon in icons.items():
        if key in player:
            return icon

    return '🎜'


def get_active_player():
    """Get the best active player (prioritize playing over paused)"""
    try:
        # Get list of all players
        players = subprocess.check_output(
            ["playerctl", "-l"],
            stderr=subprocess.DEVNULL
        ).decode("utf-8").strip().split('\n')

        if not players or players == ['']:
            return None

        # First try to find a playing player
        for player in players:
            try:
                status = subprocess.check_output(
                    ["playerctl", "-p", player, "status"],
                    stderr=subprocess.DEVNULL
                ).decode("utf-8").strip()

                if status == "Playing":
                    return player
            except subprocess.CalledProcessError:
                continue

        # If no playing player, return the first paused one
        for player in players:
            try:
                status = subprocess.check_output(
                    ["playerctl", "-p", player, "status"],
                    stderr=subprocess.DEVNULL
                ).decode("utf-8").strip()

                if status == "Paused":
                    return player
            except subprocess.CalledProcessError:
                continue

        # If all else fails, return the first player
        return players[0]

    except subprocess.CalledProcessError:
        return None


def get_player_info():
    try:
        # Get the active player
        player = get_active_player()

        if not player:
            output = {
                "text": "",
                "tooltip": "No media player",
                "class": "stopped",
                "alt": "stopped"
            }
            print(json.dumps(output))
            return

        # Get player status
        status = subprocess.check_output(
            ["playerctl", "-p", player, "status"],
            stderr=subprocess.DEVNULL
        ).decode("utf-8").strip()

        # Get metadata
        artist = subprocess.check_output(
            ["playerctl", "-p", player, "metadata", "artist"],
            stderr=subprocess.DEVNULL
        ).decode("utf-8").strip()

        title = subprocess.check_output(
            ["playerctl", "-p", player, "metadata", "title"],
            stderr=subprocess.DEVNULL
        ).decode("utf-8").strip()

        # Get player name (use the player variable if metadata doesn't work)
        try:
            player_name = subprocess.check_output(
                ["playerctl", "-p", player, "metadata", "xesam:title"],
                stderr=subprocess.DEVNULL
            ).decode("utf-8").strip()
        except:
            player_name = player

        # Clean player name for display
        player_display = player.split('.')[0].capitalize()

        # Format output
        if artist and title:
            text = f"{artist} - {title}"
        elif title:
            text = title
        else:
            text = "No media"

        # Truncate if too long
        max_length = 50
        if len(text) > max_length:
            text = text[:max_length-3] + "..."

        # Get player icon
        player_icon = get_player_icon(player)

        # Status symbol
        if status == "Playing":
            symbol = ""
        elif status == "Paused":
            symbol = ""
        else:
            symbol = ""

        output = {
            "text": f"{player_icon} {symbol} {text}",
            "tooltip": f"{player_display}: {status}\n{artist} - {title}" if artist else f"{player_display}: {status}\n{title}",
            "class": player.split('.')[0].lower(),
            "alt": status.lower()
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
        print(json.dumps({"text": "", "tooltip": f"Error: {str(e)}"}), file=sys.stderr)


if __name__ == "__main__":
    get_player_info()