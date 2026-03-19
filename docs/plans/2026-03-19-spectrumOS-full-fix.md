# SpectrumOS Full Fix Pass Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix all critical bugs, security issues, missing configs, and robustness problems found in the full audit of SpectrumOS.

**Architecture:** Shell scripts in `bin/` are installed to `/usr/share/spectrumos/scripts/` at deploy time via `dots.sh`. Pywal templates in `config/wal/templates/` are generated to `~/.cache/wal/` by pywal16. Hyprland configs in `config/hypr/` are deployed to `~/.config/hypr/`. New gaming configs go in `config/` and are deployed via a new `install_gaming_configs()` function in `dots.sh`.

**Tech Stack:** bash, pywal16, Hyprland, gamemode, MangoHud, vkbasalt, limine

---

## Group 1 — Critical Script Bugs

---

### Task 1: Fix lock screen in SOS_Session.sh

**Files:**
- Modify: `bin/SOS_Session.sh:44`

**Step 1: Inspect current state**

Open `bin/SOS_Session.sh` and confirm line 44 is:
```bash
0)  ;;
```

**Step 2: Apply fix**

Change line 44 from:
```bash
0)  ;;
```
to:
```bash
0) hyprlock ;;
```

**Step 3: Verify**

Read the file and confirm the change is present. The lock option (index 0 = "🔒 Lock") now calls `hyprlock`.

**Step 4: Commit**

```bash
git add bin/SOS_Session.sh
git commit -m "fix: lock screen now calls hyprlock in SOS_Session.sh"
```

---

### Task 2: Fix SOS_Panel.sh — missing cases and wrong script name

**Files:**
- Modify: `bin/SOS_Panel.sh`

**Background:**
- Case `#30` calls `SOS_SessionMenu.sh` which does not exist. The correct script is `SOS_Session.sh`.
- Case `#25` (Temperature Monitor) and `#27` (Screen Draw) have no handler.
- Case `#31` (Support) has no handler.

**Step 1: Fix case #30 — wrong script name**

Change:
```bash
30) /usr/share/spectrumos/scripts/SOS_SessionMenu.sh ;;
```
to:
```bash
30) /usr/share/spectrumos/scripts/SOS_Session.sh ;;
```

**Step 2: Add missing cases #25, #27, #31**

After the existing `case` block, before `esac`, add:

```bash
    # Monitor temperature
    25) kitty -e btop ;;
    # Screen Draw (gromit-mpx)
    27) gromit-mpx ;;
    # Support SpectrumOS
    31) xdg-open "https://github.com/gibranlp/SpectrumOS" ;;
```

**Step 3: Verify**

Re-read `bin/SOS_Panel.sh` and confirm all three new cases appear and case 30 points to `SOS_Session.sh`.

**Step 4: Commit**

```bash
git add bin/SOS_Panel.sh
git commit -m "fix: correct SOS_Session script name and add missing panel cases 25/27/31"
```

---

### Task 3: Fix SOS_Gowall.sh — duplicate pywal, undefined GOWALL_OUTPUT, notify-send typo

**Files:**
- Modify: `bin/SOS_Gowall.sh`

**Background:**
- `set_wallpaper()` calls pywal twice. The first call (lines 101-105) runs BEFORE gowall has processed the wallpaper, making it pointless.
- The second pywal call (lines 111-115) uses `$GOWALL_OUTPUT` which is never defined in this function. It must be replaced with the correct path `/var/lib/spectrumos/current.png` (same as `$CURRENT_WALLPAPER` from config).
- Line 141: `notify-send -t 1000"Theme Updated!"` is missing a space.

**Step 1: Remove first duplicate pywal block (lines 101-105)**

Remove these lines from `set_wallpaper()`:
```bash
    # Pywal
    if [ "$PYWAL_LIGHT_SCHEME" = "Light" ]; then
        wal -l -i /var/lib/spectrumos/current.png --backend "$PYWAL_BACKEND"
    else
        wal -i /var/lib/spectrumos/current.png --backend "$PYWAL_BACKEND"
    fi
```

