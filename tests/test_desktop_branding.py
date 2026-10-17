import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class DesktopBrandingTests(unittest.TestCase):
    def run_layout(self, config, *arguments):
        return subprocess.run(
            [str(ROOT / "scripts/spectrum-shell-layout"), *arguments],
            env={**os.environ, "XDG_CONFIG_HOME": str(config)},
            capture_output=True, text=True,
        )

    def test_defaults_and_invalid_saved_corner(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory)
            state = json.loads(self.run_layout(config, "--json").stdout)
            self.assertTrue(state["desktop_logo_enabled"])
            self.assertEqual(state["desktop_logo_corner"], "bottom-right")

            path = config / "spectrumos/shell.json"
            path.parent.mkdir()
            path.write_text('{"desktop_logo_corner": "center"}')
            state = json.loads(self.run_layout(config, "--json").stdout)
            self.assertEqual(state["desktop_logo_corner"], "bottom-right")

    def test_widget_bounce_toggle_preserves_other_settings(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory)
            self.assertTrue(json.loads(self.run_layout(config, "--json").stdout)["widget_bounce_enabled"])
            path = config / "spectrumos/shell.json"
            path.parent.mkdir()
            original = {"bar_position": "top", "igor_enabled": False, "custom": "preserved"}
            path.write_text(json.dumps(original))
            for enabled in (False, True):
                result = self.run_layout(config, "set-bounce", "on" if enabled else "off")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(path.read_text()), {**original, "widget_bounce_enabled": enabled})
                self.assertEqual(json.loads(self.run_layout(config, "--json").stdout)["widget_bounce_enabled"], enabled)
            saved = path.read_bytes()
            self.assertEqual(self.run_layout(config, "set-bounce", "maybe").returncode, 2)
            self.assertEqual(path.read_bytes(), saved)

    def test_settings_persist_without_changing_other_preferences(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory)
            path = config / "spectrumos/shell.json"
            path.parent.mkdir()
            original = {"bar_position": "top", "igor_enabled": False, "custom": "preserved"}
            path.write_text(json.dumps(original))
            for corner in ("top-left", "top-right", "bottom-left", "bottom-right"):
                result = self.run_layout(config, "set-logo-corner", corner)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(self.run_layout(config, "--json").stdout)["desktop_logo_corner"], corner)
            for enabled in (False, True):
                result = self.run_layout(config, "set-logo", "on" if enabled else "off")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(path.read_text()), {
                    **original, "desktop_logo_corner": "bottom-right", "desktop_logo_enabled": enabled,
                })

    def test_invalid_actions_leave_preferences_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory)
            self.run_layout(config, "set-logo", "off")
            path = config / "spectrumos/shell.json"
            original = path.read_bytes()
            for arguments in (("set-logo", "maybe"), ("set-logo-corner", "center")):
                self.assertEqual(self.run_layout(config, *arguments).returncode, 2)
                self.assertEqual(path.read_bytes(), original)
