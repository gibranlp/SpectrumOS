# Production repository ceremony

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
