# Production repository ceremony

## October 27 Desktop 1.1.0 package update

Stable snapshot `20261028T0035550000-84da1c1b057c6f3f` publishes Desktop **1.1.0-1** with the corrected island and widget curves, restored notification placement, compact Detailed bar controls and More menu, and startup restoration of Auto/Dark/Light selection. The other eight package artifacts are unchanged. Immutable source revision: `2fdeff3a7ac14a39`; archive SHA-256: `1c81a59793fa8e1921ba8091f5c60217091160f4fc0c8bcc8759a0f817db47fb`. The source archive retains the system release version 1.0.0; Desktop has its own package version.

Desktop was rebuilt in an Arch Devtools clean chroot with `--nocheck`, production-signed, and published directly to Stable. No test suites ran for this deployment, as requested by the owner. Remote checksums and HTTPS package, database and signed manifest delivery were verified. Testing and the website remain unchanged; no ISO was built or published. The changes were already deployed locally. Evidence: `artifacts/package-release-20261027-desktop-1.1.0`. Existing installations update through Updates or `sudo pacman -Syu`.

## October 27 widget update

Stable snapshot `20261027T2250170000-c2ea4ab7a168b833` publishes Desktop **1.0.0-28** with pointed widget attachment curves, Questline campaign navigation and Markdown viewing, the combined song and volume display, and compact installed/update package versions. The other eight package artifacts are unchanged. Source revision: `f94dee510fe5a8c7`; archive SHA-256: `aa5989778c4c2e3c31f5df85fa13de4578399da4a88139ce912a405bb08c36e1`.

Desktop was rebuilt in an Arch Devtools clean chroot with `--nocheck`, then production-signed and published directly to Stable. Test suites were skipped at the owner's request. Server artifact checksums and HTTPS package, database and signed manifest delivery were verified. Testing and the website are unchanged; no ISO was built or published. The previously deployed local widget files match the source and SpectrumShell remains active. Evidence: `artifacts/package-release-20261027-widgets`. Existing installations update through Updates or `sudo pacman -Syu`.

## October 25 package-only Stable update

Stable snapshot `20261025T2311430000-106e5134679bc151` publishes Base **1.0.0-5**, Hyprland **1.0.0-12** and Desktop **1.0.0-26**. It includes the recovery safeguards, Default Apps widget, configurable file-search locations and updated widget shortcuts. Other package versions are unchanged. Matching source revision: `364d2aae1bf13dfa`; archive SHA-256: `ab31c3355927f50efc39301a484ccd4c137ddabaede9254a2551dcddf7195775`.

Publication used the existing clean-chroot packages and prior validation evidence. No further tests or rebuilds ran at the owner's request. Full server checksums and HTTPS release metadata/database delivery passed verification. Testing is unchanged. The owner clarified packages only: the partial ISO staging upload was canceled and removed before publication, and the public ISO and download page were preserved. Evidence: `artifacts/stable-v1.1-20261025`.

SpectrumOS production packages use an offline Ed25519 certification key and a separate, expiring Ed25519 signing subkey. The primary secret key never enters the development workstation, build worker, web server, ISO tree, or repository checkout. Pacman trusts the primary public fingerprint; repository automation signs with and verifies the designated subkey fingerprint.

Do not perform this ceremony merely to test the workflow. Use disposable keys for rehearsals. The real ceremony begins only after the repository domain and responsible key custodians are settled.

## 1. Prepare the offline ceremony

Use a freshly installed computer that remains disconnected from every network. Prepare two encrypted removable backups and a third removable transfer device. Record the date, participants, GnuPG version, device identifiers, and every command in a paper or append-only ceremony log.

Create a private GnuPG home on the first encrypted device:

```bash
ceremony_gnupg=/media/spectrum-root-primary/spectrumos-production-gnupg
install -d -m 0700 "$ceremony_gnupg"
export GNUPGHOME="$ceremony_gnupg"
gpg --quick-generate-key \
  "SpectrumOS Repository Root <repository@gibranlp.dev>" \
  ed25519 cert 5y
```

Protect the key with a strong unique passphrase when Pinentry requests it.

Display and independently transcribe the complete 40-character primary fingerprint:

```bash
gpg --with-colons --fingerprint --list-keys
```

Add a separate Ed25519 signing subkey with a one-year lifetime:

