from pathlib import Path
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "scripts" / "vm-install-arch"


class VmInstallTests(unittest.TestCase):
    def test_installer_is_valid_and_guarded(self):
        result = subprocess.run(
            ("bash", "-n", str(INSTALLER)), check=False, capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        content = INSTALLER.read_text(encoding="utf-8")
        self.assertIn("SPECTRUM_VM_INSTALL", content)
        self.assertIn("findmnt -no SOURCE /", content)
        self.assertIn("disk=/dev/vda", content)
        self.assertIn("Refusing unexpected VM disk size", content)

    def test_installer_builds_the_expected_bootable_baseline(self):
        content = INSTALLER.read_text(encoding="utf-8")
        for value in (
            "label: gpt", "type=U", "mkfs.btrfs", "subvol=@", "pacstrap -K",
            "BOOTX64.EFI", "limine.conf", "NetworkManager.service", "sshd.service",
        ):
            self.assertIn(value, content)


if __name__ == "__main__":
    unittest.main()
