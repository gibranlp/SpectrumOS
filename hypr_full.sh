#!/usr/bin/env bash
set -e

echo "==> Installing core system..."

sudo pacman -S --needed --noconfirm \
  hyprland kitty rofi \
  swww python-pywal \
  wl-clipboard grim slurp \
  network-manager-applet \
  ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji \
  pipewire pipewire-alsa pipewire-pulse wireplumber \
  bluez bluez-utils \
  git base-devel meson ninja cmake \
  brightnessctl playerctl \
  steam lutris mangohud gamemode

echo "==> Enabling services..."
sudo systemctl enable NetworkManager bluetooth

# ---- AGS (ax-shell base) ----
echo "==> Installing AGS..."

if ! command -v ags &> /dev/null; then
  git clone https://github.com/Aylur/ags.git /tmp/ags
  cd /tmp/ags
  meson setup build
  ninja -C build
  sudo ninja -C build install
fi

# ---- Config dirs ----
echo "==> Creating config structure..."

mkdir -p ~/.config/hypr
mkdir -p ~/.config/ags
mkdir -p ~/.config/wal
mkdir -p ~/Pictures/wallpapers

# ---- HYPRLAND CONFIG ----
echo "==> Writing Hyprland config..."

cat > ~/.config/hypr/hyprland.conf << 'EOF'
exec-once = swww init
exec-once = ~/.config/hypr/start.sh

monitor=,preferred,auto,1

input {
    kb_layout = us
}

general {
    gaps_in = 6
    gaps_out = 12
    border_size = 2
}

decoration {
    rounding = 12
    blur = yes
    blur_size = 6
}

animations {
    enabled = yes
}

# APPS
bind = SUPER, RETURN, exec, kitty
bind = SUPER, D, exec, rofi -show drun
bind = SUPER, Q, killactive
bind = SUPER, F, fullscreen

# SYSTEM
bind = SUPER, W, exec, ~/.config/hypr/set-wallpaper.sh
bind = SUPER, E, exec, thunar
EOF

# ---- START SCRIPT ----
cat > ~/.config/hypr/start.sh << 'EOF'
#!/usr/bin/env bash

nm-applet --indicator &
blueman-applet &

# start AGS shell
ags &
EOF

chmod +x ~/.config/hypr/start.sh

# ---- WALLPAPER + PYWAL ----
echo "==> Wallpaper system..."

cat > ~/.config/hypr/set-wallpaper.sh << 'EOF'
#!/usr/bin/env bash

WALL="$1"

if [ -z "$WALL" ]; then
  WALL=$(find ~/Pictures/wallpapers -type f | shuf -n 1)
fi

swww img "$WALL" --transition-type any --transition-duration 1

wal -i "$WALL"

# restart AGS to apply new colors
pkill ags
ags &
EOF

chmod +x ~/.config/hypr/set-wallpaper.sh

# ---- AGS CONFIG (ax-shell style minimal) ----
echo "==> Creating AGS config..."

cat > ~/.config/ags/config.js << 'EOF'
const { Bar, Widget } = await import("resource:///com/github/Aylur/ags/widget.js");

const clock = Widget.Label({
    class_name: "clock",
    setup: self => {
        setInterval(() => {
            self.label = new Date().toLocaleTimeString();
        }, 1000);
    }
});

const bar = Bar({
    anchors: ["top", "left", "right"],
    widgets: [
        clock
    ]
});

export default {
    windows: [bar]
};
EOF

# ---- AGS STYLE (PYWAL COLORS) ----
cat > ~/.config/ags/style.css << 'EOF'
@import url("/home/'"$USER"'/.cache/wal/colors.css");

* {
  font-family: JetBrainsMono Nerd Font;
  font-size: 14px;
  color: @foreground;
  background: transparent;
}

.clock {
  padding: 10px;
}
EOF

echo "==> Installing Thunar..."
sudo pacman -S --noconfirm thunar

echo "==> Done!"
echo ""
echo "🔥 READY:"
echo "1. Put wallpapers in ~/Pictures/wallpapers"
echo "2. Login to Hyprland"
echo "3. Press SUPER + W"
echo ""
echo "You now have:"
echo "- Hyprland"
echo "- AGS shell"
echo "- Pywal dynamic colors"
echo "- Gaming tools (Steam, Lutris, MangoHud)"