# SpectrumOS Package Development

SpectrumOS packages are built from their directory under `packages/`. Package recipes must use explicit file ownership, official repository dependencies where available, package-local tests, and no privileged commands.

`spectrum-base` owns `/usr/share/spectrumos/release.toml`, the ordered migration manifest under `/usr/share/spectrumos/migrations/`, and the behavior-stabilizing `/usr/bin/spectrum` Python prototype. `spectrum info`, `spectrum doctor`, and `spectrum update plan` are read-only. Root-only migration commands keep mutable completion state below `/var/lib/spectrumos/migrations/`; package installation never writes completion markers.

## Theme engine

Build `spectrum-theme` without writing artifacts into the repository:

```bash
build_root=$(mktemp -d /tmp/spectrum-package.XXXXXX)
mkdir -p "$build_root/build" "$build_root/out"
BUILDDIR="$build_root/build" PKGDEST="$build_root/out" \
  makepkg --dir packages/spectrum-theme --cleanbuild --clean --noconfirm
```

The package owns:

- `/usr/bin/spectrum-theme`
- `/usr/share/spectrumos/theme-engine/spectrum_theme/*.py`
- `/usr/share/spectrumos/theme-engine/spectrum_theme/palettes/*.toml`
- `/usr/share/licenses/spectrum-theme/LICENSE`

It deliberately does not own wallpaper selection, Wofi, application reloads, desktop configuration, or user-generated state. Those belong to desktop/session packages and the user cache.

Spectrum-owned package recipes consume immutable, checksum-verified source snapshots from `repo/sources/`. Incremental releases pin changed packages to their verified snapshot and retain matching evidence for unchanged artifacts. `scripts/build-source-archive --build` creates the canonical archive, derives its content revision, and hard-links it beside each recipe. Every PKGBUILD verifies the archive SHA-256 checksum and avoids monorepo-relative inputs.

Release artifacts are built with Arch `devtools` through `pkgctl build`. `scripts/spectrum-repo import-clean` verifies each artifact's embedded `.BUILDINFO`: the build tool must be `devtools`, its build paths must be `/build` and `/startdir`, and its recorded PKGBUILD checksum must match the current recipe. Only that verified set can receive `clean-chroot` provenance and pass the Testing promotion gate.

## Signed development repository

`scripts/spectrum-repo` creates an ignored development signing key, builds or imports the package set, signs every artifact, generates a signed pacman database, and records checksums and clean-build evidence in a signed snapshot manifest. `scripts/spectrum-repo-client` prints its actions by default and can explicitly configure a test machine against a local Edge repository. See `repo/README.md` for the commands and the production trust boundary.

## Hyprland defaults

Build `spectrum-hyprland` from the repository checkout so its recipe can consume the canonical files under `configs/hyprland`. The package runs Hyprland's configuration verifier before creating its artifact.

The package owns only immutable defaults under `/usr/share/spectrumos/hyprland` and its license. It does not own administrator machine policy under `/etc/spectrumos`, generated theme fragments, or user overrides. Those mutable layers remain preserved independently of package upgrades.

## Boot and login appearance

`spectrum-base` packages the restricted appearance staging helper, Limine synchronizer, system group, tmpfiles policy, and path unit. The synchronizer modifies global Limine appearance keys, normalizes exact Arch Linux menu headings to SpectrumOS, and creates a one-time adjacent backup. Kernel paths, modules, command lines, and custom boot entries remain outside its ownership.

`spectrum-sddm` packages the GPL-licensed legacy-derived QML theme with the Spectrum logo centered above the login form. Its `/etc/sddm.conf` is a Pacman backup file, while the wallpaper, semantic colors, and generated Spectrum logo are read from `/var/lib/spectrumos/appearance`.

`spectrum-plymouth` packages the 240-frame SpectrumOS intro animation and the `plymouth-boot-sync` configurator. The configurator idempotently inserts the Plymouth mkinitcpio hook and `quiet splash` into existing Limine kernel entries, preserving one-time backups. Selecting or updating the theme must be followed by a complete `mkinitcpio -P` transaction. The package does not replace Plymouth lifecycle units; it adds a bounded two-second `plymouth-quit.service` drop-in so fast systems display the animation long enough to recognize it. Plymouth then exits normally before the X11 SDDM server acquires the display.

