# UniversalKVM: Linux/Hyprland production integration

The local shell widget now includes **Open remote screen** and **Share this screen** for the selected trusted peer. Viewing permission applies to this computer; the remote peer must separately permit viewing on its side. Management actions run on their first click. Pairing-code verification and desktop portal consent remain required. The native viewer uses the installed UKVM binary and keeps running independently when the management widget closes.

## Local M21 package candidate (October 12, 2026)

UKVM **0.1.0.r21-1** pins upstream commit
`50e8298d528274fbcf7d121cb0e52faae17b9c23`. It adds Interactive Remote Sessions
with **Input Protocol 1.4** and the separate **Display Protocol 2**. Both peers
must use these protocol versions for remote viewing/control; old Input 1.3 peers
must update for normal physical control too. Pairing 2, Clipboard 1 and File 1
are unchanged. Existing identity, pins, permissions, topology and private portal
credentials are retained. The managed Hyprland portal revision is unchanged.

The user confirmed live viewing, mouse/keyboard/click/scroll, remembered ScreenCast
consent across reconnect/reboot, clean return to physical control, and remote
Super/workspace shortcut delivery. The native-resolution SIMD JPEG performance
path has automated/synthetic evidence; measured physical latency/quality gains
and fresh-install package acceptance remain separate tests.

The package adds runtime dependencies on libpipewire, libjpeg-turbo >=3,
libxkbcommon and Wayland, and build dependencies on clang/libclang and pkgconf.
It uses library APIs for ScreenCast/PipeWire/JPEG and window shortcut inhibition,
with no external capture/codec processes. Installed usage/performance guides are
`/usr/share/doc/ukvm/REMOTE_SESSIONS.md` and `REMOTE_PERFORMANCE.md`.

This candidate is prepared and deployed locally only. Public Stable/Testing and
existing ISO images remain on their earlier package sets; no ISO build is
included. Remote sessions are available through the UKVM CLI; the existing
SpectrumOS widget retains its current management interface.

After installing the local candidate on each test PC, finish active control and
update the managed unit/runtime using the system package:

```sh
/usr/bin/ukvm service install --json
/usr/bin/ukvm service restart --json
/usr/bin/ukvm version
systemctl --user show ukvm.service -p ExecStart -p ActiveState
```

On io, explicitly grant only the intended receiver permissions using its pinned
alias for Spectrum, normally `spectrum`:

```sh
/usr/bin/ukvm peer allow spectrum view-screen --json
/usr/bin/ukvm peer allow spectrum control-this-node --json
```

Viewing defaults OFF and needs `connect` plus `view-screen`; interactive input
also needs `control-this-node` and legitimate RemoteDesktop consent. Pairing
never grants these permissions. Existing grants need no changes. On Spectrum:

```sh
/usr/bin/ukvm remote io --stats
```

Approve and remember io's legitimate ScreenCast picker if needed. Click the
rendered desktop to control it. Test Super+Enter/workspaces after the status says
“system shortcuts forwarded”, then Ctrl+Alt+Shift+Escape to restore local input
while viewing remains open. Focus loss/close/disconnect/revocation cleans held
input and restores local shortcuts. Compositors can reserve override shortcuts.
The viewer does not require a topology edge; input still uses the existing
runtime focus gate, pinned input transport and shared RemoteDesktop/EIS injector.

Defaults are native source resolution, JPEG quality 97/full 4:4:4 color, up to
60 FPS and a 500 Mbps video-payload ceiling with bounded latest-frame queues.
`--baseline --stats` supports comparison; `--fps`, `--quality` and `--bitrate`
provide explicit video limits. Video remains separate from input. There is no
H.264/hardware codec, audio, recording, multi-monitor, Windows/macOS backend or
automatic headless output in this milestone.

## Upstream decision (2026-10-08)