**Step 2: Replace `$GOWALL_OUTPUT` with `$CURRENT_WALLPAPER` in the remaining pywal block**

Change:
```bash
    # Pywal
    if [ "$PYWAL_LIGHT_SCHEME" = "Light" ]; then
        wal -l -i "$GOWALL_OUTPUT" --backend "$PYWAL_BACKEND"
    else
        wal -i "$GOWALL_OUTPUT" --backend "$PYWAL_BACKEND"
    fi
```
to:
```bash
    # Pywal
    if [ "$PYWAL_LIGHT_SCHEME" = "Light" ]; then
        wal -l -i "$CURRENT_WALLPAPER" --backend "$PYWAL_BACKEND"
    else
        wal -i "$CURRENT_WALLPAPER" --backend "$PYWAL_BACKEND"
    fi
```

**Step 3: Fix notify-send spacing**

Change:
```bash
    notify-send -t 1000"Theme Updated!"
```
to:
```bash
    notify-send -t 1000 "Theme Updated!"
```

**Step 4: Verify**

Re-read `bin/SOS_Gowall.sh`. Confirm:
- Only one pywal block remains in `set_wallpaper()`
- It uses `$CURRENT_WALLPAPER`
- `notify-send` has a space before the message

**Step 5: Commit**

```bash
git add bin/SOS_Gowall.sh
git commit -m "fix: remove duplicate pywal call, fix GOWALL_OUTPUT and notify-send in SOS_Gowall.sh"
```

---

### Task 4: Fix SOS_DarkLight.sh — duplicate pywal and undefined GOWALL_OUTPUT

**Files:**
- Modify: `bin/SOS_DarkLight.sh`

**Background:** Same pattern as SOS_Gowall.sh. First pywal block (lines 56-60) is redundant and runs before wallpaper is applied. Second block (lines 66-70) uses undefined `$GOWALL_OUTPUT`.

**Step 1: Remove first duplicate pywal block**

Remove from `set_wallpaper()`:
```bash
    # Pywal
    if [ "$PYWAL_LIGHT_SCHEME" = "Light" ]; then
        wal -l -i /var/lib/spectrumos/current.png --backend "$PYWAL_BACKEND"
    else
        wal -i /var/lib/spectrumos/current.png --backend "$PYWAL_BACKEND"
    fi
```

**Step 2: Replace `$GOWALL_OUTPUT` with `$CURRENT_WALLPAPER`**

Change:
```bash
    # Pywal
    if [ "$PYWAL_LIGHT_SCHEME" = "Light" ]; then
        wal -l -i "$GOWALL_OUTPUT" --backend "$PYWAL_BACKEND"
    else
        wal -i "$GOWALL_OUTPUT" --backend "$PYWAL_BACKEND"
    fi
```
to:
```bash
    # Pywal
    if [ "$PYWAL_LIGHT_SCHEME" = "Light" ]; then
        wal -l -i "$CURRENT_WALLPAPER" --backend "$PYWAL_BACKEND"
    else
        wal -i "$CURRENT_WALLPAPER" --backend "$PYWAL_BACKEND"
    fi
```

**Step 3: Verify**

Re-read `bin/SOS_DarkLight.sh`. Confirm only one pywal block, using `$CURRENT_WALLPAPER`.

**Step 4: Commit**

```bash
git add bin/SOS_DarkLight.sh
git commit -m "fix: remove duplicate pywal call and fix GOWALL_OUTPUT in SOS_DarkLight.sh"
```

---

### Task 5: Fix tilde expansion in SOS_Select_Wallpaper.sh

**Files:**
- Modify: `bin/SOS_Select_Wallpaper.sh:31`

**Background:** Bash does NOT expand `~` inside double-quoted strings. The rofi `-theme` argument uses `"~/.config/rofi/SOS_Wallpaper.rasi"` which literally passes the tilde character to rofi rather than the home directory path. This causes rofi to silently fall back to its default theme.

**Step 1: Fix the tilde**