```bash
gpg --quick-add-key PRIMARY_FINGERPRINT ed25519 sign 1y
gpg --with-colons --with-subkey-fingerprint --list-keys PRIMARY_FINGERPRINT
```

Independently transcribe the complete signing-subkey fingerprint. Do not use a 16-character key ID as either identity.

## 2. Export and back up

Export the public key, a revocation certificate, a complete encrypted secret-key backup, and an online signing-subkey transfer:

```bash
gpg --armor --export PRIMARY_FINGERPRINT > spectrumos-production.asc
gpg --output spectrumos-production-revocation.asc --gen-revoke PRIMARY_FINGERPRINT
gpg --armor --export-secret-keys PRIMARY_FINGERPRINT > spectrumos-production-root-secret.asc
gpg --armor --export-secret-subkeys PRIMARY_FINGERPRINT > spectrumos-production-online-signing-secret.asc
sha256sum spectrumos-production*.asc
```

Copy the complete secret backup, revocation certificate, ceremony log, and checksums to both encrypted backup devices. Store the two devices in separate secure locations. The transfer device may contain the public key and signing-subkey export temporarily; it must not contain the complete primary secret export.

Power off the offline computer before connecting the transfer device to any online system.

## 3. Audit the public key

On the development workstation, copy only the public key and two fingerprint text files into `repo/keys/`. Audit the relationship before changing repository configuration:

```bash
scripts/spectrum-repo key audit-public \
  --public-key repo/keys/spectrumos-production.asc \
  --primary-fingerprint PRIMARY_FINGERPRINT \
  --signing-fingerprint SIGNING_SUBKEY_FINGERPRINT \
  --require-separated-signing-key
```

Two people should compare the displayed primary fingerprint against the offline record. Publish that same primary fingerprint through at least two independent locations, such as the official website and the release announcement.

## 4. Provision the online signer

The online signer is a restricted build/signing machine, not the HTTPS file server. Create its GnuPG home outside the repository checkout and web root, import the public key and the secret signing-subkey export, then remove the transfer file:

```bash
signer_gnupg=/var/lib/spectrumos-signing/gnupg
sudo install -d -m 0700 -o "$USER" -g "$USER" "$signer_gnupg"
export GNUPGHOME="$signer_gnupg"
gpg --import spectrumos-production.asc
gpg --import spectrumos-production-online-signing-secret.asc
gpg --with-colons --with-subkey-fingerprint --list-secret-keys PRIMARY_FINGERPRINT
```

The listing must show a secret signing subkey and only a stub for the primary secret key. Securely erase the transfer copy according to the storage device's supported procedure.

Set `SPECTRUM_REPO_GNUPGHOME` to this external directory only for signing operations. Never commit it or copy it into an ISO:

```bash
export SPECTRUM_REPO_GNUPGHOME=/var/lib/spectrumos-signing/gnupg
```

## 5. Activate production trust

Activation is a reviewed source change. Update `repo/config.toml` to reference:

- `repo/keys/spectrumos-production.asc` as `public_key`;
- a file containing the primary fingerprint as `fingerprint_file`;
- a file containing the signing-subkey fingerprint as `signing_fingerprint_file`.

Update the installer and repository client to embed that production public key and primary fingerprint. Build a new immutable source archive and all packages in clean chroots. Import the artifacts, verify the signed Edge snapshot, promote it to Testing, and test an update from the real HTTPS endpoint before Stable promotion.

## 6. Publish without exposing signing keys

The HTTPS origin receives only public repository files. It must never receive a GnuPG home or secret-key export. Upload a complete snapshot to a temporary versioned prefix, verify its checksums there, and atomically change the channel pointer only after verification. Retain the previous Stable snapshot for rollback.

For the confirmed `spectrum.gibranlp.dev` shared-hosting account, preview publication with:

```bash
scripts/spectrum-repo-publish testing
```

After production trust is active and the dry run identifies the intended snapshot and destination, publish with exact confirmation:

```bash
scripts/spectrum-repo-publish testing --apply --confirm testing
```

The remote root is `/home2/gibranlp/spectrum.gibranlp.dev/repo`. Releases are immutable versioned directories, while `edge`, `testing`, and `stable` are atomic symlinks to the selected release. The publisher verifies all manifest-listed files plus the manifest and its detached signature after transfer and before moving the channel link.

Before the first public release, test all of these cases:

