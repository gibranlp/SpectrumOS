# UniversalKVM in SpectrumOS

Open **UniversalKVM** from the application launcher, or run `spectrum-ukvm`.
The native Quickshell page opens on the focused monitor below the SpectrumOS bar/frame and follows the
current wallpaper palette and terminal font. It runs independently from the bar,
so opening/closing it does not restart the desktop shell.

## Requirements and installation

Normal SpectrumOS installations include the `ukvm` package, Quickshell and the
managed `spectrum-xdg-desktop-portal-hyprland` package. UKVM remains an independent application.
See [production integration and acceptance](ukvm-production.md) for the temporary upstream pin and package lifecycle. SpectrumOS's desktop installer/package installs the
frontend, launcher entry and adapter through `integrations/ukvm/install`.
The integration neither installs nor restarts development portal trials.

For a focused local frontend deployment:

```sh
sudo integrations/ukvm/install "$PWD" /
spectrum-ukvm
```

The widget reloads palette and font files when opened and checks them once per second while visible. This follows atomic theme-generation changes, including replacement of the `current` symlink. Hidden widgets stop periodic checks and catch up when reopened.

Development preview: `scripts/spectrum-ukvm --repo`. Close/open preserves the
single widget instance; Quickshell reloads edited QML automatically. To restart
an installed instance after an adapter/package update:

```sh
qs --path /usr/share/spectrumos/spectrum-ukvm ipc call spectrum-ukvm close
spectrum-ukvm
```

## Use

Select a trusted computer and click **Remote control** to open its desktop in
UKVM's native viewer. The button remains visible in Details and is disabled until
a computer is selected. The other computer must allow screen viewing; keyboard
and mouse control also require its control permission and normal portal consent.
Click the remote desktop to control it. Ctrl+Alt+Shift+Escape releases control
while keeping the viewer open.

While another computer controls this PC, a red pulsing remote-control icon appears
at the far right of the top bar or at the bottom of the left bar. Click to open UKVM. The indicator follows fresh
incoming control sessions, including physical edge switching, and clears when
control ends. Permission alone, idle sharing and outgoing control do not activate
it. With shell animations disabled, the icon stays solid red.

M19 adds **Share clipboard** to each selected trusted machine, separate from
**Allow control**. Sharing is off by default. Enable the checkbox explicitly on both
computers to synchronize regular UTF-8 text, including sensitive copied text,
independently of pointer focus. The **Clipboard** status shows readiness and the
number of connected sharing computers; Details shows safe errors. No clipboard
contents are displayed or requested by the widget.

The checkbox reflects UKVM's reported peer permission. It stays unchanged while
saving or after a command failure, shows errors, and updates from the confirmed
JSON permission response before refreshing status. It never grants input control.
The page fits its viewport without scrolling: topology and permissions share the
workspace, discovery and peer lists use pagination, and diagnostics and pairing
use separate views in that same space.

Clipboard changes apply immediately, without Apply or a service restart. Stopping
sharing blocks future sends and queued writes; it cannot recall previously copied
text or history. Existing pending layout/control changes still require Apply.
After upgrading an already running pre-M19 UKVM, restart it before enabling sharing.
Both nodes need the M19 package and a compositor exposing native data-control.
No additional clipboard helper/package is required by UKVM; images, files, HTML,
primary selection and Windows/macOS clipboard backends are outside M19.

On first launch, choose this computer's name and click **Set up**. This invokes
`ukvm setup --local --name NAME --json`; it preserves existing identity/trust/layout
and never starts a service or approves pairing/portal consent. Enable startup and
start the service when ready, then approve the desktop's portal prompts explicitly.


The local machine is at `(0,0)`. Select a trusted peer, then an empty cardinal
position to place/move it. UKVM validates coordinates, occupancy, trust and outer
node dependencies. Remove outer placements before moving an inner machine when
UKVM reports that dependency. Unplaced peers remain selectable below the map.
Availability is sampled, advisory and distinct from trust or control permission.

