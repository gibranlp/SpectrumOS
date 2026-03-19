# SpectrumOS Project Memory

## Project Overview
Arch Linux distro focused on gaming, Hyprland, and pywal-based theming.
Repo: `/home/gibranlp/SpectrumOS`

## Key Architecture
- `install.sh` — full installer (packages + config deployment)
- `dots.sh` — config deployment only (calls `deploy_config()` helper)
- `bin/` → deployed to `/usr/share/spectrumos/scripts/` at install time
- `config/` → deployed to `~/.config/` via `dots.sh`
- `etc/spectrumos/spectrumos.conf` → main runtime config (`/etc/spectrumos/spectrumos.conf`)
- `limine/` → boot config + sync service
- Pywal templates: `config/wal/templates/` → generated to `~/.cache/wal/`

## Current State (as of 2026-03-19)
Full fix pass completed (see `docs/plans/2026-03-19-spectrumOS-full-fix.md`).
All changes committed on `main`. Key fixes:
- Lock screen, SOS_Panel.sh, SOS_Gowall.sh, SOS_DarkLight.sh bugs fixed
- Limine UUID placeholder added
- Gaming configs added (gamemode, mangohud, vkbasalt)
- Security validation added to 5 scripts
- install.sh: logging + Nvidia auto-config
- dots.sh: --gaming flag

## Next Steps
1. Test `install.sh` on fresh Arch Linux install
2. Fix any issues found during test
3. Build SpectrumOS ISO using `archiso`
   - `archiso` is already in APPS_PKGS in install.sh
   - Standard approach: create `archlive/` profile based on `releng` profile
   - Key files: `packages.x86_64`, `airootfs/` overlay, `profiledef.sh`

## Important Notes
- Kernel: `linux-zen` (hardcoded in limine sync script)
- AUR helper: `paru`
- Display manager: SDDM
- Lock screen: `hyprlock` (SUPER+L keybind)
- Wallpaper source: `/var/lib/spectrumos/current.png`
- Colors source: `/var/lib/spectrumos/colors.conf`
- ESP detection: `findmnt -no TARGET /boot || /efi`

## Common Pywal Integration Points
- `~/.cache/wal/colors-hyprland.conf` → sourced by hyprland + hyprlock
- `~/.cache/wal/colors-waybar.css` → waybar colors
- `~/.cache/wal/SOS_Colors.rasi` → rofi colors
- `~/.cache/wal/dunstrc` → dunst config
- `~/.cache/wal/cava-config` → cava colors
- `~/.cache/wal/sddm-colors.conf` → copied to `/var/lib/spectrumos/colors.conf` for limine sync
