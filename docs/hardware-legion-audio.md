# Legion Pro 7i Gen 10 speaker audio

The Lenovo Legion Pro 7 16IAX10H (DMI `83F5`, Realtek ALC287 codec
SSID `17aa:3907`) uses AW88399 amplifiers for its woofers. A working
analog stereo output alone does not establish that the woofers work.

The local machine initially ran `7.2.15-zen1-1-zen`, lacked the AW88399
HDA modules and amplifier firmware, and produced low speaker volume.
The loaded `snd_soc_aw88399` module alone did not provide HDA integration.

## Required support

- Linux 7.3 or later with `CONFIG_SND_HDA_SCODEC_AW88399_I2C=m` and
  the `17aa:3907` Realtek fixup.
- Matching NVIDIA modules when using the NVIDIA GPU.
- Amplifier firmware from the maintained
  [Legion audio project](https://github.com/nadimkobeissi/16iax10h-linux-sound-saga).

For Linux 7.3, the firmware location is `/usr/lib/firmware/aw88399_acf.bin`.
Linux 7.4 and later use `/usr/lib/firmware/awinic/aw88399_acf_17aa3907.bin`
(or `17aa3906` for that variant).

## SpectrumOS integration

`spectrum-base` adds `spectrum-legion-audio` and
`spectrumos-legion-audio.service`. Setup runs during package installation
and upgrades. The enabled service retries missing firmware after networking
is available on subsequent boots. Offline failures leave no partial firmware;
retry with:

```sh
spectrum-legion-audio status
sudo spectrum-legion-audio setup
```

Detection requires Lenovo DMI `83F5`, codec SSID `17aa:3906` or `17aa:3907`,
and the `AWDZ8399` ACPI amplifier. Other machines receive no changes or
downloads. Setup downloads the pinned firmware directly from upstream and
verifies its exact size and SHA-256 before installing missing files. Firmware
binaries are not redistributed in the SpectrumOS source or package. Existing
files, including compressed distro firmware, are preserved.

Both legacy and model-specific names are prepared for kernel upgrades. New
installer and live-image manifests require `linux-zen>=7.3`. Existing systems
keep their chosen kernel; status reports if its HDA amplifier driver is
unavailable. Setup does not change boot entries, force driver options, boost
volume, reload audio drivers, or reboot the machine. Reboot after firmware
is first installed so the amplifiers initialize with it.

The helper and installation checks are verified separately from audible
hardware behavior. Until the local post-reboot listening test succeeds, this
integration remains prepared support rather than a confirmed listening result.

Starting with `spectrum-base` 1.0.4, kernel and firmware package updates also
run setup through `85-spectrumos-legion-audio.hook`, before the standard
mkinitcpio hook. The firmware and upstream kernel driver work through the
normal SpectrumOS boot entry. There is no audio-specific kernel, boot option,
or Limine entry to select. Users updating an older installation should perform
a full system update so their normal kernel includes the HDA driver, then
reboot normally. Firmware setup does not install or switch kernel packages.

Firmware provenance used for this repair:

- Repository commit: `113031db46e1781ad55a2eafbcb284c2d7df9830`
- Repository path: `fix/firmware/aw88399_acf.bin`
- Git blob: `0bd65f0e58afc2eb7b9e4214b27930b9b432b892`
- SHA-256: `1e927c9bca76d868181c0f81df2bccef3cf19c7d0910219f229360c87babd42c`

## Verification after boot

```sh
uname -r
lsmod | rg 'snd_hda_scodec_aw88399'
journalctl -k -b --no-pager | rg -i 'aw88399|ALC287|firmware'
wpctl status
```

Confirm both HDA amplifier modules load, firmware loading succeeds, and
speaker volume and bass improve during playback. Begin at a low volume.
Installation checks cannot replace this listening check after reboot.

## Local verification, 2026-11-15

The regular Zen kernel `7.3.4-zen2-1-zen` includes the amplifier driver and
matching NVIDIA DKMS modules. Both amplifier channels registered successfully
in the current `7.3.4-arch1-1` boot, and the firmware helper reports no missing
files. The temporary `SpectrumOS (speaker support)` entry from the initial
repair is removed locally; the regular `SpectrumOS` entry continues to use
the standard Zen kernel. A boot into that entry and listening check remain
necessary to confirm the audible result on Zen.
