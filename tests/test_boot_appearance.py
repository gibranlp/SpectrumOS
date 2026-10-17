import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]


class BootAppearanceTests(unittest.TestCase):
    def test_limine_sync_brands_entries_and_adds_global_appearance(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            boot = root / "boot"
            config = boot / "EFI" / "BOOT" / "limine.conf"
            appearance = root / "appearance"
            config.parent.mkdir(parents=True)
            appearance.mkdir()
            original_entry = (
                "/Arch Linux\n"
                "    protocol: efi\n"
                "    path: boot():/EFI/Linux/arch.efi\n"
            )
            config.write_text(
                "timeout: 5\n\n"
                "menu_foreground: ffffff\nmenu_highlight_background: 00ff00\n"
                "  TERM_FOREGROUND: ffffff\nterm_foreground: aaaaaa\n"
                "interface_branding_color: 00ffff\n"
                + original_entry,
                encoding="utf-8",
            )
            (appearance / "current.png").write_bytes(b"wallpaper")
            (appearance / "colors.conf").write_text(
                "background=#102030\nsurface=#203040\nforeground=#f0f2f4\n"
                "muted=#a0a8b0\naccent=#70a0d0\naccent_alt=#a080c0\n",
                encoding="utf-8",
            )

            command = [
                "python",
                str(ROOT / "scripts/limine-appearance-sync"),
                "--config",
                str(config),
                "--boot-root",
                str(boot),
                "--appearance",
                str(appearance),
            ]
            subprocess.run(command, check=True)
            updated = config.read_text(encoding="utf-8")
            self.assertIn("/SpectrumOS\n    protocol: efi\n    path: boot():/EFI/Linux/arch.efi\n", updated)
            self.assertNotIn("/Arch Linux", updated)
            self.assertIn("wallpaper: boot():/EFI/BOOT/spectrumos-wallpaper.png", updated)
            self.assertIn("term_foreground: 70a0d0\n", updated)
            self.assertIn("term_background: cc102030\n", updated)
            self.assertIn("term_background_bright: 203040\n", updated)
            self.assertIn("term_foreground_bright: a080c0\n", updated)
            self.assertIn("interface_branding_colour: a080c0\n", updated)
            self.assertIn("interface_help_colour: a0a8b0\n", updated)
            self.assertIn("interface_help_colour_bright: 70a0d0\n", updated)
            self.assertIn("term_palette: 102030;70a0d0;a080c0;70a0d0;a080c0;a080c0;a080c0;f0f2f4\n", updated)
            self.assertIn("term_palette_bright: 203040;70a0d0;a080c0;70a0d0;a080c0;a080c0;a080c0;f0f2f4\n", updated)
            self.assertNotIn("menu_foreground:", updated)
            self.assertNotIn("menu_highlight_background:", updated)
            self.assertNotIn("interface_branding_color:", updated)
            self.assertEqual(updated.count("term_foreground:"), 1)
            self.assertTrue(config.with_suffix(".conf.spectrumos-backup").is_file())
            subprocess.run(command, check=True)
            self.assertEqual(updated, config.read_text(encoding="utf-8"))

    def test_wallpaper_stage_normalizes_image_and_exports_semantic_colors(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            appearance = root / "appearance"
            appearance.mkdir()
            wallpaper = root / "wallpaper.ppm"
            wallpaper.write_text("P3\n1 1\n255\n20 40 60\n", encoding="ascii")
            palette = root / "palette.json"
            palette.write_text(
                json.dumps(
                    {
                        "roles": {
                            "background": "#102030",
                            "surface": "#203040",
                            "foreground": "#f0f2f4",
                            "muted": "#a0a8b0",
                            "accent": "#70a0d0",
                            "accent_alt": "#a080c0",
                        }
                    }
                ),
                encoding="utf-8",
            )
            environment = os.environ | {
                "SPECTRUM_APPEARANCE_DIR": str(appearance),
                "SPECTRUM_PALETTE": str(palette),
                "SPECTRUM_WORDMARK_TEMPLATE": str(ROOT / "assets/branding/spectrum-wordmark.svg"),
            }
            subprocess.run(
                ["bash", str(ROOT / "scripts/appearance-stage"), str(wallpaper)],
                check=True,
                env=environment,
            )
            self.assertTrue((appearance / "current.png").read_bytes().startswith(b"\x89PNG"))
            self.assertIn("accent=#70a0d0", (appearance / "colors.conf").read_text(encoding="utf-8"))
            self.assertIn("#70a0d0", (appearance / "logo.svg").read_text(encoding="utf-8"))
            logo_svg = (appearance / "logo.svg").read_text(encoding="utf-8")
            self.assertEqual(logo_svg.count("<path"), 8)
            self.assertIn('transform="translate(20 13) scale(3.5)"', logo_svg)
            self.assertIn('transform="translate(34 20) scale(3.5)"', logo_svg)
            self.assertIn('fill="#ffffff" transform="translate(34 20)', logo_svg)
            self.assertTrue((appearance / "logo.png").read_bytes().startswith(b"\x89PNG"))
            wordmark = ET.parse(appearance / "wordmark.svg").getroot()
            fills = {shape.get("id"): shape.get("fill") for shape in wordmark}
            self.assertEqual(fills["white-letters"], "#ffffff")
            self.assertEqual(fills["outline"], "#333333")
            self.assertEqual(fills["c"], "#70a0d0")
            self.assertEqual(fills["m"], "#c2b0d6")
            self.assertEqual(len({fills[letter] for letter in "pectrum"}), 7)
            self.assertTrue((appearance / "wordmark.png").read_bytes().startswith(b"\x89PNG"))
            self.assertTrue((appearance / "lock-branding.png").read_bytes().startswith(b"\x89PNG"))
            self.assertTrue((appearance / "request").is_file())

    def test_sddm_layout_centers_logo_above_login_form(self):
        main = (ROOT / "configs/sddm/themes/spectrumos/Main.qml").read_text(encoding="utf-8")
        logo = main.index("SpectrumLogo {")
        form = main.index("LoginForm {")
        self.assertLess(logo, form)
        self.assertIn("anchors.centerIn: parent", main)
        self.assertIn("parent.height * 0.94, 980 * Math.max(1, root.font.pointSize / 14)", main)
        self.assertIn("parent.width * 0.60, 840", main)
        self.assertIn("Math.min(16, Math.round(height / 80))", main)
        self.assertIn("card.width * 0.62", main)
        self.assertIn("card.height * 0.44", main)
        self.assertIn("root.font.pointSize * 26", main)
        self.assertIn("Layout.maximumWidth: Layout.preferredWidth", main)
        self.assertIn("Layout.preferredHeight: Layout.preferredWidth * 250 / 278", main)
        self.assertIn("/var/lib/spectrumos/appearance/current.png", (ROOT / "configs/sddm/themes/spectrumos/theme.conf").read_text(encoding="utf-8"))

        vendor_config = (ROOT / "configs/sddm/zz-spectrumos.conf").read_text(encoding="utf-8")
        self.assertIn("DisplayServer=x11", vendor_config)
        self.assertIn("Current=spectrumos", vendor_config)

        input_qml = (ROOT / "configs/sddm/themes/spectrumos/Components/Input.qml").read_text(encoding="utf-8")
        self.assertIn("width: parent.width * 0.84", input_qml)
        self.assertIn("contentItem: Item {}", input_qml)
        system_buttons = (ROOT / "configs/sddm/themes/spectrumos/Components/SystemButtons.qml").read_text(encoding="utf-8")
        self.assertIn("root.font.pointSize * 2.3", system_buttons)
        session_qml = (ROOT / "configs/sddm/themes/spectrumos/Components/SessionButton.qml").read_text(encoding="utf-8")
        self.assertNotIn('color: "#444"', session_qml)
        spectrum_logo = (ROOT / "configs/sddm/themes/spectrumos/Components/SpectrumLogo.qml").read_text(encoding="utf-8")
        self.assertIn('color7: "#ffffff"', main)
        self.assertIn("/var/lib/spectrumos/appearance/logo.svg", spectrum_logo)
        self.assertIn("visible: generatedLogo.status !== Image.Ready", spectrum_logo)
        self.assertIn("width: logoContainer.width * 250 / 278", spectrum_logo)
        self.assertIn("x: logoContainer.width * modelData.x / 278", spectrum_logo)
        self.assertNotIn("width: 250", spectrum_logo)

    def test_uki_branding_removes_arch_splash_and_kernel_logo(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            cmdline = root / "cmdline"
            presets = root / "presets"
            presets.mkdir()
            cmdline.write_text("root=PARTUUID=test quiet splash\n", encoding="utf-8")
            preset = presets / "linux.preset"
            preset.write_text(
                'default_options="--splash /usr/share/systemd/bootctl/splash-arch.bmp"\n',
                encoding="utf-8",
            )
            command = [
                "python",
                str(ROOT / "scripts/uki-branding-sync"),
                "--cmdline",
                str(cmdline),
                "--preset-dir",
                str(presets),
            ]
            subprocess.run(command, check=True)
            subprocess.run(command, check=True)

            self.assertEqual(cmdline.read_text(encoding="utf-8").count("logo.nologo"), 1)
            self.assertNotIn("splash-arch.bmp", preset.read_text(encoding="utf-8"))

        hook = (ROOT / "system/pacman-hooks/95-spectrumos-uki-branding.hook").read_text(encoding="utf-8")
        self.assertIn("Target = linux-*", hook)
        self.assertIn("uki-branding-sync --rebuild", hook)

    def test_uki_branding_accepts_a_non_uki_installation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            cmdline = root / "missing-cmdline"
            presets = root / "presets"
            presets.mkdir()
            subprocess.run(
                [
                    "python",
                    str(ROOT / "scripts/uki-branding-sync"),
                    "--cmdline",
                    str(cmdline),
                    "--preset-dir",
                    str(presets),
                ],
                check=True,
            )
            self.assertFalse(cmdline.exists())

    def test_plymouth_defaults_select_theme_with_bounded_upstream_dropin(self):
        config = (ROOT / "configs/plymouth/plymouthd.conf").read_text(encoding="utf-8")
        duration = (ROOT / "system/systemd/system/plymouth-quit.service.d/20-spectrumos-duration.conf").read_text(encoding="utf-8")
        self.assertIn("Theme=spectrumos", config)
        self.assertEqual(duration, "[Service]\nExecStartPre=/usr/bin/sleep 2\n")

    def test_plymouth_boot_sync_is_idempotent_and_checkable(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            mkinitcpio = root / "mkinitcpio.conf"
            limine = root / "limine.conf"
            mkinitcpio.write_text(
                "HOOKS=(base udev autodetect microcode modconf kms keyboard block filesystems fsck)\n",
                encoding="utf-8",
            )
            limine.write_text(
                "/SpectrumOS2\n    protocol: linux\n    cmdline: root=UUID=test rw\n",
                encoding="utf-8",
            )
            command = [
                "python",
                str(ROOT / "scripts/plymouth-boot-sync"),
                "--mkinitcpio",
                str(mkinitcpio),
                "--limine-config",
                str(limine),
            ]
            subprocess.run(command, check=True)
            first_mkinitcpio = mkinitcpio.read_text(encoding="utf-8")
            first_limine = limine.read_text(encoding="utf-8")
            subprocess.run(command, check=True)
            subprocess.run(command + ["--check"], check=True)

            self.assertEqual(first_mkinitcpio, mkinitcpio.read_text(encoding="utf-8"))
            self.assertEqual(first_limine, limine.read_text(encoding="utf-8"))
            self.assertIn("modconf plymouth kms", first_mkinitcpio)
            self.assertIn("rw quiet splash", first_limine)
            self.assertTrue(mkinitcpio.with_suffix(".conf.spectrumos-backup").is_file())
            self.assertTrue(limine.with_suffix(".conf.spectrumos-backup").is_file())

    def test_plymouth_boot_sync_nvidia_flag_adds_modeset_modules_and_cmdline(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            mkinitcpio = root / "mkinitcpio.conf"
            limine = root / "limine.conf"
            mkinitcpio.write_text(
                "MODULES=()\n"
                "HOOKS=(base udev autodetect microcode modconf kms keyboard block filesystems fsck)\n",
                encoding="utf-8",
            )
            limine.write_text(
                "/SpectrumOS2\n    protocol: linux\n    cmdline: root=UUID=test rw\n",
                encoding="utf-8",
            )
            command = [
                "python",
                str(ROOT / "scripts/plymouth-boot-sync"),
                "--mkinitcpio", str(mkinitcpio),
                "--limine-config", str(limine),
                "--nvidia",
            ]
            subprocess.run(command, check=True)
            first_mkinitcpio = mkinitcpio.read_text(encoding="utf-8")
            first_limine = limine.read_text(encoding="utf-8")
            subprocess.run(command, check=True)
            subprocess.run(command + ["--check"], check=True)

            self.assertEqual(first_mkinitcpio, mkinitcpio.read_text(encoding="utf-8"))
            self.assertEqual(first_limine, limine.read_text(encoding="utf-8"))
            self.assertIn("MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)", first_mkinitcpio)
            self.assertIn("nvidia_drm.modeset=1", first_limine)
            self.assertIn("nvidia_drm.fbdev=1", first_limine)

            # A plain --check (no --nvidia) must not demand the nvidia flags --
            # a non-nvidia caller shouldn't fail validation over them.
            subprocess.run(command[:-1] + ["--check"], check=True)

    def test_plymouth_boot_sync_nvidia_check_fails_without_the_flags(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            mkinitcpio = root / "mkinitcpio.conf"
            limine = root / "limine.conf"
            mkinitcpio.write_text(
                "MODULES=()\n"
                "HOOKS=(base udev autodetect microcode modconf plymouth kms keyboard block filesystems fsck)\n",
                encoding="utf-8",
            )
            limine.write_text(
                "/SpectrumOS2\n    protocol: linux\n    cmdline: root=UUID=test rw quiet splash\n",
                encoding="utf-8",
            )
            result = subprocess.run(
                [
                    "python",
                    str(ROOT / "scripts/plymouth-boot-sync"),
                    "--mkinitcpio", str(mkinitcpio),
                    "--limine-config", str(limine),
                    "--nvidia",
                    "--check",
                ],
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