- a valid installation and full upgrade;
- rejection of a modified package;
- rejection of a modified or unsigned database;
- rejection of a snapshot signed by an unapproved subkey;
- signing-subkey expiration and rotation;
- primary-key revocation recovery;
- interrupted upload that leaves the previous channel untouched.

Stable remains closed until the real HTTPS origin, production-key audit, independent fingerprint publication, and these tests are complete.

## Current status

Published **Stable only**: spectrum-base 1.0.0-4, spectrum-theme 1.0.0-4, spectrum-hyprland 1.0.0-11, spectrumdrop 1.0.0-5, spectrum-desktop 1.0.0-25. Snapshot `20261025T0318180000-e928320aba1f6f94` includes today's shell/widget productivity and memory updates, theme pipeline improvements, SpectrumDrop transfers and update-flow fixes. All five clean-chroot packages have verified production signatures, source/payload parity and HTTPS checksums; the other four package artifacts and all of Testing are unchanged.

The selected 17 isolated Lean checks and complete 816-package dependency plan pass; broad suites remained disabled. Source `spectrumos-source-1.0.0-a448d6c9e778e350.tar.zst` includes future Lean installer corrections. Existing ISO unchanged; no ISO build/upload. Signed HTTPS packages were installed locally with preserved settings and verified shell/services. Update through Updates or `sudo pacman -Syu`. Evidence: `artifacts/stable-all-updates-20261024`.

Published Desktop **1.0.0-24** and Hyprland **1.0.0-10** to **Stable only**. Removes the redundant standalone Calendar widget, its IPC/command entries and Super+Shift+C shortcut; the dashboard calendar and Questline date picker remain available. All earlier updates are included; other seven package artifacts are unchanged. Update through Updates or `sudo pacman -Syu`.

Snapshot `20261024T1816360000-2ca9d55fb0f9c1fc` has verified production signatures and remote/HTTPS checksums. Public/local Testing unchanged. Signed downloads installed locally with matching payloads, preserved settings and active Shell/Hotkey/Sync. Tests skipped (`--nocheck`); no ISO build/upload. Evidence: `artifacts/package-release-20261024-calendar`.

Published Desktop **1.0.0-23** and Hyprland **1.0.0-9** to production-signed **Stable only** at https://spectrum.gibranlp.dev/repo/stable/x86_64. Includes display/screensaver/logout fixes, recording/Focus integration, Questline task fields/live refresh, calculator chaining and conversions, volume/brightness/song popups, WIN60 lighting/WebHID permissions and immediate theme RGB sync. Other seven package artifacts are unchanged. Update through Updates or `sudo pacman -Syu`.

Stable snapshot `20261024T1747490000-1b82688ef11c249e` has verified production signatures and remote/HTTPS checksums, including both immutable source archives. Public and local Testing remain byte-identical; neither Testing nor Edge was published. Installed both signed packages locally with matching payloads, preserved settings and active Shell/Hotkey/Sync. Tests skipped (`--nocheck`); no ISO build/upload. Evidence: `artifacts/package-release-20261024`.

Earlier release records follow.

Published Desktop **1.0.0-22** to production-signed **Stable only** at https://spectrum.gibranlp.dev/repo/stable/x86_64. Includes Favorites browser actions and Save/layout fixes, compact color swatches/copy notifications, monitor-aware widgets/window titles, and Focus countdowns with the integrated Minimal recording corner. Other eight package artifacts are unchanged. Update through Updates or `sudo pacman -Syu`.

Stable snapshot `20261023T0233210000-aaa7b3de86f0666e` has verified remote/HTTPS checksums and production signatures. Public and local Testing remain unchanged at Desktop **1.0.0-21**; no Testing promotion or publication was performed. Installed the signed Stable download locally with matching payloads, preserved settings and active Shell/Hotkey/Sync. Tests skipped (`--nocheck`), no ISO build/upload. Evidence: `artifacts/package-release-20261022-stable-widgets`.

The preceding release records are retained below.

Published Desktop **1.0.0-21** to production-signed Testing and Stable at https://spectrum.gibranlp.dev/repo. This adds the shared widget focus fix for games holding a pointer lock. All other package payloads remain unchanged, including Hyprland **1.0.0-8** and Theme **1.0.0-3**. Existing installations update through Updates or `sudo pacman -Syu`.

Testing `20261022T1855350000-1db80770e5272b53` and Stable `20261022T1855350000-46c3f2a9d275067f` have identical signed inventories. Remote checksums and HTTPS readback are verified. The signed Testing Desktop download is installed locally, settings are preserved, and Shell/Hotkey/Sync are active. Tests were skipped as requested; packaging used `--nocheck`. The ISO is unchanged. Evidence: `artifacts/package-release-20261022`.

