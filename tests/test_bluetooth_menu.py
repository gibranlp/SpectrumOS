from pathlib import Path
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
MENU = ROOT / "scripts" / "bluetooth-menu"


class BluetoothMenuTests(unittest.TestCase):
    def test_script_is_valid_bash(self):
        result = subprocess.run(("bash", "-n", str(MENU)), capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_complete_device_lifecycle_is_available(self):
        content = MENU.read_text(encoding="utf-8")
        for action in ("pair", "connect", "disconnect", "trust", "untrust", "remove"):
            self.assertIn(action, content)
        self.assertIn("scan on", content)
        self.assertIn("blueman-manager", content)
        self.assertIn("--status", content)
        self.assertIn("spectrum-shell-picker right", content)


if __name__ == "__main__":
    unittest.main()
