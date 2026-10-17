# UKVM production integration: Testing release

Published on October 8, 2026 (October 9 UTC).

Testing snapshot: `20261009T0243240000-45108c65f37b0785`.

Repository: <https://spectrum.gibranlp.dev/repo/testing/x86_64>.

This release packages M18 and the pending SpectrumOS desktop updates for physical acceptance. Stable remains on its previous snapshot. Publication does not establish clean-install, logout/login, reboot, or physical control acceptance for this candidate.

| Package | Version |
| --- | --- |
| ukvm | 0.1.0.r18-1 |
| spectrum-xdg-desktop-portal-hyprland | 1.4.1.r30.g0204ffb-1 |
| spectrum-base | 0.1.0-44 |
| spectrum-desktop | 0.1.0-164 |
| spectrum-hyprland | 0.1.0-44 |
| spectrum-theme | 0.1.0-62 |
| spectrum-plymouth | 0.1.0-23 |
| spectrum-sddm | 0.1.0-22 |

All eight packages have matching current-recipe Arch Devtools clean-build evidence in the signed manifest. Base, Hyprland and Desktop were rebuilt for publication; the other five matching clean artifacts were retained. The production signing subkey and certification relationship passed audit. The uploader verified remote checksums before switching the Testing symlink; all 26 public files were subsequently downloaded over HTTPS and matched the signed local snapshot. Stable's public manifest remained byte-identical.

Validation included 374 desktop Python tests, 16 UKVM adapter tests (one installed-CLI opt-in skipped in the chroot), 116 QML checks, Base package checks, Hyprland configuration validation, and 22 repository/UKVM packaging regression tests. UKVM's retained clean build passed its full workspace suite as recorded in M18. No tests were disabled for publication.

The reference PC updated through the public signed Testing repository and completed its ordinary system upgrade and boot-image hooks. All eight packages passed integrity checks: 653 owned paths, zero altered files. Nine identical, previously unowned UKVM widget files were adopted using an exact-path overwrite list after comparison. SpectrumShell restarted and loaded successfully; Hyprland reported no configuration errors and registered Super+Shift+K. UKVM's existing process, trust, permissions and topology were preserved. The running portals were not restarted as part of deployment.

## Update another SpectrumOS PC

On a machine using the development portal trial, first finish active control and run its ownership-checked cleanup:

```sh
ukvm service stop
~/UKVM/scripts/wayland-portal-trial stop
```

Switch the existing signed repository configuration from Stable to Testing, then perform a full upgrade:

```sh
sudo sed -i 's|/repo/stable/|/repo/testing/|' /etc/pacman.d/spectrumos.conf
sudo pacman -Syu spectrum-desktop ukvm spectrum-xdg-desktop-portal-hyprland
```

Approve Pacman's replacement of the stock Hyprland portal with the explicitly named SpectrumOS package. Do not bypass signature verification or blindly overwrite conflicting files.

For an existing UKVM installation, update its managed user unit and retain login startup:

```sh
/usr/bin/ukvm service install --json
/usr/bin/ukvm service enable --json
```

Fully log out and back in so the new portal processes use the current graphical session. Open the widget with Super+Shift+K or `spectrum-ukvm`. A new user can initialize the local node through the widget; pairing verification and portal consent remain explicit.

Follow [the complete physical acceptance procedure](ukvm-production.md#physical-acceptance-two-disposable-clean-installations), including portal capability checks, control, restart, reconnect, logout/login and reboot. Existing trusted machines should retain their relationship; do not unpair them merely to exercise removal tests.

No ISO was built or published.