## Desktop integration

`spectrum-desktop` owns the native Quickshell desktop and widgets, terminal integration fragments, Qt session environment, and the frontends under `/usr/lib/spectrumos`. Legacy Waybar/Wofi frontends are compatibility wrappers; the old daemons and static layouts are no longer installed. It depends on `spectrum-hyprland` and `spectrum-theme`, but does not duplicate their session defaults or generated palette files.

The package never writes a user home directory. User adoption remains a separate, non-destructive operation: it may reference package-owned terminal and environment fragments, while generated themes remain under the user cache. System boot/login appearance helpers remain owned by `spectrum-base`, `spectrum-sddm`, and `spectrum-plymouth`.

## Disposable VM harness

`scripts/vm-smoke` prepares an isolated QCOW2 disk and writable OVMF variable image without modifying the host boot configuration. Its default mode prints the complete QEMU command and creates nothing. `--prepare` creates state in `/tmp/spectrumos-vm` by default, and `--run` launches only previously prepared state. An Arch installation ISO can be attached with `--iso PATH`.

The harness selects KVM only when `/dev/kvm` is readable and writable. Otherwise it uses multithreaded TCG software emulation and reports that choice. SSH is forwarded to host port 2222 for later automated smoke checks. Graphical mode uses a virtio display for SDDM and nested Hyprland validation; `--headless` is available for installation and serial diagnostics.

After the official Arch ISO has booted, `scripts/vm-install-arch` can create the disposable baseline. It is guarded by the live-ISO root identity, the exact `/dev/vda` target, a bounded disk size, an unmounted-disk check, and the explicit `SPECTRUM_VM_INSTALL=1` environment variable. The resulting UEFI installation uses Limine, Btrfs subvolumes, NetworkManager, OpenSSH, and a temporary `spectrum` wheel account for repository validation.

## SpectrumDrop

`spectrumdrop` owns the maintained transfer and AWDL source from `integrations/spectrumdrop/`, its root-owned runtime under `/usr/lib/spectrumos/spectrumdrop`, the CLI, Polkit action, radio defaults and component license notices. It is a required desktop dependency and replaces the historical Omdrop integration packages. Build it before Desktop in a clean chroot. GoogleTest is a build dependency; all source is local and no submodule is fetched during the build. The package also ships the complete AWDL/radiotap source under `/usr/share/spectrumdrop/source/awdl`.

Installation migrations stop an existing legacy receiver, copy settings and identities without replacing existing SpectrumDrop state, preserve administrator radio profiles, and migrate only the legacy link-handler associations. An inactive legacy state directory does not trigger interface teardown. New installations keep receiving off and untested radio activation opt-in. The native widget and receiver behavior still require physical Mac retesting after migration. See [SpectrumDrop](spectrumdrop.md) and [source provenance](../integrations/spectrumdrop/PROVENANCE.md).

## Release readiness

Run `scripts/check-release` before building. It checks all nine selected recipes against their `.SRCINFO`, verifies every local source checksum, checks product/theme version agreement, and performs Bash recipe syntax checks. It never builds or publishes packages or an ISO. Cached binary downloads are excluded from the canonical monorepo source export; the Desktop recipe fetches and independently verifies those inputs. Source compression uses four workers by default, adjustable with `SPECTRUM_BUILD_JOBS=1..16`. Export atomically publishes a new archive or accepts an identical existing archive; different bytes under an existing immutable name are rejected.

Build the seven Spectrum-owned 1.0.0 packages against the new immutable source snapshot. Retain the pinned UKVM and managed portal artifacts only when their current recipes and clean-build evidence still match. Regenerate `.SRCINFO` after recipe changes with `makepkg --dir packages/NAME --printsrcinfo`.

After dependency-ordered clean-chroot builds, run `scripts/check-release --artifacts`. This additionally requires the exact package artifact named by every recipe and reuses the repository importer's `.BUILDINFO` checks for `devtools`, `/build`, `/startdir`, and the current recipe checksum. A source-only pass does not establish artifact readiness, signature validity, publication, or physical acceptance. Signing, repository promotion/publication and ISO creation remain separate actions.
