# SpectrumOS 1.0.0 release review

Reviewed on October 15, 2026. The release remains in the existing 1.0.0 series. The prepared package set was subsequently published at the user’s explicit request; see the publication results below. ISO creation remains separate.

The release set has nine packages: spectrum-base, spectrum-theme, spectrum-hyprland, spectrum-plymouth, spectrum-sddm, spectrum-desktop, spectrumdrop, UKVM and the managed Hyprland portal. The Omdrop recipes are retained historical inputs and are not release candidates. Empty spectrum-cli/spectrum-gaming directories are not packages; the CLI and Gaming behavior are owned by Base and Desktop. All maintained shell QML components have direct consumers, so no component was removed merely because a simple scan could not infer its lifecycle.

## Findings and changes

| Area | Finding | Resolution |
| --- | --- | --- |
| Weather | Valid JSON with the wrong top-level shape, malformed coordinates, or a damaged forecast cache could raise unhandled exceptions. | Validate state shape and finite coordinate ranges, retain malformed saved files, reject invalid caches and fall back gracefully when offline. Validate a response before replacing a working cache. |
| Wallpapers | Same filenames in different directories could share an incorrect cached thumbnail. | Cache identity includes the resolved source path. |
| Wallpaper performance | Thumbnail creation copied the full-resolution RGB image before shrinking it. | Reuse RGB input directly instead of copying it before resize; preserve the original conversion/resampling order for indexed and alpha formats. On the bundled 3840×2160 S28 image, bounded fresh-process samples dropped from roughly 86 MiB peak RSS to 54 MiB, with identical JPEG output. This is thumbnail-generation memory, not total desktop memory. |
| HotKey performance | Active rules polled every 5 ms even while waiting for a distant next repeat; a rule-free service queried compositor bindings every two seconds. | Keep short polling only while native delivery is pending, wait until the next deadline otherwise (bounded to 200 ms for control responsiveness), and skip reconciliation with no rules. No saved rule is automatically reactivated after restart. |
| Launcher performance | Repeated or equivalent XDG application roots were scanned more than once. | Deduplicate resolved directories while preserving root precedence and fresh install/removal discovery. |
| Source packaging | Previously downloaded Questline/Stash binaries could be copied into the canonical archive even though the recipe separately verifies/downloads them. | Exclude these redundant inputs and compressed download caches; preserve the theme engine source tree and the required focus companion. |
| Source immutability | Existing canonical archives could be overwritten in place. | Export through a private temporary file and atomically publish only if absent; accept identical repeats and refuse different existing bytes. Exclude output temporaries and verify readable archive permissions. This developer-only hardening is verified in the worktree; the tested package archives remain unchanged. |
| Build resources | Source compression selected all available workers. | Default to four workers, with a validated 1–16 override. |
| Version metadata | Theme runtime/Python project version still said 0.1.0 while the product and package were 1.0.0. UKVM and Desktop `.SRCINFO` had drifted. | Align theme identity to 1.0.0 and regenerate metadata. Keep the pinned upstream-derived UKVM/portal version schemes. |
| Release gates | Readiness required manually comparing recipes, sources and artifact provenance. | Add read-only `scripts/check-release` and optional `--artifacts`, using the existing strict clean-build evidence check. |
| Snapshot reporting | A real package upgrade exposed Btrfs progress text being included in the restore-point identifier message. | Report the identifier from the final output line; regression coverage preserves snapshot/cap behavior. |
| Shell cleanup | Unused recorder/Bluetooth fields, a one-iteration template loop, masked assignment failures and unquoted comma-containing QEMU arguments produced warnings. | Remove unused state and the redundant loop; preserve assignment errors and quote intended single arguments. ISO source edits were syntax-checked only; no ISO was built. |
| Documentation | Desktop ownership still described removed Waybar/Wofi layouts, and Plymouth described 140 frames. | Document the native Quickshell boundary and the current 240-frame intro. |

## Validation and release process