Select a peer to inspect its endpoint, placement, local permission and optional
full identity. **Allow control here** affects only this computer. Changes to
trust, permission and topology need **Apply configuration** to restart the UKVM
user service; Apply and Restart warn about active control and renewed consent.
Enable/disable controls login startup; start/stop controls the current session.

Discovery lists unverified claims. A matching advertised ID is not authentication.
Only pairing-mode entries can be paired. Temporary listening and direct pairing
are also available. Compare codes on both machines, inspect the full verified
identity and explicitly choose **Codes match · Trust machine**, or reject/cancel.
Closing the page cancels an unfinished ceremony. No code or verification
conversation is persisted/logged by this frontend. Newly paired peers retain
UKVM's deny-by-default input permissions. Interrupted ceremonies refresh trust
and recovery evidence; use UKVM's explicit terminal recovery workflow as directed.

Management actions execute on the first click, including Restart, Apply, permission changes, Unpair, placement removal and Forget approval. There are no secondary Y/N prompts. Pairing still requires comparing the code on both computers; portal consent remains controlled by the desktop. Unpair removes local trust;
it cannot remove the other computer's trust. UKVM may also prune dependent outer
placements. Failures are displayed and health is refreshed after mutations;
partial failure is never presented as success.

## Transport and state boundary

`scripts/ukvm-adapter` invokes the installed `ukvm` with argv arrays, inherits the
current user's graphical/XDG environment and validates schema-v1 JSON/JSONL.
It prefers `/usr/bin/ukvm`, then PATH and `~/.local/bin/ukvm`; it never depends on a source checkout.
`SPECTRUM_UKVM_BINARY` is an explicit development/test override, not a packaged
path. No shell interprets names, addresses or identities. UKVM exclusively owns
configuration, networking, identity, trust, permission enforcement, topology,
portal consent, service management and runtime ownership.

Normal results retain the UKVM envelope, with additive `integration_version: 1`,
`installed` and `apply_pending`. Missing executable, unsupported schema, malformed
or missing results, timeouts and interrupted processes become explicit errors.
Human terminal output is never parsed. A successful status query is not treated
as healthy control; service/runtime and doctor capabilities are displayed separately.

Pairing is relayed as JSONL. The adapter accepts one approval only for the current
verified full ID/code, preserves explicit accept/reject, and requires a final
successful result plus explicit user approval before showing success. Cancellation
sends SIGTERM to the ceremony process group and waits for cleanup. No runtime,
portal or trust bypass is introduced.

`UkvmState.qml` owns serialized command execution, pairing state and a four-second
read-only status timer active only while the page is open. Doctor/recovery probes
run on opening and after mutations; discovery runs only on request. `UkvmPage.qml`
owns presentation and direct actions; `UkvmModel.js` contains pure view helpers.
An advisory frontend operation lock also rejects overlapping mutations from
separate widget instances; UKVM retains its own authoritative edit/ownership locks.
All remote labels are plain text. The page never modifies UKVM files.

Only the frontend's conservative Apply reminder is saved in
`$XDG_STATE_HOME/spectrumos/ukvm-ui.json`. A potentially partial mutation leaves
this reminder set; only successful Apply clears it. UKVM cannot currently compare
disk configuration with the running snapshot, so external edits are not detected
and Apply remains available regardless of the reminder.

## Validation and limits

Run `integrations/ukvm/check "$PWD"` for transport/security/packaging and Qt UI
regressions, plus Bash/ShellCheck and Qt6 qmllint when available. The linter
reports Quickshell runtime-created PanelWindow and QProcess enum metadata as
information; the live Quickshell load validates those runtime types.
Run the repository Python suites and existing Qt checks as usual.
Tests use temporary state and executable doubles, never existing paired machines.
For additional real-M16 CLI acceptance with isolated profiles, temporary
certificates and a systemctl double (no host service changes):

```sh
UKVM_FRONTEND_TEST_BINARY=/path/to/installed/ukvm integrations/ukvm/check "$PWD"
```

This exercises placement/movement/removal, permission allow/revoke, confirmed
unpair, all service actions and Apply through the adapter against the real CLI.
Physical acceptance: inspect existing topology and health, discover, inspect a
peer's permission/details, close/open and change wallpaper to verify palette
updates. Test destructive mutations and pairing only with separate test profiles
or machines, comparing both codes. Check normal control and ReturnControl afterward.

