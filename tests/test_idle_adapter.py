from importlib.machinery import SourceFileLoader
from pathlib import Path
import importlib.util
import json
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "idle-adapter"


def load_module():
    loader = SourceFileLoader("idle_adapter", str(SCRIPT))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class IdleAdapterTests(unittest.TestCase):
    def setUp(self):
        self.module = load_module()
        self.tempdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tempdir.cleanup)
        self.module.STATE_DIR = Path(self.tempdir.name) / "spectrumos"
        self.module.PID_FILE = self.module.STATE_DIR / "idle-inhibitor.pid"

    def test_script_compiles(self):
        compile(SCRIPT.read_text(encoding="utf-8"), str(SCRIPT), "exec")

    def test_json_reports_active_and_label(self):
        with mock.patch.object(self.module, "inhibitor_pid", return_value=1234):
            self.assertEqual(
                json.loads(self._run_status_json()),
                {"active": True, "label": "Keep awake"},
            )
        with mock.patch.object(self.module, "inhibitor_pid", return_value=None):
            self.assertEqual(
                json.loads(self._run_status_json()),
                {"active": False, "label": "Allow sleep"},
            )

    def _run_status_json(self):
        import io
        import contextlib

        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            with mock.patch.object(self.module.sys, "argv", ["idle-adapter", "--json"]):
                self.module.main()
        return buffer.getvalue()

    def _run_status(self):
        import io
        import contextlib

        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            with mock.patch.object(self.module.sys, "argv", ["idle-adapter", "--status"]):
                self.module.main()
        return json.loads(buffer.getvalue())

    def test_waybar_status_active_uses_md_coffee_and_the_active_class(self):
        # Same glyph and mechanism as the Eww header icon (idle-adapter toggle,
        # systemd-inhibit) so the waybar button and the control center always agree,
        # unlike waybar's own built-in idle_inhibitor module (a separate Wayland protocol)
        # which this custom module replaced everywhere for exactly that reason.
        with mock.patch.object(self.module, "inhibitor_pid", return_value=1234):
            status = self._run_status()
        self.assertEqual(status["text"], "\U000f0176")
        self.assertEqual(status["class"], "active")
        self.assertIn("Keep awake", status["tooltip"])

    def test_waybar_status_idle_uses_md_coffee_off_and_the_idle_class(self):
        with mock.patch.object(self.module, "inhibitor_pid", return_value=None):
            status = self._run_status()
        self.assertEqual(status["text"], "\U000f0faa")
        self.assertEqual(status["class"], "idle")
        self.assertIn("Allow sleep", status["tooltip"])

    def test_enable_launches_via_uwsm_so_it_survives_an_eww_or_waybar_restart(self):
        # Toggled from either Eww's header icon or Waybar's custom/keep-awake -- both fork
        # this as a child of that app's own systemd cgroup (spectrum-eww.service /
        # spectrum-waybar.service). A wallpaper or theme change restarts both
        # (waybar-menu --restart, eww-refresh), and KillMode=control-group kills every
        # process in a service's cgroup on restart -- confirmed live that a raw
        # systemd-inhibit landed in whichever cgroup called it and died with it, silently
        # turning keep awake back off. `uwsm app -s s --` launches it into its own
        # independent scope instead (verified live: a completely separate cgroup from
        # either service), the same decoupling autostart.lua already uses for
        # dunst/awww-daemon/etc.
        with mock.patch.object(self.module, "inhibitor_pid", return_value=None), \
             mock.patch.object(self.module.subprocess, "Popen") as popen:
            popen.return_value.pid = 4321
            self.module.enable()
        command = popen.call_args.args[0]
        self.assertEqual(command[:4], ["uwsm", "app", "-s", "s"])
        self.assertIn("systemd-inhibit", command)
        self.assertIn("--what=idle:sleep", command)
        self.assertEqual(self.module.PID_FILE.read_text(encoding="utf-8").strip(), "4321")

    def test_enable_is_a_no_op_when_already_active(self):
        with mock.patch.object(self.module, "inhibitor_pid", return_value=1234), \
             mock.patch.object(self.module.subprocess, "Popen") as popen:
            self.module.enable()
        popen.assert_not_called()

    def test_on_command_uses_explicit_enable_instead_of_toggling(self):
        with mock.patch.object(self.module.sys, "argv", ["idle-adapter", "on"]), \
             mock.patch.object(self.module, "enable") as enable, \
             mock.patch.object(self.module, "disable") as disable:
            self.assertEqual(self.module.main(), 0)
        enable.assert_called_once_with()
        disable.assert_not_called()


if __name__ == "__main__":
    unittest.main()
