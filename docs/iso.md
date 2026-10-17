# SpectrumOS2 ISO

The repository contains an ArchISO-based graphical installer and recovery profile. The current SpectrumOS 1.0 release image is ready for VM and physical acceptance testing; the ISO container itself is unsigned while its embedded package repository is signed.

The ISO build requires a verified signed Edge repository under `repo/output/edge/x86_64`. The build embeds that snapshot below `/var/lib/spectrumos/repository/edge/x86_64` in the live filesystem. During installation, the backend copies the snapshot into the target, imports and locally verifies the production public key, enables strict package and database signature checking, and installs `spectrum-desktop` through Pacman before adopting user configuration. It then changes the installed system's SpectrumOS source to the public Stable channel. Consequently, Spectrum-maintained files are package-owned on first boot and later Stable releases arrive through the Control Center or Pacman without rerunning the source installer.

The embedded repository provides a coherent initial package set without requiring network access. Public HTTPS hosting and the production key deliver later Stable snapshots to installed systems.

The live image logs in as the unprivileged `spectrum` user, starts a branded Hyprland session using the S30.png wallpaper, and opens the GTK installer automatically. The current installer intentionally supports one clear path: connect through Wi-Fi or Ethernet, choose a persistent keyboard layout, erase one whole disk, create a Btrfs installation with separate home and snapshot subvolumes, install Limine for the detected UEFI or BIOS firmware, and create the first administrator account. Graphics detection offers AMD, Intel, discrete NVIDIA, NVIDIA + Intel hybrid, NVIDIA + AMD hybrid, and virtual-machine profiles, with a manual selector and an explicit review summary. Manual partitioning and same-disk dual boot are not offered yet.

The live environment and installed desktop include Flatpak with a system-wide Flathub remote. Its signed repository definition is bundled in the image, so the remote is available before the first network connection; downloading apps still requires network access.

The setup page has an unchecked **Install lean SpectrumOS** option beside the laptop option. Lean retains the Spectrum desktop, theme, audio, networking, Evolution email, KDE Connect with its tray indicator, zram, and Btrfs recovery, while omitting the Transmission daemon, printing and SMB packages, and TuneD. The full installation remains the default. Both profiles omit Docker and Docker Compose; installation does not enable Docker or grant Docker-group membership. Container tooling can be installed separately when needed. Optional browsers can still be selected separately. The ISO builder checks that its signed `spectrum-desktop` package no longer requires the omitted packages.

Future Full and Lean installations select File Roller and its archive backends from the desktop manifest, enabling Thunar's native Extract Here, Extract To and Create Archive context-menu actions. The desktop package recipe also requires these tools. This prepares future installation inputs; the current published ISO and signed desktop package remain unchanged until their next release.

The laptop option selects Power Profiles Daemon in both installation sizes, excludes TuneD, and masks its service so only one daemon controls power policy. It does not install TLP. Intel profiles include both modern and legacy VA-API drivers, covering older integrated graphics such as the 2011 MacBook Air's HD 3000. Battery runtime must be measured on the target hardware; this checkbox does not guarantee a particular battery life.