Start with `python3 -m unittest discover -s tests`, the Theme package's tests with its source on PYTHONPATH, the Desktop recipe's Qt checks, native launcher/polling tests, and `scripts/validate-hyprland.py`. Retain their logs. New regression cases exercise malformed weather state/cache, thumbnail identity, duplicate roots, HotKey deadlines, source export exclusions and release-gate failure paths.

Generate the immutable source with `scripts/build-source-archive --build`, pin all seven Spectrum-owned recipes to that revision/checksum and refresh `.SRCINFO`. Clean-build the dependency-ordered package set, retain the exact logs and run `scripts/check-release --artifacts`. Existing UKVM/portal artifacts can be retained only if their embedded devtools evidence matches their current recipe. The gate does not create signatures or publish anything.

Source and local test success are distinct from clean artifact readiness. Publication still requires production signing, coherent repository snapshots and their normal verification. The review does not establish fresh-install, interrupted-upgrade, boot/recovery, physical multi-machine KVM or repeated SpectrumDrop transfers. Existing physical acceptance limits remain in the relevant integration documents. No ISO build is authorized by this review request.

Local runtime fixes are deployed separately and verified against source; personal configuration and saved rules remain preserved. Exact build/test evidence and the final package inventory are retained under `/tmp/spectrum-release-review` for this preparation run.

## Preparation results

The complete checkout suite passes 744 Python tests (one opt-in skip), and the Theme suite passes 81. All 26 directly run Desktop Qt suites pass 262 checks, supplemented by native media/Bluetooth/file-watch/launcher/polling checks and Hyprland configuration validation. The final Desktop clean-chroot check phase passes 516 Python checks and 320 Qt checks. Base passes 97 Python checks, Theme 81, and SpectrumDrop 81 plus its native AWDL test. Counts include each suite's setup/cleanup where reported.

All seven owned packages were clean-built with checks enabled. UKVM and the managed portal retain exact verified devtools artifacts. The final nine-package `scripts/check-release --artifacts` gate passes, every candidate signature verifies against the configured production signer/root, and the local candidate manifest is signed. At the end of preparation, no Edge/Testing/Stable snapshot or public repository had changed; the subsequent authorized publication is recorded below.

Clean building also found and resolved a source-export check failure: Desktop's AppImage packaging test expects `.SRCINFO`, so the check phase now regenerates it from the actual current PKGBUILD. The build chroot explicitly preselects the declared PipeWire JACK provider when injecting local dependencies, preventing an incidental Jack2 conflict. The early 35-second animation-runner timeout was too short; the unchanged IgorSleeper suite passes in about 52 seconds with the normal build checks enabled.

Five owned packages retain the reviewed source `spectrumos-source-1.0.0-a66ae26d50893c89.tar.zst`, SHA-256 `7e12a04cbbb35818aa19bb314b18e1c8268fee2b3dffe9734eed54a905c76162`. Base 1.0.0-3 uses follow-up source `70168ad0b8e7ec5d`, SHA-256 `08ad8a259c9b1c1810dce95e00897d1fdba0163f85853e008f672a6e6ce044c2`, for the observed snapshot-reporting fix. Desktop 1.0.0-10 uses source `568a3e6037620fd5`, SHA-256 `3a0d9bb62766198aa0ecb3790840ccbe0ac9b547a87636047ee93cad242c83b0`, including indexed/transparent thumbnail compatibility coverage. Recipes and `.SRCINFO` are maintained outside that archive's content identity and included in clean-build provenance.