The preceding release records are retained below.

Published Desktop **1.0.0-19** to signed Testing and Stable at https://spectrum.gibranlp.dev/repo. The update includes Chronicles reading, creation and editing with a matching Questline 2.0.3 binary, horizontal campaign selection in the new-task editor, compact campaign scrollbars, and the character/class/level/XP header. It also includes the previously published sync controls and live Audio slider corrections. Hyprland remains **1.0.0-7**; the other eight package artifacts retain their verified bytes. Existing installations update through Updates or `sudo pacman -Syu`.

Stable snapshot `20261019T2356310000-ca666971527bb0a6` and Testing snapshot `20261019T2356310000-01cf8e088cc6c660` have identical signed package/database inventories. All public channel files and both complete immutable source archives match their local SHA-256 checksums. The signed Testing package was installed on this PC before Stable promotion; saved shell/widget/Favorites state is preserved and Shell, Sync and reminder services are active. Tests were skipped at the owner's request, including the package `check()` function; package construction used Arch Devtools with `--nocheck`.

Source revision `0323cc3f44e9a785` (archive SHA-256 `f71ed332e90de44b8e3d68075601c757673b3583b4937c7fd27ad3560b208db7`) and the matching Chronicles-enabled Questline binary/source archive are published under `/sources/`. Previous public snapshots are retained. The existing ISO is unchanged. Publication evidence: `artifacts/package-release-20261019-chronicles`.

The preceding October 18 release is retained below.

Published Desktop **1.0.0-16** and Hyprland defaults **1.0.0-6** to production-signed Testing and Stable at https://spectrum.gibranlp.dev/repo. This update adds App Store with a persistent Activity view and terminal installation, the Super+Shift+U shortcut, the Favorites cold browser launch correction, and the larger dashboard calendar with clickable task/step due dates, urgency colors, clock-sized right-aligned weather, and top-center hover across bar positions, styles and profiles including Gaming. Seven other package artifacts retain their exact verified bytes; bundled Questline remains 2.0.2. Existing installations update through Updates or `sudo pacman -Syu`.

Stable snapshot `20261019T0109440000-9ad8004b99710348` and Testing snapshot `20261019T0109440000-42674a18e8e24713` contain identical package/database inventories and clean-build evidence. All **28 HTTPS files per channel** match the signed local snapshots; manifest, database and all nine package signatures verify against the production signing subkey and trusted primary fingerprint. Previous Testing and Stable releases remain accessible for rollback.

Both changed packages passed Arch Devtools clean builds. The host suite passed 867 tests with one expected skip; the final packaging suite passes 17 checks. Desktop clean checks passed 640 Python checks with one expected skip and 549 Qt/Quickshell checks; Hyprland native parsing reports config ok. Artifact comparison verifies 100 desktop source paths and eleven Hyprland defaults, plus exact clean-build evidence for all nine packages. Release review corrected the missing App Store backend helpers in the package install loop and declared Git as a build dependency for its AUR review tests; an executed install-loop regression now guards helper inclusion and executable/source parity.

The signed Testing downloads were installed on this PC before Stable promotion. Only twelve byte-identical unowned files were adopted. Desktop reports 266 owned files and Hyprland 29, both with zero altered files. Shell, HotKey and App Store IPC are ready; saved per-monitor layout, shell/HotKey/Favorites bytes and empty Hyprland configerrors are verified. The preexisting local Questline reminder database error (SQLite error 11, malformed database) remains: journal entries before and after installation establish the same failure. No database repair or personal task-data modification was performed. A private pre-install backup is under `~/.local/state/spectrumos/oct18-package-deployment/20261019T011423Z`.

Source revision `4e9f50c253295a0d`, archive SHA-256 `d04664aa100c4028a1f7794653864b3eb9127f83effb6e5cb9b98fc551741ccd`, is published under `/sources/`; its complete HTTPS download matches all 217,682,097 local bytes. The existing ISO checksum sidecar remains unchanged (`93765646aa84182cd703cf533114f08dd1e74790e9e2c9d3032b090a6d129002`). No ISO build, resume or upload, Git push, or unrelated hosting changes occurred. Evidence: `artifacts/package-release-20261018`; build/publication helpers: `/tmp/spectrum-oct18-release`.

