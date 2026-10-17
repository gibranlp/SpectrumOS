# SpectrumOS2 Roadmap

## Base v0.1: reproducible installed system

### 0. Foundation (current)

- [x] Create independent repository and clean structure.
- [x] Audit legacy SpectrumOS without modifying it.
- [x] Capture current Arch reference baseline.
- [x] Establish configuration, package-manager, privacy, and update decisions.
- [x] Create initial intentional package manifests.
- [x] Validate every manifest package and repository origin on the AMD reference host, keeping official and AUR transactions separate.
- [ ] Add manifest/config linting; an initial dry-run-safe disposable QEMU/OVMF harness is complete.

### 1. Minimal boot-to-desktop path

- [x] Define Limine as the tested v0.1 bootloader boundary and integrate Plymouth without rewriting boot entries.
- [x] Package release identity and the shared system appearance handoff.
- [x] Package the adaptive SDDM config/theme with static fallback colors.
- [x] Package a minimal Hyprland/UWSM session.
- [x] Validate portals, polkit, PipeWire/WirePlumber, notifications, launcher, terminal, lock/idle, clipboard, and screenshots.
- [x] Select NetworkManager as the user-facing default while retaining systemd-resolved for DNS.

### Desktop Integration Slice 0.1 (current)

- [x] Define semantic palette schema v1 and a static dark fallback.
- [x] Validate color syntax and baseline text contrast.
- [x] Render isolated Hyprland, Kitty, Dunst, and canonical JSON outputs.
- [x] Activate only complete generations with an atomic link replacement.
- [x] Test invalid palettes, strict mode, fallback recovery, and repeated generation.
- [x] Add and live-test a Matugen extractor adapter without coupling consumers to Matugen.
- [x] Specify and prototype the native Spectrum extractor.
- [x] Add multi-mode evaluation reports, bounded generation retention, and wallpaper-aware rollback.
- [x] Add dark/light fallbacks and consumer-specific contrast correction and reporting.
- [x] Add modular Hyprland source defaults, legacy-compatible bindings, and parser validation.
- [x] Package the Hyprland defaults with parser and installed-path verification.
- [x] Test the packaged session in a disposable nested compositor or VM.
- [x] Define and build the first real Arch package for the Spectrum semantic theme engine.
- [ ] Port stabilized theme behavior to Rust through the reproducible development profile.

### 2. Shell and user adoption

- [x] Package reproducible Oh My Zsh defaults with pinned external plugins.
- [x] Implement non-destructive adoption with preservation and syntax tests.
- [x] Create an empty private personal-layer skeleton outside the repository without sourcing it.
- [x] Verify core shell/SSH command continuity before changing the reference user's login shell.

### 3. Hardware and gaming foundation

- [x] Implement explicit AMD, Intel, NVIDIA, NVIDIA + Intel, NVIDIA + AMD, VM, laptop, and desktop package profiles; physical acceptance beyond AMD and VM remains open.
- [x] Enable multilib only as an intentional prerequisite and perform a full synchronized transaction on the AMD reference host.
- [ ] Validate the complete gaming matrix. Steam, GameMode, MangoHud, Gamescope, Vulkan, and the 32-bit Vulkan stack pass on the AMD reference desktop; a real controller and additional hardware profiles remain open.
- [x] Define measurable and reversible gaming/work modes, including balanced/performance switching and reference-counted GameMode restoration.

### 4. Visual system

- [x] Review current visual assets and establish a source-attributed CC0/public-domain regression wallpaper corpus.
- [x] Specify semantic palette schema and static fallback.
- [x] Implement atomic palette generation and initial Hyprland/Kitty/Dunst consumers.
- [x] Adapt the legacy Waybar layouts to Spectrum semantic colors with independent persistent layout, geometry-style, and three-theme Wofi selection.
- [x] Replace the five legacy Rofi surfaces with semantic minimal Wofi profiles and a searchable wallpaper-thumbnail theme selector.
- [x] Implement a Spectrum-owned GTK 3/4 color synchronizer informed by WPGTK without overwriting unrelated user configuration.
- [x] Prototype a Spectrum-owned Kvantum color generator and validate Qt 5/6 Wayland behavior.
- [x] Make Waybar, Wofi, GTK, and Qt participate in the same atomic theme activation and rollback lifecycle.
- [x] Package the remaining launcher, terminal, notifications, lockscreen, and status visual defaults; Hyprland, SDDM, and Plymouth are packaged.
- [x] Add GTK/Qt integration only after override behavior is safe.
- [x] Add a live-tested, semantic Eww control-shell preview with Wofi fallback.
- [x] Port network, Bluetooth, audio, appearance, display, session, media, and utility surfaces to frontend-neutral adapters and Eww widgets.
- [x] Keep the application launcher and calculator as centered Wofi surfaces after Eww interaction testing showed they benefit from short-lived keyboard-first processes.
- [x] Move Waybar and the Eww visualizer to explicit user-service lifecycle ownership and validate repeated restart/open/close behavior.