For a UEFI installation with Windows on a different disk, the installer scans the other disks' EFI System Partitions read only for Windows Boot Manager. Each verified loader receives a Limine `protocol: efi` entry addressed by its partition GUID and its actual FAT filename case. The selected SpectrumOS disk is still erased in full; the Windows disk is neither repartitioned nor written. SpectrumOS appearance synchronization, Plymouth setup, rescue-entry setup, and kernel image updates preserve the Windows entry because they edit existing Limine configuration narrowly instead of regenerating it. A missing or inaccessible Windows EFI partition is skipped, and BIOS Windows chainloading is not currently configured. Limine's [configuration reference](https://github.com/Limine-Bootloader/Limine/blob/v12.x/CONFIG.md) documents EFI chainloading and GUID paths.

## October 15 installer HotKey correction

A physical installation report confirmed that the existing October 15 images stop during source adoption with `pkg-config: command not found`, undefined Wayland/xkbcommon references, and the trailing `DT_TEXTREL`/`collect2` error. The target already has the signed Desktop package's native HotKey helper, but `install.sh` unnecessarily compiled it again; the build script also masked a failed dependency-flags command and invoked the linker without its required libraries.

The corrected installer reuses an executable helper owned by `spectrum-desktop`, retains source compilation for an unowned/missing helper, and performs no compilation during a dry run. The native build script now stops immediately if `pkg-config` cannot supply the dependency flags. Tests cover package ownership, source fallback, dry runs, build failure/preservation and missing compiler metadata. All 120 focused installer/ISO/HotKey checks pass; a real installed-helper check passes with unavailable `pkg-config`. The correction is in maintained source, and a patch verified against the exact existing ISO sources is retained in `artifacts/installer-hotkey-fix-20261015/installer-hotkey.patch`.

The earlier October 15 images predate this correction; the rescue rebuild described below includes it. Successful BIOS/UEFI live boot does not establish completed target installation. Do not treat the stopped target as a finished installation; restarting the graphical erase-disk workflow repartitions the destination again.

## Rescue system terminal

The maintained installer now has a **Rescue system** button above its page content, available from setup, review, progress and completion. The live desktop's **Rescue system** bar action and **Super+R** open the same guide. Rescue terminals launch through UWSM independently of the installer.

Every new live Foot terminal starts `spectrum-rescue-shell`, which prints a compact welcome with disk/mount checks, network setup, the existing recovery menu, and guidance for a stopped installation, then opens an ordinary interactive Bash shell. Run `spectrum-rescue-shell --guide` for the full instructions, including the distinction between the live environment and an installed-system chroot. The helper does not mount disks, elevate privileges or run repairs on opening. `spectrum-recovery` remains the explicit interactive menu for chroot access, snapshots, Limine repair, disk/SMART reports and networking.

The ISO builder installs the generated Foot configuration at `/etc/xdg/foot/foot.ini`, its normal system configuration path, and preserves the guide's executable permission. The template uses the current Foot `[colors-dark]` section. Both routes were verified in a native installer/Foot preview with installation actions disabled; 100 focused checks pass, as do the live Hyprland config and actual Foot 1.28 configuration checks. Evidence: `artifacts/rescue-guide-20261015`. The helper is also installed locally for inspection with `spectrum-rescue-shell --guide`. These changes are included in the rescue rebuild described below.

## October 15 tested rescue rebuild

The replacement image is `artifacts/iso/spectrumos-1.0.0-20261015-x86_64.iso`, keeping the previous filename. Size: 2,461,775,872 bytes (2.29 GiB). SHA-256: `7146f368e5452587a18fb095deef100349abb3442c695361b8ca51b145805977`; its adjacent `.iso.sha256` file matches. It includes the installer HotKey correction and rescue guide/button above, the notification/screenshot fixes, and the Thunar-focus Islands curve fix.

Desktop 1.0.0-12 was built in a Devtools clean chroot with 527 Python and 323 Qt checks plus native suites, production-signed and embedded through the local Edge snapshot. The other eight package payloads are unchanged. It is installed locally with 230 files and zero alterations, preserved checked settings and healthy Shell/HotKey services. Public Testing/Stable remain on Desktop 1.0.0-11; the package candidate has not been published separately. The user subsequently confirmed a successful installation and authorized publication of this exact ISO at the existing download URL.

Extraction verifies the embedded production signatures/hashes, current installer and rescue payloads, all three fixed shell QML files, executable source permissions, private-path exclusions, Foot configuration parsing and bundled-app gates. The checksum and BIOS/UEFI boot catalog/MBR layout were checked. The user reports that installation worked; this rebuild has not been booted in a VM or installed to a target by the agent. Evidence: `artifacts/iso-validation-20261015-rescue` and `artifacts/rescue-iso-packages-20261015`.

October 15 tested rescue ISO publication: the user confirmed that the installer worked and authorized replacing the existing download with the exact tested image. Published spectrumos-1.0.0-20261015-x86_64.iso and its checksum at https://spectrum.gibranlp.dev/downloads/ under their original filenames. Size: 2,461,775,872 bytes; SHA-256: 7146f368e5452587a18fb095deef100349abb3442c695361b8ca51b145805977. Full staged and final server hashes pass; complete HTTPS download and checksum sidecar match at 2026-10-15T22:19:16.834201+00:00. Previous public bytes are retained in the hidden server staging directory for rollback. No rebuild or package-channel publication occurred. Evidence: artifacts/iso-publication-20261015-rescue.

## First-login application appearance

New installation inputs now save the GTK 3/4 theme, icon theme and dark preference directly in settings.ini and reapply appearance-sync at login with the actual session bus. Thunar can use the generated palette without requiring a wallpaper change first. Chrome and Brave receive GTK as a first-run default through their executable-adjacent initial_preferences files; existing profiles and explicit default-theme selections are preserved. A package hook refreshes missing browser defaults on installation or upgrade, including optional browsers installed at the end of the graphical installation.

Verified with 128 focused checks, native GTK settings and fresh temporary GUI profiles in both browsers. These maintained-source changes are deployed locally; the published ISO predates them. Full fresh-install acceptance remains pending a future explicitly authorized rebuild. Evidence: artifacts/first-login-theme-20261015.

## Default appearance

The current ISO inputs use `S30.png` from `assets/wallpapers/default/` for the live desktop, installer palette, and Limine menu background. The live and installed initial palettes use the same Clustered dark extraction. Fresh installations receive all 30 wallpapers, `S1.png` through `S30.png`, under both `/usr/share/backgrounds/spectrumos/` and the new user's `Pictures/Wallpapers/`; `S30.png` is activated for the first desktop, SDDM, and Limine.

Live boot and installed boot use the supplied 240-frame Plymouth intro at approximately 50 fps, ending on its final logo. The older wallpaper collections are removed from the source defaults and replaced by the new Base package. These source/package changes do not alter an existing ISO image.

## Build

Preview the build inputs without changing the system:

```bash
scripts/build-iso
```

Build with ArchISO installed:

```bash
sudo scripts/build-iso --build
```

ISO assembly uses a temporary directory under `artifacts/` rather than `/tmp`. On SpectrumOS `/tmp` is RAM-backed, so placing mkarchiso's multi-gigabyte root filesystem there would consume memory needed by the live desktop and running applications. The temporary build tree is removed on every normal, failed, or interrupted exit.

Images are written to `artifacts/iso/`, which is ignored by Git. The builder stages the current working tree, so uncommitted repository changes are intentionally included.

## Latest hosted image

[Download SpectrumOS 1.0.0](https://spectrum.gibranlp.dev/downloads/spectrumos-1.0.0-20261015-x86_64.iso) · [SHA-256 checksum](https://spectrum.gibranlp.dev/downloads/spectrumos-1.0.0-20261015-x86_64.iso.sha256).

October 15 ISO publication: uploaded the existing verified `spectrumos-1.0.0-20261015-x86_64.iso` and its `.iso.sha256` sidecar to `https://spectrum.gibranlp.dev/downloads/` at the user’s explicit request. Size: 2,461,763,584 bytes (2.29 GiB); SHA-256: `987e8481f3b1a398e4eaa634a26d5a9b3f8681a76597d40432a49fee99fc47eb`. Upload used a staging directory and verified full server-side hashes before moving the files into their public paths. A complete 2.46 GB HTTPS readback matched the ISO hash, length and local checksum sidecar at 2026-10-15T16:31:37Z. Receipts/logs are retained in `artifacts/iso-validation-20261015/`. The user requested direct links for posting; the website landing page was not edited, and older downloads were retained. No image rebuild or additional installation acceptance was performed.

## October 15 generated version 1 image

The user explicitly authorized this build after the October 15 package publication. The new local image is `artifacts/iso/spectrumos-1.0.0-20261015-x86_64.iso`, with adjacent `.iso.sha256` checksum. Size: 2,461,763,584 bytes (2.29 GiB). SHA-256: `987e8481f3b1a398e4eaa634a26d5a9b3f8681a76597d40432a49fee99fc47eb`. Volume label: `SPEC_20261015`.

Its embedded production-signed Edge inventory is byte-identical to the October 15 Stable package/database inventory: Base 1.0.0-3, Desktop 1.0.0-10, Hyprland 1.0.0-3, SpectrumDrop 1.0.0-4, Theme/Plymouth/SDDM 1.0.0-2, UKVM 0.1.0.r21-1 and managed portal 1.4.1.r30.g0204ffb-1. This includes the HotKey, monitor scaling, visualizer palette, wallpaper button and release-review improvements. The installed system uses public Stable for subsequent updates.

All 75 focused ISO/installer tests pass. Actual SquashFS extraction verified all 26 manifest-listed embedded repository files, production signatures for the snapshot/database/packages, installer source parity, 389 executable source files, bundled Stash/Questline/UKVM checks and private-path exclusions. The checksum sidecar matches the complete ISO. BIOS and UEFI boot entries and the MBR layout were inspected. Both firmware modes booted the exact ISO as a read-only raw disk in isolated KVM guests with no writable installation disk. BIOS opened the graphical installer automatically; UEFI reached the live desktop with its autostarted installer process/window, and the installer was visually confirmed after console/display diagnostics. VM software-rendering warnings are retained in the logs. No installation or physical hardware acceptance was performed.

Evidence: `artifacts/iso-validation-20261015/verification.json`, build/extraction/test logs in the same directory, and boot screenshots/logs in `artifacts/iso-boot-20261015/`. Both guests were closed after verification. At the end of build validation this image was local only; its subsequent authorized upload is recorded above.

## Current published release image (historical build)

- Download: https://spectrum.gibranlp.dev/downloads/spectrumos-1.0.0-20261010-r2-x86_64.iso
- Checksum: the adjacent `.iso.sha256` file
- Size: 2,458,781,696 bytes (2.29 GiB)
- SHA-256: `75512fe4179dec5acb1a4e4fe7b48b5fc8492479f5d691eb68ce808bc5bfb37c`
- Volume label: `SPEC_20261010`
- Boot support: hybrid BIOS and UEFI

The 1.0 image embeds eight production-signed packages: all six SpectrumOS packages at 1.0.0-1, UKVM 0.1.0.r20-1, and the managed Hyprland portal 1.4.1.r30.g0204ffb-1. Their immutable snapshot is `20261009T2225530000-1cf378e5b439f06e`, also published on Stable. Both Full and Lean install UKVM, the managed portal, the frontend, Questline, Stash, Evolution and KDE Connect. Later updates use public Stable.

Actual image extraction verified all embedded signed snapshot hashes, current widget/adapter/terminal/Igor files, release identity and bundled applications. ISO source staging excludes ignored build state, signing-key directories, secrets and personal files; a regression reproduces and checks those exclusions. The ISO container has a SHA-256 checksum; the embedded package set has production signatures. These are distinct checks.

The original October 9 image passed read-only raw-disk UEFI and BIOS boot tests but failed physical installation because it requested distro-only packages before registering the signed repository. The first corrected October 10 image reached the graphical installer but physical installation exposed missing executable permissions on source helpers. Revision r2 fixes that separate issue and completed a Full erase-disk installation in an isolated UEFI VM. Physical installation from r2 remains untested.

## October 10 installer correction

The initial `pacstrap` step uses only the Arch repositories. It now defers `ukvm` and `spectrum-xdg-desktop-portal-hyprland` until `install_spectrum_repository` has copied the embedded snapshot into the target, registered its strict signed repository and imported/locally signed the production public key. The subsequent synchronized transaction explicitly installs `spectrum-desktop`, UKVM and the managed portal. Both Full and Lean retain the packages. UKVM runtime, portal behavior, peer trust and existing package artifacts were not changed.

The old image's package selection reproduces both `target not found` failures using an isolated Pacman database. The fixed initial Arch transaction resolves for all 24 Full/Lean, laptop/desktop and GPU combinations; the signed transaction also resolves with both packages present. All 619 Python tests pass (one opt-in skipped), including new ordering/profile regressions. Actual extraction confirms the deployed installer and embedded source match the fix. The r2 image subsequently completed a Full installation onto an isolated 40 GiB UEFI VM disk, including the signed package transaction, UKVM integration, user/theme adoption, optional desktop applications and bootloader setup. Installed package versions and the UKVM helper's executable mode were verified on the resulting filesystem. Physical installation from r2 still needs acceptance.

To repair the already booted October 9 live image, close the graphical installer and run:

```sh
sudo sed -i 's/grep -vx paru |/grep -vx -e paru -e ukvm -e spectrum-xdg-desktop-portal-hyprland |/' /usr/local/lib/spectrumos/spectrum-installer-backend
```

Reopen the installer and retry using the intended disposable destination. The installation erases that selected disk. The patch affects only the live session; use the October 10 image for future installations.

## Default user picture for future images

User setup generates a transparent 512×512 PNG from Igor’s existing face artwork at `~/USERNAME.png`, owned by the new user. Both Full and Lean follow this path before theme setup, which stages the picture for the SDDM login screen. Existing files and symbolic links are preserved. Users can replace their PNG at any time; the usual appearance refresh stages the replacement. This change is prepared for future ISO builds and is not included in the currently published image.

## Remaining acceptance

Complete an erase-disk installation on a disposable disk and verify the installed boot/reboot. Physical laptop acceptance should cover firmware, keyboard/touchpad, displays, Wi-Fi, Bluetooth, audio, brightness, battery and suspend/resume. The installer erases the selected disk; use only an empty/test destination. M18 UKVM input/persistence and M19 clipboard have user-confirmed physical acceptance on prior production packages; complete M20 file-transfer acceptance separately.

## Stash music player

The installed Full and Lean desktops include Stash 0.7.0 through the signed `spectrum-desktop` package. The package bundles the checksum-verified Linux release binary, `/usr/lib/spectrumos/stash-open`, and the Stash application-menu entry. The installer obtains these files from the ISO’s embedded Edge repository; it does not download or compile Stash on the target system. Stash opens in the themed Kitty terminal and follows the generated SpectrumOS palette.

Questline-cli 2.0.1 is bundled in the same required package for both installation modes, including support for SpectrumShell editing and tree care. Before ISO creation, `scripts/check-bundled-apps` checks the desktop artifact indexed by the signed repository database for both application binaries and their launchers. After the offline package transaction, the installer verifies Stash is executable and checks Questline's version command before continuing.

Desktop 1.0.0-1 is included in the current release ISO and public Stable snapshot.

## October 10 r2 executable permissions

ArchISO normalizes regular files to mode 0644 unless its `file_permissions` table registers them. The embedded UKVM helper existed, but lost its executable bit; sudo consequently reported `command not found`. The builder now registers every executable regular file from staged source with root ownership and mode 0755, without following symlinks or preserving privileged mode bits. Actual r2 extraction verified all 359 executable source files, including `integrations/ukvm/install` and appearance/session helpers. A regression checks executable and non-executable files, symlinks, and shell quoting for filenames containing spaces and apostrophes.

Set `SPECTRUM_ISO_REVISION=2` when reproducing this revision; the optional revision must be a positive integer. The signed package snapshot is unchanged. The 89 focused installer/ISO tests and complete 619-test Python suite pass (one opt-in test skipped). The VM installation log ends at progress 100 with `SpectrumOS installation completed successfully`, and installed UKVM r20-1, managed portal 1.4.1.r30.g0204ffb-1 and Desktop 1.0.0-1 were verified.

The installed VM disk subsequently booted without the ISO attached and reached the SpectrumOS SDDM login screen. The server ISO was fully hash-verified before promotion; HTTPS checks matched the landing page, checksum, content length and first/last 64 KiB. Older SpectrumOS ISO copies and adjacent checksums found under the local home/temp trees and hosting account were removed after publication.


## October 10 revision 3

[Download revision 3](https://spectrum.gibranlp.dev/downloads/spectrumos-1.0.0-20261010-r3-x86_64.iso) and [verify its checksum](https://spectrum.gibranlp.dev/downloads/spectrumos-1.0.0-20261010-r3-x86_64.iso.sha256). Size: 2459994112 bytes; SHA-256: `8e489d402b9a61fb92aae81e85044f648ecf2c8515116776c246c0b6f34ef340`. The ISO carries the verified signed Stable-equivalent package set with Desktop 1.0.0-2 and UKVM r20-2. Actual extraction verified the new picker/brightness files inside the bundled desktop artifact, the new UKVM artifact, the unchanged managed portal, ddcutil in the live environment and 360 executable embedded-source helpers. The image booted via UEFI to the graphical installer in an isolated VM. Full installation, physical laptop brightness and physical first-run UKVM consent on revision 3 were not tested by this publication; earlier r2 installation evidence remains historical. Server full-file hashing and HTTPS landing page, checksum, size and first/last-range checks passed before removal of older ISO copies.
