import importlib.machinery
import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
LOADER = importlib.machinery.SourceFileLoader(
    "spectrum_build_rescue_image", str(ROOT / "scripts" / "spectrumos-build-rescue-image")
)
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
BUILD = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(BUILD)


SAMPLE_LIMINE_CONFIG = """/SpectrumOS (linux-zen)
    protocol: efi
    path: boot():/EFI/Linux/arch-linux-zen.efi
    cmdline: root=PARTUUID=99805ce2 rootflags=subvol=@ rw rootfstype=btrfs quiet splash
"""

# The classic entry spectrum-installer-backend actually writes on a fresh install --
# no per-variant suffix, no arch- prefix, a separate module_path initramfs.
SAMPLE_CLASSIC_LIMINE_CONFIG = """/SpectrumOS
    protocol: linux
    path: /vmlinuz-linux-zen
    module_path: /initramfs-linux-zen.img
    cmdline: root=UUID=99805ce2 rootfstype=btrfs rootflags=subvol=@ rw quiet splash
"""

SAMPLE_MKINITCPIO_CONFIG = "MODULES=()\nHOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)\n"
SAMPLE_SYSTEMD_MKINITCPIO_CONFIG = "MODULES=()\nHOOKS=(base systemd autodetect keyboard sd-vconsole block filesystems fsck)\n"


class SpectrumosBuildRescueImageTests(unittest.TestCase):
    def test_install_script_uses_archs_initcpio_hook_to_refresh_the_rescue_image(self):
        install_script = (ROOT / "packages" / "spectrum-base" / "spectrum-base.install").read_text(
            encoding="utf-8"
        )

        self.assertIn("spectrumos-build-rescue-image --dry-run", install_script)
        self.assertIn("post_upgrade() {\n    _spectrumos_prepare_boot_restore", install_script)
        self.assertEqual(install_script.count("spectrumos-build-rescue-image --dry-run"), 1)

    def test_detect_kernel_name_reads_the_existing_uki_entry(self):
        self.assertEqual(BUILD.detect_kernel_name(SAMPLE_LIMINE_CONFIG), "linux-zen")

    def test_detect_kernel_name_reads_a_classic_split_kernel_entry(self):
        # A fresh install (spectrum-installer-backend's own template) writes exactly
        # this shape -- the UKI pattern alone never matched it.
        self.assertEqual(BUILD.detect_kernel_name(SAMPLE_CLASSIC_LIMINE_CONFIG), "linux-zen")

    def test_detect_kernel_name_fails_without_an_existing_entry(self):
        with self.assertRaises(SystemExit):
            BUILD.detect_kernel_name("timeout: 5\n")

    def test_render_preset_points_at_the_dedicated_rescue_uki_and_config(self):
        preset = BUILD.render_preset("linux-zen")
        self.assertIn('ALL_config="/etc/mkinitcpio-spectrumos-rescue.conf"', preset)
        self.assertIn('ALL_kver="/boot/vmlinuz-linux-zen"', preset)
        self.assertIn(str(BUILD.RESCUE_UKI), preset)
        self.assertIn(f'--cmdline {BUILD.RESCUE_CMDLINE}', preset)

    def test_detect_cmdline_adds_the_restore_flag(self):
        self.assertEqual(
            BUILD.detect_cmdline(SAMPLE_CLASSIC_LIMINE_CONFIG),
            "root=UUID=99805ce2 rootfstype=btrfs rootflags=subvol=@ rw quiet splash "
            "spectrumos.restore=latest",
        )

    def test_systemd_config_is_converted_for_runtime_hook_execution(self):
        updated = BUILD.runtime_compatible_config(SAMPLE_SYSTEMD_MKINITCPIO_CONFIG)
        self.assertIn("HOOKS=(base udev autodetect keyboard keymap consolefont block filesystems fsck)", updated)
        self.assertNotIn("systemd", updated)
        self.assertNotIn("sd-vconsole", updated)

    def test_dry_run_writes_config_and_preset_without_invoking_mkinitcpio(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            limine_config = root / "limine.conf"
            limine_config.write_text(SAMPLE_LIMINE_CONFIG, encoding="utf-8")
            mkinitcpio_config = root / "mkinitcpio.conf"
            mkinitcpio_config.write_text(SAMPLE_MKINITCPIO_CONFIG, encoding="utf-8")
            rescue_config = root / "mkinitcpio-spectrumos-rescue.conf"
            rescue_preset = root / "spectrumos-rescue.preset"
            rescue_cmdline = root / "cmdline-spectrumos-rescue"
            register_hook = ROOT / "scripts" / "mkinitcpio-register-hook"

            argv = [
                "spectrumos-build-rescue-image",
                "--limine-config", str(limine_config),
                "--mkinitcpio-config", str(mkinitcpio_config),
                "--register-hook", str(register_hook),
                "--dry-run",
            ]
            with mock.patch.object(BUILD, "RESCUE_CONFIG", rescue_config), mock.patch.object(
                BUILD, "RESCUE_PRESET", rescue_preset
            ), mock.patch.object(
                BUILD, "RESCUE_CMDLINE", rescue_cmdline
            ), mock.patch("sys.argv", argv), mock.patch.object(
                subprocess, "run", wraps=subprocess.run
            ) as run:
                self.assertEqual(BUILD.main(), 0)
                run.assert_called_once()  # only the register-hook call; mkinitcpio itself is skipped

            self.assertTrue(rescue_config.is_file())
            self.assertIn("spectrumos-restore", rescue_config.read_text(encoding="utf-8"))
            self.assertTrue(rescue_preset.is_file())
            self.assertIn(str(BUILD.RESCUE_UKI), rescue_preset.read_text(encoding="utf-8"))
            self.assertEqual(
                rescue_cmdline.read_text(encoding="utf-8"),
                "root=PARTUUID=99805ce2 rootflags=subvol=@ rw rootfstype=btrfs quiet splash "
                "spectrumos.restore=latest\n",
            )


if __name__ == "__main__":
    unittest.main()