The preceding October 17 Tree maintenance release remains retained below.

Published Spectrum Desktop **1.0.0-15** to production-signed Testing and Stable. This maintenance update replaces the oversized Questline Tree rich-text renderer with a bounded Canvas.Image texture, avoiding the colored text-batching path implicated in Qt 6.12.0 / Quickshell 0.3.2 crashes. The tree preserves procedural colors, centers its visible cells, and fits both available dimensions. The shell keeps normal hardware rendering. Eight other package artifacts are unchanged, including Hyprland **1.0.0-5** and bundled Questline **2.0.2**.

Stable snapshot `20261017T1700510000-a277f65f5396eac4` and Testing snapshot `20261017T1700510000-93f20e1ffb6c993e` contain identical package/database inventories. All **28 HTTPS files per channel** matched the signed snapshots; Desktop signatures were verified, and the signed Testing download was installed locally before Stable promotion. Host checks passed 843 tests with one expected skip, and all clean-chroot package checks passed including the new Tree pixel/lifecycle suite. Desktop and Hyprland report zero altered package files. Personal shell/Favorites settings are preserved and SpectrumShell is active. A subsequent service check found a local Questline database integrity error preventing background reminders from starting; the pre-install database backup has the same error. Database recovery is separate from this published Tree update.

Source revision `5c37efcb860b8d38`, archive SHA-256 `8e75fdd1e18fc4c6ca6f17e0a3a7ee632f994d49d0b6bf260c7835d687ca8c85`, is published under `/sources/`. Previous public snapshots are retained for rollback. The existing ISO is unchanged. Users update with `sudo pacman -Syu`; Heaven should reboot after updating to clear its temporary runtime software-renderer override, then verify the Tree with normal rendering.

The preceding October 17 feature update is retained below.

Published the October 17 package update to production-signed Testing and Stable at https://spectrum.gibranlp.dev/repo. Desktop **1.0.0-14** adds Favorites (categorized/ranked links, JSON and browser imports, drag between categories, favicons and default-browser selection), shared Questline campaign navigation, bundled **Questline 2.0.2** with XP/level/achievement/Swarm/hydration notifications, blue persistent water reminders with Drink actions, automatic GameMode bar profiles with restoration, and quiet Stable update alerts with Open Updates. Hyprland defaults **1.0.0-5** includes Favorites and the Questline background-service startup. Seven unchanged artifacts retain their exact previously verified bytes. Existing installations update through Updates or `sudo pacman -Syu`.

Stable snapshot `20261017T1429470000-e642096e4e213140` and Testing snapshot `20261017T1429470000-3ae011abccf1ee49` have identical package/database inventories, clean-chroot evidence and production signatures. All **28 HTTPS files per channel** matched their signed local snapshots. The source archive revision is `7315e5f7577d4f2c`, SHA-256 `6bb6e0d5e09208310d3113296205bb0f0c36820be5948dba2d2af42d6167f553`; it and the corresponding Questline 2.0.2 source/binary archive are published under `/sources/`. The full host suite ran 841 tests with one expected skip; Desktop clean checks passed 613 Python and 481 Qt/Quickshell checks. Artifact comparison verified 93 runtime files plus packaged UKVM imports, Hyprland Lua defaults and the exact Questline binary.

Installed the actual signed Testing downloads locally before Stable promotion. Desktop and Hyprland report zero altered package files; personal shell/Favorites settings are preserved, Questline is 2.0.2, shell/reminder services are active, and Hyprland configuration errors are empty. Previous public Testing/Stable snapshots remain available for rollback. The existing ISO checksum is unchanged (`93765646aa84182cd703cf533114f08dd1e74790e9e2c9d3032b090a6d129002`); no ISO was built or uploaded. The user requested package updates as the maintenance path and no ISO work for now.

The preceding October 16 snapshot remains retained as history.

Published the October 15 release-review package set to https://spectrum.gibranlp.dev/repo. Stable snapshot `20261015T1548530000-e76bcec72972ebe5` and Testing snapshot `20261015T1548530000-bebce26be8102753` contain the exact nine reviewed candidates: Base 1.0.0-3, Desktop 1.0.0-10, Hyprland 1.0.0-3, SpectrumDrop 1.0.0-4, Theme/Plymouth/SDDM 1.0.0-2, UKVM 0.1.0.r21-1 and managed portal 1.4.1.r30.g0204ffb-1.

