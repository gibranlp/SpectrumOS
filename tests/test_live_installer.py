import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "installer"


class LaptopPackageTests(unittest.TestCase):
    def test_iso_laptop_package_selection_excludes_competing_daemon(self):
        backend = (INSTALLER / "spectrum-installer-backend").read_text()
        function = backend.split("collect_packages() {", 1)[1].split("\ninstall_spectrum_repository()", 1)[0]
        for form_factor in ("laptop", "desktop"):
            for lean in ("true", "false"):
                with self.subTest(form_factor=form_factor, lean=lean):
                    result = subprocess.run(
                        ("bash", "-c", "collect_packages() {" + function + "\ncollect_packages"),
                        env={**os.environ, "project_root": str(ROOT), "cpu_profile": "amd",
                             "gpu_profile": "amd", "form_factor": form_factor, "lean": lean},
                        capture_output=True, text=True, check=True,
                    )
                    packages = result.stdout.splitlines()
                    self.assertEqual("power-profiles-daemon" in packages, form_factor == "laptop")
                    self.assertEqual("tuned" in packages, form_factor == "desktop" and lean == "false")
                    self.assertNotIn("tlp", packages)

    def test_initial_arch_transaction_defers_managed_ukvm_packages(self):
        backend = (INSTALLER / "spectrum-installer-backend").read_text()
        function = backend.split("collect_packages() {", 1)[1].split("\ninstall_spectrum_repository()", 1)[0]
        for form_factor in ("laptop", "desktop"):
            for lean in ("true", "false"):
                for gpu in ("amd", "intel", "nvidia", "nvidia-intel", "nvidia-amd", "vm"):
                    with self.subTest(form_factor=form_factor, lean=lean, gpu=gpu):
                        result = subprocess.run(
                            ("bash", "-c", "set -euo pipefail\ncollect_packages() {" + function + "\ncollect_packages"),
                            env={**os.environ, "project_root": str(ROOT), "cpu_profile": "amd",
                                 "gpu_profile": gpu, "form_factor": form_factor, "lean": lean},
                            capture_output=True, text=True, check=True,
                        )
                        packages = result.stdout.splitlines()
                        self.assertNotIn("ukvm", packages)
                        self.assertNotIn("spectrum-xdg-desktop-portal-hyprland", packages)
                        self.assertIn("hyprland", packages)
                        self.assertIn("xdg-desktop-portal-gtk", packages)
                        self.assertIn("lib32-nvidia-utils" if gpu == "nvidia" else "lib32-mesa", packages)

    def test_deferred_packages_install_after_repository_trust_in_both_modes(self):
        backend = (INSTALLER / "spectrum-installer-backend").read_text()
        function = backend.split("install_spectrum_repository() {", 1)[1].split("\nconfigure_keyboard()", 1)[0]
        result = subprocess.run(
            ("bash", "-c", 'set -euo pipefail\nrun() { printf "%s\\n" "$*"; }\ndie() { exit 1; }\ninstall_spectrum_repository() {' + function + "\ninstall_spectrum_repository"),
            env={**os.environ, "project_root": str(ROOT), "target": "/nonexistent-test-target", "mode": "plan"},
            capture_output=True, text=True, check=True,
        )
        calls = result.stdout
        transaction = "pacman -Syu --needed --noconfirm spectrum-desktop ukvm spectrum-xdg-desktop-portal-hyprland"
        self.assertIn(transaction, calls)
        self.assertLess(calls.index("install the signed SpectrumOS Edge repository"), calls.index("pacman-key --add"))
        self.assertLess(calls.index("pacman-key --lsign-key"), calls.index(transaction))
        self.assertLess(calls.index(transaction), calls.index("activate the public SpectrumOS Stable repository"))

