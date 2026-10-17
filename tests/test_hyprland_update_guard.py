import importlib.machinery
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('hyprland_guard', str(ROOT / 'scripts/hyprland-update-guard'))
spec = importlib.util.spec_from_loader(loader.name, loader)
GUARD = importlib.util.module_from_spec(spec)
loader.exec_module(GUARD)


class HyprlandUpdateGuardTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.state = Path(self.directory.name) / 'state.json'
        self.session = {'uid': 1000, 'instance': 'test_123'}
        self.state_patch = patch.object(GUARD, 'STATE', self.state)
        self.state_patch.start()
        self.addCleanup(self.state_patch.stop)
        self.sessions_patch = patch.object(GUARD, 'sessions', return_value=[self.session])
        self.sessions_patch.start()
        self.addCleanup(self.sessions_patch.stop)
        self.owner_patch = patch.object(GUARD, 'transaction_process', return_value=None)
        self.owner_patch.start()
        self.addCleanup(self.owner_patch.stop)

    def result(self, output='ok\n', code=0):
        return subprocess.CompletedProcess([], code, output, '')

    def test_pause_and_restore_enabled_autoreload(self):
        with patch.object(GUARD, 'invoke', side_effect=[self.result('{"bool":false}'), self.result(), self.result(), self.result()]) as invoke:
            GUARD.pause()
            self.assertTrue(self.state.exists())
            self.assertIn('disable_autoreload = true', invoke.call_args.args[-1])
            GUARD.finish()
            self.assertFalse(self.state.exists())
            self.assertEqual(invoke.call_args_list[-2].args[1], 'reload')
            self.assertIn('disable_autoreload = false', invoke.call_args.args[-1])

    def test_preserves_deliberately_disabled_autoreload(self):
        with patch.object(GUARD, 'invoke', side_effect=[self.result('{"bool":true}'), self.result(), self.result(), self.result()]) as invoke:
            GUARD.pause()
            GUARD.finish()
            self.assertIn('disable_autoreload = true', invoke.call_args.args[-1])

    def test_no_running_sessions_is_a_noop(self):
        with patch.object(GUARD, 'sessions', return_value=[]), patch.object(GUARD, 'invoke') as invoke:
            GUARD.pause()
            GUARD.finish()
            invoke.assert_not_called()
            self.assertFalse(self.state.exists())

    def test_repeated_pause_does_not_lose_original_setting(self):
        with patch.object(GUARD, 'transaction_process', return_value={'pid': 123, 'started': '456'}), patch.object(GUARD, 'process_identity', return_value='456'), patch.object(GUARD.subprocess, 'run', return_value=self.result()), patch.object(GUARD, 'invoke', side_effect=[self.result('{"bool":false}'), self.result()]) as invoke:
            GUARD.pause()
            original = self.state.read_text()
            GUARD.pause()
            self.assertEqual(self.state.read_text(), original)
            self.assertEqual(invoke.call_count, 2)

    def test_failed_pause_rolls_back(self):
        with patch.object(GUARD, 'invoke', side_effect=[self.result('{"bool":false}'), self.result('error', 1), self.result(), self.result()]) as invoke:
            with self.assertRaises(RuntimeError):
                GUARD.pause()
            self.assertFalse(self.state.exists())
            self.assertIn('disable_autoreload = false', invoke.call_args.args[-1])

    def test_failed_restore_retains_recovery_state(self):
        with patch.object(GUARD, 'invoke', side_effect=[self.result('{"bool":false}'), self.result(), self.result('error', 1)]):
            GUARD.pause()
            with self.assertRaises(RuntimeError):
                GUARD.finish()
            self.assertTrue(self.state.exists())

    def test_closed_session_needs_no_reload(self):
        with patch.object(GUARD, 'invoke', side_effect=[self.result('{"bool":false}'), self.result()]) as invoke:
            GUARD.pause()
            with patch.object(GUARD, 'sessions', return_value=[]):
                GUARD.finish()
            self.assertEqual(invoke.call_count, 2)
            self.assertFalse(self.state.exists())

    def test_interrupted_transaction_recovers(self):
        with patch.object(GUARD, 'STATE_DIR', Path(self.directory.name)), patch.object(GUARD, 'transaction_process', return_value={'pid': 123, 'started': '456'}), patch.object(GUARD.subprocess, 'run', return_value=self.result()), patch.object(GUARD, 'invoke', side_effect=[self.result('{"bool":false}'), self.result(), self.result(), self.result()]) as invoke:
            GUARD.pause()
            with patch.object(GUARD, 'process_identity', return_value=None):
                GUARD.recover()
            self.assertFalse(self.state.exists())
            self.assertIn('disable_autoreload = false', invoke.call_args.args[-1])


if __name__ == '__main__':
    unittest.main()
