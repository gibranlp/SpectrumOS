from pathlib import Path
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
MENU = ROOT / "scripts" / "network-menu"


class NetworkMenuTests(unittest.TestCase):
    def test_script_is_valid_bash(self):
        result = subprocess.run(("bash", "-n", str(MENU)), capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_networkmanager_owns_configuration(self):
        content = MENU.read_text(encoding="utf-8")
        self.assertIn("nmcli", content)
        self.assertIn("nm-connection-editor", content)
        self.assertNotIn("/etc/systemd/network", content)
        self.assertNotIn("sudo", content)

    def test_wifi_and_diagnostics_are_integrated(self):
        content = MENU.read_text(encoding="utf-8")
        for action in ("Wi-Fi networks", "Toggle Wi-Fi", "Active connections", "DNS status"):
            self.assertIn(action, content)

    def test_active_summary_includes_addresses_and_wifi_identity(self):
        content = MENU.read_text(encoding="utf-8")
        self.assertIn("Local IPv4", content)
        self.assertIn("Local IPv6", content)
        self.assertIn("Public IP", content)
        self.assertIn("IN-USE,SSID,SIGNAL", content)
        self.assertIn("https://api.ipify.org", content)
        self.assertIn("--active", content)

    def test_password_entry_remains_open_and_connection_failures_are_visible(self):
        content = MENU.read_text(encoding="utf-8")
        self.assertIn("password=$(printf '\\n'", content)
        self.assertIn('notice "Wi-Fi connection failed" "$failure"', content)

    def test_ssids_with_colons_are_not_split_as_nmcli_table_fields(self):
        content = MENU.read_text(encoding="utf-8")
        self.assertIn("--mode multiline", content)
        self.assertIn("ssid=substr($0, 6)", content)
        self.assertNotIn("awk -F:", content)


if __name__ == "__main__":
    unittest.main()