Change:
```bash
    -theme ~/.config/rofi/SOS_Wallpaper.rasi \
```
to:
```bash
    -theme "$HOME/.config/rofi/SOS_Wallpaper.rasi" \
```

**Step 2: Verify**

Re-read the file. Confirm `-theme "$HOME/.config/rofi/SOS_Wallpaper.rasi"`.

**Step 3: Commit**

```bash
git add bin/SOS_Select_Wallpaper.sh
git commit -m "fix: expand tilde correctly in rofi theme path in SOS_Select_Wallpaper.sh"
```

---

### Task 6: Fix SOS_CleanSystem.sh — guard orphan removal

**Files:**
- Modify: `bin/SOS_CleanSystem.sh`

**Background:** `pacman -Rns $(pacman -Qtdq) --noconfirm` fails with a non-zero exit code when there are no orphan packages (because `pacman -Qtdq` returns exit code 1 and the command substitution is empty). This can crash scripts using `set -e`.

**Step 1: Apply fix**

Replace:
```bash
sudo pacman -Rns $(pacman -Qtdq) --noconfirm
```
with:
```bash
ORPHANS=$(pacman -Qtdq 2>/dev/null)
if [ -n "$ORPHANS" ]; then
    sudo pacman -Rns $ORPHANS --noconfirm
fi
```

**Step 2: Verify**

Re-read `bin/SOS_CleanSystem.sh`. Confirm the guard is present.

**Step 3: Commit**

```bash
git add bin/SOS_CleanSystem.sh
git commit -m "fix: guard orphan removal when no orphans exist in SOS_CleanSystem.sh"
```

---

### Task 7: Add mkdir -p guards in all wallpaper scripts

**Files:**
- Modify: `bin/SOS_Gowall.sh`
- Modify: `bin/SOS_DarkLight.sh`
- Modify: `bin/SOS_Select_Wallpaper.sh`
- Modify: `bin/SOS_Randomize_Wallpaper.sh`

**Background:** All four scripts copy generated configs to `~/.config/dunst/dunstrc` and `~/.config/cava/config` without ensuring those directories exist first. On a fresh install these dirs may not exist yet.

**Step 1: Add mkdir guards in SOS_Gowall.sh**

Find the block:
```bash
    cp "$HOME/.cache/wal/dunstrc" "$HOME/.config/dunst/dunstrc"
    pkill dunst; dunst &

    cp "$HOME/.cache/wal/cava-config" "$HOME/.config/cava/config"
```
And prepend:
```bash
    mkdir -p "$HOME/.config/dunst"
    mkdir -p "$HOME/.config/cava"
```

**Step 2: Same in SOS_DarkLight.sh**

Same block, same fix.

**Step 3: Same in SOS_Select_Wallpaper.sh**

Same block, same fix.

**Step 4: Same in SOS_Randomize_Wallpaper.sh**

Same block, same fix.

**Step 5: Verify**

Re-read all four files. Confirm both `mkdir -p` lines appear before the `cp` calls.

**Step 6: Commit**

```bash
git add bin/SOS_Gowall.sh bin/SOS_DarkLight.sh bin/SOS_Select_Wallpaper.sh bin/SOS_Randomize_Wallpaper.sh
git commit -m "fix: add mkdir -p guards for dunst and cava config dirs in wallpaper scripts"
```

---

## Group 2 — Limine UUID

---

### Task 8: Replace hardcoded UUID in limine.conf.example

**Files:**
- Modify: `limine/limine.conf.example`

**Background:** The file contains the author's personal root UUID `57736533-84a6-42a3-a18a-5428fe927e18`. The `spectrumos-limine-sync.sh` script already detects the real UUID dynamically via `get_root_uuid()` and replaces `root=UUID=...` on each sync run. So replacing the hardcoded value with a placeholder is safe — the sync will correct it on first run.

**Step 1: Replace the UUID**

Change both cmdline entries from:
```
cmdline: root=UUID=57736533-84a6-42a3-a18a-5428fe927e18 zswap.enabled=0 rw rootfstype=ext4 quiet splash
```
to:
```
cmdline: root=UUID=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX zswap.enabled=0 rw rootfstype=btrfs quiet splash
```