This milestone provides directional placement, not drag/drop; cardinal distance
1–2 remains UKVM's model. Pairing recovery stays an explicit terminal operation.
Portal capability checks do not prove consent or physical delivery. The known
Hyprland partial-edge barrier limitation is unchanged. No SpectrumOS-specific
UKVM backend, production XDPH trial packaging or Windows/macOS support is added.

## Remembered desktop authorization

Updated UKVM exposes `desktop_authorization` through schema-v1 status/doctor. The
page shows **Remote control authorization** as Persistent, Active, Needs approval
or Unsupported. Persistent means UKVM remembers a portal credential, not proof
that physical control or restoration succeeded. Service/backend health and each
peer's `control-this-node` permission remain independent.

Approve the first RemoteDesktop prompt yourself and select the backend's
remember/skip-future-prompts checkbox if you want restoration after restart or
reboot. UKVM requests the official persistence API; SpectrumOS never approves
consent or reads credentials. The pinned Hyprland backend supports RemoteDesktop
persistence but exposes InputCapture v1, so persistent capture consent remains
unavailable there. Its availability is shown under Details.

**Details → Forget approval** runs immediately when clicked and invokes
`ukvm authorization reset --yes --json`. UKVM safely stops its managed runtime,
forgets remembered RemoteDesktop, InputCapture and ScreenCast credentials and remains stopped. Start explicitly
to request normal consent again. This does not unpair machines, change their
control permissions or edit topology. A foreground/unknown runtime or another
active diagnostic authorization session causes an actionable refusal. This
forgets UKVM's credentials; use desktop portal controls for desktop-wide
revocation when available. Tokens never enter the adapter or page.

Older CLI versions omit this additive status and the page hides the reset action;
install the updated managed UKVM package to obtain it. See the installed
`/usr/share/doc/ukvm/PORTAL_PERSISTENCE.md` for protocol, storage and acceptance.

## M20 files

The selected trusted computer exposes **Receive files**, independent of input and clipboard. This allows that computer to send here without an extra click per transfer. The checkbox remains bound to the actual returned `permissions.receive_files` state; UKVM failures leave the previous state visible. Changes use `peer allow|deny ID receive-files --json`, apply immediately and do not restart the service.

Below the topology, **Send files** opens a SpectrumOS-themed inline picker with multiple selection; **Send folder** opens the same picker in directory mode. The bridge accepts local picker URLs only, converts them to literal local CLI arguments, and invokes installed `ukvm send PATH... ID --json`. No shell, TOML edits, transfer protocol or filesystem logic exists in QML. The picker stays on the shell surface, uses the live wallpaper palette/font, and supports Home, Downloads, Up, filtering, file selection and Cancel/Escape. It uses Qt's folder-list model to browse local metadata; UKVM exclusively validates and sends the selected paths. No separate native window competes with the layer-shell overlay/focus. Picker Cancel/Escape closes selection without sending. Closing the panel leaves its active upload running; the transfer-row Cancel invokes `files cancel ID --json`. Shell process shutdown terminates its upload safely.

A compact single row displays sender/receiver, filename, state, bytes and progress without introducing a scrolling area. It prioritizes the widget's own active send, then another active transfer. Completed transfers leave this row immediately, including while the sampled history is still stale. A successful-send message expires after 2.5 seconds; actionable errors stay visible. `ukvm files status --json` provides the full bounded history (64 records). Incoming transfers remain available independently of panel visibility. Receiver-selected collision names are shown after completion. Send errors surface through the existing message area. An uncertain final acknowledgment requires checking receiver history before retrying.

The normal receive default is XDG Downloads/UKVM. Configuring another receive directory uses `ukvm files directory ABSOLUTE_PATH --json` then Apply; the widget does not implement a file manager or destination editor. M20 requires `ukvm>=0.1.0.r20`; a still-running older runtime reports restart_required. File payloads and hashes never appear in frontend status. This does not change M18 consent/restoration or M19 clipboard behavior. Spectrum ↔ Hellgen physical file-transfer acceptance remains pending.

