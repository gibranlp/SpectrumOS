# SpectrumOS Architecture

## Product model

SpectrumOS is a package-composed Arch derivative, not a dotfiles installer. A supported installation is the result of declared packages, package-owned defaults, selected hardware/session profiles, migrations, and verification. The bootstrap process is temporary orchestration; every lasting system behavior must have a durable owner.

## Repository layout

- `bootstrap/`: minimal installer orchestration and intentional package manifests.
- `configs/`: source configuration organized by subsystem; package builds decide final paths.
- `packages/`: Arch package recipes grouped by ownership boundary.
- `system/`: systemd units, user units, udev, sysctl, and environment source files.
- `migrations/`: versioned, idempotent transitions with preconditions and rollback notes.
- `scripts/`: small development/build/validation utilities, not an alternate package manager.
- `assets/`: source-controlled, license-reviewed visual assets.
- `repo/`: signed repository policy, public keys, client configuration, and ignored build output.
- `iso/`: placeholder only until installed-system reproduction is mature.

## Package boundaries

- `spectrum-base`: release identity, common directories, baseline policy, migration metadata.
- `spectrum-desktop`: Wayland session foundation and cross-desktop integration.
- `spectrum-hyprland`: Hyprland defaults, session entry, keybindings, portal preference.
- `spectrum-sddm`: SDDM configuration and reviewed theme.
- `spectrum-plymouth`: supported Plymouth theme and initramfs integration guidance.
- `spectrum-theme`: static theme assets, palette schema, renderer defaults.
- `spectrum-gaming`: gaming dependencies and reversible mode integration.
- `spectrum-cli`: future Rust CLI and stable user-facing commands.

`spectrum-base` owns the cross-session appearance handoff under `/var/lib/spectrumos/appearance`. Members of the restricted `spectrumos` group may atomically stage the active wallpaper and semantic colors there. SDDM reads that root-owned shared copy instead of a user home. A root path unit copies the same normalized PNG to the ESP and updates only Limine's global wallpaper and color keys; it never creates, deletes, or rewrites boot entries. The original Limine configuration is backed up on first synchronization.

The tested v0.1 bootloader is Limine, but boot appearance synchronization is isolated from kernel/entry management so another bootloader can be added without changing theme generation. `spectrum-plymouth` owns the supplied 240-frame intro, played once at 50 fps and held on its final logo, and an idempotent boot configurator that inserts the standard mkinitcpio `plymouth` hook and the Limine `quiet splash` flags without replacing upstream services. `spectrum-sddm` owns the centered logo/login theme and a backed-up `/etc/sddm.conf`; SDDM and Limine consume the same staged wallpaper. Every appearance activation also atomically generates an eight-layer Spectrum logo as SVG and PNG from the active semantic accents. SDDM uses the SVG, Hyprlock uses the PNG, and the QML logo remains a static fallback.

Package splits may change when real file ownership becomes clear; they must not become empty meta-packages that hide uncontrolled scripting.

## Configuration and state

| Layer | Location | Owner | Mutability |
|---|---|---|---|
| Distribution defaults | `/usr/share/spectrumos/<component>/` | package | immutable outside package upgrades |
| Administrator policy | `/etc/spectrumos/<component>/` | package/admin | preserved across upgrades with pacman semantics |
| User overrides | `${XDG_CONFIG_HOME:-$HOME/.config}/...` | user | never silently overwritten |
| Generated palette/config | `${XDG_CACHE_HOME:-$HOME/.cache}/spectrumos/` | generator | disposable, atomically replaced |
| User state | `${XDG_STATE_HOME:-$HOME/.local/state}/spectrumos/` | user/service | durable non-secret state |
| Personal/work | `~/.config/spectrumos-personal/` | user only | private and repository-excluded |

Components with include support load defaults, then administrator policy, then user overrides, and only reference generated palette fragments. A renderer for a component without includes owns only its explicitly generated output and must back up/adopt existing files through a migration rather than overwriting them.

