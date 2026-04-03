#!/bin/bash
# _____             _                 _____ _____ 
#|   __|___ ___ ___| |_ ___ _ _ _____|     |   __|
#|__   | . | -_|  _|  _|  _| | |     |  |  |__   |
#|_____|  _|___|___|_| |_| |___|_|_|_|_____|_____|
#      |_|   
# SpectrumOS - Embrace the Chromatic Symphony!
# By: gibranlp <thisdoesnotwork@gibranlp.dev>
# MIT licence 
# Qt/Kvantum theme generator using pywal colors

source "$HOME/.cache/wal/colors.sh"

KVANTUM_DIR="$HOME/.config/Kvantum/Pywal"
mkdir -p "$KVANTUM_DIR"

# Generate Kvantum SVG (for better rendering)
cat > "$KVANTUM_DIR/Pywal.svg" << EOF
<svg width="1" height="1" version="1.1" xmlns="http://www.w3.org/2000/svg">
 <rect width="1" height="1" fill="${background}"/>
</svg>
EOF

# Generate Kvantum config
cat > "$KVANTUM_DIR/Pywal.kvconfig" << EOF
[%General]
author=Pywal
comment=Auto-generated from pywal
x11drag=menubar_and_primary_toolbar
alt_mnemonic=true
left_tabs=true
attach_active_tab=false
mirror_doc_tabs=false
group_toolbar_buttons=true
toolbar_item_spacing=0
toolbar_interior_spacing=2
spread_progressbar=true
composite=true
menu_shadow_depth=5
spread_menuitems=true
tooltip_shadow_depth=3
splitter_width=1
scroll_width=12
scroll_arrows=false
scroll_min_extent=50
slider_width=6
slider_handle_width=16
slider_handle_length=16
center_toolbar_handle=true
check_size=16
textless_progressbar=false
progressbar_thickness=4
menubar_mouse_tracking=true
toolbutton_style=0
double_click=false
translucent_windows=false
blurring=false
popup_blurring=false
vertical_spin_indicators=false
spin_button_width=16
fill_rubberband=false
merge_menubar_with_toolbar=true
small_icon_size=16
large_icon_size=32
button_icon_size=16
toolbar_icon_size=16
combo_as_lineedit=true
animate_states=true
button_contents_shift=false
combo_menu=true
hide_combo_checkboxes=false
combo_focus_rect=true
groupbox_top_label=true
inline_spin_indicators=true
joined_inactive_tabs=false
layout_spacing=6
layout_margin=9
scrollbar_in_view=false
transient_scrollbar=false
transient_groove=false
submenu_overlap=0
tooltip_delay=-1
tree_branch_line=true
contrast=1.00
dialog_button_layout=0
intensity=1.00
saturation=1.00
shadowless_popup=false
respect_DE=true
scrollable_menu=false
submenu_delay=250
no_window_pattern=false

[GeneralColors]
window.color=${background}
base.color=${color0}
alt.base.color=${color8}
button.color=${color1}
light.color=${color7}
mid.light.color=${color8}
dark.color=${color0}
mid.color=${color8}
highlight.color=${color1}
inactive.highlight.color=${color8}
text.color=${foreground}
window.text.color=${foreground}
button.text.color=${foreground}
disabled.text.color=${color8}
tooltip.base.color=${color0}
tooltip.text.color=${foreground}
highlight.text.color=${foreground}
link.color=${color4}
link.visited.color=${color5}
progress.indicator.text.color=${foreground}

[Hacks]
transparent_ktitle_label=true
transparent_dolphin_view=true
transparent_pcmanfm_sidepane=true
blur_translucent=false
transparent_menutitle=true
respect_darkness=true
kcapacitybar_as_progressbar=true
force_size_grip=true
iconless_pushbutton=false
iconless_menu=false
disabled_icon_opacity=70
lxqtmainmenu_iconsize=22
normal_default_pushbutton=true
single_top_toolbar=true
tint_on_mouseover=0
transparent_pcmanfm_view=false
no_selection_tint=false
EOF

# Set as active theme
if command -v kvantummanager &> /dev/null; then
    kvantummanager --set Pywal 2>/dev/null || true
else
    echo "kvantummanager not found. Kvantum theme generated but not activated."
fi