| Upstream | Exact revision | Required support |
| --- | --- | --- |
| Latest release, XDPH v1.4.1 (2026-07-29) | `cc8e5ef8fb2acef3db488b9a33b0c48c2a4ee204` | InputCapture; RemoteDesktop absent |
| Official master (2026-09-22) | `e87ae7823e7bf0601385220c69b5a3b245123fc5` | InputCapture; RemoteDesktop absent |
| PR #426, open/draft/unmerged | `0204ffbbcb3cef72af76804cdf59f114f2e2f6d9` | Consent-capable RemoteDesktop v2/ConnectToEIS and InputCapture |

Primary evidence: [PR #426](https://github.com/hyprwm/xdg-desktop-portal-hyprland/pull/426), [release v1.4.1](https://github.com/hyprwm/xdg-desktop-portal-hyprland/releases/tag/v1.4.1), [official master tree](https://github.com/hyprwm/xdg-desktop-portal-hyprland/tree/e87ae7823e7bf0601385220c69b5a3b245123fc5/src/portals). The PR head still matches the physically validated development pin. No replacement released API was found.

Until equivalent support ships, SpectrumOS carries the exact tested upstream revision in **spectrum-xdg-desktop-portal-hyprland**. This is an explicitly downstream, temporary package, not a claim that the draft has upstream release support. Its source archives and `hyprland-protocols` submodule (`bd153e76f751f150a09328dbdeb5e4fab9d23622`) are checksum pinned. It applies no compositor patches or consent bypasses. Its version is `1.4.1.r30.g0204ffb-1`; UKVM is `0.1.0.r18-4`, source commit `5fec1f735ce3d87899c237b291999673976714be`.

The downstream portal provides/conflicts with the stock package through pacman. No installer overwrites an arbitrary portal executable. Other Wayland desktops can install independent UKVM and use native portals; this SpectrumOS portal package is specifically for Hyprland.

## Installation and first launch

A fresh SpectrumOS installation selects UKVM and the managed portal through the normal desktop manifest/dependencies. The SpectrumOS desktop package owns the widget, adapter and launcher. The packages own all executable/unit assets under `/usr`; users do not build anything, clone UKVM, use `/tmp`, edit TOML or import environments.

After these artifacts have passed the release gates and are available in the configured signed repository:

```sh
sudo pacman -Syu spectrum-desktop ukvm spectrum-xdg-desktop-portal-hyprland
spectrum-ukvm
```

Open UniversalKVM from the launcher or **Super+Shift+K**. On a fresh profile, choose the computer name and click **Set up**, then enable login startup and start UKVM. Confirm the desktop's portal prompts yourself. Discover/pair only after comparing the verification code on both computers. Grant control on the computer that will receive input and place the trusted peer in the map; confirm **Apply configuration**. No input permission, portal consent or trust is implicitly granted.

Existing identity/trust/topology is retained. The adapter prefers the system-packaged `/usr/bin/ukvm` over a developer's older PATH binary. On an existing development installation, use **Install service** once (or `/usr/bin/ukvm service install --json`) to replace a per-user unit that points at an older developer binary; installation reloads but does not restart UKVM.

## Session and portal lifecycle

The managed portal package installs vendor drop-ins for both portal services. `/usr/lib/ukvm/ukvm-portal-session` validates the current logind/Hyprland session, owned live Wayland socket, compositor start time/instance, runtime directory and session bus. It discards inherited session values before exec. It does not approve consent or operate the UKVM runtime.

Backend DBus activation/readiness comes before frontend startup. Both are bound to graphical-session.target; frontend is also bound to/PartOf the backend. Backend restart starts the frontend again. Missing or ambiguous current sessions fail and retry through systemd every five seconds; an absent inherited WAYLAND_DISPLAY never permanently skips the unit. Vendor assets persist if runtime directories or user managers disappear. Normal DBus activation and UKVM's existing readiness path activate the stack again after login. Pacman's standard user-manager reload hook loads installed/removed drop-ins. Package installation never force-restarts a working portal or UKVM; log out/in after changing portal packages.

User portal/systemd overrides keep precedence. They are not deleted. Diagnostics show missing/incompatible backend, service state and interface versions separately. Capability readiness never proves that consent was granted; advanced capture/receiver diagnostics remain available. A declined portal dialog requires explicit approval on a subsequent start/restart.

## One-time migration from the development trial

Only machines already using the developer trial need this step. Finish active control before stopping UKVM. Use the existing trial script's ownership-checked cleanup; never manually delete unknown overrides:

```sh
ukvm service stop
~/UKVM/scripts/wayland-portal-trial status
~/UKVM/scripts/wayland-portal-trial stop
sudo pacman -Syu spectrum-desktop ukvm spectrum-xdg-desktop-portal-hyprland
/usr/bin/ukvm service install --json
/usr/bin/ukvm service enable --json
```

Then log out and back in. Normal installations never invoke the trial script. If cleanup refuses conflicting/unowned files, inspect them rather than forcing deletion. Trial overrides mask the vendor drop-ins and must not be mistaken for the production backend. The development script remains available for separate testing.

## Maintainer build and release gates

Use the existing immutable-source and signed repository pipeline. UKVM source is exported from the exact committed revision, excluding working-tree edits. Retain/distribute that checksum-verified archive alongside the existing SpectrumOS source archives; no authenticated developer checkout is needed to install binary packages. The portal sources are public immutable upstream archives.

```sh
scripts/build-ukvm-source /path/to/UKVM
scripts/build-source-archive --build
```

Build the eight recipes in dependency order with Arch devtools, installing already-built dependencies into the next clean chroot. Build UKVM first, then the managed portal, then spectrum-base/theme/hyprland/plymouth/sddm/desktop as their dependencies require. For example:

```sh
(cd packages/ukvm && extra-x86_64-build)
(cd packages/spectrum-xdg-desktop-portal-hyprland && extra-x86_64-build -- -I ../ukvm/ukvm-0.1.0.r18-4-x86_64.pkg.tar.zst)
```

Use the existing custom repository/dependency injection flow for the remaining desktop recipes. Do not skip tests or publish host-build artifacts as stable. The unchanged importer checks each artifact's exact recipe checksum and devtools clean-chroot evidence:

```sh
scripts/spectrum-repo import-clean
scripts/spectrum-repo verify --channel edge
scripts/check-ukvm-packages repo/output/edge/x86_64
```

Complete physical acceptance below before promotion/publication through the existing signed Testing/Stable process. The ISO preflight now also rejects missing UKVM/portal/widget artifacts; preparing this integration does not authorize an ISO build. No stable publication or clean-install/reboot/physical acceptance is implied by a successful local build.

## Physical acceptance (two disposable clean installations)

Use two supported SpectrumOS/Hyprland computers with full external-edge layouts. Preserve the existing spectrum/io relationship: destructive fresh-profile, consent-denial and uninstall checks belong on disposable acceptance profiles/machines. Record exact package versions, compositor version and results. Keep direct local input available and do not use unsupported partial external barriers.

1. Install through the configured signed repository using the installation command above. Run `pacman -Q ukvm spectrum-xdg-desktop-portal-hyprland hyprland xdg-desktop-portal spectrum-desktop`; ensure no trial/user portal override exists with `systemctl --user cat xdg-desktop-portal-hyprland.service xdg-desktop-portal.service`. No developer source/build paths may appear.
2. Open `spectrum-ukvm` (also test Super+Shift+K). Verify first-run name/setup, local node and no peers. Set up each computer, enable login startup and start. Explicitly approve each desktop portal prompt. Also decline once on a disposable profile: the widget must retain useful diagnostics and permit retry without automatic approval.
3. Run `/usr/bin/ukvm doctor --json`; require backend_state=backend_ready, InputCapture v1+, RemoteDesktop v2+, keyboard/pointer true on both and ConnectToEIS available. This does not substitute for physical input tests.
4. Discover each other in the widget. Compare verification codes on both computers, reject/cancel one ceremony first, then explicitly approve a new matching ceremony on both. Check that pairing itself grants no control permission or layout.
5. Grant only the intended local control permission. Place a trusted peer at a full external edge, Apply, and inspect the map and details. Test move/remove/invalid occupied or orphaned placement on the disposable profile, then restore the valid map.
6. Cross the edge and test pointer movement, left/right/middle buttons, held button release, vertical/horizontal scroll, ordinary keys and held Ctrl/Shift/Alt/Super modifiers in a harmless local test app. Perform at least ten round trips. Verify inverse-edge ReturnControl and **Ctrl+Alt+Shift+Escape** emergency release; the pointer must move inward before capture rearms. Release the chord and move at least 32 logical pixels inward before deliberately crossing again.
7. Disconnect/reconnect the peer's network while active. Held inputs must release, local control must recover, and reconnect must reuse pinned trust without granting new permissions. Verify unknown/unavailable/offline UI states remain distinct.
8. Run `/usr/bin/ukvm service restart --json`. Approve fresh portal consent if requested. Require one runtime and repeat physical switching; inspect `/usr/bin/ukvm status --json`.
9. Finish active input, then run `systemctl --user restart xdg-desktop-portal-hyprland.service`. Require both portal services active and `/usr/lib/ukvm/ukvm-portal-session check-frontend` successful. Repeat with `systemctl --user restart xdg-desktop-portal.service`. If an existing portal grant was invalidated, use the widget's Restart once and explicitly approve fresh consent; no package/runtime hook may auto-approve it.
10. Fully log out of Hyprland and log back in without manual portal/service/environment commands. Require UKVM automatic startup, both portals in the current session, successful helper/doctor checks and physical switching. Repeat with a destroyed/recreated user manager/runtime (non-lingering acceptance user with no other sessions), then with a surviving manager (a separate login session). Never deliberately destroy the production user's manager.
11. Reboot both acceptance computers; log in and repeat health, consent, discovery of the trusted peer, topology and switching. Do not run trial/start/import-environment commands.
12. In the widget, test Disable/Stop/Enable/Start, then Apply, topology and permission rendering, wallpaper palette changes, keyboard navigation and explicit failure/retry. Disabled service must stay disabled after login; re-enable/start for subsequent tests.
13. On a disposable profile only, revoke control and Apply: the peer must be rejected. Confirm Unpair and verify only local trust/topology removal. Pair again only through matching-code approval.

Useful verification commands after each lifecycle case:

```sh
/usr/bin/ukvm status --json
/usr/bin/ukvm doctor --json
/usr/lib/ukvm/ukvm-portal-session check-backend
/usr/lib/ukvm/ukvm-portal-session check-frontend
systemctl --user status ukvm.service xdg-desktop-portal-hyprland.service xdg-desktop-portal.service --no-pager
journalctl --user -b -u ukvm.service -u xdg-desktop-portal-hyprland.service -u xdg-desktop-portal.service --no-pager
```

## Removal/restoration acceptance

On a disposable installation, `/usr/bin/ukvm service stop`, `service disable` and `service uninstall` remove only the managed per-user service, leaving identity/trust/preferences intact. The vendor unit is part of the installed package and remains available until package removal. The widget's Disable/Stop is the normal way to turn UKVM off on a SpectrumOS desktop.

The desktop metapackage requires UKVM and the managed portal. To test complete package removal on a disposable machine, first remove the desktop metapackage without recursive dependency removal, then replace the managed portal with the stock one through pacman, and finally remove UKVM. No force dependency bypass is needed:

```sh
/usr/bin/ukvm service stop
/usr/bin/ukvm service disable
/usr/bin/ukvm service uninstall
sudo pacman -R spectrum-desktop
sudo pacman -S xdg-desktop-portal-hyprland
sudo pacman -R ukvm
```

Log out/in. Verify stock portal ownership/activation, absent SpectrumOS vendor portal drop-ins, absent UKVM processes, unchanged user identity/trust/config and unrelated overrides. Reinstall the desktop package set to restore SpectrumOS integration. Never automatically delete a user's profile or trust during removal.

## Remaining limits and evidence

The Hyprland partial external-edge InputCapture barrier validator remains an upstream limitation; no bypass is included. Full external-edge operation is the acceptance baseline. A capability probe does not prove physical delivery or consent. Upstream PR support is still a draft, so SpectrumOS owns downstream maintenance until an official implementation can replace it.

Automated tests cover structured setup/security preservation, stale/missing session checks inherited from M15, backend capability checks, widget states, immutable package metadata, complete/missing offline artifacts and package-owned unit ordering. The user physically validated production installation, pairing, RemoteDesktop consent, seamless control and control after reboot on a new SpectrumOS laptop. Persistent unattended authorization is a subsequent change and still requires the acceptance procedure below; automated success does not establish it.

## Persistent authorization acceptance

The updated UKVM package requests RemoteDesktop v2 persistence mode 2 and safely
rotates its private single-use restore credential. The existing managed XDPH
revision already supports it; no backend package or trial changes are required.
Explicitly select the initially unchecked remember/skip-future-prompts checkbox
when approving the first control prompt. The backend exposes InputCapture v1,
so persistent controller capture consent is unsupported there.

On the controlled node, preserving existing trust and layout:

```sh
ukvm service restart
ukvm authorization status --json
```

Initiate control, explicitly approve and remember consent, then re-query status;
RemoteDesktop must be `persistent`/`remembered: true`. Restart UKVM again and
exercise pointer/buttons/scroll/keyboard/modifiers, ReturnControl and emergency
release with no new controlled-node approval. Repeat after complete graphical
logout/login, reboot and a normal backend restart. A logged-in supported graphical
session is required; greeter control and automatic login configuration are outside
scope. Confirm remembered authorization survives each replacement token.

Test **Details → Forget approval** deliberately: cancel once, then confirm.
UKVM must stop, forget authorization and retain peer trust/control permissions and
topology. Start explicitly, reject fresh portal consent once and verify no input;
approve/remember only if desired. Portal-side revocation, expiry or incompatible
backend changes must result in normal consent or safe failure. Never print the
private credential files. These unattended physical checks have not been run for
this update.

The r18-2 same-session `backend_changed` failure is corrected in r18-3: runtime and CLI use the actual portal frontend desktop context, not their separate caller environments. Tokens remain private and single-use; genuine desktop/API changes and backend vendor/restore-data incompatibility still require normal consent. This correction is not physically accepted yet.

The controlled laptop's inspected r18-2 metadata confirms a saved token, `authorized: true`, reason `remembered`, and `hyprland`/API v2 scope; both service and frontend use `Hyprland`, while the terminal desktop label is missing. Preserve that token when retesting r18-3: query status immediately after installation, then restart UKVM and reconnect without new approval.

The r18-3 restoration rejection is fixed in r18-4. Portal frontend 1.22.1 consumes
the saved permission entry and returns a newly authorized token which may reuse
the same string; UKVM incorrectly rejected that success and then requested fresh
consent. The fix accepts only the credential returned by successful Start and
persists it atomically, regardless of value equality. No pinned XDPH patch or
consent/security change is required. New verbose phase/result diagnostics expose
only booleans/device grants, never credentials or raw response dictionaries.

Install r18-4, then `ukvm service install --verbose` and `ukvm service restart`.
If the failed r18-3 attempt consumed the credential, explicitly approve/remember
once to obtain a fresh grant. Restart again, reconnect and require no RemoteDesktop
dialog; remembered status must remain true. A returned reissued value should reach
durable storage and ConnectToEIS in the journal, without a fresh duplicate request.
Actual restoration, logout/login and reboot remain pending physical acceptance.
