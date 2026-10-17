# Repository and artifact policy

`SpectrumOS` is the canonical checkout and GitHub repository. The SpectrumOS2 working tree was consolidated here without changing the distribution's 1.0.0 version. Original GitHub commits remain ancestors of the new source snapshot. Historical SpectrumOS2 commits are backed up locally rather than imported as an unreviewed second history.

On the development machine, `~/SpectrumOS2` is a compatibility symlink to `~/SpectrumOS`. Existing local tooling can continue resolving its old paths while new work uses the canonical name. The old checkout and the original development Git metadata are preserved outside the active repository. No installed desktop files, packages, services, public package channels, or ISO images are changed by this consolidation.

## What belongs in Git

Keep application and integration source, package recipes and `.SRCINFO`, public verification keys, tests, documentation, original branding/wallpaper assets, and required boot artwork. The 30 supplied wallpapers remain lossless PNGs. Source files under `packages/spectrum-theme/src/` are intentionally included; other package `src/` directories are makepkg extraction output.

The existing `integrations/questline/spectrum-focus` executable is an intentional runtime dependency, accompanied by its Rust source, MIT license, and `scripts/build-questline-focus`. It is not a general exception for build binaries. Its regeneration procedure is documented in `integrations/questline/README.md`.

Run the read-only inventory before committing:

```sh
scripts/check-repository
```

It checks tracked and new nonignored files, rejects common artifacts and private-key material, reports the largest files, and enforces a 50 MiB per-file and 350 MiB working-source budget. These are guardrails, not a substitute for reviewing your staged diff. Git history and ignored local outputs are not included in the working-source budget. ArchISO profile symlinks point into the future live root and are checked as links rather than followed into the host.

## What stays local

- `artifacts/`: ISO images, VM disks, boot screenshots, validation and publication evidence.
- `generated/`, `state/`, caches and virtual environments: generated/runtime state.
- `packages/*/pkg/` and makepkg extraction/download files: package build products; the theme source directory is the exception described above.
- `repo/output/`, `repo/state/`, `repo/work/`: signed repository snapshots, private signing state and build orchestration.
- `repo/sources/*.tar.*`: immutable release source archives.
- Personal configuration, credentials, private keys and environment files.

The ignore file does not delete anything. Large local builds remain available without being uploaded to GitHub. Public certificates used by SpectrumDrop and the public repository signing keys remain included; private keys do not.

## Reproducing published packages

Package recipes pin exact source filenames and SHA-256 checksums. Download the corresponding archives from `https://spectrum.gibranlp.dev/sources/` into each recipe's directory, then follow `docs/packaging.md` and the clean-build workflow. Archives are intentionally not duplicated in Git. `scripts/check-release` validates locally available release sources and metadata; it does not fetch missing archives or build an ISO.

Do not rewrite package source pins merely because the repository was renamed. They identify already published, immutable releases. A future source change can receive a new archive and package revision through the normal release process.

The ISO builder requires an explicitly requested build and a prepared signed offline repository. A source publication never implicitly authorizes an ISO build.