All nine current artifacts passed `scripts/check-release --artifacts` again before import. Imported their verified Devtools evidence into production-signed Edge, promoted to Testing, published and read back all 28 HTTPS files, then promoted the identical package/database inventory to Stable and verified all 28 HTTPS files there. Both public snapshot signatures verify against the configured production signer/root, and every public package hash matches the previously installed signed candidate. The host rejects Python's default HTTP user agent with 406; verification succeeded with an explicit user agent. No server security settings changed.

The previous Testing and Stable immutable snapshot manifests remain accessible over HTTPS for rollback. Local snapshot backup: `repo/output/.before-publication-20261015T154844Z`. Publication logs, signed public manifests, per-file HTTPS receipts and rollback-retention checks: `/tmp/spectrum-package-publication`. All nine installed packages still report zero altered files; Shell and HotKey are active and live Hyprland configuration errors are empty. Existing installations update with `sudo pacman -Syu`. No ISO was built or uploaded.

The preceding October 13 local-time publication is retained below as historical evidence.

Stable snapshot `20261014T0022510000-fc03f135a5197618` and Testing snapshot `20261014T0022510000-999fed9b443ef101` publish Desktop 1.0.0-8. This includes the SpectrumOS Matrix, Rain and Constellation screensaver with name/logo branding and Displays controls; playback/fullscreen idle suppression; the raised vertical clock area; Thunar archive tools; and the latest HotKey sequence timing. Archive dependencies are also in the installation manifest for future ISO installations. The Diablo preference fix remains local and is excluded from the source archive and package.

Desktop was rebuilt with normal Arch Devtools clean-chroot checks from immutable source revision `66c14d6942f10511` (archive SHA-256 `44cfdb3eacf1e9fb1a1f1531c6cd0e7478cc41675eb56ba2a74dfb93fa45eced`). The eight unchanged packages retain their verified clean artifacts. All nine packages carry production signatures, both channels have identical package/database artifacts, and all 28 public files per channel match the signed snapshots over HTTPS. Clean Desktop checks pass 491 Python checks with one expected opt-in skip and 306 Qt/Quickshell checks; 38 repository/packaging checks also pass.

The Desktop package downloaded from Testing is installed locally with zero altered files across 225 owned paths. Twelve affected runtime files match the signed artifact, SpectrumShell and HotKey are active, and Hyprland reports no configuration errors. Shell and Diablo settings are unchanged; a new user-saved HotKey rule made after installation is retained. Existing installations update with `sudo pacman -Syu`. Previous snapshots remain available for rollback. No ISO was built or uploaded.

The preceding October 12 local-time publication is retained below as historical evidence.

Stable snapshot `20261013T0217220000-bdb3800e4e7be2b0` and Testing snapshot `20261013T0217220000-3030c4ebedfe2cf3` replace the temporary Omdrop package integration with SpectrumOS-maintained SpectrumDrop 1.0.0-3 and Desktop 1.0.0-7. The desktop requires SpectrumDrop; neither Omdrop package is included or required. Seven unchanged packages retain exact verified clean artifacts. All nine packages have matching Devtools build evidence and production signatures; all 28 public files per channel match their signed local snapshots over HTTPS. Both channels have identical package/database artifacts.

The maintained transfer/AWDL fork includes original license notices and corresponding native source. Existing identity, receiver settings, MIME associations and administrator radio profiles migrate without overwriting existing SpectrumDrop settings. Receiving remains off and experimental radio authorization is not granted automatically. The local Omdrop packages are removed; SpectrumDrop and Desktop report zero altered files, and shell, UKVM and HotKey remain active. The full Python suite passes 701 tests with one expected skip; native checks pass 65 C/C++ tests and 59 protocol/radio tests with one hardware skip. Clean Desktop checks pass 479 Python tests with one expected skip and 290 Qt/Quickshell checks. New Mac transfer acceptance remains pending. Existing installations update with `sudo pacman -Syu`. No ISO was built or uploaded.

The superseded October 12 package publication is retained below as historical evidence.

Stable snapshot `20261013T0126520000-b3398e4bc263077b` and Testing snapshot `20261013T0126520000-b40fee772bf65654` publish the October 12 local-time update: Desktop 1.0.0-6, Hyprland 1.0.0-2, UKVM 0.1.0.r21-1, optional Omdrop 0.16.1-3 and Omdrop-owl 0.1.0-1.2. The other five packages retain their verified clean artifacts. All ten packages carry matching Devtools clean-build evidence and production signatures. The channels contain identical package/database artifacts; all 30 public files per channel match the signed local snapshots over HTTPS.