### 5. Update and recovery prototype

- [x] Define release metadata and migration format.
- [x] Prototype Btrfs pre-upgrade snapshots and health checks in a VM.
- [x] Define and VM-test rollback semantics across bootloader, kernel, and packages; migration reversal remains version-specific.
- [x] Prototype read-only `spectrum info` with human and JSON output.
- [x] Prototype read-only `spectrum doctor` before update mutation.
- [x] Add a dry-run-only update plan with disk, lock, snapshot, package-origin, and migration preflight checks.
- [x] Implement ordered, atomic, idempotent migration execution and exact marker rollback, then validate both explicit and whole-root rollback in an isolated Btrfs VM.
- [x] Define a conservative read-only snapshot retention policy.
- [x] Add exact-confirmed pruning and synthetic interrupted-prune recovery coverage.
- [x] Add an automatic pre-upgrade restore-point Pacman hook that aborts the transaction if snapshot creation fails, and cap automatic restore points at 3.
- [x] Implement and enable a dedicated boot-time restore image (mkinitcpio hook + Limine entry) without modifying the normal kernel images.
- [x] Build and verify a signed local Edge repository with strict trusted package/database signatures and exact-snapshot manifests.
- [x] Add Edge-to-Testing-to-Stable promotion gates that reject host-built development artifacts from release channels.
- [x] Convert every monorepo-relative PKGBUILD to an immutable checksummed source archive, pass all six `pkgctl build` clean-chroot builds, and promote the exact signed set from Edge to Testing.
- [x] Establish the offline production root key, separate online package-signing subkey, witnessed fingerprint ceremony, and HTTPS repository hosting.
  - [x] Document and test the offline-primary/online-signing-subkey contract and add a public-key audit gate.
  - [x] Perform the witnessed real-key ceremony and provision the external online signer.
  - [x] Provision HTTPS hosting and publish a production-signed Testing snapshot atomically.
  - [ ] Publish the primary fingerprint through a channel independent of `spectrum.gibranlp.dev`.
  - [x] Witness an interrupted publication leaving the previously verified channel selected.
  - [ ] Witness signing-subkey expiration/rotation and primary-key revocation recovery.
- [x] Enable restore-image registration through `spectrum-base.install` while leaving normal kernel images unchanged.
- [x] Boot-test the restore image in a disposable Btrfs VM: prove normal boot remains unaffected, then boot a real `spectrumos.restore=latest` recovery.
- [x] Destructively validate pruning and interrupted-prune recovery in an isolated Btrfs VM before enabling update execution.

### 6. Base v0.1 acceptance

- [x] Transform a clean Arch VM using only this repository, Arch repositories, paru for declared AUR packages, and documented steps.
- [x] Re-run bootstrap safely without duplicating or destroying state.
- [x] Boot through Plymouth and SDDM into a usable Hyprland session.
- [x] Build and UEFI-boot the first branded installer/recovery ISO candidate in a disposable VM.
- [ ] Complete physical laptop boot, input, display, networking, audio, brightness, battery, and suspend/resume acceptance from the ISO.
- [ ] Pass the full networking, audio, portal, notification, shell, development, and cross-hardware gaming-foundation matrix. The AMD desktop gaming path passes; see `hardware-acceptance.md` for deferred physical tests.
- [x] Demonstrate user overrides and the private work layer survive a production-signed Testing package upgrade byte-for-byte.
- [ ] Publish complete known limitations and recovery procedure.

## Later milestones

- Rust `spectrum` CLI transaction/recovery features.
- Broader hardware matrix and optional compositor evaluation.
- Polish and sign release ISO images after physical acceptance and recovery validation.
