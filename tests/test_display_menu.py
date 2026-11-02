from pathlib import Path
import runpy
import json
import tempfile
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

    def test_scale_preserves_live_modes_and_reflows_neighbors(self):
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
                expected["HDMI-A-1"]["position"] = f"{round(2160 / float(value))}x0"
                saved.assert_called_once_with(expected, live)

    def test_scaling_round_trip_keeps_monitor_edges_attached(self):
        reflow = runpy.run_path(str(MENU))["reflow_geometry"]
        for positions in [("0x0", "3840x0"), ("0x0", "-1920x0"), ("0x0", "0x2160"), ("0x0", "0x-1080")]:
            for changed in ("DP-1", "HDMI-A-1"):
                state = {
                    "DP-1": {"disabled":False,"mode":"3840x2160@60","scale":1,"transform":0,"position":positions[0]},
                    "HDMI-A-1": {"disabled":False,"mode":"1920x1080@60","scale":1,"transform":0,"position":positions[1]},
                }
                original = deepcopy(state)
                for scale in (1.25, 1, 1.25, 1):
                    previous = deepcopy(state)
                    state[changed]["scale"] = scale
                    reflow(state, previous)
                self.assertEqual(state, original, (positions, changed))

    def test_three_monitor_chain_and_bottom_alignment_reflow(self):
        reflow = runpy.run_path(str(MENU))["reflow_geometry"]
        state = {name:{"disabled":False,"mode":"1920x1080@60","scale":1,"transform":0,"position":f"{index * 1920}x0"} for index,name in enumerate(("left","middle","right"))}
        previous = deepcopy(state)
        state["middle"]["scale"] = 1.25
        reflow(state, previous)
        self.assertEqual(state["right"]["position"], "3456x0")
        state.pop("right")
        state["middle"]["position"] = "1920x216"
        previous = deepcopy(state)
        state["left"]["scale"] = 1.25
        reflow(state, previous)
        self.assertEqual(state["middle"]["position"], "1536x0")

    def test_live_enumeration_order_is_stable(self):
        live = runpy.run_path(str(MENU))["live_state"]
        with patch.dict(live.__globals__, monitors=lambda:[{"id":1,"name":"HDMI"},{"id":0,"name":"DP"}]):
            self.assertEqual(list(live()), ["DP", "HDMI"])

    def test_readback_reflows_using_compositor_adjusted_scale(self):
        namespace = runpy.run_path(str(MENU))
        apply = namespace["save_and_apply"]
        original = {
            "DP": {"disabled":False,"mode":"3840x2160@60","scale":1,"transform":0,"position":"0x0"},
            "HDMI": {"disabled":False,"mode":"1920x1080@60","scale":1,"transform":0,"position":"3840x0"},
        }
        requested = deepcopy(original)
        requested["DP"]["scale"] = 1.75
        namespace["reflow_geometry"](requested, original)
        observed = deepcopy(requested)
        observed["DP"]["scale"] = 1.7777778
        ok = subprocess.CompletedProcess([],0,"","")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            with patch.dict(apply.__globals__, CONFIG_DIR=path, STATE_FILE=path/"state.json", LUA_FILE=path/"monitors.lua", live_state=lambda:observed, command=Mock(return_value=ok), notify=Mock()), patch.object(namespace["time"],"sleep"):
                self.assertTrue(apply(requested,original))
                saved = json.loads((path/"state.json").read_text())
                self.assertEqual(saved["HDMI"]["position"], "2160x0")
                self.assertEqual(saved["DP"]["scale"], 1.7777778)

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
