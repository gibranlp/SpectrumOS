# Dual-boot installer plan

Reviewed: 2026-10-25. Status: first alongside implementation prepared in source; published installation media unchanged.

## Implementation status

The GTK installer now defaults to **Install alongside**, with an explicit separate erase choice. The new storage helper discovers validated GPT partitions/free extents, creates deterministic plans tied to disk state, revalidates under a device lock, saves partition/firmware recovery records and allocates only two new partitions. Minimum allocation is 34 GiB: a 2 GiB dedicated ESP and at least 32 GiB Btrfs root. Firmware must be UEFI, Secure Boot positively disabled and EFI variables writable. Mounted storage, swap, active holders, LVM members, damaged/non-GPT tables and insufficient space are refused.

Alongside mode installs `EFI/SpectrumOS/limine.efi`, retaining the canonical `/boot/limine.conf` at the root of its dedicated ESP. Limine searches its own EFI volume first, so no duplicate configuration files or changes to existing boot/appearance helpers are needed. It creates a new firmware entry without deleting old entries and applies the reviewed boot-order choice. Same-disk Windows and common Linux EFI loaders are discovered read only. Firmware boot entries remain available when an unrecognized existing loader cannot be added automatically.

Recovery validates root/boot filesystem UUIDs, EFI PARTUUID, the boot ownership marker and the selected archive's owner before replacing boot files. The boot-time hook selects owned EFI storage by UUID instead of a potentially duplicated label. It retains the legacy path for existing installations, but refuses foreign EFI contents. Failed boot archive extraction attempts to restore the previous boot archive and root. The recovery menu selects EFI storage from the chosen root's ownership metadata or fstab and validates it before namespaced loader repair; BIOS-mode repair of an owned UEFI installation is refused. A final initramfs rebuild during alongside installation includes the updated hook.

Final verification: 199 passing checks with one ISO-creation fixture skipped, seven passing GTK scenarios and a passing UEFI chainload check. Available commands include `python -m unittest tests.test_installer_storage tests.test_installer_recovery tests.test_installer tests.test_live_installer tests.test_iso tests.test_rescue_shell tests.test_limine_windows_entry tests.test_snapshot tests.test_spectrumos_restore_hook tests.test_pre_upgrade_snapshot tests.test_limine_recovery_entry tests.test_mkinitcpio_register_hook tests.test_boot_appearance tests.test_spectrumos_build_rescue_image tests.test_lean_session`, `python scripts/check-installer-ui`, and `python scripts/check-installer-uefi`. The GTK check uses a private Broadway display; the UEFI check uses disposable GPT/FAT images and an executable EFI marker, not installed Windows/Linux systems. The ISO-creation regression is disabled by default and must only be enabled with explicit ISO-build authorization. Evidence is under `artifacts/dual-boot-review-20261025`.

Nine installer/recovery/appearance files were installed locally with exact source parity and backups under `/tmp/spectrum-dual-boot/before`. No host disk/firmware changes, installer launch, initramfs regeneration or service restart was involved. The local installer remains dependent on the source/repository bundle supplied by installation media for actual installation.

Before an ISO release, build/publish the matching core recovery package and complete actual UEFI alongside installations plus update/restore/reboot checks with Windows and representative Linux distributions. Physical firmware behavior, BitLocker/Secure Boot preparation and complete target installation remain acceptance gates. Guided resizing, selected-existing-partition installation, shared ESP reuse and BIOS/MBR alongside remain unimplemented. The following sections retain the original design and delivery roadmap.

## Review scope and current behavior

Reviewed the maintained GTK installer, privileged backend, Windows boot-entry helper, snapshot restore paths and boot configuration helpers. Also extracted and read the two installer programs from the existing local `artifacts/iso/spectrumos-1.0.0-20261015-x86_64.iso`, without mounting it or running its installer. That image has the same erase-only architecture described below. Its identity was not compared with the currently hosted download. Extraction metadata is in `artifacts/dual-boot-review-20261025/iso-inspection.json`.

| Component | Current behavior | Required change |
| --- | --- | --- |
| `installer/spectrum-installer` | Whole-disk selector; every installation passes `--confirm-erase` | Explicit installation modes, partition map, allocation controls and operation-specific confirmation |
| `installer/spectrum-installer-backend` | Lists whole disks; hardcodes partitions 1 and 2; runs whole-disk `wipefs` and `sgdisk --zap-all` | Separate discovery, plan validation and execution; preserve all partitions outside the approved operation |
| EFI setup | Formats a new ESP, mounts it at `/boot`, copies Limine to `EFI/BOOT/BOOTX64.EFI` | Dedicated Spectrum EFI storage and boot entry; preserve existing loaders and fallback paths |
| `scripts/limine-windows-entry` | Detects Windows EFI loaders on other disks; excludes the installation disk | Discover preserved same-disk loaders and other Linux EFI loaders |
| `scripts/snapshot`, initramfs restore hook | Archives and replaces the entire mounted `/boot` | Verify ownership of a dedicated Spectrum boot partition; prohibit whole-volume replacement on a shared ESP |

