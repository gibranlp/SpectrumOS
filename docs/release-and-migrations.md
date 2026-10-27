# Release and migration metadata

SpectrumOS publishes immutable release identity at `/usr/share/spectrumos/release.toml` and an ordered migration manifest at `/usr/share/spectrumos/migrations/manifest.toml`. Both formats carry an integer schema version and are owned by `spectrum-base`.

The release record describes the installed SpectrumOS product version and channel independently of Arch's `/etc/os-release`. SpectrumOS remains Arch-based and does not replace upstream operating-system identity files during the development milestone.

Each migration has a stable, monotonically ordered identifier, source and target versions, explicit preconditions, a completion marker, verification text, and rollback support notes. Package metadata is immutable; successful completion is recorded separately below `/var/lib/spectrumos/migrations/`. A migration must be safe to evaluate repeatedly and must treat an existing, valid completion marker as success.

The initial `0001-release-foundation` entry is declarative. Installing its package-owned files satisfies its verification contract, and `sudo spectrum migrate apply` records completion after checking every pending migration's preconditions. Declarative mode has no arbitrary command field: the executor only validates package and path state, then writes the completion record.

The executor takes a non-blocking process lock, refuses active or interrupted Pacman transactions, validates the complete ordered set before writing any state, and creates each marker through a same-directory fsynced atomic replacement. A valid marker records schema version, migration ID, target release, and a timezone-qualified completion timestamp. Repeated application is a successful no-op; malformed markers, symlinks, unknown package versions, missing preconditions, and a completed migration after an earlier pending entry fail closed.

`sudo spectrum migrate rollback ID --confirm ID` removes only the newest completed marker when that migration declares rollback support. It never guesses an identifier, skips a later completion, or reverses package files. For the declarative release-foundation migration, package-owned metadata follows package rollback while the executor reverses only its external completion record. Repeated marker rollback is also a successful no-op.

The Python `spectrum info` prototype reads the release record and reports support-relevant facts without machine IDs, network addresses, usernames, hostnames, serial numbers, or home-directory paths. `spectrum info --json` provides stable field names for diagnostics and future support tooling.

`spectrum doctor` is also read-only. It reports eight bounded checks with `pass`, `warn`, or `fail` status: release metadata, Spectrum package integrity, failed system and user units, desktop portals, PipeWire/WirePlumber, root filesystem usage, Btrfs snapshot support, and Limine configuration. Human output uses matching labels and `--json` emits schema version 1. A failed check returns status 1; warnings alone return status 0. The normal session-user run checks portals and audio. An optional root run adds the count of complete restore points plus access to a protected boot configuration and marks user-session checks as deferred instead of treating root's missing user manager as a failure.

Normal widget updates do not automatically invoke `spectrum doctor`. Package transactions, ordered migrations and requested Flatpak updates retain their own failure statuses. Manual health checks remain available independently; user-session Limine permission warnings and locally modified package files do not turn a completed update into a failed transaction.
