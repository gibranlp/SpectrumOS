from importlib.machinery import SourceFileLoader
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    loader = SourceFileLoader(name.replace('-', '_'), str(ROOT / 'scripts' / name))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class ShellIdleTests(unittest.TestCase):
    def test_telemetry_never_launches_helpers(self):
        module = load('system-adapter')
        with mock.patch.object(module.subprocess, 'run') as run:
            data = module.telemetry()
        run.assert_not_called()
        self.assertIn('memory', data)
        self.assertIn('temperature', data)

    def test_profile_cache_expires_and_successful_changes_invalidate(self):
        module = load('performance-mode')
        with tempfile.TemporaryDirectory() as directory:
            module.STATE_DIR = Path(directory)
            with mock.patch.object(module, 'backend', return_value='tuned') as backend, \
                 mock.patch.object(module, 'current_mode', return_value='balanced'), \
                 mock.patch.object(module, 'available_modes', return_value=list(module.MODES)), \
                 mock.patch.object(module.time, 'monotonic', return_value=100) as clock:
                module.snapshot()
                module.snapshot()
                self.assertEqual(backend.call_count, 1)
                clock.return_value = 131
                module.snapshot()
                self.assertEqual(backend.call_count, 2)
                with mock.patch.object(module, 'run', return_value=mock.Mock(returncode=0)):
                    self.assertTrue(module.set_mode('performance', 'tuned'))
                module.snapshot()
                self.assertEqual(backend.call_count, 3)

    def test_failed_profile_change_preserves_cache(self):
        module = load('performance-mode')
        with tempfile.TemporaryDirectory() as directory:
            module.STATE_DIR = Path(directory)
            cache = module.STATE_DIR / 'status-cache.json'
            cache.write_text('{}')
            with mock.patch.object(module, 'run', return_value=mock.Mock(returncode=1)):
                self.assertFalse(module.set_mode('performance', 'tuned'))
            self.assertTrue(cache.exists())