The current erase flow cannot safely become an alongside flow just by removing the erase confirmation. Partition creation, formatting, bootloader installation and later recovery all assume exclusive disk/boot ownership.

## Recommended first release

Support **UEFI systems with an existing GPT disk**, installing into a contiguous unallocated extent. Preserve Windows/Linux partitions, their EFI partition, recovery/OEM partitions and existing boot entries. Create a separate Spectrum EFI partition and a Btrfs root partition in the selected extent.

Keep these user choices distinct:

| Mode | Result | Delivery |
| --- | --- | --- |
| Install alongside an existing system | Allocate selected unallocated space; preserve existing partitions | First release |
| Erase disk and install | Explicitly replace the selected disk | Retain existing option, isolated execution path |
| Install into a selected partition | Format only a clearly selected target partition; allocate dedicated boot space separately | Follow-up after the alongside path is verified |
| Resize an existing system and install alongside | Shrink a supported filesystem and partition to create space | Later, filesystem-specific implementation |

First-release alongside mode must not silently fall back to erasing, resizing or converting the partition table. A full disk should explain how to create unallocated space and allow rescanning.

For Windows, initially direct users to shrink the volume using Windows Disk Management, then return to the installer. Microsoft documents this workflow and the limits imposed by unmovable files. Free space *inside* C: is not unallocated disk space. [Microsoft: shrink a basic volume](https://learn.microsoft.com/en-us/windows-server/storage/disk-management/shrink-a-basic-volume).

Do not promise support for resizing every distribution. The filesystem, encryption and storage layout determine what can be resized. GParted's capability table, for example, lists no shrinking support for BitLocker or XFS. [GParted filesystem capabilities](https://gparted.org/features.php).

## Discovery and planning backend

1. Produce structured disk/partition discovery: stable device identity, disk GUID, capacity, logical/physical sector sizes, partition starts/ends, types, PARTUUIDs, filesystem UUIDs, mounts, active swap, holders and aligned unallocated extents. Use tools such as `lsblk`, `blkid` and `sfdisk --json`; avoid parsing display text.
2. Identify the live medium and all backing-device ancestors. Refuse it as an installation target. Reject conflicting mounts, active swap, read-only devices, invalid GPT layouts and unsupported storage configurations before planning writes.
3. Discover existing EFI loaders and OS labels without executing installed programs or enabling filesystem journal replay. Preserve unrecognized partitions. Encrypted installations may have a discoverable loader even when their root filesystem cannot be identified.
4. Generate a backend-owned operation plan containing exact partitions/sectors to create, format and mount; preserved partitions; boot changes; size checks; and a digest of the observed disk state. Keep preview/dry-run behavior as the default.
5. Revalidate disk identity, geometry, partition UUIDs and affected filesystem state immediately before applying the approved plan. Reject stale plans after a rescan, external partition-tool change, hotplug or device renumbering. The privileged process must validate the plan independently of the GUI.
6. Isolate whole-disk erase commands behind erase mode. Alongside mode may create partitions only inside its approved free extent. Selected-partition mode may format only its explicitly approved target. Use argument arrays and validated values rather than GUI-supplied command strings.

Allocate Spectrum partition numbers dynamically; they need not be 1 and 2. Align by sectors correctly on both 512-byte and 4 KiB devices. Keep the current Btrfs `@`, `@home` and `@snapshots` layout and UUID-based mounts.

The current 20 GiB check measures the entire disk. Replace it with a check of the actual allocated root space, chosen package profile, installation workspace and update headroom. Size the dedicated ESP for installed kernels, fallback initramfs, rescue image and future updates; validate whether the present 1 GiB allocation is sufficient instead of assuming it is.

## Bootloader and recovery requirements

- Keep Spectrum's `/boot` on its own new ESP for the initial release. This fits the existing kernel/rescue layout and avoids writing large kernel files into a small Windows ESP. Validate multiple-ESP firmware behavior before release; do not assume every firmware selects the intended partition reliably.
- Install a namespaced loader such as `EFI/SpectrumOS/limine.efi` with a matching configuration in its directory. Limine documents configuration lookup beside the EFI executable. Keep generated configuration, appearance, rescue and update helpers consistent with that canonical location. [Limine configuration reference](https://github.com/limine-bootloader/limine/blob/trunk/CONFIG.md).
- Register a Spectrum UEFI firmware entry, preserve unrelated entries and record the original boot order. Let the installer explain and select whether Spectrum becomes the default. Do not replace another system's `EFI/BOOT/BOOTX64.EFI`. On a Spectrum-owned ESP, any fallback loader must still be explicitly planned and firmware selection verified.
- Add Windows Boot Manager and existing Linux EFI loaders to the Spectrum menu using stable partition identifiers. Preserve other distributions' loader files and configuration; chainload their existing bootloader. Remove the target-disk exclusion only for preserved partitions in alongside mode; retain appropriate exclusions for erase mode.
- Detect Secure Boot and firmware-mode mismatches before installation. An unsigned or otherwise incompatible loader must produce an actionable block, not a supposedly successful installation. Signing/enrollment support needs its own verified design.
- Explain Windows recovery-key preparation and protection suspension when boot changes require it. Never resize a BitLocker volume in this release or require decrypting an untouched Windows volume merely to use separate free space. [Microsoft BitLocker guidance](https://learn.microsoft.com/en-us/troubleshoot/windows-client/windows-security/suspend-bitlocker-protection-non-microsoft-updates).
- Store and validate Spectrum boot/root ownership and UUIDs in installation metadata. Both normal and initramfs restore must refuse a foreign/shared boot volume. Verify update, rescue and rollback paths preserve all other systems after installation.
- Before writes, save partition records, relevant EFI files and firmware-entry state to a recovery destination outside the affected storage, with exportable recovery instructions. Such records cannot recover filesystem data lost during a failed shrink. Do not describe partitioning or resizing as an atomic transaction.

Shared-ESP reuse is a separate later design: it requires changing whole-`/boot` archive/restore behavior and boot file placement across all helpers. It must not be enabled by the first alongside implementation.

## Installer flow

1. Choose disk; display detected systems, capacity and partition map.
2. Choose installation mode. Offer alongside only when a supported layout and sufficient usable space exist.
3. Select free extent and Spectrum allocation. Display a before/after partition map, with existing partitions marked as preserved and new partitions labelled.
4. Complete the existing account, hardware and Full/Lean choices.
5. Show a final operation summary: exact disk identity, partitions created/formatted, preserved systems, boot-menu changes and required preparation. Confirmation text must match the selected mode.
6. Apply the reviewed plan with progress and persistent diagnostic output. On failure, identify completed operations and recovery options; never continue with an erase fallback.

Advanced manual partitioning should follow the same plan/validation path. If an external partition editor is offered, discard the previous plan and rediscover the disk afterward.

## Guided resizing follow-up

Implement one supported filesystem/layout at a time. Probe minimum safe size and filesystem health; calculate realistic headroom; require an appropriate clean/unmounted state and recovery preparation. Shrink the filesystem before shrinking its partition. Do not move partition starts in the initial resizing implementation.

Consider plain ext4 first after offline checks; evaluate plain NTFS separately with clean shutdown, hibernation/Fast Startup and dirty-volume handling. Keep BitLocker, LUKS, LVM, RAID, dynamic disks, multi-device Btrfs, unsupported filesystems and legacy BIOS/MBR outside automatic resizing until explicitly designed and verified. Existing systems using these layouts may still coexist untouched when the separately allocated installation layout is supported.

## Delivery order and release gates

1. **Discovery and plan preview:** structured backend, GUI maps, fixtures and stale-plan protection; no installation writes.
2. **UEFI/GPT alongside:** unallocated-space allocation, dedicated ESP, boot discovery, recovery ownership checks and end-to-end installation.
3. **Selected-partition/manual allocation:** exact-target confirmation and the same preservation checks.
4. **Guided resize:** filesystem-specific support with independent failure/recovery verification.

Future verification must cover Windows and representative GRUB/systemd-boot Linux installations; same-disk and separate-disk setups; NVMe/SATA and 512e/4Kn layouts; constrained ESPs; missing firmware-variable access; live-medium rejection; changed disks; unsupported encryption/hibernation states; interruption; and Full/Lean selections. Use disposable disk images/VMs before hardware checks.

Release requires both systems to boot before and after Spectrum kernel updates, rescue boot and snapshot restore. Compare untouched partition boundaries/UUIDs and foreign boot-file hashes; verify the requested firmware boot order. Confirm rejected plans perform no installation writes.

The original review performed no tests or installation writes. Subsequent implementation checks may write only disposable test images and temporary fixtures. ISO creation remains a separate action requiring explicit authorization.
