# SpectrumDrop

SpectrumDrop is SpectrumOS's maintained nearby file-transfer implementation. The desktop installs the `spectrumdrop` package automatically. Neither `omdrop` nor `omdrop-owl` is required. The licensed transfer and AWDL source is maintained under `integrations/spectrumdrop/`; see its provenance and license notices. Standard Arch libraries provide TLS, archive handling, Bluetooth, packet capture and network APIs.

Open the native widget from the bar's More menu, Super+Shift+D, or the launcher. Choose a receive window, search for nearby devices, select a device and send files through the native portal chooser. Stop and Cancel act directly. Transfers and receive results produce SpectrumDrop notifications. Receiving remains off until explicitly started; closing the widget does not cancel a transfer or its timed receive window.

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
