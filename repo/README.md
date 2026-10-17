# SpectrumOS signed repository

SpectrumOS uses three repository channels: `edge`, `testing`, and `stable`. Packages and repository databases require signatures from a trusted SpectrumOS signing key. `TrustAll` is forbidden.

## Production repository

Production trust is active. The trusted certification fingerprint is:

```text
7F064D404E79BDECC5FA0EEB8EBC1B05ACF9CCB6
```

Packages and databases are signed by the designated subkey `0F4B4D2D8AE036D1972B89192F4F88BAFD59BA24`. The online signing home must be supplied explicitly and must remain outside the checkout:

```bash
export SPECTRUM_REPO_GNUPGHOME=/var/lib/spectrumos-signing/gnupg
```

The current production-signed clean snapshot is published to Stable at `https://spectrum.gibranlp.dev/repo/stable/x86_64`. Configure a machine with:

```bash
scripts/spectrum-repo-client --channel stable
sudo scripts/spectrum-repo-client --channel stable --apply
sudo pacman -Syu
```

Compare the complete fingerprint shown by the client with an independently published copy before approving trust. The public key is also available at `https://spectrum.gibranlp.dev/repo/spectrumos-production.asc`.

## Building the repository

Build the current package set and create a signed Edge database:

```bash
scripts/spectrum-repo build --channel edge
scripts/spectrum-repo verify --channel edge
```

The result is written below `repo/output/edge/x86_64/`. Each package has a detached signature. `spectrumos.db.tar.zst`, `snapshot.json`, and both detached signatures describe one coherent snapshot.

Host builds are development-only. To create a snapshot eligible for Testing, first generate the immutable source archive, build all nine recipes through `pkgctl build`, and import the resulting artifacts:

```bash
scripts/build-ukvm-source /path/to/UKVM
scripts/build-source-archive --build
# Build the nine dependency-ordered PKGBUILDs with pkgctl build.
scripts/spectrum-repo import-clean
scripts/spectrum-repo verify --channel edge
scripts/spectrum-repo promote edge testing
scripts/spectrum-repo verify --channel testing
```

The importer selects the exact artifact named by each current recipe. It rejects a package unless `.BUILDINFO` identifies Arch `devtools`, clean-chroot paths, and the exact current PKGBUILD checksum. The signed manifest retains this evidence for all nine packages.

The signed repository owns Spectrum-maintained code and defaults. Third-party Arch packages continue to update from the official Arch repositories. Reviewed AUR applications such as Gowall, Vesktop, and Paru remain a separate transaction managed by Paru; they are not silently republished under the Spectrum signing identity. Browser binaries with separate redistribution terms are also not mirrored here.

Configure a test installation against a local repository snapshot:

```bash
scripts/spectrum-repo-client --channel edge --local
sudo scripts/spectrum-repo-client --channel edge --local --apply
sudo pacman -Syu
```

The first command is a dry run. Applying copies the signed snapshot to the system-readable `/var/lib/spectrumos/repository/edge/x86_64/`; Pacman's restricted download user cannot traverse a normal private home directory. Re-run the apply command after rebuilding the local snapshot. Before applying, compare the displayed 40-character fingerprint with `repo/keys/spectrumos-production.fingerprint`. The client uses `PackageRequired`, `DatabaseRequired`, and `TrustedOnly` semantics through pacman's `Required DatabaseRequired TrustedOnly` repository policy.

Development ISOs embed the verified Edge snapshot. The installer imports the production public key into the new target and installs `spectrum-desktop` and its Spectrum package dependencies through Pacman without requiring network access. After that bootstrap transaction, it switches the installed system to the public Stable channel so subsequent Control Center or Pacman updates receive published SpectrumOS releases. This establishes package ownership and the production update path from the first boot.

## Promotion policy

Promotion copies an already-built package set; it never rebuilds packages between channels:

```bash
scripts/spectrum-repo promote edge testing
scripts/spectrum-repo promote testing stable
```

Testing and Stable reject development host builds. Their snapshots must carry `clean-chroot` build evidence. The current complete clean snapshot has been promoted through Edge and Testing to Stable and published over HTTPS. It retains clean-chroot build evidence, package signatures, and a signed repository database. Key rotation, revocation, interrupted-publication, and recovery acceptance cases remain tracked release work.

Preview the SSH publication plan for the confirmed shared-hosting web root:

```bash
scripts/spectrum-repo-publish stable
```

The publisher verifies the local signed snapshot, uploads into a versioned release directory, verifies every remote checksum, and atomically changes the channel symlink. Mutation additionally requires `--apply --confirm stable`, and production signing mode is mandatory.

## Production boundary

The complete offline-root and online-signing-subkey procedure is documented in [`docs/production-repository.md`](../docs/production-repository.md). `scripts/spectrum-repo key audit-public` validates the primary/signing relationship, Ed25519 capabilities, expiration, and production separation policy without importing secret material.

The HTTPS origin and production trust chain are active. Continued Stable maintenance requires:

- an independently distributed and verified public-key fingerprint;
- CI clean-chroot builds with retained logs and source checksums;
- key rotation and revocation procedures;
- successful update, interrupted-transaction, migration, and rollback tests in VMs and on reference hardware.

Never copy a production private key into this repository, an ISO source tree, CI variables readable by untrusted jobs, or a web server.

M18 adds the independent `ukvm` package and the explicitly managed `spectrum-xdg-desktop-portal-hyprland` replacement. See [UKVM production integration](../docs/ukvm-production.md) for source pins, dependency order, migration and acceptance gates.

SpectrumDrop is built from the maintained transfer/AWDL source in this repository and installed as a desktop dependency. The `spectrumdrop` package replaces the earlier optional `omdrop` and `omdrop-owl` integration packages; those recipes are retained as historical development artifacts, not selected for release.
