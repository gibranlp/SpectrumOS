# Historical Omdrop integration

This page records the earlier integration and physical tests. SpectrumOS now uses its maintained [SpectrumDrop](spectrumdrop.md) fork; neither Omdrop package is required. Use the current SpectrumDrop documentation for commands and installation.

SpectrumDrop is the native SpectrumShell widget for the Omdrop command/receiver and AWDL radio backend. Native Apple AirDrop requires AWDL over Wi-Fi; Ethernet carries ordinary networking while this experimental profile dedicates Wi-Fi to AWDL.

## Local results

This PC has a Realtek RTL8821CE, PCI ID 10ec:c821, using rtw88_8821ce. The driver reports monitor, IBSS and HT-IBSS support. configs/omdrop/owl-profiles selects exclusive mode, stays marked untested and requires /etc/omdrop/allow-untested containing 1. The override and opt-in are installed locally, not enabled for all SpectrumOS installations.

The local test created an HT-IBSS cell and monitor interface on channel 6, started OWL and created awdl0 with a usable IPv6 link-local address. The receiver started and listened on TCP 8771 with a bounded receive window. Cleanup removed temporary interfaces, restored the managed station and returned Wi-Fi to its initially disabled state. Ethernet retained the default route. Status still reports rx_proven=false: Apple-device discovery, reception, transfers and long-term stability remain unvalidated.

The kernel logged “failed to get tx report from firmware” during both startup checks. This did not prevent local startup or cleanup, but transmit reliability needs physical validation. No driver workaround has been applied.

Installed packages: omdrop 0.16.1-1 and omdrop-owl 0.1.0-1.1. Package recipes pin and hash source archives; OWL and portable helpers use upstream pinned commits and submodule revisions. SpectrumOS notifications use notify-send with argument-array actions, links use xdg-open, and setup does not offer to install AI-agent skills. First-use dependency installation through an Omarchy terminal remains unsupported; dependencies are installed through Pacman before setup. The receiver and TLS identity use normal upstream setup and its hardened user service. No kernel module, firmware patch, regulatory override, public publication or ISO build is involved.

## Confirmed incoming transfer

On October 12, the user reported Spectrum appearing on the Mac and sent a test image. Receiver logs show /Ask accepted, /Upload completed with HTTP 200 and profile.jpg saved at 13:50:45. Downloads metadata confirms 136567 bytes, matching the announced file size. The user subsequently confirmed receiving an image on the Mac, establishing one successful transfer in each direction. Repeated transfers and long-term stability still require physical testing. The file contents were not opened by the agent.

## SpectrumDrop widget

Open SpectrumDrop from the bar (More in Standard mode), with **Super+Shift+D**, the application launcher, or the **Super+K** shortcuts widget. The panel opens at the top right with a top bar or bottom left with a left bar. Choose 5, 10 or 30 minutes to start receiving and nearby discovery. Wi-Fi is enabled when necessary; Ethernet remains the normal network connection on this PC. Visibility uses the configured Omdrop audience, shown in the widget; the current setting is Everyone nearby. No second confirmation is required.

Search runs automatically while the panel is open, with a manual Search button. Devices without a resolved name remain selectable by address. Asking for names may take up to 45 seconds and performs the backend's normal discovery/Bluetooth announcements. Click Send files for a device, choose one or more files in the native chooser and accept on the recipient. The widget dismisses for the chooser so it cannot cover that window, continues monitoring, and returns after selection or cancellation to show transfer status. It stays closed if another shell panel has been opened. Active name discovery is cancelled cleanly before starting a send. Progress/status and Cancel send remain available. Sends run in a separate user service and survive closing or reloading the widget. Stop is disabled while sending; cancel first to avoid interrupting a transfer by tearing down its radio.

Receiving, stopping, sending, completion and failures produce notifications. Received files use the existing receiver's notification with an Open action, labeled SpectrumDrop. Destination folder can be changed through a native folder chooser. Transfer results are bounded private runtime state, not persistent history; the widget renders device names and messages as plain text.

Closing the widget leaves the receive window and active send running. Omdrop ends receiving when the timed window expires. If SpectrumDrop enabled an initially disabled Wi-Fi radio, click Stop to restore it; after timer expiry, Stop remains available for that restoration. Expiry alone restores the backend's managed interface but leaves the radio enabled. Starting a window or send remains an explicit user action; merely opening the widget never enables receiving.

Missing Omdrop produces an installation message. The Spectrum desktop package lists Omdrop and its radio backend as optional dependencies; the Realtek experimental opt-in remains local. No privileged desktop daemon or new transfer protocol is introduced.

## Physical test

Keep Ethernet connected. Place an Apple device nearby with Wi-Fi and Bluetooth enabled. Use Everyone for testing; sending to Contacts Only requires an Apple-issued AirDrop identity, which setup does not obtain.

On Spectrum run:

```sh
nmcli radio wifi on
omdrop doctor --json
omdrop on 5
omdrop status --json
```

The receiver name is Spectrum and destination is ~/Downloads. Share a small test photo from the Apple device through native AirDrop and choose Spectrum. Verify the complete photo in ~/Downloads. Test the other direction while the window is active:

```sh
omdrop peers -n
omdrop send ~/Pictures/test-photo.jpg "NAME_FROM_PEER_LIST"
```

Accept on the Apple device and verify the file. Opening the phone's share sheet may help wake discovery. Use a non-sensitive test file. Everyone mode permits nearby senders during the window.

Finish:

```sh
omdrop off --force
nmcli radio wifi off
omdrop status --json
iw dev
ip route show default
```

Wi-Fi was initially off; omit radio-off if you subsequently want normal Wi-Fi enabled. Expected: receiving off, only the managed wlp9s0 interface remains and the default route uses enp10s0. Wait at least five minutes after teardown and repeat to check recovery/stability.

If discovery fails, collect:

```sh
omdrop doctor --json
omdrop status --json
/usr/lib/omdrop/omdrop-discoverable peers
journalctl --user -u airdrop-receiver.service --since '10 minutes ago' --no-pager
sudo tail -40 /run/omdrop-owl/owl.log
```

Logs may include device identifiers and filenames; review before sharing. Never share private identity files in ~/.omdrop. A local startup is not validated card compatibility. Further profile changes, including mon_mac=own or shared mode, should be tested separately and remain experimental until both directions and cleanup work physically.

## Recovery and disabling

If normal stop fails:

```sh
sudo /usr/lib/omdrop/omdrop-discoverable stop
nmcli radio wifi off
```

Remove /etc/omdrop/allow-untested to disable future untested-radio activation. Installed packages remain idle until explicitly started; receiving is not enabled at login. SpectrumDrop uses the physically tested backend; broader radio compatibility remains experimental.
