from pathlib import Path
import runpy
import subprocess
import unittest
from copy import deepcopy
from unittest.mock import Mock, patch


ROOT = Path(__file__).resolve().parents[1]
MENU = ROOT / "scripts" / "display-menu"


class DisplayMenuTests(unittest.TestCase):
    def test_current_hyprctl_json_argument_order_is_used(self):
        content = MENU.read_text(encoding="utf-8")
        self.assertIn('command("hyprctl", "-j", "monitors", "all")', content)
        self.assertNotIn('command("hyprctl", "monitors", "all", "-j")', content)
        self.assertIn('tempfile.TemporaryFile(mode="w+"', content)
        self.assertIn("for attempt in range(3)", content)
        self.assertIn("time.sleep(0.15)", content)

    def test_script_compiles(self):
        result = subprocess.run(
            (
                "python",
                "-c",
                "import pathlib; compile(pathlib.Path(__import__('sys').argv[1]).read_text(), __import__('sys').argv[1], 'exec')",
                str(MENU),
            ),
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_uses_native_hyprland_lua_monitor_rules(self):
        content = MENU.read_text(encoding="utf-8")
        self.assertIn('"hl.monitor({"', content)
        for field in ("mode", "position", "scale", "transform", "disabled"):
            self.assertIn(field, content)
        self.assertNotIn("hyprctl keyword", content)

    def test_prevents_disabling_the_only_active_monitor(self):
        content = MENU.read_text(encoding="utf-8")
        self.assertIn("At least one monitor must remain active", content)
        self.assertIn("previous_lua", content)
        self.assertIn("configerrors", content)

    def test_eww_cli_exposes_bounded_native_controls(self):
        content = MENU.read_text(encoding="utf-8")
        for action in ("--json", "--arrange", "--relative", "--scale", "--rotate", "--mode", "--enabled", "--reset"):
            self.assertIn(action, content)
        self.assertIn("Cannot disable the only active display", content)
        self.assertIn("save_and_apply(state)", content)

    def test_arrangements_use_explicit_non_overlapping_coordinates(self):
        namespace = runpy.run_path(str(MENU))
        arrange = namespace["explicit_arrangement"]
        state = {
            "DP-1": {
                "disabled": False, "mode": "3840x2160@60", "scale": 1,
                "transform": 0, "available_modes": [], "position": "auto",
            },
            "HDMI-A-1": {
                "disabled": False, "mode": "1920x1080@59.94", "scale": 1,
                "transform": 0, "available_modes": [], "position": "auto-left",
            },
        }

        arrange(state, "right")
        self.assertEqual(state["DP-1"]["position"], "0x0")
        self.assertEqual(state["HDMI-A-1"]["position"], "3840x0")
        arrange(state, "left")
        self.assertEqual(state["HDMI-A-1"]["position"], "-1920x0")

    def test_logical_size_accounts_for_scale_and_rotation(self):
        dimensions = runpy.run_path(str(MENU))["mode_dimensions"]
        settings = {
            "mode": "1920x1080@60", "scale": 1.5, "transform": 1,
            "available_modes": [],
        }
        self.assertEqual(dimensions(settings), (720, 1280))

    def test_scale_preserves_live_modes_geometry_and_other_monitors(self):
        action = runpy.run_path(str(MENU))["cli_action"]
        live = {
            "DP-1": {"disabled": False, "mode": "3840x2160@119.88", "scale": 1,
                     "transform": 1, "position": "0x0", "available_modes": []},
            "HDMI-A-1": {"disabled": False, "mode": "1920x1080@59.94", "scale": 1.25,
                         "transform": 0, "position": "2160x0", "available_modes": []},
        }
        for value in ("1", "1.5", "1.75", "2"):
            with self.subTest(value=value):
                saved = Mock(return_value=True)
                stale = Mock(side_effect=AssertionError("Saved settings must not replace live modes"))
                with patch.dict(action.__globals__, live_state=lambda: deepcopy(live), load_state=stale, save_and_apply=saved):
                    with self.assertRaises(SystemExit) as exit_result:
                        action(["--scale", "DP-1", value])
                self.assertEqual(exit_result.exception.code, 0)
                expected = deepcopy(live)
                expected["DP-1"]["scale"] = float(value)
                saved.assert_called_once_with(expected)

    def test_invalid_scale_or_disconnected_monitor_does_not_save(self):
        action = runpy.run_path(str(MENU))["cli_action"]
        saved = Mock()
        for arguments in (["--scale", "DP-1", "3"], ["--scale", "missing", "1.5"]):
            with patch.dict(action.__globals__, live_state=lambda: {"DP-1": {}}, save_and_apply=saved):
                with self.assertRaises(SystemExit): action(arguments)
        saved.assert_not_called()

    def test_selected_monitor_can_be_placed_relative_to_primary(self):
        relative = runpy.run_path(str(MENU))["relative_position"]
        state = {
            "DP-1": {
                "disabled": False, "mode": "3840x2160@60", "scale": 1,
                "transform": 0, "available_modes": [], "position": "0x0",
            },
            "HDMI-A-1": {
                "disabled": False, "mode": "1920x1080@60", "scale": 1,
                "transform": 0, "available_modes": [], "position": "3840x0",
            },
        }
        relative(state, "HDMI-A-1", "DP-1", "left")
        self.assertEqual(state["HDMI-A-1"]["position"], "-1920x0")
        relative(state, "HDMI-A-1", "DP-1", "up")
        self.assertEqual(state["HDMI-A-1"]["position"], "0x-1080")
        relative(state, "HDMI-A-1", "DP-1", "right")
        self.assertEqual(state["HDMI-A-1"]["position"], "3840x0")


if __name__ == "__main__":
    unittest.main()
