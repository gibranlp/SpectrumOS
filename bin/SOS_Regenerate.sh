#!/bin/bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 
# Regenerate GTK QT and icon themes

/usr/share/spectrumos/scripts/SOS_PywalThemix.sh
/usr/share/spectrumos/scripts/SOS_ReloadIcons.sh

# Send notification with thumbnail
dunstify -a "SpectrumOS" -t 1000 "GTK, QT, Icons Regenerated"
