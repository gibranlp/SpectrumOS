# SpectrumDrop

SpectrumDrop is SpectrumOS's maintained file-transfer implementation for Spectrum PCs and Apple AirDrop. The desktop installs the `spectrumdrop` package automatically. Neither `omdrop` nor `omdrop-owl` is required. The licensed transfer and AWDL source is maintained under `integrations/spectrumdrop/`; see its provenance and license notices. Standard Arch libraries provide TLS, archive handling, Bluetooth, packet capture and network APIs.

Open the native widget from the bar's More menu, Super+Shift+D, or the launcher. Choose **Spectrum PCs** for encrypted sharing over Ethernet or Wi-Fi, or **Apple AirDrop** for the existing AWDL route. Choose a receive window, search for nearby devices, select a device and send files through the native portal chooser. Stop and Cancel act directly. Transfers and receive results produce SpectrumDrop notifications. Receiving remains off until explicitly started; closing the widget does not cancel a transfer or its timed receive window.

Native Apple AirDrop requires AWDL over Wi-Fi and Bluetooth announcements. Ethernet can remain the normal network connection while SpectrumDrop uses the Wi-Fi radio. Mac Everyone mode works with a self-signed identity; Contacts Only needs a valid Apple identity. Owning the source does not remove these protocol requirements or guarantee support for every Wi-Fi driver.

The packaged radio helper is `/usr/lib/spectrumos/spectrumdrop/radio/spectrumdrop-radio`; a named Polkit action grants local active seats access, while inactive/remote seats require administrator authentication. The user receiver uses a sandboxed `spectrumdrop-receiver.service`. No kernel driver is fetched, patched or installed at runtime. New installations retain the upstream conservative radio profiles, with untested cards disabled unless explicitly opted in.

On upgrade, the SpectrumOS-maintained implementation copies legacy receiver settings, visibility, sender policy and identity into its own locations without overwriting existing settings or deleting originals. Identity/settings reside in `~/.spectrumdrop/keys` and `~/.config/spectrumdrop/`; receiver configuration is `receiver.toml`. Root-owned radio configuration resides in `/etc/spectrumdrop`; migrating an already-authorized local profile does not authorize untested cards on other PCs. The old receiver is stopped before the replacement is used so two backends cannot own the radio simultaneously.

Commands:

```sh
spectrumdrop --version
spectrumdrop doctor --json
spectrumdrop on 5
spectrumdrop peers -n --json
spectrumdrop send --pick --to AA:BB:CC:DD:EE:FF
spectrumdrop off --force
spectrumdrop status --json
```

Accept on the Mac and physically verify the received file. The last widget failure fix and this source/package migration require physical retesting; build and loopback tests do not establish a successful Mac transfer. Stop receiving after testing. SpectrumDrop restores the radio/interface through its existing lifecycle; the widget restores Wi-Fi to off if it originally enabled it.

## Spectrum PC network sharing

Both PCs need the updated SpectrumDrop and desktop widget. Receiving is off by default. On the receiving PC, select **Spectrum PCs** and a 5, 10 or 30 minute window. On the sender, select **Spectrum PCs**, Search, enter the 16-character code displayed by the receiver, and choose files. The receiver must explicitly **Accept** or **Decline** the request. Sending does not require enabling receiving on the sender, and network mode never enables, disables or takes ownership of the Wi-Fi radio.

Automatic discovery uses `_spectrumdrop._tcp.local.` over mDNS. If the network blocks discovery, use **Connect by IP** with an address and port shown by the receiver, plus the same receiver code. TCP 8857 must be reachable between the PCs; mDNS discovery also needs UDP 5353. SpectrumDrop does not change firewall policy automatically or bypass router client isolation. Both PCs need a network path to each other. IPv4 and routed IPv6 addresses are supported; manually supplied link-local IPv6 addresses need the sender's interface scope.