# A fixture matching real `lsblk --json` output for a machine with QEMU's default
# legacy floppy controller present alongside a real 32GiB destination disk --
# confirmed live as exactly what showed up in the installer's own disk dropdown
# as a selectable disk. Its size is 1,474,560 bytes (a standard 1.44MB floppy's
# *nominal* capacity), not 0 -- confirmed live that the floppy driver reports
# this fixed value regardless of whether any media is inserted, so an earlier
# `size > 0` filter alone let it straight through; it only reads as "0.0 GiB"
# in the UI because that's small enough to round down to one decimal place.
FAKE_LSBLK_JSON = json.dumps({"blockdevices": [
    {"path": "/dev/zram0", "size": 34359738368, "model": None, "type": "disk", "ro": False, "rm": False, "tran": None},
    {"path": "/dev/fd0", "size": 1474560, "model": None, "type": "disk", "ro": False, "rm": True, "tran": None},
    {"path": "/dev/vda", "size": 34359738368, "model": "QEMU_HARDDISK", "type": "disk", "ro": False, "rm": False, "tran": "virtio"},
    {"path": "/dev/sr0", "size": 1073741824, "model": "QEMU_DVD-ROM", "type": "rom", "ro": True, "rm": True, "tran": "ata"},
]})
FAKE_LSBLK_TEXT = (
    "PATH      SIZE MODEL         TRAN   RO TYPE\n"
    "/dev/zram0 34359738368 - - 0 disk\n"
    "/dev/fd0  1474560    -             -      0  disk\n"
    "/dev/vda  34359738368 QEMU_HARDDISK virtio 0  disk\n"
    "/dev/sr0  1073741824 QEMU_DVD-ROM  ata    1  rom\n"
)
FAKE_LSBLK_SCRIPT = f"""#!/usr/bin/env bash
if [[ " $* " == *" --json "* ]]; then
    cat <<'JSON'
{FAKE_LSBLK_JSON}
JSON
else
    cat <<'TEXT'
{FAKE_LSBLK_TEXT}
TEXT
fi
"""


