# Legacy SpectrumOS Audit

Audit date: 2026-08-30  
Source: `/home/gibranlp/SpectrumOS` (read-only)

## Executive assessment

The legacy repository contains strong product ideas and several useful visual prototypes, but its operational model is not safe or reproducible enough to reuse wholesale. The most valuable material is the modular Hyprland layout, adaptive-color integration map, SDDM theme concept, desktop action UX, and gaming intent. Most implementations should be refactored because they directly mutate user/system files, mix privileges and concerns, assume specific applications, or duplicate package-manager behavior.

No secret-bearing key material was found in the visible repository inventory. Public-looking author names/email metadata and machine-specific paths exist and must be reviewed before any asset migration. This audit does not reproduce private values.

## Inventory and classification

| Area | Evidence | Class | Why |
|---|---|---:|---|
| Root installers | `install.sh`, `dots.sh`, `hypr_full.sh`, `setup-dirs.sh` | REMOVE | Monolithic and overlapping; mutate pacman config and dotfiles, mix official/AUR packages, use destructive cache/package operations, and make system directories user-writable. Preserve only requirements learned from them. |
| Package selection | arrays in `install.sh` | REFERENCE | Broad checklist for desktop/gaming/dev features, but bloated, contains questionable/obsolete names and AUR prefixes, and lacks ownership/profiles. |
| Hyprland | `config/hypr/*.conf` | REFACTOR | Good split by concerns and useful behavior/keybinding reference. It sources generated cache files and includes host/application assumptions; rebuild as packaged defaults plus overrides. |
| Current experimental Hypr installer | `hypr_full.sh` | REMOVE | Duplicates main installer, builds from source, emits files with heredocs, hardcodes home paths, and is not an auditable package. |
| Waybar | `config/waybar/` with five layouts, seven styles, scripts | REFACTOR | Useful modes and UI reference, but configuration/style combinations and helper scripts are sprawling; weather and GPU scripts are machine/network dependent. Choose a small supported baseline first. |
| Rofi launcher | `config/rofi/`, launcher/action scripts | REFERENCE | UX flows are useful; implementation is coupled to Rofi, fixed theme paths, fonts, and shell parsing. Launcher remains undecided. |
| Notifications | generated `wal/templates/dunstrc`, dunst restart logic | REFACTOR | Dunst is viable, but overwriting its complete config and killing/restarting it from a global theme script is brittle. |
| Terminals | Alacritty and Kitty configs | REFERENCE | Both are present without a clear default/ownership rule. Select one minimal default and keep the other optional. |
| Shell | `config/zsh/.zshrc` | REFACTOR | Confirms zsh intent but a distro must ship fragments/defaults, not replace a user's whole startup file. Personal/work layering was absent. |
| Oh My Zsh | installer references, no vendored framework | REFACTOR | Retain the legacy theme and plugin experience with pinned revisions, disabled self-updates, and no private machine data in distro configuration. |
| Lock/idle | `config/hypr/hyprlock.conf`; Hypridle package intent | REFACTOR | Keep Hyprlock concept; separate palette, wallpaper, authentication UI, and machine power policy. No clear Hypridle config was found. |
| Wallpaper | select/random/generate/Gowall scripts; `/var/lib/spectrumos/current.png` | REFACTOR | Adaptive wallpaper concept is central. Current scripts combine UI, transformation, global state, wallpaper setting, palette generation, and application reloads. |
| Adaptive colors | `config/wal/templates/*`, `SOS_Apply_Colors.sh`, app-specific scripts | REFACTOR | The integration inventory is valuable. Replace the giant fan-out script with a palette schema, atomic outputs, and isolated renderers/reload adapters. |
| GTK/Qt | generated GTK CSS, xsettingsd, Pywal QT script, qt5ct/qt6ct/Kvantum package intent | REFACTOR | Useful targets but direct CSS copying and process killing risk user customizations. Establish explicit support boundaries and fallbacks. |
| Icons/cursors | Papirus/Bibata package intent and Papirus folder mutation | REFERENCE | Sensible candidates; avoid AUR variants or runtime global mutation unless justified. |
| Fonts | bundled FiraCode, SourceCodePro, OfficeCodePro, Courier Prime, icon/proprietary-looking fonts | REMOVE | Duplicates packages and has unclear licensing/provenance, notably “Font Awesome 6 Pro”. Use repository font packages or assets with verified redistribution licenses only. |
| SDDM | `etc/sddm.conf`, `sddm/themes/spectrumos/` | REFACTOR | Cohesive QML prototype worth preserving visually. It reads dynamic colors and includes metadata/assets needing licensing, Qt/QML compatibility, security, and fallback review. |
| Plymouth | custom services/hooks plus theme with ~140 progress frames | REFACTOR | Branding idea is useful; replacing upstream units and the legacy five-second delay is rejected. Spectrum retains upstream units and uses only a bounded two-second quit drop-in. |
| Limine | config example, sync script, hook, path/service | REFERENCE | Demonstrates boot wallpaper/color synchronization, but is complex, ESP-specific, and couples mutable desktop state to boot. Bootloader support scope remains open. |
| Audio | `SOS_Audio.sh` | REFACTOR | Useful interaction design, but shell parsing and Rofi coupling should become a small adapter to PipeWire/WirePlumber tools. |
| Networking | `SOS_Wifi.sh` | REFERENCE | Network UI concept only. Password prompts and `nmcli` parsing deserve a maintained frontend or carefully scoped implementation. |
| Bluetooth | `SOS_Bluetooth.sh` | REFERENCE | Same: retain requirements, not the long shell implementation. |
| Screenshots/recording | Grim/Slurp/Swappy actions and recorder design docs | REFACTOR | Wayland-native toolchain is appropriate. Consolidate scripts, avoid compositor-only assumptions where possible, and test failure/cancel paths. |
| Session/power | `SOS_Session.sh`, `SOS_Power.sh` | REFACTOR | Useful keyboard-driven actions. Keep policy and command execution separate; avoid assuming laptop power controls on desktops. |
| Gaming | `gamemode.ini`, MangoHud, vkBasalt configs and package arrays | REFACTOR | Good foundation targets but must be measurable, optional, GPU-neutral, and not enabled through random tuning. Legacy gaming package list is overbroad. |
| Steam/Wine/Proton | installer package arrays only | REFERENCE | No reproducible configuration or validation found. Build a supported foundation with multilib/Vulkan profiles; keep launchers/runners optional. |
| Audio stack | package arrays for PipeWire/WirePlumber | REFERENCE | Correct direction, but installer force-removes JACK providers with `pacman -Rdd`; that behavior is rejected. |
| Networking/Bluetooth stack | NetworkManager/BlueZ packages and service enables | REFERENCE | Reasonable defaults, though the current reference machine uses systemd-networkd. Make the distro choice explicit and migrate safely. |
| Power/laptop | TLP config plus TLP/cpupower packages | REFERENCE | Unconditional laptop tooling conflicts with desktop and other profile managers. Use mutually exclusive hardware profiles. |
| GPU handling | shell detection for AMD/Intel/NVIDIA/VM | REFACTOR | Profiles are necessary, but simplistic `lspci` branches and unconditional legacy Xorg drivers are insufficient. Include correct 32-bit Vulkan per selected GPU. |
| Udev | root `50-keychron.rules` | UNKNOWN | Hardware-specific rule needs purpose, safety, and upstream/package investigation; never enable globally by default without a profile. |
| System services | Plymouth/LightDM units and Limine sync units | REMOVE/REFACTOR | LightDM is inconsistent with SDDM; upstream unit replacement is unsafe. Limine mechanism can inform a new optional integration. |
| User services | none found | UNKNOWN | Runtime processes are launched/restarted ad hoc; SpectrumOS2 should define user services only where lifecycle ownership helps. |
| Portals/environment | Hyprland env file and package arrays | REFACTOR | Necessary but needs a single compositor/session model, portal preference config, and avoidance of conflicting backends. |
| Updates | `SOS_UpdateBase.sh` | REMOVE | Separates `pacman -Sy` and `-Su`, creating a partial-upgrade hazard, and mixes UI/AUR/system update concerns. Replace with transactional design. |
| Rollback/snapshots | no completed implementation found | UNKNOWN | Legacy docs mention ISO more than rollback. SpectrumOS2 must design Btrfs snapshot and boot recovery explicitly. |
| Package repository | no working signed repository found | UNKNOWN | Future channel design starts in architecture documentation, not copied code. |
| Installer/ISO | master installer and historical ISO notes | REMOVE/REFERENCE | Installer requirements are useful; implementation is unsafe. ISO work is deliberately deferred. |
| Branding/assets | SDDM visuals, Plymouth frames, test PNGs | REFERENCE | Review licenses, source files, quality, and naming. Root `test*.png` files and `test.conf` are abandoned clutter. |
| Neovim | full LazyVim-style personal config | REMOVE | This is application/user preference, not a minimal distro foundation. Development packages may include Neovim without taking ownership of its dotfiles. |
| Misc apps | Gromit, Cava, cmus, browsers, chat clients, editors | REFERENCE | Some workflows may become optional profiles; none belongs unconditionally in the base distro. |

## Cross-cutting problems

- Duplicate installers and commands (`install.sh`, `hypr_full.sh`, `dots.sh`) have conflicting package/config strategies.
- Many scripts directly kill/restart applications, edit files in place, or require sudo for user-facing theme changes.
- Mutable state is placed in `/var/lib/spectrumos` but made user-owned; `/etc/spectrumos` and `/usr/share/spectrumos` are also made user-writable.
- Several scripts assume Rofi, pywal cache layouts, exact filenames, and particular browsers/editors.
- Hardcoded `/home/...` patterns and generated substitutions appear in scripts/styles.
- The installer enables services and groups indiscriminately, including Docker and laptop power tools.
- Abandoned experiments include root test images/config, the second Hyprland installer, LightDM/Plymouth integration despite SDDM direction, and oversized Plymouth frame sequences.

## Migration recommendation

Start from contracts rather than files: define package ownership and configuration layering; build a minimal Hyprland session; specify a palette format and renderer interface; then migrate visual components one at a time with tests and fallbacks. Do not migrate bundled fonts, legacy updater, monolithic installers, or upstream systemd unit replacements.
