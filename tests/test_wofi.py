from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RetiredLauncherTests(unittest.TestCase):
    def test_legacy_profiles_and_launcher_are_removed(self):
        self.assertEqual(list((ROOT / "configs/wofi").rglob("*.conf")), [])
        self.assertFalse((ROOT / "scripts/wofi").exists())
        self.assertNotIn("\nwofi\n", (ROOT / "bootstrap/packages/desktop.txt").read_text())

    def test_menus_use_native_shell_picker(self):
        for name in ("theme-menu", "network-menu", "bluetooth-menu", "application-menu", "session-menu"):
            self.assertIn("spectrum-shell-picker", (ROOT / "scripts" / name).read_text())