The receiver code is a fresh 80-bit random secret for each receive window, displayed in four groups for readability. It is not advertised over mDNS. Before any filenames are sent, TLS is authenticated with HMAC-SHA256 proofs bound to the actual server certificate, a fresh nonce and separate request/response roles. Reconnections pin that certificate. This application uses locally generated certificates rather than a public certificate authority; the out-of-band receiver code establishes trust. Invalid code attempts are rate limited and connection/session/request sizes are bounded. The UI submits the code through stdin; the send worker reads a mode-0600 runtime job file and removes it on startup. Codes are not passed in process arguments or written to logs. Network access does not authorize a file write: explicit local acceptance is still required.

Files upload in bounded 4 MiB chunks with SHA-256 verification. An interrupted connection resumes from the receiver's acknowledged byte position while the receiver process and accepted transfer remain alive. Offer IDs and completion are idempotent, including a lost final acknowledgement. Sources are checked for changes while preparing/sending. Partial files stay in a private, randomized staging directory inside the save folder, then a complete batch is published with one directory rename. Existing files are not overwritten; each accepted batch gets a unique **SpectrumDrop DATE TIME ID** folder. Per-file incoming cancellation does not stop other transfers, and completed cards offer **Open folder**.

The current network protocol accepts up to 128 regular files and 1 TiB total per batch, further limited by the configured free-space policy. Archive folders before sending. Filenames and sizes are validated, paths cannot escape the batch, and symlinks/special files are not sent as regular files. A stopped receiver, declined offer, bad checksum or disk write failure does not publish an incomplete batch. A receive-window expiry rejects new sessions while already accepted uploads can finish; inactive offers/transfers time out. A service restart loses in-memory resume sessions; retry the transfer rather than assuming restart-resume support. Interrupted uploads that have not been published can leave a hidden `.spectrumdrop-*.partial` directory after a process/OS crash; SpectrumDrop does not automatically delete unrelated or uncertain user data.

The on-demand `spectrumdrop-lan.service` is installed as a static user unit; it is not enabled at login. Search or Receive starts it. Its local control socket is private under `$XDG_RUNTIME_DIR/spectrumdrop-lan`; its TLS listener opens only for a receive window or accepted transfer. Persistent network identity is separate from Apple identity under `$XDG_DATA_HOME/spectrumdrop/lan` (normally `~/.local/share/spectrumdrop/lan`). The configured AirDrop save folder and free-space policy are reused. Network receiving requires a user-owned destination; existing Downloads permissions and sharing ACLs are preserved. Received file paths come only from validated basenames, and staging remains private. No radio/driver/Apple-identity changes are needed for this transport.

Commands for inspection/control:

```sh
spectrumdrop lan status
spectrumdrop lan receive 5
spectrumdrop lan scan
spectrumdrop lan stop
```

The widget supplies files and secrets to the network sender over stdin; the command-line `lan send` entry point consumes a bounded JSON job rather than exposing a secret as a command-line flag.

## Mac transfer improvements

The Apple AirDrop transport retains its existing identity, consent, receive-window and AWDL/Bluetooth behavior. Sending stages the CPIO archive in an automatically removed file under the user's disk cache, then streams the same DVZip framing with bounded buffers. It no longer retains full CPIO and DVZip copies in Python memory. Preparation reports progress; upload socket operations return to the configured operation timeout after the longer acceptance wait. Opt-in protocol diagnostics do not consume/capture the streamed file body.

This improves transfer memory and failure handling; it does not make unsupported Wi-Fi radios AWDL-capable. A physical Mac send/receive still needs validation on the actual radios and OS versions. Ordinary Spectrum-to-Spectrum transfers use the network transport independently of those limitations.

## October 24 verification

Owner explicitly lifted the earlier pause for isolated local transfer checks. Temporary loopback endpoints verified code/certificate rejection, acceptance, chunks, actual interrupted sockets, stopped stalled uploads, checksum/size failures, idempotent offers/completion and lost acknowledgements. Two loopback-only mDNS nodes discovered and removed each other. Existing isolated Mac receiver protocol checks passed. A temporary 8 MiB Mac send streamed with less than 4 MiB peak traced Python allocations; this is not a whole-process RSS claim. Existing legacy adapter checks and offscreen widget acceptance/code/transport checks passed. Native widget previews were inspected without opening live widgets. No physical two-PC or Mac transfer is claimed by these checks. Evidence: `artifacts/spectrumdrop-network-20261024`.
