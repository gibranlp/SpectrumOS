# Update snapshots and recovery

SpectrumOS creates a paired restore point before a system upgrade when `/` is a Btrfs subvolume. The prototype command is `spectrum-snapshot`.

## Restore-point boundary

A restore point contains:

- a read-only snapshot of the mounted root subvolume;
- an archive of the matching EFI `/boot` contents;
- the complete installed package list and filesystem metadata.

The Spectrum installation layout keeps `/home`, `/var/log`, and `/var/cache/pacman/pkg` in separate subvolumes. They are intentionally not rolled back with system state. User files therefore survive a system rollback, logs retain the failure record, and the package cache remains available for recovery.

The `/boot` archive and root snapshot are one restore point. Restoring only one side can combine an incompatible kernel, initramfs, and module tree and is unsupported.

## Commands

```sh
spectrum-snapshot status
sudo spectrum-snapshot create --label pre-upgrade
sudo spectrum-snapshot list
sudo spectrum-snapshot check <restore-point-id>
sudo spectrum-snapshot plan <restore-point-id>
```

Creation requires root because it mounts the Btrfs top level temporarily under `/run/spectrumos/`. Snapshots live below `@snapshots/spectrumos/` and are not part of the active root subvolume.

## Automatic pre-upgrade snapshot

`system/pacman-hooks/05-spectrumos-pre-upgrade-snapshot.hook` runs `spectrum-snapshot create --label pre-upgrade` as a `PreTransaction` hook on every Pacman `Upgrade` operation, so a restore point exists before packages change without anyone remembering to run `spectrum-snapshot create` by hand. A root that does not support Btrfs restore points is not a failure: the hook prints a notice and the upgrade proceeds without a snapshot, exactly as before this hook existed. A real failure (for example, no free space) uses the hook's `AbortOnFail` key to stop the transaction instead of upgrading without a safety net.

This only closes the "did I forget to snapshot" gap. It does not create, and does not imply, an automatic rollback: recovering from a bad update below still means booting recovery media and running `spectrum-snapshot restore`, because replacing the root subvolume a running system is booted from cannot be done safely while it is mounted.

The same hook runs `spectrum-snapshot enforce-cap --limit 3` right after a successful snapshot, deleting anything older than the newest 3 restore points regardless of the daily/weekly/monthly windows below. This is a hard, automatic ceiling for unattended systems, deliberately simpler than the conservative retention policy; `enforce-cap` is not meant for interactive use, and `retention`/`prune` keep their existing, more conservative meaning unchanged.

## Boot-menu recovery (no USB required)

`system/initcpio/hooks/spectrumos-restore` is an early-boot hook: before the real root is ever mounted, it checks the kernel parameter `spectrumos.restore=`, and if present, promotes a restore point to a new writable `@` and restores the matching `/boot` archive, then lets boot continue normally. This is the same operation `spectrum-snapshot restore` already performs, moved to the one moment in a normal boot where it can run without recovery media: the point before `@` is mounted as `/`.

This hook is never added to the system's real `/etc/mkinitcpio.conf`, and the default kernel images are never rebuilt to carry it. `scripts/spectrumos-build-rescue-image` instead builds it into a dedicated, separate image (`/boot/EFI/Linux/spectrumos-rescue.efi`), from a private copy of the mkinitcpio config (`/etc/mkinitcpio-spectrumos-rescue.conf`) and a dedicated preset (`/etc/mkinitcpio.d/spectrumos-rescue.preset`). A bug in the rescue hook can therefore only break the rescue entry, never a normal boot — the default `arch-linux-*.efi` images and `/etc/mkinitcpio.conf` are provably untouched by this feature, which is what made it safe to enable without the disposable-VM boot testing that would otherwise be required before touching shared boot state.

`scripts/limine-recovery-entry` adds one Limine entry, "SpectrumOS (Restore Last Good Snapshot)", pointing at that dedicated image, with `spectrumos.restore=latest`. It never needs regenerating as restore points are created or pruned, because the restore point is resolved at boot time, not baked into the entry.

