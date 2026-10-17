import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class BarStyleTests(unittest.TestCase):
    def run_layout(self, directory, *args):
        return subprocess.run([str(ROOT / 'scripts/spectrum-shell-layout'), *args],
                              env=dict(os.environ, XDG_CONFIG_HOME=directory), capture_output=True, text=True)

    def test_default_and_invalid_stored_style_use_full(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(json.loads(self.run_layout(directory, '--json').stdout)['bar_style'], 'full')
            path = Path(directory) / 'spectrumos/shell.json'
            path.parent.mkdir()
            path.write_text('{"bar_style": "unknown"}')
            self.assertEqual(json.loads(self.run_layout(directory, '--json').stdout)['bar_style'], 'full')

    def test_styles_preserve_gaming_and_monitor_preferences(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'spectrumos/shell.json'
            path.parent.mkdir()
            original = {'bar_position': 'top', 'gaming_enabled': True,
                        'bar_profiles': {'DP-1': 'detailed', 'HDMI-A-1': 'minimal'}}
            path.write_text(json.dumps(original))
            for style in ('islands', 'full'):
                self.assertEqual(self.run_layout(directory, 'set-style', style).returncode, 0)
                stored = json.loads(path.read_text())
                self.assertEqual(stored.pop('bar_style'), style)
                self.assertEqual(stored, original)
                self.assertEqual(json.loads(self.run_layout(directory, '--json').stdout)['bar_style'], style)

    def test_invalid_style_cannot_mutate_preferences(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'spectrumos/shell.json'
            path.parent.mkdir()
            original = b'{"bar_style":"islands", "custom": 42}\n'
            path.write_bytes(original)
            self.assertEqual(self.run_layout(directory, 'set-style', 'floating').returncode, 2)
            self.assertEqual(path.read_bytes(), original)
