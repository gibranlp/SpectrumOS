import runpy
import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
NOTIFY = runpy.run_path(str(ROOT / 'scripts/omdrop-notify'))['notify']


class OmdropNotificationTests(unittest.TestCase):
    def test_plain_notification_uses_argument_array(self):
        with patch('subprocess.run', return_value=subprocess.CompletedProcess([], 0)) as run:
            self.assertEqual(NOTIFY(['Omdrop', 'Transfer complete']), 0)
            run.assert_called_once_with(['notify-send', '--app-name=SpectrumDrop', 'Omdrop', 'Transfer complete'], check=False)

    def test_action_preserves_filename_without_shell_expansion(self):
        filename = '/tmp/photo $(touch unexpected).png'
        action = ['/usr/bin/omdrop', 'act', 'open', filename]
        with patch('subprocess.run', return_value=subprocess.CompletedProcess([], 0, 'default\n')), \
             patch('subprocess.Popen') as launch:
            self.assertEqual(NOTIFY(['Received', filename, '--exec', *action]), 0)
            self.assertEqual(launch.call_args.args[0], action)
            self.assertNotIn('shell', launch.call_args.kwargs)

    def test_dismissed_notification_does_not_open_file(self):
        with patch('subprocess.run', return_value=subprocess.CompletedProcess([], 0, '')), \
             patch('subprocess.Popen') as launch:
            NOTIFY(['Received', '--exec', '/usr/bin/omdrop', 'act', 'open', '/tmp/file'])
            launch.assert_not_called()

    def test_empty_action_is_rejected(self):
        with patch('subprocess.run') as run:
            self.assertEqual(NOTIFY(['Received', '--exec']), 2)
            run.assert_not_called()

    def test_realtek_profile_remains_experimental(self):
        rows = [line.split() for line in (ROOT / 'configs/omdrop/owl-profiles').read_text().splitlines()
                if line and not line.startswith('#')]
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0][:3], ['rtw88_8821ce', 'untested', 'exclusive'])
        self.assertEqual((ROOT / 'scripts/omdrop-notify').read_bytes(),
                         (ROOT / 'packages/omdrop/omdrop-notify').read_bytes())
