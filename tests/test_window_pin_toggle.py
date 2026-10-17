import importlib.machinery
import importlib.util
import subprocess
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
LOADER = importlib.machinery.SourceFileLoader(
    "spectrum_window_pin_toggle", str(ROOT / "scripts" / "window-pin-toggle")
)
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
TOGGLE = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(TOGGLE)


def completed(returncode=0, stdout="", stderr=""):
    return subprocess.CompletedProcess(args=[], returncode=returncode, stdout=stdout, stderr=stderr)


class WindowPinToggleTests(unittest.TestCase):
    def test_floats_a_tiled_window_then_pins_and_raises_it(self):
        with mock.patch.object(
            TOGGLE, "active_window", return_value={"floating": False, "pinned": False}
        ), mock.patch.object(TOGGLE, "dispatch") as dispatch:
            self.assertEqual(TOGGLE.main(), 0)

        dispatch.assert_has_calls(
            [
                mock.call('hl.dsp.window.float({action="toggle"})'),
                mock.call("hl.dsp.window.pin()"),
                mock.call('hl.dsp.window.alter_zorder({mode="top"})'),
            ]
        )

    def test_an_already_floating_window_is_pinned_and_raised_without_re_floating(self):
        with mock.patch.object(
            TOGGLE, "active_window", return_value={"floating": True, "pinned": False}
        ), mock.patch.object(TOGGLE, "dispatch") as dispatch:
            self.assertEqual(TOGGLE.main(), 0)

        dispatch.assert_has_calls(
            [mock.call("hl.dsp.window.pin()"), mock.call('hl.dsp.window.alter_zorder({mode="top"})')]
        )
        self.assertEqual(dispatch.call_count, 2)

    def test_unpinning_an_already_pinned_window_does_not_alter_its_stacking(self):
        # Only pinning raises the window -- un-pinning shouldn't force it to the
        # front of whatever it's returning to.
        with mock.patch.object(
            TOGGLE, "active_window", return_value={"floating": True, "pinned": True}
        ), mock.patch.object(TOGGLE, "dispatch") as dispatch:
            self.assertEqual(TOGGLE.main(), 0)

        dispatch.assert_called_once_with("hl.dsp.window.pin()")

    def test_no_active_window_does_nothing(self):
        with mock.patch.object(TOGGLE, "active_window", return_value=None), mock.patch.object(
            TOGGLE, "dispatch"
        ) as dispatch:
            self.assertEqual(TOGGLE.main(), 1)

        dispatch.assert_not_called()

    def test_active_window_handles_a_json_decode_failure(self):
        with mock.patch.object(subprocess, "run", return_value=completed(0, stdout="not json")):
            self.assertIsNone(TOGGLE.active_window())

    def test_active_window_handles_a_nonzero_exit(self):
        with mock.patch.object(subprocess, "run", return_value=completed(1)):
            self.assertIsNone(TOGGLE.active_window())

    def test_dispatch_sends_one_lua_expression_argument_not_the_classic_two_word_form(self):
        # Confirmed live against this Hyprland version: "hyprctl dispatch togglefloating
        # active" (the classic two-word form) errors with "hl.dispatch: expected a
        # dispatcher (e.g. hl.dsp.window.close())" -- dispatch now evaluates its argument
        # as Lua, so it must be exactly one hl.dsp.* expression string.
        with mock.patch.object(subprocess, "run") as run:
            TOGGLE.dispatch("hl.dsp.window.pin()")
        run.assert_called_once_with(["hyprctl", "dispatch", "hl.dsp.window.pin()"], check=False)


if __name__ == "__main__":
    unittest.main()