System-wide mutable runtime state belongs in `/var/lib/spectrumos` only when a root-owned service truly needs it. It must not be broadly user-writable.

## Shell architecture

Load order:

1. a small package-owned SpectrumOS Oh My Zsh configuration;
2. the pinned Oh My Zsh framework and pinned external plugins;
3. opt-in private fragments under `~/.config/spectrumos-personal/`.

Spectrum uses Oh My Zsh with a package-owned Spectrum prompt inspired by Agnoster's segmented Powerline layout and the legacy SpectrumOS plugin set: `archlinux`, `colored-man-pages`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `git`, `colorize`, and `command-not-found`. The context carries the Arch logo used by SpectrumOS branding and colors it with the extracted primary accent; the directory uses the wallpaper-derived alternate accent and Git consistently uses the primary accent, while `±` distinguishes a dirty tree and actual failures retain semantic error coloring. The official Arch `thefuck` package supplies the generated `fuck` correction alias. The installer fetches pinned framework and external-plugin revisions, and framework self-updates are disabled so a distro update remains responsible for changing them. Adoption creates the minimal entrypoint only when `~/.zshrc` is absent and preserves any existing file. The installer syntax-checks the assembled configuration and validates core command continuity before its explicit `--set-default-shell` option changes the login shell. Private aliases, SSH configuration, credentials, host data, and feed URLs are never copied into distro files.

The reference account adopted this configuration on 2026-08-31 and now uses `/usr/bin/zsh` as its login shell. Its private directory skeleton remains empty and optional.

## Dynamic theming

The theme engine is a producer/consumer system:

```text
wallpaper or fixed scheme -> palette extractor -> validated palette schema
                                              -> atomic named outputs
                                              -> component renderers/reload adapters
```

The canonical palette should include semantic roles (background, surface, foreground, muted, accent, warning, error, success) plus derived contrast metadata, not merely numbered pywal colors. Each application consumes its own generated fragment. A failed renderer must not invalidate the canonical palette or other consumers. Static fallback palettes are package-owned and always available.

Neovim uses the legacy LazyVim configuration and pinned plugin lockfile without the Pywal-dependent Lushwal plugin. Each atomic Spectrum generation includes a native `colors/spectrum.lua` renderer built from the semantic palette. Neovim loads it from the active generation and reapplies it when the editor regains focus. User adoption installs the baseline only when `~/.config/nvim` does not exist.

Initial consumers: Hyprland, terminal, launcher, notifications, lockscreen, and status bar. GTK/Qt and application-specific browser/editor integrations follow only after safe ownership is proven.

The menu frontend is undergoing a staged Wofi-to-Eww migration. Eww owns the persistent control center and consumes the same atomic semantic palette; Wofi remains the fallback and continues to own workflows that benefit from short-lived keyboard-first processes. Backend operations live behind bounded data/action adapters rather than embedding NetworkManager, Bluetooth, PipeWire, or session mutation in frontend expressions.

## Hardware profiles

Base manifests are hardware-neutral. Installation selects CPU, GPU, and form-factor profiles independently:

- AMD: Mesa, Vulkan Radeon, matching lib32 packages for gaming.
- Intel: Mesa, Vulkan Intel, modern and legacy VA-API media drivers, and matching lib32 packages. Legacy Intel graphics such as HD 3000 use the i965 video driver; installing Vulkan packages does not add Vulkan support to unsupported hardware.
- NVIDIA: supported driver branch, utilities, matching lib32 packages, and documented Wayland settings.
- NVIDIA + Intel: both Mesa/Intel and NVIDIA stacks, matching lib32 Vulkan drivers, and Switcheroo Control.
- NVIDIA + AMD: both Mesa/Radeon and NVIDIA stacks, matching lib32 Vulkan drivers, and Switcheroo Control.
- VM: minimal Mesa/virtio profile; gaming omitted by default.
- Laptop: Power Profiles Daemon is the single default power-policy owner in both full and lean installations. TuneD is excluded from the package selection and masked to prevent competing CPU policies. TLP is not installed.
- Power controls offer Power Saving, Balanced, and Performance where the backend supports them. Both bar orientations cycle supported modes; the battery widget selects modes directly. Power Saving maps to the daemon's `power-saver` profile or TuneD's `powersave` profile.
- Desktop: full installations include TuneD; lean installations omit it.

