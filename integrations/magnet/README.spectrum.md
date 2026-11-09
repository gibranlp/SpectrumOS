# Magnet in SpectrumOS

This directory vendors Magnet 0.1.0 from the maintainer's working tree.
`provenance.json` records the upstream repository, base commit, modified paths,
and exact file hashes. The upstream MIT license and explanatory comments are
preserved. The working snapshot includes the search and daemon behavior reviewed
for the Spectrum widget; it is not claimed to be an unmodified upstream commit.

`spectrum-magnet` builds this source with Cargo.lock, owns `/usr/bin/magnet`, and
ships its license, upstream README, and provenance. `spectrum-desktop` owns the
launcher, widget, socket adapter, and desktop entry, and requires this engine.
Both full and lean desktop profiles include Magnet. Its package is selected before
Desktop by `scripts/spectrum-repo`, so clean builds, imports, signatures, channel
promotion, and publication use the standard Spectrum release path.

There is no boot or login service. A user download or Resume saved action starts
the background daemon. Polling an idle widget does not start it. User data and
unfinished downloads remain in the normal XDG Magnet directories across package
updates. No install script downloads a mutable binary from GitHub.

To update the snapshot, copy the reviewed Cargo files, Rust sources, README, and
LICENSE; regenerate the provenance hashes; update the package version and
Desktop's minimum version when its daemon protocol changes; export a new immutable
Spectrum archive; and refresh the recipe pins. Build with `makepkg` for local
development or Arch Devtools for a publishable candidate. Run the Rust tests,
`tests.test_magnet_packaging`, `tests.test_magnet_adapter`, and
`tests/run_magnet_widget.py` before release. No ISO build is part of this workflow.
