#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PHASES=(preflight packages system user theme validate reload)
SELECTED_PHASES=(all)
PROFILES=(base desktop)
APPLY=false
RELOAD_SESSION=true
SET_DEFAULT_SHELL=false
LEAN=false
CPU_PROFILE=""
GPU_PROFILE=""
FORM_FACTOR_PROFILE=""
LEGACY_HARDWARE_PROFILE=""
TARGET_USER=${SUDO_USER:-${USER}}
TARGET_HOME=""
OH_MY_ZSH_COMMIT=a5ecff7560b2e26f612032c632a12c75a3048bd0
ZSH_AUTOSUGGESTIONS_COMMIT=85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5
ZSH_SYNTAX_HIGHLIGHTING_COMMIT=2fc57d63067c18b1100ecdbf684fa5baf49459d1

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

Phased SpectrumOS2 installer for development and reference machines.
It prints a dry-run by default; pass --apply to make changes.

Options:
  --apply                    Perform changes (default: dry-run)
  --phase NAME[,NAME...]     Run selected phases or "all"
  --profile NAME[,NAME...]   Package profiles: base, desktop, development,
                             gaming, optional (default: base,desktop)
  --cpu NAME                 CPU profile: amd or intel
  --gpu NAME                 GPU profile: amd, intel, nvidia, nvidia-intel,
                             nvidia-amd, or vm
  --form-factor NAME         Power/device profile: laptop or desktop
  --hardware NAME            Compatibility alias for matching AMD/Intel CPU and GPU
  --target-user USER         User whose configuration is adopted
  --set-default-shell        Change the target user's login shell to zsh after validation
  --lean                     Skip optional background services and integrations
  --no-reload                Do not reload a running Hyprland session
  --list-phases              Print phases and exit
  -h, --help                 Show this help

Phases:
  preflight  Check the host, repository, profiles, and required tools
  packages   Fully update Arch, then install selected official and AUR packages
  system     Install package-owned defaults under /usr/share and /etc
  user       Replace managed Hyprland and Kitty configuration
  theme      Render and activate the default wallpaper palette
  validate   Validate files, dependencies, and the assembled config
  reload     Report whether Hyprland must be restarted

Examples:
  ./install.sh
  ./install.sh --apply --phase packages,system,user,theme,validate
  ./install.sh --apply --profile base,desktop,development --cpu amd --gpu amd --form-factor desktop
EOF
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

log() {
    printf '[spectrum] %s\n' "$*"
}

run() {
    printf '+ '
    printf '%q ' "$@"
    printf '\n'
    if [[ $APPLY == true ]]; then
        "$@"
    fi
}

run_as_target() {
    if [[ $(id -un) == "$TARGET_USER" ]]; then
        run "$@"
    else
        run sudo -u "$TARGET_USER" -- "$@"
    fi
}

install_pinned_git_tree() {
    local repository=$1
    local commit=$2
    local destination=$3
    if [[ -d $destination/.git ]]; then
        log "Preserving existing Git installation: $destination"
        return
    fi
    [[ ! -e $destination ]] || die "Cannot install Git source over existing path: $destination"
    run_as_target mkdir -p -- "$destination"
    run_as_target git -C "$destination" init
    run_as_target git -C "$destination" remote add origin "$repository"
    run_as_target git -C "$destination" fetch --depth 1 origin "$commit"
    run_as_target git -C "$destination" checkout --detach FETCH_HEAD
}

csv_to_array() {
    local value=$1
    local -n destination=$2
    IFS=',' read -r -a destination <<< "$value"
}

contains() {
    local wanted=$1
    shift
    local item
    for item in "$@"; do
        [[ $item == "$wanted" ]] && return 0
    done
    return 1
}

phase_enabled() {
    contains all "${SELECTED_PHASES[@]}" || contains "$1" "${SELECTED_PHASES[@]}"
}

validate_choices() {
    local item
    for item in "${SELECTED_PHASES[@]}"; do
        [[ $item == all ]] || contains "$item" "${PHASES[@]}" || die "Unknown phase: $item"
    done
    for item in "${PROFILES[@]}"; do
        [[ -f $PROJECT_ROOT/bootstrap/packages/$item.txt ]] || die "Unknown profile: $item"
    done
    [[ -z $CPU_PROFILE || $CPU_PROFILE == amd || $CPU_PROFILE == intel ]] || \
        die "CPU must be amd or intel"
    [[ -z $GPU_PROFILE || $GPU_PROFILE == amd || $GPU_PROFILE == intel || $GPU_PROFILE == nvidia || $GPU_PROFILE == nvidia-intel || $GPU_PROFILE == nvidia-amd || $GPU_PROFILE == vm ]] || \
        die "GPU must be amd, intel, nvidia, nvidia-intel, nvidia-amd, or vm"
    [[ -z $FORM_FACTOR_PROFILE || $FORM_FACTOR_PROFILE == laptop || $FORM_FACTOR_PROFILE == desktop ]] || \
        die "Form factor must be laptop or desktop"
    [[ -z $LEGACY_HARDWARE_PROFILE || $LEGACY_HARDWARE_PROFILE == amd || $LEGACY_HARDWARE_PROFILE == intel ]] || \
        die "Hardware compatibility alias must be amd or intel"
    if [[ -n $LEGACY_HARDWARE_PROFILE ]]; then
        [[ -z $CPU_PROFILE || $CPU_PROFILE == "$LEGACY_HARDWARE_PROFILE" ]] || \
            die "Hardware alias conflicts with CPU profile"
        [[ -z $GPU_PROFILE || $GPU_PROFILE == "$LEGACY_HARDWARE_PROFILE" ]] || \
            die "Hardware alias conflicts with GPU profile"
        CPU_PROFILE=$LEGACY_HARDWARE_PROFILE
        GPU_PROFILE=$LEGACY_HARDWARE_PROFILE
    fi
}

resolve_target() {
    getent passwd "$TARGET_USER" >/dev/null || die "User does not exist: $TARGET_USER"
    TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    [[ -n $TARGET_HOME && -d $TARGET_HOME ]] || die "Cannot resolve home for $TARGET_USER"
    [[ $TARGET_USER != root ]] || die "Refusing to install desktop configuration for root"
}

read_manifest() {
    local manifest=$1
    sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$manifest"
}

