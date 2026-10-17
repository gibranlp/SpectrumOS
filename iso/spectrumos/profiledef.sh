#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="spectrumos"
iso_label="SPEC_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m%d)"
iso_publisher="SpectrumOS <https://spectrum.gibranlp.dev>"
iso_application="SpectrumOS Installer and Recovery"
iso_version="1.0.0-$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m%d)"
if [[ -n ${SPECTRUM_ISO_REVISION:-} ]]; then
    [[ $SPECTRUM_ISO_REVISION =~ ^[1-9][0-9]*$ ]] || { printf 'Invalid ISO revision\n' >&2; exit 1; }
    iso_version+="-r$SPECTRUM_ISO_REVISION"
fi
install_dir="spectrum"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/usr/local/bin/spectrum-hardware-report"]="0:0:755"
  ["/usr/local/bin/spectrum-snapshot"]="0:0:755"
  ["/usr/local/bin/spectrum"]="0:0:755"
  ["/usr/local/bin/spectrum-installer"]="0:0:755"
  ["/usr/local/bin/spectrum-recovery"]="0:0:755"
  ["/usr/local/bin/spectrum-rescue-shell"]="0:0:755"
  ["/usr/local/bin/spectrum-live-session"]="0:0:755"
  ["/usr/local/bin/spectrum-live-network"]="0:0:755"
  ["/usr/local/lib/spectrumos/network-adapter"]="0:0:755"
  ["/usr/local/lib/spectrumos/spectrum-installer-backend"]="0:0:755"
  ["/usr/local/share/spectrumos/source/install.sh"]="0:0:755"
  ["/usr/local/share/spectrumos/source/scripts/check-lean-package"]="0:0:755"
  ["/usr/local/share/spectrumos/source/vendor/paru"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
)