| Candidate | SHA-256 |
| --- | --- |
| `ukvm-0.1.0.r21-1-x86_64.pkg.tar.zst` | `d6a8419e308ce57aff432a73166654def38e2ab32893bec59b397a19b676d88d` |
| `spectrum-xdg-desktop-portal-hyprland-1.4.1.r30.g0204ffb-1-x86_64.pkg.tar.zst` | `3691e8c91b8fbecc654b532ccf55081a675257f690d4daf1ba3a99039b91ea5a` |
| `spectrumdrop-1.0.0-4-x86_64.pkg.tar.zst` | `8585363ab7a68fdc7f3870870d7bc9dd5ef25659250105cd98e4c41d9d6c9de0` |
| `spectrum-theme-1.0.0-2-any.pkg.tar.zst` | `485ee4ce548fb2fe11bf19a5917e72929dd8463bc5022dd7a5a4982dda67f11c` |
| `spectrum-hyprland-1.0.0-3-any.pkg.tar.zst` | `548762c88f9ac0ca252c556adcd2e1d7fc764f957b95e1e82d49de2fd713a246` |
| `spectrum-base-1.0.0-3-any.pkg.tar.zst` | `a7b5e3f4cb4c05589deb45520cdade67d6ae68505789237a4cdd7f3e4a401824` |
| `spectrum-desktop-1.0.0-10-x86_64.pkg.tar.zst` | `cff783fc81b51dc0a99e4b3e47882b6d4e16b1080a3531c816e8f066c7baf4a8` |
| `spectrum-plymouth-1.0.0-2-any.pkg.tar.zst` | `aab00a9f9c15bb67eeda75d1e587869a228b6336464d4f55179bdd763698a9c9` |
| `spectrum-sddm-1.0.0-2-any.pkg.tar.zst` | `bf7438d3959dd0ad36130d6717cb902ba08aa06762e5079217e1f258e8d30bc4` |

## Local deployment verification

The final seven owned candidates are installed through Pacman, with only five previously unowned paths adopted after exact-byte comparison. Every installed package in the nine-package release set reports zero altered files. The retained UKVM/portal candidate payloads also match the installed files byte-for-byte. All affected runtime scripts and widget files match maintained source. Saved shell, HotKey and monitor settings were checked unchanged during each transaction.

SpectrumShell and HotKey are active; SpectrumShell reports Configuration Loaded and Hyprland has no configuration errors. The user health check reports zero failures, seven passes and one warning requesting a root read-only boot check. The separate root checks pass for Limine and the Btrfs snapshot inventory. Real upgrade hooks created pre-upgrade restore points and rebuilt the normal rescue kernel image; the final transaction confirms the corrected clean snapshot identifier. These were normal package hooks, not an ISO build.

The final candidate inventory/signatures and validation logs are under `/tmp/spectrum-release-review`. Preparation itself did not replace repository channels or upload public files; the subsequent publication is recorded below. Fresh OS installation, interrupted-update/rollback acceptance and physical multi-machine KVM/SpectrumDrop acceptance retain their documented limits.

## Publication results

Published the October 15 release-review package set to https://spectrum.gibranlp.dev/repo. Stable snapshot `20261015T1548530000-e76bcec72972ebe5` and Testing snapshot `20261015T1548530000-bebce26be8102753` contain the exact nine reviewed candidates: Base 1.0.0-3, Desktop 1.0.0-10, Hyprland 1.0.0-3, SpectrumDrop 1.0.0-4, Theme/Plymouth/SDDM 1.0.0-2, UKVM 0.1.0.r21-1 and managed portal 1.4.1.r30.g0204ffb-1.

All nine current artifacts passed `scripts/check-release --artifacts` again before import. Imported their verified Devtools evidence into production-signed Edge, promoted to Testing, published and read back all 28 HTTPS files, then promoted the identical package/database inventory to Stable and verified all 28 HTTPS files there. Both public snapshot signatures verify against the configured production signer/root, and every public package hash matches the previously installed signed candidate. The host rejects Python's default HTTP user agent with 406; verification succeeded with an explicit user agent. No server security settings changed.

The previous Testing and Stable immutable snapshot manifests remain accessible over HTTPS for rollback. Local snapshot backup: `repo/output/.before-publication-20261015T154844Z`. Publication logs, signed public manifests, per-file HTTPS receipts and rollback-retention checks: `/tmp/spectrum-package-publication`. All nine installed packages still report zero altered files; Shell and HotKey are active and live Hyprland configuration errors are empty. Existing installations update with `sudo pacman -Syu`. No ISO was built or uploaded.