collect_packages() {
    local profile package
    local -a packages=()
    for profile in "${PROFILES[@]}"; do
        while IFS= read -r package; do
            [[ $package == paru ]] && continue
            [[ $FORM_FACTOR_PROFILE == laptop && $package == tuned ]] && continue
            packages+=("$package")
        done < <(read_manifest "$PROJECT_ROOT/bootstrap/packages/$profile.txt")
    done
    if [[ -n $CPU_PROFILE ]]; then
        while IFS= read -r package; do
            packages+=("$package")
        done < <(read_manifest "$PROJECT_ROOT/bootstrap/packages/cpu/$CPU_PROFILE.txt")
    fi
    if [[ -n $GPU_PROFILE ]]; then
        while IFS= read -r package; do
            packages+=("$package")
        done < <(read_manifest "$PROJECT_ROOT/bootstrap/packages/gpu/$GPU_PROFILE.txt")
    fi
    if [[ -n $FORM_FACTOR_PROFILE ]]; then
        while IFS= read -r package; do
            packages+=("$package")
        done < <(read_manifest "$PROJECT_ROOT/bootstrap/packages/form-factor/$FORM_FACTOR_PROFILE.txt")
    fi
    if [[ $LEAN == true ]]; then
        printf '%s\n' "${packages[@]}" | grep -vxFf "$PROJECT_ROOT/bootstrap/packages/desktop-lean-exclude.txt" | sort -u
    else
        printf '%s\n' "${packages[@]}" | sort -u
    fi
}

