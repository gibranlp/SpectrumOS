from pathlib import Path
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
MENU = ROOT / "scripts" / "session-menu"


class SessionMenuTests(unittest.TestCase):
    def test_script_is_valid_bash(self):
        result = subprocess.run(("bash", "-n", str(MENU)), capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_uses_the_shell_picker(self):
        content = MENU.read_text(encoding="utf-8")
        self.assertIn("/usr/lib/spectrumos/spectrum-shell-picker session --dmenu", content)

    def test_offers_every_session_action(self):
        content = MENU.read_text(encoding="utf-8")
        for label in ("Lock", "Suspend", "Log out", "Restart", "Power off"):
            self.assertIn(f"'{label}'", content)

    def test_each_choice_maps_to_the_matching_session_action(self):
        content = MENU.read_text(encoding="utf-8")
        for call in ("set -- lock", "set -- run suspend", "set -- run logout", "set -- run reboot", "set -- run poweroff"):
            self.assertIn(call, content)
        for call in ("hyprlock -c", "systemctl suspend", "uwsm stop", "systemctl reboot", "systemctl poweroff"):
            self.assertIn(call, content)
        self.assertNotIn("eww-session", content)

    def test_an_empty_selection_is_a_quiet_no_op(self):
        # Escape / closing the menu without picking anything must not fall through to
        # running one of the destructive session actions.
        content = MENU.read_text(encoding="utf-8")
        self.assertIn("'') exit 0 ;;", content)


if __name__ == "__main__":
    unittest.main()