The update packages Interactive Remote Sessions, HotKey sequences, SpectrumDrop, direct widget actions, the standard bar More menu, orientation-aware placement, larger icon controls, stable polling and Islands joins. The latest SpectrumDrop Mac send still needs physical retesting. Optional radio support is not enabled automatically.

The full Python suite passes 695 tests with one expected opt-in skip; the clean Desktop build passes 479 Python tests and 290 Qt/Quickshell checks. The four rebuilt packages were installed from the actual Testing HTTPS endpoint, with verified signatures. Desktop, Hyprland, UKVM, Omdrop and Omdrop-owl report zero altered files across 340 paths. SpectrumShell, UKVM and HotKey are active; Hyprland reports no configuration errors and the checked personal settings are preserved. Existing installations update with `sudo pacman -Syu`; SpectrumDrop's optional backend packages can be installed with `sudo pacman -S omdrop omdrop-owl`. No ISO was built or uploaded, and the preceding Stable snapshot is retained on the server.

The October 11 release is retained below.

Stable snapshot `20261011T1726440000-04d7e247b5648100`, created 2026-10-11T17:26:44+00:00, contains Desktop 1.0.0-5 with the Gaming profile, Full/Islands bar themes, and Igor entrance/wake refinements. The other seven packages retain their previously verified clean artifacts. All 26 public files match the production-signed local snapshot over HTTPS. Clean Desktop checks pass 435 Python tests (one expected opt-in skip) and 219 Qt/Quickshell checks. The signed package is installed locally with zero alterations across 207 owned files, preserved personal shell settings, and a healthy SpectrumShell. Public Testing and ISO downloads are unchanged; no ISO was built. Existing installations update with `sudo pacman -Syu`.

The previous release details are retained below.

Stable snapshot created 2026-10-10T19:20:35+00:00 contains Desktop 1.0.0-2, UKVM 0.1.0.r20-2 (commit `96236c72e7bd9ad589179651c18a8bf49dbc4639`), the unchanged managed XDPH 1.4.1.r30.g0204ffb-1 and the other five Spectrum packages at 1.0.0-1. All eight artifacts have matching clean-chroot evidence and production signatures; all 26 public snapshot files matched local hashes over HTTPS. Public Testing was not republished.

Desktop uses immutable source revision `4caccf9ce689898d`, archive SHA-256 `3754f4184feded4d4d0fec25e2f4e4f547636b6da19835ae070eec00e5482056`. Unchanged package recipes/artifacts retain their original evidence. The reference PC has Desktop 1.0.0-2 and UKVM r20-2 installed with zero altered files, adopting only four previously deployed unowned files whose bytes matched the signed artifact. No peer trust/permissions or runtime restart was performed by this release task. ISO revision 3 is published under `/downloads/`; see [ISO validation and remaining acceptance](iso.md).

The preceding release history follows.

Production trust was activated on 2026-09-08. The October 7 package set contains Base 43, Desktop 161, Hyprland 42, Plymouth 23, SDDM 22, and Theme 62 (all 0.1.0). Desktop and Hyprland were rebuilt in clean chroots from immutable source revision `00bf9ca3d23b759c` to include Mouse Settings, adaptive cursors, audio recording controls, shortcuts, and blinking recording indicators with microphone/camera icons. Desktop also includes the preceding Stash integration. All 364 Python, 68 Qt, and 31 repository/packaging checks pass.

Testing `20261007T1507540000-49e0690d5d8b7eca` and Stable `20261007T1507540000-17456c843ac90658` are published with identical production-signed package artifacts and clean-build evidence. All 22 public files per channel match their signed local snapshots over HTTPS. The six release packages are installed on the reference machine through a complete system upgrade, with zero alterations across 588 owned paths, preserved personal settings, and healthy desktop services. Normal and rescue boot images rebuilt successfully. No ISO was built or uploaded for this release.

Stable is active. Independent fingerprint distribution, signing-subkey rotation/expiration, and primary-revocation recovery remain tracked release maintenance work. A real SSH disconnect during an earlier release upload stopped before the atomic channel switch; HTTPS readback proved the preceding Testing snapshot remained selected, and retrying the same immutable release completed successfully.
