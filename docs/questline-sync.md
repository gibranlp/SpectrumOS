# SpectrumOS Sync and profile controls

Open the SpectrumOS **Questline** widget and select **Sync**. The new tab uses Questline's local services and the same per-PC settings as the terminal's `[8] Sync` screen. No web app is involved.

- **Cloud Sync** switches between hosted encrypted sync and local-only use.
- **Auto Sync** enables or pauses background publication and pulling. Pausing does not discard local changes. The running TUI reads the same flags, so its settings follow widget changes.
- **Sync Now** performs an incremental sync even with Auto Sync off, as long as Cloud Sync is enabled and the profile is not on a recovery hold.
- Status shows pending changes, deferred/quarantined events, the latest successful sync, errors, the desktop service state, and known devices.
- **Export profile** saves the full profile with private identity metadata directly to your Downloads folder (respecting the system download-folder setting). Each export gets a unique dated filename, so previous exports are preserved. The widget stays open and shows the saved path without a file dialog. With Cloud Sync enabled, it also uploads an independent encrypted recovery snapshot. A private Transfer Code is shown only after the cloud upload succeeds. A failed cloud upload leaves the local export intact and reports the failure.
- **Create backup** creates a consistent private SQLite backup under the active profile's `backups/` directory. It also uploads an encrypted recovery snapshot when Cloud Sync is enabled. Local-only backups work offline.
- **Restore file** previews a saved SQLite backup or JSON profile export. **Restore cloud backup** previews the latest recoverable state for the current identity. **Restore identity** accepts a private Transfer Code to preview another saved identity's cloud profile.
- **Prune tasks** previews completed private quests/steps older than 30 days. Shared campaigns and branches with unfinished or recently updated steps are preserved. Confirmation creates a local backup, then deletes only the previewed eligible rows and queues deletion tombstones for sync.

Backup, export, sync and restore operations show an animated activity bar,
the current operation stage and elapsed time. The timer pauses while a restore
or prune preview waits for confirmation. Questline currently does not report
byte totals or measured completion progress for these operations, so remaining
time is shown as unknown rather than an estimated percentage or countdown.

Restore and prune require a second confirmation in the panel. Cancel leaves the active data intact. Close the Questline terminal before either operation; the profile-use lock prevents the TUI from editing through a replacement. A restore is staged and validated off to the side and canceled if local data changes during the preview/download. Activation backs up the current database, preserves the destination device identity and local Cloud Sync preference, and leaves Auto Sync off for review. Enable it after checking the restored data.

The widget archives old drafts before switching profiles, and archive errors preserve and block old drafts rather than replaying them into the new profile. Shell mutations carry a profile binding; an old widget cannot save into a newly restored profile. The reminder service refreshes its cached profile after activation. Transfer Codes are sent over standard input, never command arguments, and are not saved in the widget draft store. Hiding the Sync panel clears its displayed code and restore input. Copying a code uses the system clipboard only when explicitly requested.

`questline sync-json` is the JSON-lines interface used by `/usr/lib/spectrumos/questline-sync-control`. Interactive restores and pruning hold a prepared operation, emit a preview with a random confirmation token, and accept one confirmation/cancel line. EOF cancels; arbitrary or stale confirmation values do not activate a restore. Local export/backup failures and cloud failures are reported separately.

The desktop service is `spectrum-questline-sync.service`. It stays running while automatic sync is paused and observes the stored preferences. The panel reports a missing/inactive service rather than implying successful background delivery.

## Recovery hold on another PC

**Recovery hold — restore before enabling sync** means the local database has
`sync_restore_hold=1`. Both Auto Sync and Sync Now are intentionally blocked.
Cloud Sync is a separate preference; toggling it does not clear the hold.
Questline can set this hold after detecting a copied database from another PC,
legacy JSON imports, automatic identity recovery, or local sync-history cleanup.
The message alone does not identify which operation caused it.

To reconnect the PC:

1. If it contains unique local changes, use **Export profile** first and keep the
   exported file. A restore replaces the local profile rather than merging it.
2. Close the Questline terminal. Enable **Cloud Sync**, then select **Restore
   cloud backup…** for the identity already on this PC.
3. Review the incoming profile preview and confirm only if it is the intended
   profile. To use the identity from another PC instead, create a backup/export
   there and use its private Transfer Code with **Preview identity restore**.
   A saved profile file can also be previewed with **Restore file…**.
4. Check the restored data, then enable **Auto Sync** or use **Sync Now**.

The widget's confirmed restore clears the hold and leaves Auto Sync off for
review. If the restore fails or the preview is wrong, cancel and retain the
export; do not manually delete the hold setting to force synchronization.

Available in Questline 2.0.3 and SpectrumOS Desktop 1.0.0-17.
