# Questline database corruption investigation — October 18, 2026

The local database was rolled back to the verified `questline_backup_20261017_154647.db` backup. The damaged original and a separate salvage candidate remain private under `~/.local/state/questline/recovery/20261019T011908Z/`. The salvage candidate was not installed. No Questline source, binaries, cloud data or published packages were changed during this investigation.

## Verified timeline

All times below are America/Cancun (UTC−05:00).

- October 17, 10:46:01: the last successful TUI startup recorded in `questline.log`.
- October 17, 10:46:47: the most recent complete backup passes full SQLite integrity and foreign-key checks.
- October 17, 11:20:08: the existing reminder process first reports SQLite error 11 in the user journal. This establishes detection time, not the exact time of the damaging write.
- October 17, 12:02:44: the pre-install Tree package database snapshot is already malformed.
- October 18: the dashboard package installation snapshots the same preexisting failure.

The recent dashboard release therefore did not introduce this corruption. An earlier raw database snapshot alone would not establish this, because copying an active WAL database is not a reliable backup; the live reminder process's independent error establishes that the active database was also malformed.

## Damage and code findings

The damaged database was last written by SQLite 3.45.0, according to its file header. Questline's locked `libsqlite3-sys` 0.28.0 dependency bundles SQLite 3.45.0; upgrading the operating system's sqlite package does not upgrade this embedded library.

This is structural page damage. Settings references page 3567 as a table leaf, but that page contains an index leaf. Presence has the same table/index mismatch at root page 79. These are not ordinary invalid task values or merely a missing index. Most task, project and note data remains readable. Salvage can misinterpret index row IDs as setting values, which is another reason it was not used as the replacement.

Questline uses WAL mode and several connections: the reminder service retains a headless application connection, shell actions create additional headless connections, and the TUI/cloud workers open connections and perform writes. Shutdown explicitly requests a truncating WAL checkpoint. The notifier yields to the TUI lock, but that does not serialize all database connections, shell actions or checkpoints.

SQLite documents a **WAL-reset corruption race** affecting versions through 3.51.2, fixed in 3.51.3 and later, with selected backports. It involves concurrent checkpoints and a write that resets the WAL. Questline's bundled version is affected, and its connection pattern supplies the required kind of concurrency. This is a concrete candidate, **not proof that this historical incident was that race**. The retained files do not include the WAL or transaction-level tracing from the damaging moment, and the race was not reproduced during this investigation.

Separately, CLI backup and several TUI backup paths use `std::fs::copy` on the live main database file. SQLite explicitly warns that live file copies can produce inconsistent backups or omit WAL transactions. This defect concerns backup reliability; no evidence was found that one of those copies was restored over the active database during the corruption window. It must not be presented as the demonstrated cause of damage to the original.

The available kernel journal in the 10:40–11:25 window contains no matching I/O, NVMe, Btrfs, corruption or OOM errors. Absence of a logged error does not exclude a storage or memory fault.

## Rollback validation and follow-up

The restored database contains 16 projects, 157 tasks and 161 notes. Full `integrity_check` returns `ok` and `foreign_key_check` returns no violations, both immediately after replacement and after the reminder process initializes. The installed dashboard adapter produces valid data. The reminder service remains active/running with zero restarts after restoration.

The backup predates newer XP/sync/history updates; those remain in the preserved damaged original and separate salvage candidate. No automatic merge or cloud reset was performed.

Before treating the underlying risk as resolved, upgrade Questline's bundled SQLite to a release containing the WAL-reset fix and replace raw live database copies with the SQLite backup API. Validate these changes against isolated profiles and concurrent write/checkpoint scenarios. A passing stress run cannot prove the historical cause or guarantee that a rare race never occurs.

Sources: [SQLite WAL-reset bug](https://www.sqlite.org/wal.html#walreset), [SQLite corruption mechanisms](https://www.sqlite.org/howtocorrupt.html), [SQLite online backup API](https://www.sqlite.org/backup.html).
