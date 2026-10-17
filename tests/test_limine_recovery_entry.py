import importlib.machinery
import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LOADER = importlib.machinery.SourceFileLoader(
    "spectrum_limine_recovery_entry", str(ROOT / "scripts" / "limine-recovery-entry")
)
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
ENTRY = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(ENTRY)


SAMPLE_CONFIG = """timeout: 5

wallpaper: boot():/EFI/BOOT/spectrumos-wallpaper.png

/SpectrumOS (linux-zen)
    protocol: efi
    path: boot():/EFI/Linux/arch-linux-zen.efi
    cmdline: root=PARTUUID=99805ce2-af0d-4164-a8ee-fe4c302cbce4 rootflags=subvol=@ rw rootfstype=btrfs quiet splash

/SpectrumOS (linux-lts)
    protocol: efi
    path: boot():/EFI/Linux/arch-linux-lts.efi
    cmdline: root=PARTUUID=99805ce2-af0d-4164-a8ee-fe4c302cbce4 rootflags=subvol=@ rw rootfstype=btrfs quiet splash
"""

# The classic entry spectrum-installer-backend actually writes on a fresh install --
# protocol: linux plus a separate module_path initramfs, no UKI at all.
CLASSIC_SAMPLE_CONFIG = """/SpectrumOS
    protocol: linux
    path: /vmlinuz-linux-zen
    module_path: /initramfs-linux-zen.img
    cmdline: root=UUID=99805ce2 rootfstype=btrfs rootflags=subvol=@ rw quiet splash
"""


class LimineRecoveryEntryTests(unittest.TestCase):
    def test_parse_entries_groups_indented_lines_under_their_heading(self):
        entries = ENTRY.parse_entries(SAMPLE_CONFIG)
        self.assertEqual(len(entries), 2)
        self.assertEqual(entries[0][0], "/SpectrumOS (linux-zen)")
        self.assertEqual(len(entries[0]), 4)

    def test_build_recovery_entry_appends_the_restore_flag_to_cmdline_only(self):
        entries = ENTRY.parse_entries(SAMPLE_CONFIG)
        recovery = ENTRY.build_recovery_entry(ENTRY.source_entry(entries))
        self.assertEqual(recovery[0], ENTRY.RECOVERY_ENTRY_NAME)
        cmdline = next(line for line in recovery if "cmdline:" in line)
        self.assertTrue(cmdline.rstrip().endswith(ENTRY.RESTORE_FLAG))
        self.assertIn("rootflags=subvol=@", cmdline)
        path = next(line for line in recovery if "path:" in line)
        self.assertIn("spectrumos-rescue.efi", path)
        self.assertNotIn("arch-linux-zen.efi", path)

    def test_build_recovery_entry_normalizes_a_classic_split_kernel_source(self):
        # spectrumos-build-rescue-image's output is always a self-contained UKI --
        # carrying over the source's own protocol: linux / module_path: would produce
        # a structurally inconsistent entry (protocol linux + module_path pointing at
        # an initramfs, while path points at a UKI).
        entries = ENTRY.parse_entries(CLASSIC_SAMPLE_CONFIG)
        recovery = ENTRY.build_recovery_entry(ENTRY.source_entry(entries))
        rendered = "\n".join(recovery)
        self.assertIn("protocol: efi", rendered)
        self.assertNotIn("protocol: linux", rendered)
        self.assertNotIn("module_path", rendered)
        self.assertIn("spectrumos-rescue.efi", rendered)
        cmdline = next(line for line in recovery if "cmdline:" in line)
        self.assertIn("rootflags=subvol=@", cmdline)
        self.assertTrue(cmdline.rstrip().endswith(ENTRY.RESTORE_FLAG))

    def test_source_entry_requires_an_existing_spectrumos_entry(self):
        with self.assertRaises(SystemExit):
            ENTRY.source_entry(ENTRY.parse_entries("timeout: 5\n\n/Reboot\n    protocol: efi\n"))

    def test_main_is_idempotent_and_only_edits_the_config_once(self):
        with tempfile.TemporaryDirectory() as temporary:
            config = Path(temporary) / "limine.conf"
            config.write_text(SAMPLE_CONFIG, encoding="utf-8")

            result_one = subprocess.run(
                ["python", str(ROOT / "scripts" / "limine-recovery-entry"), "--config", str(config)],
                check=True,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result_one.returncode, 0)
            first_write = config.read_text(encoding="utf-8")
            self.assertIn(ENTRY.RECOVERY_ENTRY_NAME, first_write)
            self.assertIn(ENTRY.RESTORE_FLAG, first_write)

            result_two = subprocess.run(
                ["python", str(ROOT / "scripts" / "limine-recovery-entry"), "--config", str(config)],
                check=True,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result_two.returncode, 0)
            self.assertEqual(config.read_text(encoding="utf-8"), first_write)
            self.assertEqual(first_write.count(ENTRY.RECOVERY_ENTRY_NAME), 1)


if __name__ == "__main__":
    unittest.main()
