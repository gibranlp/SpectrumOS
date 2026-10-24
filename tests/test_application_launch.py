import importlib.machinery
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]


class ApplicationLaunchTests(unittest.TestCase):
    def setUp(self):
        loader = importlib.machinery.SourceFileLoader('application_launch_adapter', str(ROOT / 'scripts/application-adapter'))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        self.adapter = importlib.util.module_from_spec(spec)
        loader.exec_module(self.adapter)

    def test_launch_tracks_before_catalog_lookup(self):
        with patch.object(self.adapter.sys, 'argv', ['application-adapter', 'launch', 'a' * 16]), \
                patch.object(self.adapter, 'applications', side_effect=AssertionError('Catalog must run after tracking')), \
                patch.object(self.adapter.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, 'ok\n', '')) as run:
            self.assertEqual(self.adapter.main(), 0)
            argv = run.call_args.args[0]
            self.assertEqual(argv[:2], ['hyprctl', 'dispatch'])
            self.assertIn('hl.dsp.exec_cmd(', argv[2])
            self.assertIn('_launch aaaaaaaaaaaaaaaa', argv[2])

    def test_rejected_dispatch_reports_failure(self):
        with patch.object(self.adapter.sys, 'argv', ['application-adapter', 'launch', 'a' * 16]), \
                patch.object(self.adapter.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, 'error: invalid dispatcher', '')):
            self.assertEqual(self.adapter.main(), 1)

    def test_invalid_token_does_not_dispatch(self):
        with patch.object(self.adapter.sys, 'argv', ['application-adapter', 'launch', "x'; echo bad"]), \
                patch.object(self.adapter.subprocess, 'run') as run:
            self.assertEqual(self.adapter.main(), 2)
            run.assert_not_called()

    def test_tracked_launch_retains_scope_environment(self):
        with patch.object(self.adapter.sys, 'argv', ['application-adapter', '_launch', 'a' * 16]), \
                patch.object(self.adapter, 'applications', return_value=[dict(token='a' * 16, desktop_id='example.desktop')]), \
                patch.object(self.adapter.subprocess, 'Popen') as popen:
            self.assertEqual(self.adapter.main(), 0)
            self.assertEqual(popen.call_args.args[0], ['uwsm', 'app', '-t', 'scope', '--', 'example.desktop'])
            self.assertNotIn('env', popen.call_args.kwargs)