Also change `rootfstype=ext4` to `rootfstype=btrfs` as a safe placeholder (the sync script also replaces `rootfstype` dynamically).

**Step 2: Verify**

Re-read `limine/limine.conf.example`. Confirm no personal UUID remains.

**Step 3: Commit**

```bash
git add limine/limine.conf.example
git commit -m "fix: replace hardcoded personal UUID with placeholder in limine.conf.example"
```

---

## Group 3 — Gaming Configs

---

### Task 9: Create gamemode.ini

**Files:**
- Create: `config/gamemode.ini`

**Background:** gamemode reads its config from `$HOME/.config/gamemode.ini` or `/etc/gamemode.ini`. This config tunes CPU governor, nice levels, and triggers GPU performance modes. Without it, gamemode uses conservative defaults.

**Step 1: Create the file**

```ini
[general]
renice = 10
inhibit_screensaver = 1
disable_splitlock = 1

[gpu]
apply_gpu_optimisations = accept-responsibility
gpu_device = 0
amd_performance_level = high

[custom]
start = notify-send -a "SpectrumOS" "GameMode" "Performance mode activated"
end   = notify-send -a "SpectrumOS" "GameMode" "Performance mode deactivated"
```

**Step 2: Verify**

Read back `config/gamemode.ini`. Confirm content is correct.

---

### Task 10: Create MangoHud.conf

**Files:**
- Create: `config/mangohud/MangoHud.conf`

**Background:** MangoHud reads from `$HOME/.config/MangoHud/MangoHud.conf`. Without config it shows a minimal overlay. This preset shows the most useful gaming metrics.

**Step 1: Create the directory and file**

```ini
# SpectrumOS MangoHud Configuration
legacy_layout = false
fps
fps_limit = 0
frame_timing = 1
frametime

cpu_stats
cpu_temp
cpu_power

gpu_stats
gpu_temp
gpu_core_clock
gpu_mem_clock
gpu_power
gpu_load_change
gpu_load_value = 60,90

ram
vram

wine
engine_version
vulkan_driver

gamemode_indicator = 1
background_alpha = 0.4
font_size = 20
position = top-left
toggle_hud = Shift_R+F12
toggle_fps_limit = Shift_L+F1
```

**Step 2: Verify**

Read back `config/mangohud/MangoHud.conf`. Confirm content.

---

### Task 11: Create vkbasalt.conf

**Files:**
- Create: `config/vkbasalt/vkbasalt.conf`

**Background:** vkbasalt reads from `$HOME/.config/vkbasalt/vkbasalt.conf`. CAS (Contrast Adaptive Sharpening) is a low-overhead sharpening pass that improves image quality at no significant performance cost. It is disabled by default to not force it on users; they can enable via env var `ENABLE_VKBASALT=1`.

**Step 1: Create the file**

```ini
# SpectrumOS vkBasalt Configuration
# Enable with: ENABLE_VKBASALT=1 %command%

effects = cas

# CAS - Contrast Adaptive Sharpening
# 0.0 = no sharpening, 1.0 = maximum sharpening
cas.sharpness = 0.4

# FXAA (optional, add to effects list)
# fxaa.subpixelQuality = 0.75
# fxaa.qualityEdgeThreshold = 0.166
# fxaa.qualityEdgeThresholdMin = 0.0833
```

**Step 2: Verify**

Read back `config/vkbasalt/vkbasalt.conf`.

---

### Task 12: Add gaming window rules to windowrules.conf

**Files:**
- Modify: `config/hypr/windowrules.conf`

**Background:** Without window rules, Steam launches on whatever workspace is active, game windows may not go fullscreen properly, and Gamescope may have border/decoration artifacts.

**Step 1: Append gaming rules**

Add to the end of `config/hypr/windowrules.conf`:

