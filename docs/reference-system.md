# Current Arch Reference System

Audit date: 2026-08-30

This is an observational baseline, not the SpectrumOS2 package manifest. Package inventories distinguish explicitly installed native packages from dependencies and foreign packages. The inspection environment restricted some service/EFI access; those gaps are marked.

## Platform and storage

- OS: Arch Linux, x86_64.
- Running kernel: `linux-zen` 7.1.11; `linux-lts` 6.18.48 is also explicitly installed.
- CPU: AMD Ryzen 7 3700X, 12 logical CPUs visible to the inspection environment.
- Memory: 15 GiB.
- GPU: AMD Radeon RX 9060 XT (Navi 44), kernel driver `amdgpu`.
- Root: Btrfs on NVMe, compressed with zstd, with `@`, `@home`, `@log`, and `@pkg` subvolumes.
- ESP: 1 GiB VFAT at `/boot`.
- Swap: zstd-compressed zram sized to total RAM and capped at 8 GiB.
- Bootloader package: Limine 12.6.1. Kernel command line references Btrfs `subvol=@`, `quiet`, and `splash`. Direct ESP inspection was permission-restricted.
- Initramfs: mkinitcpio with the Plymouth hook before autodetect; Plymouth theme configured as `glow`.

## Explicitly installed official packages

The following were reported by `pacman -Qqen`; this is not a dependency tree:

```text
alacritty amd-ucode base base-devel btrfs-progs cava cups-pk-helper
dms-shell-niri dolphin dunst efibootmgr firefox git grim htop hyprland
intel-media-driver kimageformats kitty libva-intel-driver limine linux-firmware
linux-lts linux-zen matugen mesa mkinitcpio nano niri openssh plymouth
polkit-kde-agent qt5-wayland qt6-wayland sddm slurp smartmontools sudo
tuned-ppd uwsm vim vulkan-intel vulkan-nouveau vulkan-radeon wget wofi
xdg-desktop-portal-gnome xdg-desktop-portal-hyprland xdg-utils
xf86-video-amdgpu xf86-video-ati xf86-video-nouveau zram-generator
```

`pacman -Qqem` returned no explicitly installed foreign/AUR packages. Paru and yay are both absent.

## Session and desktop

- Hyprland 0.56.2 is the active Wayland session, apparently launched through UWSM.
- The user Hyprland configuration is an upstream-generated Lua example with Kitty, Dolphin, and `hyprlauncher` variables. It is not a SpectrumOS configuration.
- Niri and a DMS shell config are also present; treat them as experiments/reference-machine state, not distro defaults.
- SDDM 0.21 is installed and `/etc/systemd/system/display-manager.service` points to SDDM.
- Dunst, Kitty, Alacritty, Wofi, Grim, Slurp, Dolphin, and KDE polkit agent packages are present.
- No user systemd unit enablement symlinks were found.

## Core services and hardware support

- System enablement links show SDDM, systemd-networkd, systemd-resolved, systemd-timesyncd, and wait-online.
- NetworkManager is not explicitly installed; the reference host currently follows systemd-networkd rather than the legacy project's NetworkManager assumption.
- Bluetooth packages/service could not be confirmed from explicit packages or enablement links.
- PipeWire 1.6.8 is installed as a dependency; WirePlumber package state/runtime could not be conclusively captured in the restricted session and must be rechecked on the live host.
- `tuned-ppd` is installed; TLP is not explicitly installed.
- AMD microcode, Mesa, Vulkan Radeon, and Xorg AMD drivers are explicit. Intel and Nouveau packages are also explicit despite the active AMD GPU, suggesting prior broad hardware seeding rather than an intentional profile.

## Gaming and development

- Steam, GameMode, MangoHud, Gamescope, and paru executables are absent.
- Multilib is disabled in `/etc/pacman.conf`, so the intended 32-bit gaming stack cannot yet be installed from official repositories.
- Base-devel, Git, Vim, OpenSSH, Wget, and Nano are explicit.
- Docker, Podman, and libvirt tools are absent.
- Firefox is explicit; no personal browser state was inspected.

## Shell and private configuration

- Login shell: `/usr/bin/bash`.
- zsh is not installed according to the targeted package query.
- `~/.zshrc`, `~/.zprofile`, `~/.zshenv`, and `~/.zlogin` do not exist.
- `~/.oh-my-zsh` does not exist.
- `~/.ssh/config` does not exist. No SSH private key contents were inspected or recorded.
- Environment variable names indicate a normal UWSM/Hyprland Wayland session. Values that could be session- or machine-specific were not documented.

Because no work-specific shell or SSH layer exists, no migration was performed and current work behavior was left untouched. Empty private directories were created at `~/.config/spectrumos-personal/{zsh,aliases,work,ssh}` for future use; no file sources them yet.

## Gaps requiring live verification

- Exact enabled and running system/user services via an unrestricted `systemctl` session.
- PipeWire/WirePlumber runtime and portal backend selection.
- SDDM theme/session configuration and Plymouth-to-SDDM transition behavior.
- Network interface configuration and whether systemd-networkd is the intended SpectrumOS2 default.
- Bluetooth controller state, fonts, GTK/Qt settings, clipboard tooling, lock/idle setup, screenshots, and polkit agent startup.
- Limine entries and snapshot boot integration on the ESP.