The installer exposes `--cpu`, `--gpu`, and `--form-factor`; its older AMD/Intel hardware flag is only a compatibility alias. Display-controller detection recommends a discrete or hybrid profile, and the review screen records the editable choice before installation. Physical hybrid acceptance remains mandatory.

## Updates, recovery, and channels

Release flow:

```text
Arch upstream -> Edge -> Testing -> Stable -> SpectrumOS users
```

Each published channel points to a coherent repository snapshot plus SpectrumOS package versions and release metadata. Packages are built in clean environments and signed. Client update responsibilities are preflight checks, repository freshness, disk-space checks, a Btrfs snapshot when supported, one complete pacman transaction, ordered migrations, health checks, and a clear reboot/rollback record.

The repository signs Edge packages, its database, and a checksummed snapshot manifest. Testing and Stable enforce clean-chroot provenance and receive the exact verified package set through promotion rather than rebuilding. Clean imports validate Arch `devtools` evidence and the exact PKGBUILD checksum embedded in each package before assigning that provenance. Production trust uses an offline certification primary and a separate online signing subkey. A production-signed Testing snapshot is published at the HTTPS origin; Stable remains gated on independent fingerprint publication and the remaining trust and recovery acceptance cases.

The initial snapshot contract pairs a read-only root-subvolume snapshot with the matching EFI `/boot` archive and installed-package record. Separate home, log, and package-cache subvolumes remain outside system rollback. Live-root replacement is prohibited; rollback runs from recovery media or another bootable root and restores root plus boot as one unit. See `docs/update-recovery.md`.

No mechanism may refresh databases and then selectively upgrade packages. Unsupported/AUR packages are surfaced separately and never allowed to silently break the official transaction. Non-Btrfs systems remain installable but receive explicit reduced rollback capability.

## Future `spectrum` CLI responsibilities

- `spectrum update`: orchestrate safe full transactions, snapshots, migrations, and reporting.
- `spectrum doctor`: read-only by default; check package integrity, services, portals, graphics, audio, disk/snapshot health, and drift. Repairs require explicit selection.
- `spectrum info`: release, channel, kernel, GPU, session, and support-relevant facts without secrets.
- `spectrum theme`: select wallpaper/scheme, render atomically, report consumer failures, restore fallback.
- `spectrum mode gaming|work`: activate documented reversible policies; record prior state and avoid global mystery tuning.
- `spectrum rollback`: enumerate valid restore points, validate boot/package compatibility, and guide/perform a supported rollback.

Rust is preferred once these commands share state, transactions, schemas, and recovery logic.

The initial behavior-stabilizing `spectrum info` prototype is a standard-library Python command owned by `spectrum-base`. It reads package-owned TOML release metadata and reports only non-sensitive release, kernel, architecture, session, GPU, and Spectrum package-version facts. This narrow prototype does not establish an update transaction engine or change the future Rust ownership boundary.

## Security and testing

- Packages and repository metadata are signed; build provenance and licenses are recorded.
- No credentials, machine IDs, Wi-Fi profiles, host keys, private certificates, browser state, or private SSH/work data enter builds or docs.
- Shell scripts use strict mode where appropriate and have narrow responsibilities.
- Validate manifests, package builds, config syntax, migration idempotency, and secrets patterns in CI.
- Test installation and upgrades in VMs before reference hardware; add AMD/Intel/NVIDIA coverage as resources permit.

## Language and commenting convention

User communication, documentation, identifiers, user-facing text, and commit messages use English. Code comments are added only around important functions or genuinely non-obvious behavior, and every ordinary explanatory code comment uses natural Mexican Spanish with a balanced tone. Required technical directives, SPDX identifiers, generated headers, and third-party text keep their required format.