**The rescue image itself must be rebuilt on every kernel upgrade**, or it keeps booting whatever kernel it was last built against — including that kernel's *module directory*, which a normal kernel upgrade deletes. Spectrum prepares a normal mkinitcpio preset on first installation. Arch's package-owned `90-mkinitcpio-install` post-transaction hook then rebuilds that preset together with the normal kernel presets whenever a kernel or initcpio hook changes. Keeping this at the post-transaction stage matters: Pacman temporarily removes the old kernel image before installing its replacement, so a package-level `post_upgrade` rebuild can run too early during a combined kernel and Spectrum update.

**Known limitation:** if a kernel upgrade is the specific thing a rescue boot is recovering *from* (i.e. the broken update also changed the kernel), the rescue image built *before* that upgrade still reflects the pre-upgrade kernel, which is exactly what you want to boot back into. If instead a *later*, unrelated kernel upgrade lands after the restore point you want was taken, the rescue image will have moved on to that newer kernel while the restore point's own root predates it — `/boot` is restored to match the restore point before boot continues, so a second, ordinary reboot afterward is fully consistent again either way.

**Status: implemented and enabled.** `spectrum-base.install` prepares the dedicated preset on installation and upgrade and maintains the Limine entry; Arch's standard post-transaction hook handles image builds. A destructive Btrfs VM boot proved that selecting "Restore Last Good Snapshot" restores paired root and EFI state, preserves the failed state, and leaves the following ordinary boot unaffected.

`check` verifies the metadata schema, package record, read-only Btrfs property, and boot archive. `plan` prints the recovery contract only; it does not mutate the running system.

## Rollback safety

The restore command refuses the block device that backs its currently running root. From recovery media, use the exact root and EFI devices shown by `lsblk -f`, and confirm the full restore-point identifier:

```sh
sudo spectrum-snapshot restore <restore-point-id> \
  --root-device /dev/vda2 \
  --boot-device /dev/vda1 \
  --target @ \
  --confirm <restore-point-id>
```

Restore preserves the failed root below `@failed/spectrumos/`, archives the pre-restore EFI contents beside it, creates a writable `@` from the selected read-only snapshot, and restores the paired boot archive. If root creation or boot extraction fails, it attempts to put both the original root and EFI contents back before returning an error.

Interrupted-transaction recovery passed destructive VM testing. Update execution now applies ordered migrations only after a successful package transaction and still runs health checks when either stage fails.

## Retention policy

`sudo spectrum-snapshot retention` classifies complete restore points without deleting anything. `--json` emits schema version 1. The policy retains:

- the newest 3 restore points;
- the newest point in each of the last 7 UTC calendar days;
- the newest point in each of the last 4 ISO calendar weeks;
- the newest point in each of the last 6 UTC calendar months;
- every restore point whose future metadata explicitly marks it as protected.

A restore point selected by none of those rules is reported as a candidate and is never removed automatically. `sudo spectrum-snapshot prune ID --confirm ID` deletes exactly one current candidate. It refuses retained or protected points, requires the full identifier twice, and validates the root snapshot, metadata, package record, and boot archive immediately before mutation.

Pruning first moves the complete restore point atomically below the private `.pruning` directory. If deletion is interrupted, the point no longer appears as usable and the same exactly confirmed command resumes it from quarantine. No wildcard, age-only, bulk, or implicit deletion interface exists. Synthetic coverage and destructive Btrfs VM validation both pass, including exact-confirmed deletion and resumption from a manually interrupted quarantine.

## Dry-run update plan

`spectrum update plan` inspects the future transaction without refreshing repositories, downloading packages, creating snapshots, writing migration state, or invoking Pacman mutation. `--json` emits schema version 1.

The plan validates release and migration metadata, checks at least 5 GiB of free root space, refuses an existing Pacman database lock, and detects an unmatched transaction start in Pacman's ALPM log. It also confirms Btrfs snapshot capability, lists pending official packages from the current local sync database, separates locally built Spectrum packages from other foreign packages, and evaluates migration preconditions and completion markers in manifest order. Missing transaction history is reported as unknown rather than silently treated as clean.

A clean preflight means the transaction is internally consistent and `ready_for_execution` is true. Snapshot retention, interrupted-transaction recovery, and ordered atomic migration execution have destructive VM coverage. The interactive update runner still requires explicit confirmation, relies on Pacman's pre-transaction restore point, applies migrations only after a successful package transaction, and reports post-transaction health.