collect_aur_packages() {
    local profile package manifest
    local -a packages=()
    for profile in "${PROFILES[@]}"; do
        manifest=$PROJECT_ROOT/bootstrap/packages/$profile.aur.txt
        [[ -f $manifest ]] || continue
        while IFS= read -r package; do
            packages+=("$package")
        done < <(read_manifest "$manifest")
    done
    ((${#packages[@]} > 0)) && printf '%s\n' "${packages[@]}" | sort -u
}

check_multilib() {
    local -a packages=("$@")
    local package
    for package in "${packages[@]}"; do
        if [[ $package == lib32-* || $package == steam ]]; then
            pacman-conf --config="${SPECTRUM_PACMAN_CONFIG:-/etc/pacman.conf}" --repo-list 2>/dev/null | grep -qx multilib || \
                die "The selected profiles require multilib; enable it and run a full upgrade first"
            return
        fi
    done
}

phase_preflight() {
    log "Preflight"
    [[ -f /etc/arch-release ]] || die "This installer currently supports Arch Linux only"
    command -v pacman >/dev/null || die "pacman is required"
    command -v sudo >/dev/null || die "sudo is required"
    command -v python >/dev/null || die "python is required"
    [[ -f $PROJECT_ROOT/configs/hyprland/hyprland.lua ]] || die "Hyprland defaults are missing"
    resolve_target
    local -a packages=()
    local -a aur_packages=()
    mapfile -t packages < <(collect_packages)
    mapfile -t aur_packages < <(collect_aur_packages)
    check_multilib "${packages[@]}"
    if ((${#aur_packages[@]} > 0)) && [[ $APPLY == true ]]; then
        command -v paru >/dev/null || die "Selected profiles include AUR packages; install Paru before applying them"
    fi
    log "Target: $TARGET_USER ($TARGET_HOME)"
    log "Profiles: ${PROFILES[*]}${CPU_PROFILE:+; cpu=$CPU_PROFILE}${GPU_PROFILE:+; gpu=$GPU_PROFILE}${FORM_FACTOR_PROFILE:+; form-factor=$FORM_FACTOR_PROFILE}"
    log "Mode: $([[ $APPLY == true ]] && printf apply || printf dry-run)"
}

phase_packages() {
    log "Installing package profiles with a full synchronized upgrade"
    local -a packages=()
    local -a aur_packages=()
    mapfile -t packages < <(collect_packages)
    mapfile -t aur_packages < <(collect_aur_packages)
    check_multilib "${packages[@]}"
    if ((${#packages[@]} > 0)); then
        local -a pacman_args=(-Syu --needed --noconfirm)
        run sudo pacman "${pacman_args[@]}" "${packages[@]}"
    fi
    if ((${#aur_packages[@]} > 0)); then
        if [[ $APPLY == true ]]; then
            command -v paru >/dev/null || die "Selected profiles include AUR packages; install Paru before applying them"
        fi
        run_as_target paru -S --needed --noconfirm -- "${aur_packages[@]}"
    fi
}

install_hotkey_keyboard() {
    local hotkey_destination=${1:-/usr/lib/spectrumos/hotkey-keyboard}
    if [[ -x $hotkey_destination ]] && [[ $(pacman -Qqo -- "$hotkey_destination" 2>/dev/null) == spectrum-desktop ]]; then
        log "Using the package-owned HotKey keyboard helper"
        return
    fi
    if [[ $APPLY != true ]]; then
        log "Would build and install the HotKey keyboard helper at $hotkey_destination"
        return
    fi
    local hotkey_keyboard
    hotkey_keyboard=$(mktemp)
    if ! "$PROJECT_ROOT/integrations/hotkey/build" "$PROJECT_ROOT" "$hotkey_keyboard"; then
        rm -f -- "$hotkey_keyboard"
        die "Could not build the HotKey keyboard helper; check pkgconf, Wayland and xkbcommon build dependencies"
    fi
    run sudo install -m 0755 "$hotkey_keyboard" "$hotkey_destination"
    rm -f -- "$hotkey_keyboard"
}

phase_system() {
    run sudo "$PROJECT_ROOT/integrations/ukvm/install" "$PROJECT_ROOT" /
    log "Installing package-owned SpectrumOS2 defaults"
    if [[ $FORM_FACTOR_PROFILE == laptop ]]; then
        run sudo systemctl mask --now tuned.service
        run sudo systemctl unmask power-profiles-daemon.service
        run sudo systemctl enable --now power-profiles-daemon.service
    fi
    if [[ $GPU_PROFILE == vm ]]; then
        run sudo systemctl enable qemu-guest-agent.service
    fi
    if [[ $GPU_PROFILE == nvidia-intel || $GPU_PROFILE == nvidia-amd ]]; then
        run sudo systemctl enable --now switcheroo-control.service
    fi
    if [[ $GPU_PROFILE == nvidia || $GPU_PROFILE == nvidia-intel || $GPU_PROFILE == nvidia-amd ]]; then
        # NVreg_PreserveVideoMemoryAllocations=1 plus the nvidia-suspend/resume/
        # hibernate services (shipped by nvidia-utils but not enabled by
        # default) are what keep a laptop's dGPU state intact across suspend --
        # without them, resuming with the nvidia driver active is a well-known
        # source of hangs or a corrupted GPU state.
        run sudo install -m 0644 "$PROJECT_ROOT/system/modprobe.d/spectrumos-nvidia-power.conf" \
            /etc/modprobe.d/spectrumos-nvidia-power.conf
        run sudo systemctl enable nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service
        run sudo install -d -m 0755 /usr/lib/spectrumos
        run sudo install -m 0755 "$PROJECT_ROOT/scripts/nvidia-offload" /usr/lib/spectrumos/nvidia-offload
    fi
    if [[ $GPU_PROFILE == nvidia ]]; then
        run sudo install -d -m 0755 /etc/spectrumos/hyprland
        run sudo install -m 0644 "$PROJECT_ROOT/configs/hyprland/gpu/nvidia.lua" /etc/spectrumos/hyprland/gpu.lua
    elif [[ $GPU_PROFILE == nvidia-intel || $GPU_PROFILE == nvidia-amd ]]; then
        run sudo install -d -m 0755 /etc/spectrumos/hyprland
        run sudo install -m 0644 "$PROJECT_ROOT/configs/hyprland/gpu/hybrid-nvidia.lua" /etc/spectrumos/hyprland/gpu.lua
    fi
    run sudo install -d -m 0755 /usr/share/spectrumos/hyprland \
        /usr/share/spectrumos/shell \
        /usr/share/spectrumos/spectrum-shell \
        /usr/share/spectrumos/terminal /usr/share/spectrumos/environment /usr/share/spectrumos/zsh/themes /usr/share/spectrumos/nvim \
        /usr/share/spectrumos/migrations \
        /usr/share/spectrumos/theme-engine/spectrum_theme/palettes \
        /usr/share/backgrounds/spectrumos \
        /usr/share/sddm/themes/spectrumos /usr/share/plymouth/themes/spectrumos \
        /usr/lib/spectrumos /usr/lib/systemd/system /usr/lib/systemd/user \
        /usr/lib/systemd/zram-generator.conf.d \
        /usr/lib/initcpio/install /usr/lib/initcpio/hooks /usr/lib/sysusers.d /usr/lib/tmpfiles.d \
        /usr/share/libalpm/hooks \
        /etc/spectrumos/hyprland /etc/NetworkManager/conf.d /etc/samba /etc/xdg \
        /etc/flatpak/remotes.d
    run sudo install -d -m 0755 /usr/share/spectrumos/branding
    run sudo install -m 0644 "$PROJECT_ROOT/assets/branding/spectrum-wordmark.svg" /usr/share/spectrumos/branding/spectrum-wordmark.svg
    local source
    run sudo install -m 0644 "$PROJECT_ROOT"/configs/terminal/* /usr/share/spectrumos/terminal/
    run sudo install -Dm644 "$PROJECT_ROOT/configs/terminal/kitty-user.conf" /etc/skel/.config/kitty/kitty.conf
    run sudo install -Dm644 "$PROJECT_ROOT/configs/terminal/alacritty-user.toml" /etc/skel/.config/alacritty/alacritty.toml
    for source in "$PROJECT_ROOT"/configs/hyprland/*.lua "$PROJECT_ROOT"/configs/hyprland/hypridle.conf; do
        run sudo install -m 0644 "$source" "/usr/share/spectrumos/hyprland/$(basename "$source")"
    done
    for source in "$PROJECT_ROOT"/configs/spectrum-shell/*.qml "$PROJECT_ROOT"/configs/spectrum-shell/*.js; do
        run sudo install -m 0644 "$source" "/usr/share/spectrumos/spectrum-shell/$(basename "$source")"
    done
    run sudo install -d -m 0755 /usr/share/spectrumos/spectrum-shell/igor
    for source in "$PROJECT_ROOT"/configs/spectrum-shell/igor/*.svg; do
        run sudo install -m 0644 "$source" "/usr/share/spectrumos/spectrum-shell/igor/$(basename "$source")"
    done
    run sudo install -Dm 0644 "$PROJECT_ROOT/system/polkit/org.spectrumos.time-region.policy" \
        /usr/share/polkit-1/actions/org.spectrumos.time-region.policy
    run sudo install -m 0644 "$PROJECT_ROOT/configs/xdg/mimeapps.list" /etc/xdg/mimeapps.list
    run sudo install -m 0644 "$PROJECT_ROOT/system/flatpak-flathub.flatpakrepo" \
        /etc/flatpak/remotes.d/flathub.flatpakrepo
    run sudo install -m 0644 "$PROJECT_ROOT/configs/networkmanager/20-spectrumos.conf" \
        /etc/NetworkManager/conf.d/20-spectrumos.conf
    run sudo install -m 0644 "$PROJECT_ROOT/system/zram-generator.conf.d/60-spectrumos.conf" \
        /usr/lib/systemd/zram-generator.conf.d/60-spectrumos.conf
    if [[ ! -e /etc/samba/smb.conf ]]; then
        run sudo install -m 0644 "$PROJECT_ROOT/configs/samba/smb.conf" /etc/samba/smb.conf
    else
        log "Preserving existing /etc/samba/smb.conf"
    fi
    run sudo install -m 0644 "$PROJECT_ROOT/system/sysusers.d/spectrumos-sharing.conf" \
        /usr/lib/sysusers.d/spectrumos-sharing.conf
    run sudo install -m 0644 "$PROJECT_ROOT/system/tmpfiles.d/spectrumos-sharing.conf" \
        /usr/lib/tmpfiles.d/spectrumos-sharing.conf
    run sudo systemd-sysusers /usr/lib/sysusers.d/spectrumos-sharing.conf
    run sudo systemd-tmpfiles --create /usr/lib/tmpfiles.d/spectrumos-sharing.conf
    run sudo systemctl enable --now systemd-resolved.service
    # NetworkManager-wait-online.service blocks network-online.target (and
    # anything ordered after it) for up to its NM_ONLINE_TIMEOUT=60s default
    # if no connection is up yet -- confirmed live as a "graphical.target is
    # queued for start, waiting for 60s..." boot stall on the installer's own
    # live medium with no network configured yet. A normal desktop shouldn't
    # block reaching a session on confirmed connectivity; mask it so boots
    # stay fast regardless of network state, the same fix applied to the live
    # ISO profile itself (iso/spectrumos/airootfs/etc/systemd/system/
    # NetworkManager-wait-online.service, masked to /dev/null there).
    run sudo systemctl mask NetworkManager-wait-online.service
    # arch-chroot bind-mounts /run (and /etc/resolv.conf itself, for DNS while
    # chrooted) from the live medium into the target, and the live medium's own
    # systemd-resolved already manages /etc/resolv.conf this exact way -- so
    # inside an arch-chroot install, both paths can already resolve to the
    # identical underlying file. `ln -sfn` refuses that even with -f ("are the
    # same file", a deliberate GNU coreutils safety check against removing a
    # file out from under its own source), which previously aborted the whole
    # install here under set -e even though the desired end state -- resolv.conf
    # correctly pointing at the stub -- was already achieved.
    #
    # A `readlink -f` text comparison of the two paths is NOT the same check:
    # it only follows symlinks, and arch-chroot's bind mount of /etc/resolv.conf
    # turns it into a plain regular file inside the chroot (bind-mounting a
    # path that is itself a symlink bind-mounts its resolved target), not a
    # symlink -- so `readlink -f /etc/resolv.conf` just returns "/etc/resolv.conf"
    # unchanged and never discovers it's the same underlying file as the stub.
    # Confirmed live: the guard's `readlink -f` strings compared unequal, `ln`
    # ran anyway, and failed with the exact "are the same file" it was meant to
    # avoid. `stat`'s device:inode pair is what `ln` itself actually checks, so
    # comparing that instead catches both a symlink chain and a bind mount.
    if [[ $(stat -c '%d:%i' /run/systemd/resolve/stub-resolv.conf 2>/dev/null) != "$(stat -c '%d:%i' /etc/resolv.conf 2>/dev/null)" ]]; then
        run sudo ln -sfn /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    else
        log "/etc/resolv.conf already points at the systemd-resolved stub"
    fi
    run sudo install -m 0644 "$PROJECT_ROOT/configs/environment/90-spectrumos-qt.conf" \
        /usr/share/spectrumos/environment/90-spectrumos-qt.conf
    run sudo install -m 0644 "$PROJECT_ROOT/system/spectrumos/font-families.conf" \
        /usr/share/spectrumos/font-families.conf
    for source in "$PROJECT_ROOT"/assets/wallpapers/default/*.png; do
        run sudo install -m 0644 "$source" "/usr/share/backgrounds/spectrumos/$(basename "$source")"
    done
    for source in $(find "$PROJECT_ROOT/configs/sddm/themes/spectrumos" -type f | sort); do
        local relative=${source#"$PROJECT_ROOT/configs/sddm/themes/spectrumos/"}
        run sudo install -d -m 0755 "/usr/share/sddm/themes/spectrumos/$(dirname "$relative")"
        run sudo install -m 0644 "$source" "/usr/share/sddm/themes/spectrumos/$relative"
    done
    for source in $(find "$PROJECT_ROOT/configs/plymouth/themes/spectrumos" -type f | sort); do
        local relative=${source#"$PROJECT_ROOT/configs/plymouth/themes/spectrumos/"}
        run sudo install -m 0644 "$source" "/usr/share/plymouth/themes/spectrumos/$relative"
    done
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/plymouth-boot-sync" /usr/lib/spectrumos/plymouth-boot-sync
    run sudo plymouth-set-default-theme spectrumos
    local plymouth_flags=()
    if [[ $GPU_PROFILE == nvidia || $GPU_PROFILE == nvidia-intel || $GPU_PROFILE == nvidia-amd ]]; then
        plymouth_flags+=(--nvidia)
    fi
    run sudo /usr/lib/spectrumos/plymouth-boot-sync "${plymouth_flags[@]}"
    run sudo python "$PROJECT_ROOT/scripts/uki-branding-sync"
    run sudo mkinitcpio -P
    run sudo install -m 0644 "$PROJECT_ROOT/configs/sddm/zz-spectrumos.conf" /etc/sddm.conf
    run sudo install -m 0644 "$PROJECT_ROOT/configs/zsh/defaults.zsh" \
        /usr/share/spectrumos/zsh/defaults.zsh
    run sudo install -Dm 0644 "$PROJECT_ROOT/configs/fastfetch/config.jsonc" \
        /etc/xdg/fastfetch/config.jsonc
    run sudo install -m 0644 "$PROJECT_ROOT/configs/zsh/themes/spectrum.zsh-theme" \
        /usr/share/spectrumos/zsh/themes/spectrum.zsh-theme
    for source in $(find "$PROJECT_ROOT/configs/nvim" -type f | sort); do
        local relative=${source#"$PROJECT_ROOT/configs/nvim/"}
        run sudo install -d -m 0755 "/usr/share/spectrumos/nvim/$(dirname "$relative")"
        run sudo install -m 0644 "$source" "/usr/share/spectrumos/nvim/$relative"
    done
    run sudo systemctl enable bluetooth.service
    if [[ $LEAN == false ]]; then
        run sudo systemctl enable --now cups.socket
        run sudo systemctl enable --now cups-browsed.service
        run sudo systemctl enable --now avahi-daemon.service
        if [[ $FORM_FACTOR_PROFILE != laptop ]]; then
            run sudo systemctl unmask tuned.service
            run sudo systemctl enable tuned.service
        fi
    fi
    run sudo systemctl enable sddm.service
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/volume" /usr/lib/spectrumos/volume
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/brightness" /usr/lib/spectrumos/brightness
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/theme-menu" /usr/lib/spectrumos/theme-menu
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/wallpaper-restore" /usr/lib/spectrumos/wallpaper-restore
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/waybar-menu" /usr/lib/spectrumos/waybar-menu
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/panel" /usr/lib/spectrumos/panel
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/hyprland-menu" /usr/lib/spectrumos/hyprland-menu
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/font-size-menu" /usr/lib/spectrumos/font-size-menu
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/network-menu" /usr/lib/spectrumos/network-menu
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/bluetooth-menu" /usr/lib/spectrumos/bluetooth-menu
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/recorder-menu" /usr/lib/spectrumos/recorder-menu
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/display-menu" /usr/lib/spectrumos/display-menu
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/weather-adapter" /usr/lib/spectrumos/weather-adapter
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/idle-adapter" /usr/lib/spectrumos/idle-adapter
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/screensaver-adapter" /usr/lib/spectrumos/screensaver-adapter
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/appearance-sync" /usr/lib/spectrumos/appearance-sync
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/appearance-stage" /usr/lib/spectrumos/appearance-stage
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/limine-appearance-sync" /usr/lib/spectrumos/limine-appearance-sync
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/uki-branding-sync" /usr/lib/spectrumos/uki-branding-sync
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/pipewire-restart" /usr/lib/spectrumos/pipewire-restart
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/snapshot" /usr/bin/spectrum-snapshot
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/spectrum" /usr/bin/spectrum
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/hyprland-update-guard" /usr/lib/spectrumos/hyprland-update-guard
    for source in "$PROJECT_ROOT"/system/pacman-hooks/{10-spectrumos-hyprland-pause,99-spectrumos-hyprland-resume}.hook; do
        run sudo install -m 0644 "$source" /usr/share/libalpm/hooks/
    done
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/pre-upgrade-snapshot" /usr/lib/spectrumos/pre-upgrade-snapshot
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/limine-recovery-entry" /usr/lib/spectrumos/limine-recovery-entry
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/mkinitcpio-register-hook" /usr/lib/spectrumos/mkinitcpio-register-hook
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/spectrumos-build-rescue-image" /usr/lib/spectrumos/spectrumos-build-rescue-image
    run sudo install -m 0644 "$PROJECT_ROOT/system/release/release.toml" /usr/share/spectrumos/release.toml
    run sudo install -m 0644 "$PROJECT_ROOT/migrations/manifest.toml" /usr/share/spectrumos/migrations/manifest.toml
    run sudo install -m 0644 "$PROJECT_ROOT/system/initcpio/install/spectrumos-restore" \
        /usr/lib/initcpio/install/spectrumos-restore
    run sudo install -m 0644 "$PROJECT_ROOT/system/initcpio/hooks/spectrumos-restore" \
        /usr/lib/initcpio/hooks/spectrumos-restore
    run sudo install -m 0644 "$PROJECT_ROOT/system/pacman-hooks/05-spectrumos-pre-upgrade-snapshot.hook" \
        /usr/share/libalpm/hooks/05-spectrumos-pre-upgrade-snapshot.hook
    run sudo install -m 0644 "$PROJECT_ROOT/system/pacman-hooks/95-spectrumos-uki-branding.hook" \
        /usr/share/libalpm/hooks/95-spectrumos-uki-branding.hook
    run sudo install -m 0644 "$PROJECT_ROOT/system/pacman-hooks/60-spectrumos-pipewire-restart.hook" \
        /usr/share/libalpm/hooks/60-spectrumos-pipewire-restart.hook
    run sudo install -m 0644 "$PROJECT_ROOT/system/sysusers.d/spectrumos.conf" /usr/lib/sysusers.d/spectrumos.conf
    run sudo install -m 0644 "$PROJECT_ROOT/system/tmpfiles.d/spectrumos-appearance.conf" /usr/lib/tmpfiles.d/spectrumos-appearance.conf
    run sudo install -m 0644 "$PROJECT_ROOT/system/systemd/system/spectrumos-limine-appearance.path" \
        /usr/lib/systemd/system/spectrumos-limine-appearance.path
    run sudo install -m 0644 "$PROJECT_ROOT/system/systemd/system/spectrumos-limine-appearance.service" \
        /usr/lib/systemd/system/spectrumos-limine-appearance.service
    run sudo systemd-sysusers /usr/lib/sysusers.d/spectrumos.conf
    run sudo systemd-tmpfiles --create /usr/lib/tmpfiles.d/spectrumos-appearance.conf
    run sudo systemctl enable spectrumos-limine-appearance.path
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/waybar-widgets" /usr/lib/spectrumos/waybar-widgets
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/waybar-cava" /usr/lib/spectrumos/waybar-cava
    run sudo install -m 0755 "$PROJECT_ROOT/scripts/spectrum-shell-picker" /usr/lib/spectrumos/spectrum-shell-picker
    run sudo install -Dm0644 "$PROJECT_ROOT/system/modules-load.d/spectrumos-ddc.conf" /usr/lib/modules-load.d/spectrumos-ddc.conf
    install_hotkey_keyboard
    local desktop_script
    for desktop_script in \
        application-menu calculator-menu keyboard-layout spectrum-browser-defaults \
        font-family-menu performance-mode resource-monitor session-menu spectrum-update-run window-pin-toggle spectrum-shell spectrum-shell-launcher spectrum-shell-open spectrum-shell-session spectrum-shell-layout spectrum-gaming-session \
        waybar-workspace-icons \
        spectrumdrop-adapter hotkey-adapter network-adapter system-adapter brightness-adapter control-adapter theme-adapter time-region-adapter mouse-adapter audio-recorder \
        application-adapter appimage-adapter media-adapter media-control workspace-layout spectrum-shell-tools thunar-actions spectrum-desktop-cleanup spectrum-terminal-config spectrum-user-avatar questline-adapter questline-open questline-action stash-open spectrum-focus; do
        run sudo install -m 0755 "$PROJECT_ROOT/scripts/$desktop_script" "/usr/lib/spectrumos/$desktop_script"
    done
    run sudo install -m 0644 "$PROJECT_ROOT/system/pacman-hooks/90-spectrumos-desktop-cleanup.hook" \
        /usr/share/libalpm/hooks/90-spectrumos-desktop-cleanup.hook
    run sudo install -m 0644 "$PROJECT_ROOT/system/pacman-hooks/91-spectrumos-browser-defaults.hook" \
        /usr/share/libalpm/hooks/91-spectrumos-browser-defaults.hook
    run sudo /usr/lib/spectrumos/spectrum-browser-defaults
    run sudo install -Dm 0644 "$PROJECT_ROOT/integrations/omdrop/spectrumdrop.desktop" /usr/share/applications/spectrumdrop.desktop
    run sudo install -Dm 0644 "$PROJECT_ROOT/system/spectrum-appimages.desktop" /usr/share/applications/spectrum-appimages.desktop
    run sudo install -Dm 0644 "$PROJECT_ROOT/integrations/stash/stash.desktop" /usr/share/applications/stash.desktop
    run sudo install -Dm 0644 "$PROJECT_ROOT/system/autostart/spectrum-kdeconnect-indicator.desktop" /etc/xdg/autostart/spectrum-kdeconnect-indicator.desktop
    run sudo install -m 0755 "$PROJECT_ROOT/integrations/questline/spectrum-focus" /usr/lib/spectrumos/questline-focus
    local user_service
    for user_service in spectrum-hotkey.service spectrum-resource-monitor.service spectrum-shell.service spectrum-workspace-layout.service; do
        run sudo install -m 0644 "$PROJECT_ROOT/system/systemd/user/$user_service" "/usr/lib/systemd/user/$user_service"
    done
    for source in "$PROJECT_ROOT"/packages/spectrum-theme/src/spectrum_theme/*.py; do
        run sudo install -m 0644 "$source" "/usr/share/spectrumos/theme-engine/spectrum_theme/$(basename "$source")"
    done
    for source in "$PROJECT_ROOT"/packages/spectrum-theme/src/spectrum_theme/palettes/*.toml; do
        run sudo install -m 0644 \
            "$source" "/usr/share/spectrumos/theme-engine/spectrum_theme/palettes/$(basename "$source")"
    done
    if [[ ! -e /etc/spectrumos/hyprland/machine.lua ]]; then
        run sudo install -m 0644 /dev/null /etc/spectrumos/hyprland/machine.lua
    else
        log "Preserving existing /etc/spectrumos/hyprland/machine.lua"
    fi
}

phase_user() {
    log "Adopting user configuration"
    resolve_target
    run sudo /usr/lib/spectrumos/spectrum-desktop-cleanup
    run sudo usermod -aG spectrumos "$TARGET_USER"
    if [[ $LEAN == false ]]; then
        run sudo usermod -aG sambashare "$TARGET_USER"
    fi
    if [[ $APPLY == true && ! -f /usr/share/spectrumos/hyprland/hyprland.lua ]]; then
        die "System defaults are not installed; run the system phase first"
    fi
    local hypr_dir="$TARGET_HOME/.config/hypr"
    local spectrum_dir="$TARGET_HOME/.config/spectrumos"
    local kitty_dir="$TARGET_HOME/.config/kitty"
    local alacritty_dir="$TARGET_HOME/.config/alacritty"
    local nvim_dir="$TARGET_HOME/.config/nvim"
    local transmission_dir="$TARGET_HOME/.config/transmission"
    local transmission_download_dir="$TARGET_HOME/Downloads"
    local transmission_override_dir=/etc/systemd/system/transmission-daemon.service.d
    local transmission_override="$transmission_override_dir/10-spectrumos-download-dir.conf"
    local projects_dir="$TARGET_HOME/Projects"
    local environment_dir="$TARGET_HOME/.config/environment.d"
    local wallpaper_dir="$TARGET_HOME/Pictures/Wallpapers"
    local personal_dir="$TARGET_HOME/.config/spectrumos-personal"
    local vlc_dir="$TARGET_HOME/.config/vlc"
    run_as_target /usr/lib/spectrumos/thunar-actions sync
    run_as_target xdg-user-dirs-update
    run_as_target /usr/lib/spectrumos/spectrum-user-avatar \
        /usr/share/spectrumos/spectrum-shell/igor/face.svg "$TARGET_HOME/$TARGET_USER.png"
    run_as_target mkdir -p -- "$projects_dir" "$hypr_dir" "$spectrum_dir" "$kitty_dir" "$alacritty_dir" "$environment_dir" "$wallpaper_dir" "$vlc_dir" "$transmission_download_dir"
    if [[ $LEAN == false ]]; then
        run_as_target mkdir -p -- "$transmission_dir"
    if [[ ! -e $transmission_dir/settings.json ]]; then
        if [[ $APPLY == true ]]; then
            printf '{\n    "download-dir": "%s"\n}\n' "$transmission_download_dir" | \
                sudo -u "$TARGET_USER" tee "$transmission_dir/settings.json" >/dev/null
        else
            printf '+ configure Transmission downloads in %q\n' "$transmission_dir/settings.json"
        fi
    else
        log "Preserving existing Transmission settings: $transmission_dir/settings.json"
    fi
    run sudo setfacl -m "u:transmission:--x" "$TARGET_HOME"
    run sudo setfacl -m "u:transmission:rwx,d:u:transmission:rwx,d:u:$TARGET_USER:rwx" "$transmission_download_dir"
    run sudo find "$transmission_download_dir" -xdev -user transmission -type d \
        -exec setfacl -m "u:$TARGET_USER:rwx,d:u:$TARGET_USER:rwx,d:u:transmission:rwx" {} +
    run sudo find "$transmission_download_dir" -xdev -user transmission -type f \
        -exec setfacl -m "u:$TARGET_USER:rw" {} +
    run sudo install -d -m 0755 "$transmission_override_dir"
    if [[ $APPLY == true ]]; then
        local escaped_transmission_home=${TARGET_HOME//%/%%}
        local escaped_transmission_download_dir=${transmission_download_dir//%/%%}
        escaped_transmission_home=${escaped_transmission_home//\\/\\\\}
        escaped_transmission_home=${escaped_transmission_home//\"/\\\"}
        escaped_transmission_download_dir=${escaped_transmission_download_dir//\\/\\\\}
        escaped_transmission_download_dir=${escaped_transmission_download_dir//\"/\\\"}
        printf '[Service]\nExecStart=\nExecStart=/usr/bin/transmission-daemon -f --log-level=error -w "%s"\nExecStartPre=+/usr/bin/setfacl -m "u:transmission:--x" "%s"\nExecStartPre=+/usr/bin/setfacl -m "u:transmission:rwx,d:u:transmission:rwx,d:u:%s:rwx" "%s"\n' \
            "$escaped_transmission_download_dir" "$escaped_transmission_home" "$TARGET_USER" "$escaped_transmission_download_dir" | \
            sudo tee "$transmission_override" >/dev/null
    else
        printf '+ configure persistent Transmission service override in %q\n' "$transmission_override"
    fi
    run sudo install -m 0644 "$PROJECT_ROOT/system/systemd/system/transmission-daemon.service.d/20-spectrumos-start-timeout.conf" \
        "$transmission_override_dir/20-spectrumos-start-timeout.conf"
    run sudo systemctl daemon-reload
    run sudo systemctl enable --now transmission-daemon.service
    # Best-effort only: settings.json above already carries the right
    # download-dir for the daemon's first real boot, and this is purely a
    # redundant nudge to a transmission-daemon that might already be running
    # (the retrofit-onto-an-existing-system case this file was originally
    # written for). Inside spectrum-installer-backend's from-scratch
    # pacstrap install, phase_system/user/theme all run under a plain
    # arch-chroot with no init of any kind actually running, so `--now`
    # above can never really start the daemon there -- this RPC client call
    # would fail to connect and, unguarded under `set -e`, take the whole
    # installation down with it for something purely cosmetic.
    run transmission-remote --download-dir "$transmission_download_dir" || true
    fi
    run_as_target mkdir -p -- "$personal_dir/aliases" "$personal_dir/zsh" "$personal_dir/work" "$personal_dir/ssh"
    local wallpaper_number system_wallpaper target_wallpaper
    for wallpaper_number in {1..30}; do
        system_wallpaper="/usr/share/backgrounds/spectrumos/S$wallpaper_number.png"
        target_wallpaper="$wallpaper_dir/S$wallpaper_number.png"
        if [[ ! -e $target_wallpaper ]]; then
            run_as_target install -m 0644 "$system_wallpaper" "$target_wallpaper"
        else
            log "Preserving existing wallpaper: $target_wallpaper"
        fi
    done

    local oh_my_zsh_dir="$TARGET_HOME/.oh-my-zsh"
    install_pinned_git_tree https://github.com/ohmyzsh/ohmyzsh.git \
        "$OH_MY_ZSH_COMMIT" "$oh_my_zsh_dir"
    install_pinned_git_tree https://github.com/zsh-users/zsh-autosuggestions.git \
        "$ZSH_AUTOSUGGESTIONS_COMMIT" "$oh_my_zsh_dir/custom/plugins/zsh-autosuggestions"
    install_pinned_git_tree https://github.com/zsh-users/zsh-syntax-highlighting.git \
        "$ZSH_SYNTAX_HIGHLIGHTING_COMMIT" "$oh_my_zsh_dir/custom/plugins/zsh-syntax-highlighting"

    local zshrc="$TARGET_HOME/.zshrc"
    if [[ ! -e $zshrc ]]; then
        run_as_target install -m 0644 "$PROJECT_ROOT/configs/zsh/zshrc" "$zshrc"
    elif cmp -s "$PROJECT_ROOT/configs/zsh/zshrc" "$zshrc"; then
        log "Spectrum zsh entrypoint is already current"
    else
        log "Preserving existing zsh entrypoint: $zshrc"
    fi

    run_as_target rm -f -- "$hypr_dir/hyprland.lua" "$hypr_dir/hyprland.conf"
    run_as_target install -m 0644 /usr/share/spectrumos/hyprland/hyprland.lua "$hypr_dir/hyprland.lua"
    run_as_target install -m 0644 /usr/share/spectrumos/environment/90-spectrumos-qt.conf \
        "$environment_dir/90-spectrumos-qt.conf"
    if [[ $APPLY == true ]]; then
        printf 'HYPRLAND_CONFIG=%s\n' "$hypr_dir/hyprland.lua" | \
            sudo -u "$TARGET_USER" tee "$environment_dir/90-spectrumos-hyprland.conf" >/dev/null
    else
        printf '+ write HYPRLAND_CONFIG=%q to %q\n' \
            "$hypr_dir/hyprland.lua" "$environment_dir/90-spectrumos-hyprland.conf"
    fi

    if [[ ! -e $spectrum_dir/hyprland.lua ]]; then
        run_as_target install -m 0644 /dev/null "$spectrum_dir/hyprland.lua"
    else
        log "Preserving existing user override: $spectrum_dir/hyprland.lua"
    fi

    run_as_target /usr/lib/spectrumos/spectrum-terminal-config --home "$TARGET_HOME"
    if [[ ! -e $nvim_dir ]]; then
        run_as_target mkdir -p -- "$nvim_dir"
        run_as_target cp -a /usr/share/spectrumos/nvim/. "$nvim_dir/"
    else
        log "Preserving existing Neovim configuration: $nvim_dir"
    fi
    if [[ ! -e $vlc_dir/vlcrc ]]; then
        run_as_target install -m 0644 "$PROJECT_ROOT/configs/vlc/vlcrc" "$vlc_dir/vlcrc"
    else
        log "Preserving existing VLC configuration: $vlc_dir/vlcrc"
    fi
}

phase_theme() {
    log "Rendering the semantic theme from the SpectrumOS default wallpaper"
    resolve_target
    local wallpaper="$TARGET_HOME/Pictures/Wallpapers/S30.png"
    local palette="$TARGET_HOME/.cache/spectrumos/default-wallpaper.toml"
    local state_dir="$TARGET_HOME/.local/state/spectrumos/theme"
    run_as_target mkdir -p -- "$TARGET_HOME/.cache/spectrumos" "$state_dir"
    run_as_target env \
        "PYTHONPATH=$PROJECT_ROOT/packages/spectrum-theme/src" \
        python -m spectrum_theme.cli extract native "$wallpaper" --mode clustered --variant dark --output "$palette"
    run_as_target env \
        "PYTHONPATH=$PROJECT_ROOT/packages/spectrum-theme/src" \
        python -m spectrum_theme.cli render --strict --palette "$palette" --wallpaper "$wallpaper"
    run_as_target /usr/lib/spectrumos/appearance-sync --apply
    run_as_target /usr/lib/spectrumos/appearance-stage "$wallpaper"
    if [[ $APPLY == true ]]; then
        printf '%s\n' "$wallpaper" | sudo -u "$TARGET_USER" tee "$state_dir/last-wallpaper" "$state_dir/last-rendered-wallpaper" >/dev/null
    else
        printf '+ remember default wallpaper %q in %q\n' "$wallpaper" "$state_dir"
    fi
}

phase_validate() {
    log "Validating repository and installed configuration"
    resolve_target
    run python "$PROJECT_ROOT/scripts/validate-hyprland.py"
    run python -m unittest discover -s "$PROJECT_ROOT/tests" -v
    run env "PYTHONPATH=$PROJECT_ROOT/packages/spectrum-theme/src" \
        python -m unittest discover -s "$PROJECT_ROOT/packages/spectrum-theme/tests" -v
    if [[ $APPLY == true ]]; then
        [[ -f $TARGET_HOME/.config/hypr/hyprland.lua && ! -L $TARGET_HOME/.config/hypr/hyprland.lua ]] || \
            die "User Hyprland entrypoint is not a regular file"
        cmp -s /usr/share/spectrumos/hyprland/hyprland.lua \
            "$TARGET_HOME/.config/hypr/hyprland.lua" || die "User Hyprland entrypoint differs from system defaults"
        [[ -e $TARGET_HOME/.cache/spectrumos/theme/current/hyprland.lua ]] || die "Active theme is missing"
        local executable
        for executable in Hyprland uwsm alacritty kitty nvim thunar swayimg qs hyprlock notify-send wpctl playerctl brightnessctl ffmpeg awww kvantummanager bluetoothctl wf-recorder; do
            command -v "$executable" >/dev/null || die "Required executable is missing: $executable"
        done
        [[ -r $TARGET_HOME/.config/nvim/init.lua ]] || die "Neovim configuration is missing"
        [[ -r $TARGET_HOME/.cache/spectrumos/theme/current/colors/spectrum.lua ]] || \
            die "Generated Neovim theme is missing"
        command -v zsh >/dev/null || die "Required executable is missing: zsh"
        [[ -r $TARGET_HOME/.oh-my-zsh/oh-my-zsh.sh ]] || die "Oh My Zsh is missing"
        [[ -r $TARGET_HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh ]] || \
            die "Oh My Zsh autosuggestions plugin is missing"
        [[ -r $TARGET_HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh ]] || \
            die "Oh My Zsh syntax-highlighting plugin is missing"
        zsh -n /usr/share/spectrumos/zsh/defaults.zsh \
            /usr/share/spectrumos/zsh/themes/spectrum.zsh-theme "$TARGET_HOME/.zshrc" || \
            die "Zsh configuration failed syntax validation"
        local continuity_command
        for continuity_command in git ssh sudo pacman; do
            sudo -u "$TARGET_USER" -- zsh -lic "command -v $continuity_command >/dev/null" || \
                die "Zsh command continuity failed: $continuity_command"
        done
        if [[ $SET_DEFAULT_SHELL == true ]]; then
            grep -Fxq /usr/bin/zsh /etc/shells || die "/usr/bin/zsh is not listed in /etc/shells"
            run sudo usermod --shell /usr/bin/zsh "$TARGET_USER"
        fi
        [[ -x /usr/lib/spectrumos/volume ]] || die "Spectrum volume control is missing"
        [[ -x /usr/lib/spectrumos/brightness ]] || die "Spectrum brightness control is missing"
        [[ -x /usr/lib/spectrumos/theme-menu ]] || die "Spectrum theme menu is missing"
        [[ -x /usr/lib/spectrumos/wallpaper-restore ]] || die "Spectrum wallpaper restorer is missing"
        [[ -r /usr/share/backgrounds/spectrumos/S30.png ]] || die "Spectrum default wallpaper is missing"
        [[ -x /usr/lib/spectrumos/spectrum-shell-picker ]] || die "SpectrumShell picker is missing"
        [[ -x /usr/lib/spectrumos/panel ]] || die "Spectrum panel is missing"
        [[ -x /usr/lib/spectrumos/hyprland-menu ]] || die "Spectrum Hyprland menu is missing"
        [[ -x /usr/lib/spectrumos/font-size-menu ]] || die "Spectrum font size menu is missing"
        [[ -x /usr/lib/spectrumos/network-menu ]] || die "Spectrum network menu is missing"
        [[ -x /usr/lib/spectrumos/bluetooth-menu ]] || die "Spectrum Bluetooth menu is missing"
        [[ -x /usr/lib/spectrumos/recorder-menu ]] || die "Spectrum recorder menu is missing"
        [[ -x /usr/lib/spectrumos/display-menu ]] || die "Spectrum display menu is missing"
        [[ -x /usr/lib/spectrumos/weather-adapter ]] || die "Spectrum weather adapter is missing"
        [[ -x /usr/lib/spectrumos/idle-adapter ]] || die "Spectrum idle adapter is missing"
        [[ -x /usr/lib/spectrumos/appearance-sync ]] || die "Spectrum appearance synchronizer is missing"
        [[ -x /usr/lib/spectrumos/spectrum-browser-defaults ]] || die "Spectrum browser appearance defaults helper is missing"
        [[ -x /usr/lib/spectrumos/appearance-stage ]] || die "Spectrum system appearance handoff is missing"
        [[ -x /usr/lib/spectrumos/limine-appearance-sync ]] || die "Spectrum Limine appearance synchronizer is missing"
        [[ -x /usr/lib/spectrumos/uki-branding-sync ]] || die "Spectrum UKI branding synchronizer is missing"
        [[ -x /usr/lib/spectrumos/pipewire-restart ]] || die "Spectrum PipeWire restart hook script is missing"
        [[ -r /usr/share/libalpm/hooks/60-spectrumos-pipewire-restart.hook ]] || die "Spectrum PipeWire restart pacman hook is missing"
        [[ -x /usr/bin/spectrum-snapshot ]] || die "Spectrum snapshot tool is missing"
        [[ -r /etc/xdg/mimeapps.list ]] || die "Spectrum default application map is missing"
        [[ -r /etc/flatpak/remotes.d/flathub.flatpakrepo || -r /usr/share/flatpak/remotes.d/flathub.flatpakrepo ]] || \
            die "Flathub remote configuration is missing"
        command -v flatpak >/dev/null || die "Flatpak is missing"
        [[ -r /usr/lib/systemd/zram-generator.conf.d/60-spectrumos.conf ]] || die "Spectrum zram policy is missing"
        systemctl is-enabled --quiet systemd-resolved.service || die "systemd-resolved is not enabled"
        if [[ $FORM_FACTOR_PROFILE == laptop ]]; then
            command -v powerprofilesctl >/dev/null || die "Laptop power profile control is missing"
            systemctl is-enabled --quiet power-profiles-daemon.service || die "Laptop power management is not enabled"
            [[ $(systemctl is-enabled tuned.service 2>/dev/null || true) == masked ]] || \
                die "TuneD must be masked when laptop power management is selected"
        fi
        if [[ $LEAN == false ]]; then
            systemctl is-enabled --quiet cups.socket || die "CUPS socket is not enabled"
            systemctl is-enabled --quiet cups-browsed.service || die "CUPS network discovery is not enabled"
            systemctl is-enabled --quiet avahi-daemon.service || die "Avahi discovery is not enabled"
        fi
        [[ $(readlink -f /etc/resolv.conf) == /run/systemd/resolve/stub-resolv.conf ]] || \
            die "resolv.conf is not managed by systemd-resolved"
        [[ -r /usr/share/sddm/themes/spectrumos/Main.qml ]] || die "Spectrum SDDM theme is missing"
        [[ -r /usr/share/plymouth/themes/spectrumos/spectrumos.plymouth ]] || die "Spectrum Plymouth theme is missing"
        [[ -x /usr/lib/spectrumos/plymouth-boot-sync ]] || die "Spectrum Plymouth boot synchronizer is missing"
        local plymouth_check_flags=(--check)
        if [[ $GPU_PROFILE == nvidia || $GPU_PROFILE == nvidia-intel || $GPU_PROFILE == nvidia-amd ]]; then
            plymouth_check_flags+=(--nvidia)
        fi
        sudo /usr/lib/spectrumos/plymouth-boot-sync "${plymouth_check_flags[@]}" || die "Spectrum Plymouth boot path is incomplete"
        [[ -x /usr/lib/spectrumos/waybar-widgets ]] || die "Spectrum Waybar widgets are missing"
        [[ -x /usr/lib/spectrumos/waybar-cava ]] || die "Spectrum Waybar Cava bridge is missing"
    fi
}

phase_reload() {
    [[ $RELOAD_SESSION == true ]] || { log "Skipping session reload"; return; }
    if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
        if [[ $APPLY == true ]] && command -v hyprctl >/dev/null; then
            run_as_target env "HYPRLAND_INSTANCE_SIGNATURE=$HYPRLAND_INSTANCE_SIGNATURE" hyprctl seterror disable
        fi
        log "Hyprland must be restarted because its config entrypoint changed from Hyprlang to Lua"
        log "Log out and start the Hyprland session again; hot reload is intentionally skipped"
    else
        log "No running Hyprland session was detected; the new config will load at next login"
    fi
}

while (($#)); do
    case $1 in
        --apply) APPLY=true ;;
        --phase) shift; (($#)) || die "--phase requires a value"; csv_to_array "$1" SELECTED_PHASES ;;
        --profile) shift; (($#)) || die "--profile requires a value"; csv_to_array "$1" PROFILES ;;
        --cpu) shift; (($#)) || die "--cpu requires a value"; CPU_PROFILE=$1 ;;
        --gpu) shift; (($#)) || die "--gpu requires a value"; GPU_PROFILE=$1 ;;
        --form-factor) shift; (($#)) || die "--form-factor requires a value"; FORM_FACTOR_PROFILE=$1 ;;
        --hardware) shift; (($#)) || die "--hardware requires a value"; LEGACY_HARDWARE_PROFILE=$1 ;;
        --target-user) shift; (($#)) || die "--target-user requires a value"; TARGET_USER=$1 ;;
        --set-default-shell) SET_DEFAULT_SHELL=true ;;
        --lean) LEAN=true ;;
        --no-reload) RELOAD_SESSION=false ;;
        --list-phases) printf '%s\n' "${PHASES[@]}"; exit 0 ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
    shift
done

validate_choices
for phase in "${PHASES[@]}"; do
    if phase_enabled "$phase"; then
        "phase_$phase"
    fi
done

log "Completed selected phases"
if [[ $APPLY != true ]]; then
    log "Dry-run only; rerun with --apply to make changes"
fi