Discovery presents one row per advertised node ID, preferring that node's pairing advertisement and its pairing endpoint over the normal runtime entry. Matching names alone are never merged. The local advertised node is omitted. This is presentation deduplication of untrusted discovery hints, not identity verification; code-bound approval and pinned UKVM authentication remain required. The topology grid retains its placement cards without horizontal/vertical guide lines. File/folder buttons remain visible beside the selected-peer label even when peer Details is open; selection and UKVM support are required to enable them.
# Fresh pairing and control authorization

Pairing pins identity and enables connection; it does not grant control, clipboard sharing, or file receiving. UKVM's interactive terminal setup already offers separate input permissions. SpectrumOS uses `setup --local` and the pairing JSONL ceremony, so the widget must provide its own explicit authorization step.

After a successful newly created pairing, the widget asks **Allow <peer> to control this computer**. **Allow and apply** runs `ukvm peer allow <node-id> control-this-node --json`, checks the peer identity and granted permission in the response, then runs `ukvm apply --json`. **Not now** keeps pairing with control denied. Selecting a peer and clicking **Allow control** provides the same grant-and-apply path later. Existing trust records do not automatically show the new-pair offer or change permissions.

The first authorized receiver setup requests the normal RemoteDesktop portal dialog. The user approves it and chooses Remember when offered. The widget never approves portal consent or accesses portal credentials. Clipboard and file receiving remain independent; granting control preserves both. Permission errors do not trigger Apply; an Apply error leaves the saved grant pending and displays the error for retry through the existing Apply button.

Minimal physical fresh-ISO acceptance:

1. Install the new ISO on a disposable receiver. Open UKVM with Super+Shift+K, Set up, and enable login startup; install the user service if offered.
2. Discover/pair the other computer and compare/approve the code on both. Confirm the named control offer appears. Choose Not now: control must remain denied and receiver consent must not be requested.
3. Select that peer, click Allow control. Alternatively, on a separate fresh pairing choose Allow and apply. The normal RemoteDesktop dialog must appear without a manual CLI command or service restart. Approve and select Remember when offered.
4. Configure the controller's topology in the widget and Apply. Verify real keyboard/mouse control and existing clipboard/file permissions.
5. Restart UKVM, then log out/in and reboot. Control must work with the remembered authorization. Inspect `ukvm peers` only for verification: `control-this-node=true`, clipboard/file settings unchanged.

## M21 remote sessions (local package candidate)

The local `ukvm 0.1.0.r21-1` candidate includes the physically working interactive
remote window and scoped system-shortcut forwarding. The widget continues to use
its existing management contract and prefers `/usr/bin/ukvm`. Launch a session
from a graphical terminal with `/usr/bin/ukvm remote PEER --stats`; permission
setup, protocol compatibility, consent and test commands are documented in
[the M21 package section](ukvm-production.md#local-m21-package-candidate-october-12-2026).
Select a trusted peer and click **Open remote screen** to launch the installed
native viewer. The widget closes after launching so the viewer can receive focus;
the viewer remains independent of the widget. Launch success is not connection
success: connection/permission failures appear in the viewer. Click the remote
desktop to control it; Ctrl+Alt+Shift+Escape releases control and keeps viewing.

**Share this screen** grants the selected peer permission to view THIS
computer, applies live, and does not grant control. The peer must independently
allow this computer to view its screen before Open remote screen can connect.
Launch is not gated by the local viewing/control toggles, since those permissions
have the opposite direction. The adapter passes a pinned peer ID with argv,
without a shell, JSON mode, command timeout or widget-owned viewer lifetime.

`view-screen` is independent and defaults OFF. Use the widget toggle or installed CLI on the
receiver to allow/deny this permission explicitly; control additionally requires
control-this-node. Control/clipboard/file operations do
not grant viewing. Forget approval now clears all three portal credentials after
stopping UKVM; peer trust and permissions remain unchanged. Package installation
never resets authorization or silently enables viewing. Both peers need Input
1.4 and Display 2, while pairing/clipboard/file protocols remain unchanged.
