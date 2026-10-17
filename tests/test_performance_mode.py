from importlib.machinery import SourceFileLoader
from pathlib import Path
import importlib.util
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "performance-mode"


def load_module():
    loader = SourceFileLoader("performance_mode", str(SCRIPT))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class PerformanceModeTests(unittest.TestCase):
    def setUp(self):
        self.module = load_module()
        # Isolate state under a per-test scratch path instead of the real XDG state dir.
        self.tempdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tempdir.cleanup)
        state_dir = Path(self.tempdir.name) / "spectrumos/performance-mode"
        self.module.STATE_DIR = state_dir
        self.module.PRE_GAME_FILE = state_dir / "pre-game-mode"
        self.module.GAME_COUNT_FILE = state_dir / "game-count"
        # Points at a path that doesn't exist by default, so every existing test below
        # still exercises (and mocks) the `tuned-adm active` fallback exactly as before,
        # without ever touching the real /etc/tuned/active_profile on the test machine.
        self.module.TUNED_ACTIVE_PROFILE_FILE = state_dir / "active_profile"

    def test_script_compiles(self):
        compile(SCRIPT.read_text(encoding="utf-8"), str(SCRIPT), "exec")

    def test_backend_prefers_power_profiles_daemon_over_tuned(self):
        with mock.patch.object(self.module.shutil, "which", side_effect=lambda name: f"/usr/bin/{name}"), \
             mock.patch.object(self.module, "run", return_value=mock.Mock(returncode=0)):
            self.assertEqual(self.module.backend(), "power-profiles-daemon")

    def test_backend_falls_back_to_tuned_when_ppd_is_not_running(self):
        def fake_run(*arguments, **kwargs):
            if arguments[:2] == ("systemctl", "is-active") and "power-profiles-daemon.service" in arguments:
                return mock.Mock(returncode=1, stdout="")
            return mock.Mock(returncode=0, stdout="")

        with mock.patch.object(self.module.shutil, "which", side_effect=lambda name: f"/usr/bin/{name}"), \
             mock.patch.object(self.module, "run", side_effect=fake_run):
            self.assertEqual(self.module.backend(), "tuned")

    def test_backend_is_none_without_either_daemon(self):
        with mock.patch.object(self.module.shutil, "which", return_value=None):
            self.assertEqual(self.module.backend(), "none")

    def test_current_mode_maps_tuned_profile_name_to_performance_or_balanced(self):
        def fake_run(*arguments, **kwargs):
            if arguments[:2] == ("tuned-adm", "active"):
                return mock.Mock(stdout="Current active profile: throughput-performance\n")
            return mock.Mock(stdout="")

        with mock.patch.object(self.module, "run", side_effect=fake_run):
            self.assertEqual(self.module.current_mode("tuned"), "performance")

    def test_current_mode_recognizes_tuned_power_saving_profile(self):
        def fake_run(*arguments, **kwargs):
            if arguments[:2] == ("tuned-adm", "active"):
                return mock.Mock(stdout="Current active profile: powersave\n")
            return mock.Mock(stdout="")

        with mock.patch.object(self.module, "run", side_effect=fake_run):
            self.assertEqual(self.module.current_mode("tuned"), "power-saver")

    def test_current_mode_reads_the_tuned_state_file_directly_without_shelling_out(self):
        # The fast path around `tuned-adm active`'s D-Bus round trip: TuneD keeps the
        # active profile's name in this plain file too, so read that instead of forking.
        self.module.STATE_DIR.mkdir(parents=True, exist_ok=True)
        self.module.TUNED_ACTIVE_PROFILE_FILE.write_text("throughput-performance\n", encoding="utf-8")
        with mock.patch.object(self.module, "run") as run:
            self.assertEqual(self.module.current_mode("tuned"), "performance")
        run.assert_not_called()

    def test_current_mode_falls_back_to_tuned_adm_when_the_state_file_is_missing(self):
        def fake_run(*arguments, **kwargs):
            if arguments[:2] == ("tuned-adm", "active"):
                return mock.Mock(stdout="Current active profile: balanced\n")
            return mock.Mock(stdout="")

        with mock.patch.object(self.module, "run", side_effect=fake_run):
            self.assertEqual(self.module.current_mode("tuned"), "balanced")

    def test_current_mode_reads_power_profiles_daemon_directly(self):
        with mock.patch.object(self.module, "run", return_value=mock.Mock(stdout="performance\n")):
            self.assertEqual(self.module.current_mode("power-profiles-daemon"), "performance")

    def test_set_mode_maps_performance_to_the_tuned_throughput_profile(self):
        calls = []

        def fake_run(*arguments, **kwargs):
            calls.append(arguments)
            return mock.Mock(returncode=0)

        with mock.patch.object(self.module, "run", side_effect=fake_run):
            self.assertTrue(self.module.set_mode("performance", "tuned"))
        self.assertIn(("tuned-adm", "profile", "throughput-performance"), calls)

    def test_set_mode_rejects_an_unknown_mode(self):
        self.assertFalse(self.module.set_mode("turbo", "tuned"))

    def test_toggle_flips_and_notifies(self):
        notified = []
        with mock.patch.object(self.module, "backend", return_value="tuned"), \
             mock.patch.object(self.module, "current_mode", return_value="performance"), \
             mock.patch.object(self.module, "set_mode", return_value=True) as set_mode, \
             mock.patch.object(self.module, "notify", side_effect=notified.append):
            self.assertEqual(self.module.toggle(), 0)
        set_mode.assert_called_once_with("power-saver", "tuned")
        self.assertEqual(notified, ["power-saver"])

    def test_power_saving_sets_each_backend_native_profile(self):
        with mock.patch.object(self.module, "run", return_value=mock.Mock(returncode=0)) as run:
            self.assertTrue(self.module.set_mode("power-saver", "tuned"))
            run.assert_called_with("tuned-adm", "profile", "powersave")
            self.assertTrue(self.module.set_mode("power-saver", "power-profiles-daemon"))
            run.assert_called_with("powerprofilesctl", "set", "power-saver")

    def test_laptop_without_performance_cycles_only_available_modes(self):
        with mock.patch.object(self.module, "backend", return_value="power-profiles-daemon"), \
             mock.patch.object(self.module, "run", return_value=mock.Mock(stdout="* balanced:\n  power-saver:\n")), \
             mock.patch.object(self.module, "current_mode", return_value="balanced"), \
             mock.patch.object(self.module, "set_mode", return_value=True) as set_mode, \
             mock.patch.object(self.module, "notify"):
            self.assertEqual(self.module.toggle(), 0)
            set_mode.assert_called_once_with("power-saver", "power-profiles-daemon")

    def test_power_saving_before_game_is_restored(self):
        self.module._write_count(1)
        self.module.PRE_GAME_FILE.write_text("power-saver")
        with mock.patch.object(self.module, "backend", return_value="tuned"), \
             mock.patch.object(self.module, "current_mode", return_value="performance"), \
             mock.patch.object(self.module, "set_mode", return_value=True) as set_mode, \
             mock.patch.object(self.module, "notify"):
            self.module.game_end()
            set_mode.assert_called_once_with("power-saver", "tuned")

    def test_toggle_fails_cleanly_without_a_backend(self):
        with mock.patch.object(self.module, "backend", return_value="none"):
            self.assertEqual(self.module.toggle(), 1)

    def _status(self):
        import contextlib
        import io
        import json

        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            self.module.print_status()
        return json.loads(buffer.getvalue())

    def test_waybar_status_uses_md_speedometer_when_performance(self):
        # Same md-speedometer glyph as the Eww header icon, and only "performance" gets
        # the accent highlight (the "performance" CSS class) -- "balanced" is the everyday
        # default and stays the plain chip look, matching header-icon.active's own rule.
        with mock.patch.object(self.module, "backend", return_value="tuned"), \
             mock.patch.object(self.module, "current_mode", return_value="performance"):
            status = self._status()
        self.assertEqual(status["text"], "\U000f04c5")
        self.assertEqual(status["class"], "performance")

    def test_waybar_status_uses_fa_scale_balanced_when_balanced(self):
        with mock.patch.object(self.module, "backend", return_value="tuned"), \
             mock.patch.object(self.module, "current_mode", return_value="balanced"):
            status = self._status()
        self.assertEqual(status["text"], "\U0000f24e")
        self.assertEqual(status["class"], "balanced")

    def test_waybar_status_hides_when_no_backend_is_available(self):
        # Empty text plus the layout's own "hide-empty-text" is what makes Waybar collapse
        # this module entirely on a form factor with neither power-profile daemon, rather
        # than showing a dead button.
        with mock.patch.object(self.module, "backend", return_value="none"):
            status = self._status()
        self.assertEqual(status["text"], "")
        self.assertEqual(status["class"], "unavailable")

    def test_game_start_remembers_the_prior_mode_only_on_first_arrival(self):
        modes = iter(["balanced"])
        set_calls = []
        notified = []
        with mock.patch.object(self.module, "backend", return_value="tuned"), \
             mock.patch.object(self.module, "current_mode", side_effect=lambda b: next(modes)), \
             mock.patch.object(self.module, "set_mode", side_effect=lambda m, b: set_calls.append(m) or True), \
             mock.patch.object(self.module, "notify", side_effect=notified.append):
            self.module.game_start()
            self.module.game_start()  # a second, overlapping game
        self.assertEqual(set_calls, ["performance"])  # only switched once
        self.assertEqual(notified, ["performance"])  # activation announced exactly once
        self.assertEqual(self.module.PRE_GAME_FILE.read_text(encoding="utf-8"), "balanced")
        self.assertEqual(self.module._read_count(), 2)

    def test_game_start_does_not_notify_when_performance_was_already_active(self):
        # e.g. the user had already manually switched to Performance before the game
        # launched -- GameMode's hook firing shouldn't repeat a toast for no real change.
        set_calls = []
        notified = []
        with mock.patch.object(self.module, "backend", return_value="tuned"), \
             mock.patch.object(self.module, "current_mode", return_value="performance"), \
             mock.patch.object(self.module, "set_mode", side_effect=lambda m, b: set_calls.append(m) or True), \
             mock.patch.object(self.module, "notify", side_effect=notified.append):
            self.module.game_start()
        self.assertEqual(set_calls, [])
        self.assertEqual(notified, [])

    def test_game_end_only_restores_after_the_last_departure(self):
        set_calls = []
        notified = []
        with mock.patch.object(self.module, "backend", return_value="tuned"), \
             mock.patch.object(self.module, "current_mode", return_value="performance"), \
             mock.patch.object(self.module, "set_mode", side_effect=lambda m, b: set_calls.append(m) or True), \
             mock.patch.object(self.module, "notify", side_effect=notified.append):
            self.module._write_count(2)
            self.module.PRE_GAME_FILE.parent.mkdir(parents=True, exist_ok=True)
            self.module.PRE_GAME_FILE.write_text("balanced", encoding="utf-8")

            self.module.game_end()
            self.assertEqual(set_calls, [])  # one game still running
            self.assertEqual(notified, [])
            self.module.game_end()
            self.assertEqual(set_calls, ["balanced"])  # last one restores
            # Only the restored (now-active) mode is ever announced -- never a separate
            # "Performance deactivated" message for the one it replaced.
            self.assertEqual(notified, ["balanced"])

    def test_game_end_does_not_notify_when_already_at_the_mode_being_restored(self):
        # e.g. the user manually switched back to Balanced while the game was still
        # running -- the restore is then a no-op and shouldn't repeat a toast.
        set_calls = []
        notified = []
        with mock.patch.object(self.module, "backend", return_value="tuned"), \
             mock.patch.object(self.module, "current_mode", return_value="balanced"), \
             mock.patch.object(self.module, "set_mode", side_effect=lambda m, b: set_calls.append(m) or True), \
             mock.patch.object(self.module, "notify", side_effect=notified.append):
            self.module._write_count(1)
            self.module.PRE_GAME_FILE.parent.mkdir(parents=True, exist_ok=True)
            self.module.PRE_GAME_FILE.write_text("balanced", encoding="utf-8")
            self.module.game_end()
        self.assertEqual(set_calls, [])
        self.assertEqual(notified, [])

    def test_game_end_defaults_to_balanced_when_nothing_was_remembered(self):
        set_calls = []
        with mock.patch.object(self.module, "backend", return_value="tuned"), \
             mock.patch.object(self.module, "current_mode", return_value="performance"), \
             mock.patch.object(self.module, "set_mode", side_effect=lambda m, b: set_calls.append(m) or True), \
             mock.patch.object(self.module, "notify"):
            self.module._write_count(1)
            self.module.game_end()
        self.assertEqual(set_calls, ["balanced"])


if __name__ == "__main__":
    unittest.main()