class LiveInstallerTests(unittest.TestCase):
    def test_backend_is_valid_and_safe_by_default(self):
        backend = INSTALLER / "spectrum-installer-backend"
        syntax = subprocess.run(
            ("bash", "-n", str(backend)), check=False, capture_output=True, text=True
        )
        self.assertEqual(syntax.returncode, 0, syntax.stderr)
        help_result = subprocess.run(
            ("bash", str(backend), "--help"), check=False, capture_output=True, text=True
        )
        self.assertEqual(help_result.returncode, 0, help_result.stderr)
        self.assertIn("dry-run", help_result.stdout)
        self.assertIn("--confirm-erase DEVICE", help_result.stdout)
        content = backend.read_text(encoding="utf-8")
        self.assertIn('[[ $confirm_erase == "$disk" ]]', content)
        self.assertIn('[[ $(lsblk -dn -o TYPE "$disk") == disk ]]', content)
        self.assertIn("Refusing to install on a disk with mounted filesystems", content)
        self.assertIn("/usr/local/share/spectrumos/source", content)
        self.assertIn("pacman -Sy --noconfirm", content)
        self.assertLess(content.index("pacman -Sy --noconfirm"), content.index("wipefs --all --force"))

    def test_list_disks_excludes_floppy_and_ram_devices(self):
        # A machine's default legacy floppy controller (/dev/fd0) reports TYPE=disk,
        # RO=0 -- confirmed live under QEMU: it passed the old type/ro-only filter
        # and showed up in the installer's own dropdown as a selectable destination
        # disk, matching a user report of being unable to install because "the
        # drive was 0gb". A size floor alone isn't enough either: the floppy driver
        # reports its drive's *nominal* capacity regardless of whether media is
        # inserted (1,474,560 bytes here, a standard 1.44MB floppy) rather than 0,
        # so `size > 0` alone let it straight through -- it only displayed as
        # "0.0 GiB" because that's small enough to round down. Excluding /dev/fd*
        # by name is what actually catches it; the size floor stays as
        # defense-in-depth against a different phantom (e.g. an empty card-reader
        # slot that genuinely reports size=0). validate() below already rejects
        # anything under 20 GiB with a clear error at apply time, so a genuinely
        # too-small real disk should still be listed here, not silently hidden.
        with tempfile.TemporaryDirectory() as directory:
            fake_lsblk = Path(directory) / "lsblk"
            fake_lsblk.write_text(FAKE_LSBLK_SCRIPT, encoding="utf-8")
            fake_lsblk.chmod(fake_lsblk.stat().st_mode | stat.S_IEXEC)
            environment = {**os.environ, "PATH": f"{directory}:{os.environ['PATH']}"}

            json_result = subprocess.run(
                ("bash", str(INSTALLER / "spectrum-installer-backend"), "--list-disks", "--json"),
                env=environment, check=True, capture_output=True, text=True,
            )
            disks = json.loads(json_result.stdout)
            self.assertEqual([d["path"] for d in disks], ["/dev/vda"])

            text_result = subprocess.run(
                ("bash", str(INSTALLER / "spectrum-installer-backend"), "--list-disks"),
                env=environment, check=True, capture_output=True, text=True,
            )
            self.assertIn("/dev/vda", text_result.stdout)
            self.assertNotIn("/dev/fd0", text_result.stdout)
            self.assertNotIn("/dev/zram0", text_result.stdout)

    def test_validation_rejects_ram_and_floppy_before_device_access(self):
        backend = (INSTALLER / "spectrum-installer-backend").read_text()
        validation = backend.split("validate() {", 1)[1].split("\npartition_path()", 1)[0]
        for disk in ("/dev/zram0", "/dev/zram12", "/dev/fd0"):
            with self.subTest(disk=disk):
                result = subprocess.run(
                    ("bash", "-c", 'die() { printf "%s\\n" "$*" >&2; exit 1; }\nvalidate() {' + validation + "\nvalidate"),
                    env={**os.environ, "disk": disk, "install_mode": "erase", "target": "/tmp/spectrum-installer-unused"}, capture_output=True, text=True,
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Refusing a floppy or RAM-backed installation device", result.stderr)

    def test_multilib_is_enabled_on_the_live_medium_before_the_pacman_sync(self):
        # Every bootstrap/packages/gpu/*.txt profile ships at least
        # lib32-mesa plus a matching lib32 Vulkan driver, but the live
        # medium's own /etc/pacman.conf carries pacman's stock commented-out
        # multilib section (the ISO profile's build-time pacman.conf that
        # enables it only ever drives what mkarchiso itself installs into
        # the image, not the live rootfs's actual config) -- confirmed live:
        # an unpatched pacman -Sy here never syncs a multilib database, so
        # pacstrap's lib32-* packages come back "target not found" and the
        # graphical installer aborts before ever touching the destination
        # disk. Must run before the one pacman -Sy that has to see it.
        content = (INSTALLER / "spectrum-installer-backend").read_text(encoding="utf-8")
        self.assertIn("sed -i '/^#\\[multilib\\]/,+1 s/^#//' /etc/pacman.conf", content)
        self.assertLess(
            content.index("sed -i '/^#\\[multilib\\]/,+1 s/^#//' /etc/pacman.conf"),
            content.index("pacman -Sy --noconfirm"),
        )

    def test_backend_builds_branded_btrfs_limine_system(self):
        content = (INSTALLER / "spectrum-installer-backend").read_text(encoding="utf-8")
        for value in (
            "sgdisk --zap-all",
            "mkfs.btrfs",
            'btrfs subvolume create "$target/@"',
            'pacstrap -K "$target" linux-zen',
            "genfstab -U",
            "BOOTX64.EFI",
            "limine bios-install",
            "/opt/SpectrumOS2/install.sh --apply",
            "NetworkManager.service sddm.service",
            "configure_keyboard",
            'printf \'KEYMAP=%s\\n\' "$keymap"',
            "SPECTRM_EFI",
            "/usr/lib/spectrumos/limine-appearance-sync",
        ):
            self.assertIn(value, content)
        self.assertNotIn("--exclude='packages/*/src'", content)
        self.assertIn("vmlinuz-linux-zen", content)
        self.assertIn("initramfs-linux-zen.img", content)
        self.assertIn("initramfs-linux-zen-fallback.img", content)

    def test_rescue_uki_directory_exists_before_spectrum_packages_are_installed(self):
        content = (INSTALLER / "spectrum-installer-backend").read_text(encoding="utf-8")
        create_directory = 'mkdir -p "$target/boot/EFI/Linux"'
        self.assertIn(create_directory, content)
        self.assertLess(content.index(create_directory), content.index("\n    install_spectrum_repository\n"))

    def test_graphical_frontend_uses_spectrum_branding_and_root_boundary(self):
        frontend = (INSTALLER / "spectrum-installer").read_text(encoding="utf-8")
        self.assertIn('gi.require_version("Gtk", "4.0")', frontend)
        self.assertIn('"logo.svg"', frontend)
        self.assertNotIn("logo.set_size_request(48, 48)", frontend)
        self.assertIn('"pkexec", BACKEND', frontend)
        self.assertIn("Everything on the selected disk will be permanently erased", frontend)
        self.assertNotIn("Wi-Fi & network settings", frontend)
        self.assertIn("SpectrumOS downloads packages during installation", frontend)
        self.assertIn('"keyboard": self.keyboard_profiles', frontend)
        self.assertIn('"--keyboard", options["keyboard"]', frontend)
        self.assertIn('"Spanish (Latin America)"', frontend)
        self.assertIn('tr_widget(Gtk.Entry, text="igor")', frontend)
        self.assertIn("Adds laptop power management, battery support, brightness controls", frontend)
        self.assertIn("label=msg('Exit installer')", frontend)
        self.assertIn("label=msg('Restart')", frontend)
        self.assertIn("label=msg('Power off')", frontend)
        # GTK4's default CSD reserves an invisible shadow/resize margin around the whole
        # toplevel surface -- Hyprland doesn't crop it the way Mutter does, so it rendered
        # live as a ~30px genuinely transparent frame outside this window's own custom
        # border. set_decorated(False) alone wasn't enough -- confirmed live, the frame
        # was still there after that shipped -- because it only drops the header bar; the
        # margin itself is sized from GTK4's own default box-shadow on the window/csd
        # decoration node, which has to be zeroed directly in CSS to actually remove it.
        self.assertIn("self.window.set_decorated(False)", frontend)
        self.assertIn("self.window.set_size_request(480, 360)", frontend)
        self.assertNotIn("set_margin_top(42)", frontend)
        self.assertNotIn("set_size_request(280, -1)", frontend)
        style = (INSTALLER / "style.css").read_text(encoding="utf-8")
        self.assertIn("window.csd decoration { box-shadow: none; margin: 0; }", style)
        self.assertIn(".installer-shell { background: #__BACKGROUND__; padding: 16px; }", style)
        self.assertTrue((ROOT / "assets/branding/spectrum-logo.svg").is_file())
        # append_log() only ever inserted at the buffer's end iter -- the log view
        # itself stayed wherever it was scrolled (the top, on first open) as new
        # lines landed below the visible area, so watching progress meant
        # repeatedly scrolling down by hand. Confirmed live.
        append_log = frontend.split("def append_log(self, line):", 1)[1].split("\n\n", 1)[0]
        self.assertIn("scroll_to_iter", append_log)

    def test_graphics_selector_supports_discrete_and_hybrid_nvidia(self):
        frontend = (INSTALLER / "spectrum-installer").read_text(encoding="utf-8")
        backend = (INSTALLER / "spectrum-installer-backend").read_text(encoding="utf-8")
        for profile in ("nvidia", "nvidia-intel", "nvidia-amd"):
            self.assertIn(profile, frontend)
            self.assertIn(profile, backend)
        self.assertIn('"NVIDIA + Intel (hybrid)"', frontend)
        self.assertIn('"NVIDIA + AMD (hybrid)"', frontend)
        self.assertIn('"vga compatible controller"', frontend)
        self.assertIn("switcheroo-control.service", backend)

    def test_iso_starts_a_non_root_branded_live_session(self):
        packages = (ROOT / "iso/spectrumos/packages.x86_64").read_text(encoding="utf-8")
        for package in ("gtk4", "hyprland", "network-manager-applet", "pciutils", "python-gobject", "polkit-gnome", "swaybg", "quickshell"):
            self.assertIn(f"\n{package}\n", f"\n{packages}\n")
        self.assertNotIn("\nwaybar\n", f"\n{packages}\n")
        self.assertNotIn("\nwofi\n", f"\n{packages}\n")
        autologin = (
            ROOT
            / "iso/spectrumos/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf"
        ).read_text(encoding="utf-8")
        self.assertIn("--autologin spectrum", autologin)
        # Hyprland's own native config is Lua (the classic .conf format warns it
        # will change in a future release). Routing the launch through `uwsm
        # start` to also silence its "started without uwsm" warning broke
        # everything the first two times, both traced to the same root cause:
        # uwsm's own environment preloader sources /etc/profile as part of *its*
        # startup, which cascades into every /etc/profile.d/*.sh. Installing the
        # launcher itself as one of those files (it used to be
        # /etc/profile.d/99-spectrum-live.sh) re-entered its own guards and
        # re-exec'd uwsm start from inside uwsm's own probe shell, corrupting its
        # environment-capture handshake and leaving the compositor dead --
        # confirmed live as a black screen on every boot. The fix is to stop the
        # launcher from being reachable via /etc/profile.d at all: it's now
        # spectrum's actual login shell (see spectrum-live-user.conf), so
        # /etc/profile's own cascade never reaches it a second time, and uwsm's
        # env preload and `uwsm app` (used below) both work normally.
        live = (INSTALLER / "live-hyprland.lua").read_text(encoding="utf-8")
        self.assertIn("spectrum-installer", live)
        self.assertIn("wallpaper.png", live)
        self.assertIn('hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("uwsm app -- foot"))', live)
        self.assertIn('hl.bind(mainMod .. " + Q", hl.dsp.window.close())', live)
        self.assertIn('hl.exec_cmd("uwsm app -s s -- /usr/local/bin/spectrum-installer")', live)
        self.assertIn("live-network", live)
        self.assertIn("qs --path /usr/share/spectrumos/installer/shell", live)
        self.assertIn("disable_splash_rendering = true", live)
        session = (INSTALLER / "spectrum-live-session").read_text(encoding="utf-8")
        self.assertIn("HYPRLAND_CONFIG=/etc/spectrumos/live-hyprland.lua", session)
        self.assertIn("exec uwsm start -e -D Hyprland hyprland.desktop", session)
        self.assertIn("\nuwsm\n", f"\n{packages}\n")

        network = (INSTALLER / "spectrum-live-network").read_text(encoding="utf-8")
        live_shell = (INSTALLER / "live-shell.qml").read_text(encoding="utf-8")
        self.assertIn("spectrum-live toggleNetwork", network)
        self.assertIn('"connect-secured"', live_shell)
        self.assertIn("TextInput.Password", live_shell)
        self.assertIn('"/usr/local/bin/spectrum-installer"', live_shell)
        self.assertIn('"/usr/local/bin/spectrum-rescue-shell"', live_shell)

        user_conf = (INSTALLER / "spectrum-live-user.conf").read_text(encoding="utf-8")
        self.assertIn("/usr/local/bin/spectrum-live-session", user_conf)
        # pam_shells.so (required by /etc/pam.d/system-login, which login's own
        # PAM stack includes via system-local-login) refuses to authenticate an
        # account whose shell isn't listed in /etc/shells at all -- without this
        # override, making the launcher spectrum's shell would fail the tty1
        # autologin outright rather than ever reaching Hyprland.
        shells = (ROOT / "iso/spectrumos/airootfs/etc/shells").read_text(encoding="utf-8")
        self.assertIn("/usr/local/bin/spectrum-live-session", shells)
        self.assertIn("/usr/bin/bash", shells)

        builder = (ROOT / "scripts/build-iso").read_text(encoding="utf-8")
        self.assertIn(
            'install -m 0755 "$project_root/installer/spectrum-live-session" \\\n'
            '    "$staging/airootfs/usr/local/bin/spectrum-live-session"',
            builder,
        )
        self.assertIn("spectrum-installer-backend", builder)
        self.assertIn('"$project_root/installer/live-shell.qml"', builder)
        self.assertIn('"$project_root/scripts/network-adapter"', builder)
        self.assertIn('chmod 0755 "$staging/airootfs$source_path/scripts/check-lean-package"', builder)
        self.assertIn("appearance/logo.svg", builder)
        self.assertIn('s/width="278" height="250"/width="16" height="14"/', builder)
        self.assertNotIn('"$staging/airootfs$source_path/vendor/eww"', builder)
        self.assertIn('"$staging/airootfs$source_path/vendor/paru"', builder)
        self.assertIn('"$palette_json/current/gtk-3.css"', builder)
        self.assertIn('"$project_root/installer/live-gtk-settings.ini"', builder)
        self.assertIn("NetworkManager.service", builder)
        self.assertIn("multi-user.target.wants/iwd.service", builder)
        self.assertIn("dbus-org.freedesktop.network1.service", builder)
        self.assertIn("appearance/logo.svg", builder)

    def test_optional_browsers_are_opt_in_via_checkboxes(self):
        frontend = (INSTALLER / "spectrum-installer").read_text(encoding="utf-8")
        backend = (INSTALLER / "spectrum-installer-backend").read_text(encoding="utf-8")
        for label in ("label=msg('Google Chrome')", "label=msg('Brave')", "label=msg('Zen Browser')"):
            self.assertIn(label, frontend)
        self.assertIn('"browsers": ",".join(self.selected_browsers())', frontend)
        self.assertIn('"--browsers", options["browsers"]', frontend)
        self.assertIn("browser_packages=([chrome]=google-chrome [brave]=brave-bin [zen]=zen-browser-bin)", backend)
        self.assertIn("aur_packages=(gowall-bin vesktop-bin)", backend)
        self.assertIn("if [[ $lean == false ]]; then", backend)
        for value in ("google-chrome", "brave-bin", "zen-browser-bin"):
            self.assertIn(value, backend)
        # A failure here is best-effort, not fatal to the whole install.
        self.assertIn("skipping desktop AUR applications", backend)
        self.assertIn('sudoers_file=$target/etc/sudoers.d/90-spectrum-aur-build', backend)
        self.assertIn('install -m 0755 "$project_root/vendor/paru"', backend)
        self.assertIn('rm -f "$sudoers_file"', backend)
        self.assertNotIn("trap 'rm -f \"$sudoers_file\"' RETURN", backend)

    def test_live_user_can_save_networkmanager_connections(self):
        rules = (INSTALLER / "49-spectrum-installer.rules").read_text(encoding="utf-8")
        self.assertIn("org.freedesktop.NetworkManager.", rules)
        self.assertIn('subject.user == "spectrum"', rules)

    def test_recovery_menu_is_valid_and_reachable_without_a_password(self):
        recovery = INSTALLER / "spectrum-recovery"
        syntax = subprocess.run(("bash", "-n", str(recovery)), check=False, capture_output=True, text=True)
        self.assertEqual(syntax.returncode, 0, syntax.stderr)

        content = recovery.read_text(encoding="utf-8")
        for value in (
            "exec sudo \"$0\" \"$@\"",
            "arch-chroot",
            "spectrum-snapshot restore",
            "spectrum-snapshot list --root-device",
            "limine bios-install",
            "BOOTX64.EFI",
            "nmtui",
            "smartctl",
        ):
            self.assertIn(value, content)

        live = (INSTALLER / "live-hyprland.lua").read_text(encoding="utf-8")
        self.assertIn(
            'hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("uwsm app -- foot --title=\\"Rescue system\\" -e /usr/local/bin/spectrum-rescue-shell"))',
            live,
        )

        sudoers = (INSTALLER / "10-spectrum-live").read_text(encoding="utf-8")
        self.assertIn("NOPASSWD: /usr/local/bin/spectrum-recovery", sudoers)

        builder = (ROOT / "scripts/build-iso").read_text(encoding="utf-8")
        self.assertIn('"$staging/airootfs/usr/local/bin/spectrum-recovery"', builder)

        motd = (ROOT / "iso/spectrumos/airootfs/etc/motd").read_text(encoding="utf-8")
        self.assertIn("Super+R", motd)

        profile = (ROOT / "iso/spectrumos/profiledef.sh").read_text(encoding="utf-8")
        self.assertIn('["/usr/local/bin/spectrum-recovery"]="0:0:755"', profile)


if __name__ == "__main__":
    unittest.main()