```ini
# Gaming window rules
windowrule = workspace 6 silent, match:class ^(steam)$
windowrule = workspace 6 silent, match:class ^(lutris)$
windowrule = float on, match:class ^(steam)$
windowrule = float on, match:class ^(lutris)$
windowrule = fullscreen, match:class ^(gamescope)$
windowrule = nodim, match:class ^(gamescope)$
windowrule = noblur, match:class ^(gamescope)$
windowrule = noborder, match:class ^(gamescope)$
# Game-specific: suppress idle inhibit during gaming
windowrule = idleinhibit always, match:class ^(gamescope)$
windowrule = idleinhibit focus, match:class ^(steam_app_.*)$
```

**Step 2: Verify**

Re-read `config/hypr/windowrules.conf`. Confirm rules are present.

**Step 3: Commit tasks 9-12 together**

```bash
git add config/gamemode.ini config/mangohud/MangoHud.conf config/vkbasalt/vkbasalt.conf config/hypr/windowrules.conf
git commit -m "feat: add gamemode, mangohud, vkbasalt configs and gaming window rules"
```

---

### Task 13: Deploy gaming configs in dots.sh

**Files:**
- Modify: `dots.sh`

**Step 1: Add install function**

After the `install_mimeapps()` function and before `install_all()`, add:

```bash
function install_gaming_configs() {
    echo -e "${BLUE}Installing gaming configs...${NC}"
    mkdir -p "$HOME/.config/MangoHud"
    mkdir -p "$HOME/.config/vkbasalt"
    deploy_config "$SCRIPT_DIR/config/gamemode.ini" "$HOME/.config/gamemode.ini"
    deploy_config "$SCRIPT_DIR/config/mangohud/MangoHud.conf" "$HOME/.config/MangoHud/MangoHud.conf"
    deploy_config "$SCRIPT_DIR/config/vkbasalt/vkbasalt.conf" "$HOME/.config/vkbasalt/vkbasalt.conf"
    echo -e "${GREEN}✓ Gaming configs installed${NC}"
}
```

**Step 2: Add to install_all()**

Inside `install_all()`, add `install_gaming_configs` after `install_mimeapps`:
```bash
    install_gaming_configs
```

**Step 3: Add CLI option**

In the `case` block for CLI args, add:
```bash
        --gaming)
            install_gaming_configs
            ;;
```

And add to `usage()`:
```bash
    echo "  --gaming         Install gaming configs (gamemode, mangohud, vkbasalt)"
```

**Step 4: Verify**

Re-read `dots.sh`. Confirm function exists, is called from `install_all`, and has a CLI flag.

**Step 5: Commit**

```bash
git add dots.sh
git commit -m "feat: add install_gaming_configs to dots.sh with --gaming flag"
```

---

## Group 4 — Security: Input Validation

---

### Task 14: Validate rofi selections before sed in config scripts

**Files:**
- Modify: `bin/SOS_Backends.sh`
- Modify: `bin/SOS_Gowall.sh`
- Modify: `bin/SOS_DarkLight.sh`
- Modify: `bin/SOS_Waybar_Theme.sh`
- Modify: `bin/SOS_Waybar_Style.sh`