## October 15 notification and screenshot update

Published Desktop **1.0.0-11** through Testing and Stable with the notification-toast dismissal and upper-left screenshot-widget fixes. The other eight package payloads retain their previous verified bytes. Desktop source revision: `1b0dcfa32964acee`; source SHA-256: `eed8ba909bca32efec77eb58d2c89de36a1b8dbfb691189401d130feaf2478a2`. Package SHA-256: `f5ad16759f56d39cc24ec46b9a3e40fe7fd1ab60b931bfb9451d341291571a45`.

Clean Desktop checks pass 516 Python checks and 320 Qt checks, plus native UKVM, launcher, polling and six capture/notification checks. All nine artifact/provenance checks pass. Testing snapshot `20261015T1934160000-b01c47c108e2adeb` and Stable snapshot `20261015T1934160000-28b103f6b142b8e0` are production-signed; all 28 files in each public channel match the local hashes over HTTPS. Local installation reports 230 files with zero alterations; shell, HotKey and monitor preferences were preserved, both services are active and Hyprland configerrors is empty.

Build, signing, publication/readback and local deployment evidence: `/tmp/spectrum-widget-release`. The authorized replacement ISO is handled separately with the existing filename to preserve the website URL.

The explicitly authorized ISO rebuild is complete as `artifacts/iso/spectrumos-1.0.0-20261015-x86_64.iso`, 2,461,767,680 bytes, SHA-256 `6b7b7488d01bce31e14469a17ff2b68036a20362195d7683f767e9b5f4a13075`. Its signed inventory equals Stable, and the embedded package/source copies of both fixed QML files match maintained source. The checksum, signatures, 390 source executable permissions and bundled-app gates pass. The exact read-only raw image reached the graphical installer under both BIOS and UEFI in isolated guests without network or writable installation disks; no installation was performed and both guests were closed. Evidence: `artifacts/iso-validation-20261015-widgets` and `artifacts/iso-boot-20261015-widgets`. The temporary previous-image backup was removed after validation. The public ISO has not been replaced; upload the new ISO and its adjacent checksum together under their existing names.

## October 15 local rescue ISO candidate

Desktop 1.0.0-12 is clean-built and production-signed from source 386d25300fb59be3, with 527 Python and 323 Qt checks plus native suites. It packages the persistent Islands model that fixes focus-change curve flicker, includes the fail-fast native-helper build, and checks the corrected source installer/rescue guide. The other eight release package payloads retain their previous verified bytes. Local installation reports 230 files with zero alterations, preserved checked settings and active Shell/HotKey. The candidate is only in local Edge; public Testing/Stable remain unchanged.

The explicitly requested ISO rebuild is `artifacts/iso/spectrumos-1.0.0-20261015-x86_64.iso`, 2,461,775,872 bytes, SHA-256 `7146f368e5452587a18fb095deef100349abb3442c695361b8ca51b145805977`. It includes the installer pkg-config correction, Rescue system guide/button and live terminal configuration, with static embedded-file/signature/checksum verification. The user subsequently confirmed that installation worked and authorized the public upload recorded below. Evidence: `artifacts/iso-validation-20261015-rescue` and `artifacts/rescue-iso-packages-20261015`.

October 15 tested rescue ISO publication: the user confirmed that the installer worked and authorized replacing the existing download with the exact tested image. Published spectrumos-1.0.0-20261015-x86_64.iso and its checksum at https://spectrum.gibranlp.dev/downloads/ under their original filenames. Size: 2,461,775,872 bytes; SHA-256: 7146f368e5452587a18fb095deef100349abb3442c695361b8ca51b145805977. Full staged and final server hashes pass; complete HTTPS download and checksum sidecar match at 2026-10-15T22:19:16.834201+00:00. Previous public bytes are retained in the hidden server staging directory for rollback. No rebuild or package-channel publication occurred. Evidence: artifacts/iso-publication-20261015-rescue.
