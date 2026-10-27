from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import tempfile
import unittest
import re
import tempfile
import tarfile


ROOT = Path(__file__).resolve().parents[1]


class IsoProfileTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required to verify the live password hash")
    def test_live_ssh_starts_with_the_requested_root_password(self):
        live = ROOT / "iso/spectrumos/airootfs"
        service = live / "etc/systemd/system/multi-user.target.wants/sshd.service"
        self.assertTrue(service.is_symlink())
        self.assertEqual(str(service.readlink()), "/usr/lib/systemd/system/sshd.service")
        self.assertIn("openssh", (ROOT / "iso/spectrumos/packages.x86_64").read_text().splitlines())
        settings = (live / "etc/ssh/sshd_config.d/10-archiso.conf").read_text().splitlines()
        for setting in ("PasswordAuthentication yes", "PermitRootLogin yes", "PermitEmptyPasswords no"):
            self.assertIn(setting, settings)
        root = next(row for row in (live / "etc/shadow").read_text().splitlines() if row.startswith("root:"))
        encoded = root.split(":")[1]
        self.assertTrue(encoded.startswith("$6$"))
        calculated = subprocess.check_output(
            ["openssl", "passwd", "-6", "-salt", encoded.split("$")[2], "-stdin"],
            input="spectrum\n", text=True,
        ).strip()
        self.assertEqual(encoded, calculated)

    def test_every_0755_usr_local_install_has_a_matching_profiledef_permission(self):
        # mkarchiso resets every squashfs file's permissions to profiledef.sh's
        # file_permissions table (644 for anything not listed), independent of
        # whatever mode build-iso's own `install -m` staged it with. A script
        # installed 0755 into the staging airootfs but left out of that table
        # silently loses its executable bit in the finished ISO. That's exactly
        # what happened to spectrum-live-session -- installed correctly, absent
        # from file_permissions, and it's the "spectrum" account's login shell,
        # so login(1) failed to exec it on every autologin: instant session
        # close, getty respawn, repeat -- confirmed live via QEMU debug-boot as
        # a login/getty loop that read as "Hyprland loops, then black screen"
        # once the restart-limit killed tty1's getty for good. Catch the whole
        # class instead of re-adding one more spot-check per script.
        builder = (ROOT / "scripts/build-iso").read_text(encoding="utf-8")
        profile = (ROOT / "iso/spectrumos/profiledef.sh").read_text(encoding="utf-8")
        paths = re.findall(
            r'install -m 0755 "[^"]*" \\?\s*"\$staging/airootfs(/usr/local/(?:bin|lib)/[^"]+)"',
            builder,
        )
        self.assertGreaterEqual(len(paths), 5, "sanity check: the regex should match known installs")
        for path in paths:
            with self.subTest(path=path):
                self.assertIn(f'["{path}"]="0:0:755"', profile)

    def test_profile_has_spectrum_identity_and_recovery_payload(self):
        profile = (ROOT / "iso/spectrumos/profiledef.sh").read_text(encoding="utf-8")
        packages = (ROOT / "iso/spectrumos/packages.x86_64").read_text(encoding="utf-8")
        self.assertIn('iso_name="spectrumos"', profile)
        self.assertIn('install_dir="spectrum"', profile)
        for package in ("inxi", "brightnessctl", "mesa", "vulkan-tools", "bluez-utils"):
            self.assertIn(f"\n{package}\n", f"\n{packages}\n")
        self.assertIn("\nlinux-zen\n", f"\n{packages}\n")
        self.assertNotIn("\nlinux\n", f"\n{packages}\n")
        self.assertTrue((ROOT / "iso/spectrumos/airootfs/usr/local/bin/spectrum-hardware-report").is_file())

    def test_live_environment_gets_explicit_zram_policy(self):
        packages = (ROOT / "iso/spectrumos/packages.x86_64").read_text(encoding="utf-8")
        builder = (ROOT / "scripts/build-iso").read_text(encoding="utf-8")
        policy = ROOT / "system/zram-generator.conf.d/60-spectrumos.conf"
        self.assertIn("\nzram-generator\n", f"\n{packages}\n")
        self.assertIn("system/zram-generator.conf.d/60-spectrumos.conf", builder)
        self.assertIn("usr/lib/systemd/zram-generator.conf.d/60-spectrumos.conf", builder)
        self.assertIn("zram-size = min(ram, 8192)", policy.read_text(encoding="utf-8"))

    def test_iso_source_staging_excludes_private_and_ignored_state(self):
        builder = (ROOT / "scripts/build-iso").read_text(encoding="utf-8")
        block = builder.split('tar -C "$project_root"', 1)[1].split('-cf - . | tar', 1)[0]
        flags = ["--exclude=" + value for value in re.findall(r"--exclude='([^']+)'", block)]
        self.assertIn("--exclude-vcs-ignores", block)
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "source"
            fixture.mkdir()
            (fixture / ".gitignore").write_text((ROOT / ".gitignore").read_text())
            for relative in ("scripts/check-lean-package", "repo/keys/public.asc",
                             "repo/state/gnupg/private-keys-v1.d/example.key", "secrets/credential",
                             "personal/settings", "spectrumos-personal/settings", "state/runtime",
                             "generated/private-cache", "private.pem",
                             ".comem/comem.py", ".comem/inventory.json", ".comem/records/example.json"):
                path = fixture / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("synthetic fixture")
            archive = Path(directory) / "source.tar"
            subprocess.run(["tar", "-C", str(fixture), "--exclude-vcs-ignores", *flags,
                            "-cf", str(archive), "."], check=True)
            with tarfile.open(archive) as exported:
                names = set(exported.getnames())
            self.assertIn("./scripts/check-lean-package", names)
            self.assertIn("./repo/keys/public.asc", names)
            for prefix in ("./repo/state", "./secrets", "./personal", "./spectrumos-personal",
                           "./state", "./generated", "./private.pem", "./.comem"):
                self.assertFalse(any(name == prefix or name.startswith(prefix + "/") for name in names), prefix)

    def test_iso_preserves_source_executables_through_archiso_normalization(self):
        builder = (ROOT / "scripts/build-iso").read_text()
        marker = 'python - "$staging/airootfs$source_path" "$staging/profiledef.sh" "$source_path" <<\'PY\'\n'
        code = builder.split(marker, 1)[1].split("\nPY\n", 1)[0]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            source.mkdir()
            profile = root / "profiledef.sh"
            profile.write_text("declare -A file_permissions=()\n")
            for name, mode in (("integrations/ukvm/install", 0o755),
                               ("scripts/appearance-sync", 0o755),
                               ("integrations/questline/spectrum-focus", 0o755),
                               ("scripts/quoted name's helper", 0o755),
                               ("configs/example.conf", 0o644)):
                path = source / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("fixture")
                path.chmod(mode)
            (source / "link").symlink_to(source / "integrations/ukvm/install")
            subprocess.run(["python", "-", str(source), str(profile), "/source"],
                           input=code, text=True, check=True)
            result = subprocess.run(["bash", "-c", 'source "$1"; for path in "${!file_permissions[@]}"; do printf "%s=%s\\n" "$path" "${file_permissions[$path]}"; done',
                                     "test", str(profile)], capture_output=True, text=True, check=True)
            for name in ("integrations/ukvm/install", "scripts/appearance-sync",
                         "integrations/questline/spectrum-focus", "scripts/quoted name's helper"):
                self.assertIn("/source/" + name + "=0:0:755", result.stdout)
            self.assertNotIn("example.conf", result.stdout)
            self.assertNotIn("/source/link", result.stdout)

    def test_builder_is_dry_run_by_default_and_stages_current_source(self):
        result = subprocess.run(
            ("bash", str(ROOT / "scripts/build-iso")),
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertIn("Dry-run only", result.stdout)
        builder = (ROOT / "scripts/build-iso").read_text(encoding="utf-8")
        self.assertIn("/usr/local/share/spectrumos/source", builder)
        self.assertIn('ln -s "$source_path" "$staging/airootfs/root/SpectrumOS2"', builder)
        self.assertIn('chmod 0755 "$staging/airootfs$source_path/install.sh"', builder)
        self.assertIn("scripts/snapshot", builder)
        self.assertIn('packages/spectrum-theme/src/.', builder)
        self.assertIn("mkarchiso", builder)
        self.assertIn("limine-bios-cd.bin", builder)
        self.assertIn("limine-uefi-cd.bin", builder)
        self.assertIn('limine bios-install "$limine_image"', builder)
        self.assertIn("wallpaper: boot():/spectrum-wallpaper.png", builder)
        self.assertIn('scripts/spectrum-repo" verify --channel edge', builder)
        self.assertIn("var/lib/spectrumos/repository/edge/x86_64", builder)
        self.assertIn('cp -a -- "$repository/."', builder)
        self.assertIn('mktemp -d "$temporary_parent/.iso-build.XXXXXX"', builder)
        self.assertIn("trap 'rm -rf -- \"$temporary_root\"' EXIT", builder)
        self.assertNotIn("/tmp/spectrumos-archiso", builder)
        self.assertNotIn("/tmp/spectrumos-profile", builder)
        profile = (ROOT / "iso/spectrumos/profiledef.sh").read_text(encoding="utf-8")
        self.assertIn('["/usr/local/share/spectrumos/source/install.sh"]="0:0:755"', profile)

    def test_limine_repack_preserves_the_archiso_boot_medium_identity(self):
        # The Limine hybrid repack creates a brand-new ISO 9660 volume, which
        # gets a fresh creation timestamp. The archiso boot entry's
        # archisosearchuuid is matched against that timestamp, so carrying it
        # over unmodified would make the live environment unable to find its
        # own boot medium (it would silently fail to boot). Volume-label
        # search survives a repack as long as the label itself is preserved.
        builder = (ROOT / "scripts/build-iso").read_text(encoding="utf-8")
        self.assertIn("archiso_volid=$(xorriso -indev \"$archiso_image\" -pvd_info", builder)
        self.assertIn("archisosearchuuid=[^ ]*/archisolabel=$archiso_volid", builder)
        self.assertIn('xorriso -as mkisofs -R -r -J -V "$archiso_volid"', builder)
        self.assertLess(
            builder.index("archiso_volid=$(xorriso"),
            builder.index('cmdline: $archiso_options'),
        )

    def test_live_wifi_settings_are_available_from_shell(self):
        packages = (ROOT / "iso/spectrumos/packages.x86_64").read_text(encoding="utf-8")
        self.assertIn("\nquickshell\n", f"\n{packages}\n")
        self.assertNotIn("\nwaybar\n", f"\n{packages}\n")
        self.assertNotIn("\nwofi\n", f"\n{packages}\n")
        network = (ROOT / "installer/spectrum-live-network").read_text(encoding="utf-8")
        self.assertIn("spectrum-live toggleNetwork", network)
        live_shell = (ROOT / "installer/live-shell.qml").read_text(encoding="utf-8")
        self.assertIn("connect-secured", live_shell)
        self.assertIn("TextInput.Password", live_shell)
        builder = (ROOT / "scripts/build-iso").read_text(encoding="utf-8")
        self.assertIn("live-shell.qml", builder)
        self.assertIn('palette_json/current/palette.json', builder)

    def test_live_wifi_covers_broadcom_only_chips_and_can_build_dkms(self):
        # Algunas MacBook de alrededor de 2011 usan chips Broadcom cuyo soporte
        # libre no basta. El módulo wl debe compilarse contra el mismo kernel
        # zen de la imagen, por eso sus headers forman parte del perfil en vivo.
        packages = (ROOT / "iso/spectrumos/packages.x86_64").read_text(encoding="utf-8")
        for package in ("broadcom-wl-dkms", "linux-zen-headers", "linux-firmware-qcom"):
            self.assertIn(f"\n{package}\n", f"\n{packages}\n")

    def test_every_live_bootloader_uses_the_zen_kernel(self):
        paths = (
            ROOT / "scripts" / "build-iso",
            ROOT / "iso" / "spectrumos" / "syslinux" / "archiso_pxe-linux.cfg",
            ROOT / "iso" / "spectrumos" / "syslinux" / "archiso_sys-linux.cfg",
            ROOT / "iso" / "spectrumos" / "grub" / "loopback.cfg",
            ROOT / "iso" / "spectrumos" / "grub" / "grub.cfg",
            ROOT / "iso" / "spectrumos" / "efiboot" / "loader" / "entries" / "01-archiso-linux.conf",
            ROOT / "iso" / "spectrumos" / "efiboot" / "loader" / "entries" / "02-archiso-speech-linux.conf",
        )
        for path in paths:
            with self.subTest(path=path):
                content = path.read_text(encoding="utf-8")
                self.assertIn("vmlinuz-linux-zen", content)
                self.assertIn("initramfs-linux-zen.img", content)
                self.assertNotRegex(content, r"vmlinuz-linux(?!-zen)")
                self.assertNotRegex(content, r"initramfs-linux\.img")

    @unittest.skipUnless(os.environ.get("SPECTRUM_ALLOW_ISO_FIXTURE") == "1", "ISO fixture creation requires explicit ISO-build authorization")
    def test_repacked_hybrid_iso_has_no_bogus_partitions(self):
        # -hfsplus -apm-block-size 2048 used to sit in this xorriso invocation
        # for Mac/APM boot support this project never actually ships (no HFS+
        # content, no -hfs-bless-by). It made xorriso wrap the *entire*
        # ISO9660 data area in a bogus partition (type 0xAF, starting well
        # past sector 0 -- so it doesn't even line up with where the real
        # ISO9660 filesystem begins) plus a stray trailing partition. QEMU's
        # `-cdrom`/`media=cdrom` boots the image via its El Torito catalog and
        # never looks at the partition table, so it always booted fine there
        # -- but a real USB stick (or any raw-disk boot -- reproduced with
        # `-drive format=raw` instead of `-cdrom`) is read through that same
        # broken table: archiso's `archisolabel=` device search lands on the
        # bogus partition and fails with exactly "mount: /run/archiso/bootmnt:
        # wrong fs type, bad option, bad superblock" / "ERROR; failed to mount
        # /dev/disk/by-label/...", confirmed live and reproduced+fixed here.
        if shutil.which("xorriso") is None:
            self.skipTest("xorriso is unavailable on this test host")
        if shutil.which("sfdisk") is None:
            self.skipTest("sfdisk is unavailable on this test host")
        builder = (ROOT / "scripts/build-iso").read_text(encoding="utf-8")
        marker = 'xorriso -as mkisofs -R -r -J -V "$archiso_volid"'
        tail = '"$limine_root" -o "$limine_image"'
        self.assertIn(marker, builder)
        self.assertIn(tail, builder)
        command = marker + builder.split(marker, 1)[1].split(tail, 1)[0] + tail
        self.assertNotIn("-hfsplus", command)
        self.assertNotIn("-apm-block-size", command)

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "root"
            (root / "boot" / "limine").mkdir(parents=True)
            (root / "EFI" / "BOOT").mkdir(parents=True)
            # xorriso embeds these boot images verbatim without validating
            # their content, so placeholder bytes are enough to exercise the
            # exact same partitioning logic build-iso itself triggers.
            (root / "boot" / "limine" / "limine-bios-cd.bin").write_bytes(b"\0" * 2048)
            (root / "boot" / "limine" / "limine-uefi-cd.bin").write_bytes(b"\0" * (1024 * 1024))
            script = (
                'archiso_volid=TESTVOL\n'
                'limine_root=root\n'
                'limine_image=out.iso\n'
                f'{command}\n'
            )
            subprocess.run(
                ("bash", "-c", script), cwd=directory, check=True, capture_output=True, text=True,
            )
            image = Path(directory) / "out.iso"
            self.assertTrue(image.is_file(), "the test xorriso repack did not produce an image")
            table = json.loads(
                subprocess.run(
                    ("sfdisk", "-J", str(image)), check=True, capture_output=True, text=True,
                ).stdout
            )
            partitions = table["partitiontable"]["partitions"]
            # sfdisk reports the partition table as classic MBR hex codes
            # ("af") or as GPT type GUIDs depending on image size/structure --
            # xorriso's actual Apple HFS+ marker is stable either way, so
            # check for both spellings rather than depending on which one
            # this particular image happens to get.
            types = [partition["type"].lower() for partition in partitions]
            self.assertNotIn("af", types, f"a bogus HFS/HFS+ partition reappeared: {partitions}")
            self.assertNotIn(
                "48465300-0000-11aa-aa11-00306543ecac", types,
                f"a bogus HFS/HFS+ partition reappeared: {partitions}",
            )

    def test_repacked_iso_is_readable_by_the_user_who_will_burn_it(self):
        builder = (ROOT / "scripts/build-iso").read_text(encoding="utf-8")
        self.assertIn('chmod 0644 "$archiso_image"', builder)

    def test_checksum_is_generated_after_the_limine_repack(self):
        builder = (ROOT / "scripts/build-iso").read_text(encoding="utf-8")
        repack = builder.index('mv -f "$limine_image" "$archiso_image"')
        checksum = builder.index('sha256sum "$checksum_name" > "$checksum_name.sha256"')
        self.assertGreater(checksum, repack)

    def test_live_boot_does_not_stall_waiting_for_network(self):
        # NetworkManager-wait-online.service blocks network-online.target
        # for up to its NM_ONLINE_TIMEOUT=60s default when nothing is
        # connected yet -- confirmed live as a "graphical.target is queued
        # for start, waiting for 60s..." stall on every boot of the live
        # medium (which has no network configured out of the box). Masked
        # the same way this profile already masks systemd-gpt-auto-generator.
        unit = ROOT / "iso/spectrumos/airootfs/etc/systemd/system/NetworkManager-wait-online.service"
        self.assertTrue(unit.is_symlink(), "NetworkManager-wait-online.service must be masked")
        self.assertEqual(os.readlink(unit), "/dev/null")
        builder = (ROOT / "scripts/build-iso").read_text(encoding="utf-8")
        self.assertIn("cloud-init.target.wants", builder)
        self.assertIn("systemd-time-wait-sync.service", builder)

    def test_embedded_binaries_remain_executable_in_the_iso(self):
        profile = (ROOT / "iso/spectrumos/profiledef.sh").read_text(encoding="utf-8")
        for binary in ("paru",):
            self.assertIn(
                f'["/usr/local/share/spectrumos/source/vendor/{binary}"]="0:0:755"',
                profile,
            )

    def test_live_and_installed_defaults_use_the_new_wallpaper(self):
        builder = (ROOT / "scripts/build-iso").read_text(encoding="utf-8")
        installer = (ROOT / "install.sh").read_text(encoding="utf-8")
        restorer = (ROOT / "scripts/wallpaper-restore").read_text(encoding="utf-8")
        self.assertEqual(builder.count("assets/wallpapers/default/S30.png"), 5)
        self.assertIn("--mode clustered --variant dark", builder)
        self.assertIn("Pictures/Wallpapers/S30.png", installer)
        self.assertIn("Pictures/Wallpapers/S30.png", restorer)
        self.assertIn("/usr/share/backgrounds/spectrumos/S30.png", restorer)
        for text in (builder, installer, restorer):
            self.assertNotIn("spectrumos-wall5.png", text)

    def test_profile_ships_the_branded_plymouth_splash_for_the_live_boot(self):
        # The archiso default profile never shows a splash on its own -- no
        # plymouth in HOOKS, no plymouth package, no quiet/splash on the
        # kernel cmdline -- so the live/installer boot dropped straight from
        # Limine's own branded menu to plain kernel text. This wires the same
        # spectrumos theme the installed system gets (spectrum-plymouth) into
        # the live squashfs image itself.
        packages = (ROOT / "iso/spectrumos/packages.x86_64").read_text(encoding="utf-8")
        self.assertIn("\nplymouth\n", f"\n{packages}\n")
        hooks = (ROOT / "iso/spectrumos/airootfs/etc/mkinitcpio.conf.d/archiso.conf").read_text(encoding="utf-8")
        self.assertIn("plymouth", hooks)
        self.assertLess(hooks.index("plymouth"), hooks.index("kms"))
        plymouthd = (ROOT / "iso/spectrumos/airootfs/etc/plymouth/plymouthd.conf").read_text(encoding="utf-8")
        self.assertIn("Theme=spectrumos", plymouthd)
        theme = ROOT / "iso/spectrumos/airootfs/usr/share/plymouth/themes/spectrumos"
        self.assertTrue((theme / "spectrumos.plymouth").is_file())
        self.assertTrue((theme / "spectrumos.script").is_file())
        self.assertEqual(len(list(theme.glob("progress-*.png"))), 240)
        self.assertTrue((theme / "progress-239.png").is_file())
        canonical = ROOT / "configs/plymouth/themes/spectrumos"
        self.assertEqual((theme / "spectrumos.script").read_bytes(),
                         (canonical / "spectrumos.script").read_bytes())
        self.assertTrue((
            ROOT / "iso/spectrumos/airootfs/usr/lib/systemd/system/plymouth-quit.service.d"
            "/20-spectrumos-duration.conf"
        ).is_file())

    def test_live_initramfs_has_every_archiso_pxe_binary(self):
        packages = (ROOT / "iso/spectrumos/packages.x86_64").read_text(encoding="utf-8").splitlines()
        self.assertIn("nbd", packages)

    def test_builder_adds_quiet_and_splash_to_the_live_cmdline_without_duplicating(self):
        # Same append-if-missing rule plymouth-boot-sync uses for the
        # installed system's own Limine entries, so re-running this builder
        # never doubles the flags up on an entry that already has them.
        builder = (ROOT / "scripts/build-iso").read_text(encoding="utf-8")
        loop = builder.split("for flag in quiet splash; do", 1)[1].split("\ndone", 1)[0]
        loop = "for flag in quiet splash; do" + loop + "\ndone"
        for missing in ("archisobasedir=spectrum archisolabel=SPEC_20260905",):
            result = subprocess.run(
                f'archiso_options={missing!r}\n{loop}\nprintf %s "$archiso_options"',
                shell=True, capture_output=True, text=True, check=True,
            )
            self.assertEqual(result.stdout, f"{missing} quiet splash")
        already_present = subprocess.run(
            f'archiso_options="archisolabel=SPEC_20260905 quiet splash"\n{loop}\nprintf %s "$archiso_options"',
            shell=True, capture_output=True, text=True, check=True,
        )
        self.assertEqual(already_present.stdout, "archisolabel=SPEC_20260905 quiet splash")

    def test_volid_extraction_matches_real_xorriso_pvd_info_output(self):
        # A prior version of this sed pattern matched xorriso's plain
        # -indev summary line ("Volume id    : 'SPEC_20260903'", lowercase,
        # quoted) instead of the actual -pvd_info dump this script parses
        # ("Volume Id    : SPEC_20260903", capital Id, unquoted) -- it
        # silently extracted nothing and aborted every build. Run the
        # script's own sed command against real captured -pvd_info output
        # to make sure that regression can't come back unnoticed.
        sample = (
            "xorriso 1.5.8.pl02 : RockRidge filesystem manipulator, libburnia project.\n\n"
            "Drive current: -indev 'spectrumos.iso'\n"
            "PVD address  : 16s\n"
            "Volume Id    : SPEC_20260903\n"
            "Volume Set Id: \n"
        )
        result = subprocess.run(
            "sed -n 's/^Volume Id[[:space:]]*:[[:space:]]*//p' | head -n 1 | tr -d '[:space:]'",
            shell=True,
            input=sample,
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertEqual(result.stdout, "SPEC_20260903")


if __name__ == "__main__":
    unittest.main()