**Background:** All five scripts take user selection from rofi and pass it directly to `sed -i` for writing into config files. If the selection contains shell metacharacters or sed delimiters (`/`, `&`, `\`), it corrupts the config file. The fix is to validate the selection against the known-good list before using it in sed.

**Step 1: Add validation helper to SOS_Backends.sh**

After `local selected` is set and before the `sed -i` line, add:

```bash
    # Validate selection against known-good list
    local valid=false
    for b in "${backends[@]}"; do
        [[ "$selected" == "$b" ]] && valid=true && break
    done
    if [[ "$valid" != true ]]; then
        notify-send -a "SpectrumOS" "Invalid backend selection" -u critical
        exit 1
    fi
```

**Step 2: Add validation to SOS_Gowall.sh — set_default_wall_theme()**

After `selected` is set and before the `sudo sed -i` line, add:

```bash
    local valid=false
    for t in "${wall_theme[@]}"; do
        [[ "$selected" == "$t" ]] && valid=true && break
    done
    if [[ "$valid" != true ]]; then
        notify-send -a "SpectrumOS" "Invalid theme selection" -u critical
        exit 1
    fi
```

**Step 3: Add validation to SOS_DarkLight.sh — set_pywal_scheme()**

After `selected` is set and before `sudo sed -i`, add:

```bash
    local valid=false
    for s in "${schemes[@]}"; do
        [[ "$selected" == "$s" ]] && valid=true && break
    done
    if [[ "$valid" != true ]]; then
        notify-send -a "SpectrumOS" "Invalid scheme selection" -u critical
        exit 1
    fi
```

**Step 4: Add validation to SOS_Waybar_Theme.sh — set_waybar_theme()**

After `selected=$(echo "$selected" | awk '{print $2}')` and before the `ln -sf` line, add:

```bash
    # Validate against known themes
    local valid_themes=("Minimal" "Multimedia" "Productivity" "Detailed" "Gaming")
    local valid=false
    for t in "${valid_themes[@]}"; do
        [[ "$selected" == "$t" ]] && valid=true && break
    done
    if [[ "$valid" != true ]]; then
        notify-send -a "SpectrumOS" "Invalid waybar theme" -u critical
        exit 1
    fi
```

**Step 5: Add validation to SOS_Waybar_Style.sh — set_waybar_style()**

Same pattern, after `selected=$(echo "$selected" | awk '{print $1}')`:

```bash
    local valid_styles=("default" "transparent" "floating" "minimal" "pills")
    local valid=false
    for s in "${valid_styles[@]}"; do
        [[ "$selected" == "$s" ]] && valid=true && break
    done
    if [[ "$valid" != true ]]; then
        notify-send -a "SpectrumOS" "Invalid waybar style" -u critical
        exit 1
    fi
```

**Step 6: Add symlink target existence check to SOS_Waybar_Theme.sh**

Before the `ln -sf` in `set_waybar_theme()`, add:

```bash
    if [[ ! -f "$WAYBAR_CONFIG_DIR/${selected}.json" ]]; then
        notify-send -a "SpectrumOS" "Waybar config not found: ${selected}.json" -u critical
        exit 1
    fi
```

**Step 7: Add symlink target existence check to SOS_Waybar_Style.sh**

Before the `ln -sf` in `set_waybar_style()`, add:

```bash
    if [[ ! -f "$WAYBAR_STYLE_DIR/${selected}.css" ]]; then
        notify-send -a "SpectrumOS" "Waybar style not found: ${selected}.css" -u critical
        exit 1
    fi
```

**Step 8: Verify**

Re-read all five files. Confirm validation blocks are present before each sed/ln call.

**Step 9: Commit**

```bash
git add bin/SOS_Backends.sh bin/SOS_Gowall.sh bin/SOS_DarkLight.sh bin/SOS_Waybar_Theme.sh bin/SOS_Waybar_Style.sh
git commit -m "security: validate rofi selections before sed/ln in config scripts"
```

---

## Group 5 — install.sh Improvements

---

### Task 15: Add logging to install.sh

**Files:**
- Modify: `install.sh`

**Step 1: Add log redirect after the shebang and color definitions**

After line 16 (`NC='\033[0m' # No Color`), add:

```bash
# Log all output to file for debugging
LOG_FILE="/tmp/spectrumos-install-${TIMESTAMP}.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "Install log: $LOG_FILE"
```

**Step 2: Verify**

Re-read `install.sh`. Confirm the three log lines are present.

**Step 3: Commit**

```bash
git add install.sh
git commit -m "feat: add install log file to /tmp/spectrumos-install-<timestamp>.log"
```

---

### Task 16: Auto-detect Nvidia and configure Hyprland env vars in install.sh

**Files:**
- Modify: `install.sh`

**Background:** The `config/hypr/env.conf` has Nvidia-specific env vars commented out. When an Nvidia GPU is detected during install, those lines should be uncommented in the deployed config. This must happen AFTER `dots.sh --all` deploys the configs (line ~181).

**Step 1: Add Nvidia env var configuration block after `dots.sh --all`**

After the `bash "$SCRIPT_DIR/dots.sh" --all` call, add:

```bash
# Auto-configure Nvidia env vars if Nvidia GPU detected
if [[ "${GPU_PKGS[*]}" == *"nvidia"* ]]; then
    echo -e "${BLUE}Nvidia GPU detected — enabling Hyprland Nvidia env vars...${NC}"
    HYPR_ENV="$HOME/.config/hypr/env.conf"
    sed -i 's/^# env = LIBVA_DRIVER_NAME,nvidia/env = LIBVA_DRIVER_NAME,nvidia/' "$HYPR_ENV"
    sed -i 's/^# env = GBM_BACKEND,nvidia-drm/env = GBM_BACKEND,nvidia-drm/' "$HYPR_ENV"
    sed -i 's/^# env = __GLX_VENDOR_LIBRARY_NAME,nvidia/env = __GLX_VENDOR_LIBRARY_NAME,nvidia/' "$HYPR_ENV"
    sed -i 's/^# env = WLR_NO_HARDWARE_CURSORS,1/env = WLR_NO_HARDWARE_CURSORS,1/' "$HYPR_ENV"
    echo -e "${GREEN}✓ Nvidia env vars configured${NC}"
fi
```

**Step 2: Verify**

Re-read the relevant section of `install.sh`. Confirm the block is present after `dots.sh --all`.

**Step 3: Commit**

```bash
git add install.sh
git commit -m "feat: auto-uncomment Nvidia Hyprland env vars when Nvidia GPU detected"
```

---

### Task 17: Add WAYBAR_THEME and WAYBAR_STYLE to spectrumos.conf

**Files:**
- Modify: `etc/spectrumos/spectrumos.conf`

**Background:** `SOS_Waybar_Theme.sh` and `SOS_Waybar_Style.sh` read `WAYBAR_THEME` and `WAYBAR_STYLE` from the config but these are not present in the default config. When absent, the scripts default to hardcoded fallbacks. Adding them to the source config makes the defaults explicit.

**Step 1: Append to spectrumos.conf**

Add after the last line:
```bash
WAYBAR_THEME="Productivity"
WAYBAR_STYLE="default"
```

**Step 2: Verify**

Re-read `etc/spectrumos/spectrumos.conf`. Confirm both new variables are present.

**Step 3: Commit**

```bash
git add etc/spectrumos/spectrumos.conf
git commit -m "feat: add WAYBAR_THEME and WAYBAR_STYLE defaults to spectrumos.conf"
```

---

## Final: Save design doc and wrap up

### Task 18: Commit the design doc

```bash
git add docs/plans/2026-03-19-spectrumOS-full-fix.md
git commit -m "docs: add full fix implementation plan"
```

---

## Summary of All Changes

| Task | File(s) | Type |
|------|---------|------|
| 1 | `bin/SOS_Session.sh` | Bug fix |
| 2 | `bin/SOS_Panel.sh` | Bug fix |
| 3 | `bin/SOS_Gowall.sh` | Bug fix |
| 4 | `bin/SOS_DarkLight.sh` | Bug fix |
| 5 | `bin/SOS_Select_Wallpaper.sh` | Bug fix |
| 6 | `bin/SOS_CleanSystem.sh` | Bug fix |
| 7 | `bin/SOS_Gowall.sh`, `SOS_DarkLight.sh`, `SOS_Select_Wallpaper.sh`, `SOS_Randomize_Wallpaper.sh` | Robustness |
| 8 | `limine/limine.conf.example` | Bug fix |
| 9 | `config/gamemode.ini` | New file |
| 10 | `config/mangohud/MangoHud.conf` | New file |
| 11 | `config/vkbasalt/vkbasalt.conf` | New file |
| 12 | `config/hypr/windowrules.conf` | Enhancement |
| 13 | `dots.sh` | Enhancement |
| 14 | 5x `bin/SOS_*.sh` | Security |
| 15 | `install.sh` | Enhancement |
| 16 | `install.sh` | Enhancement |
| 17 | `etc/spectrumos/spectrumos.conf` | Enhancement |
| 18 | `docs/plans/` | Docs |
