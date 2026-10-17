import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('screensaver', str(ROOT / 'scripts/screensaver-adapter'))
spec = importlib.util.spec_from_loader(loader.name, loader)
saver = importlib.util.module_from_spec(spec)
loader.exec_module(saver)


class ScreensaverTests(unittest.TestCase):
    def test_default_does_not_modify_user_configuration(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {'XDG_CONFIG_HOME': directory}):
            self.assertEqual(saver.read_settings()[1], saver.DEFAULTS)
            self.assertFalse(saver.config_path().exists())

    def test_all_settings_persist_preserving_unknown_keys(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {'XDG_CONFIG_HOME': directory}):
            path = saver.config_path()
            path.parent.mkdir()
            path.write_text('{"personal":"preserved"}')
            for key, values in [('enabled', ['off', 'on']), ('timeout', ['30', '180', '540']),
                                ('effect', saver.EFFECTS), ('branding', saver.BRANDING)]:
                for value in values:
                    saver.save(key, value)
                    self.assertEqual(json.loads(path.read_text())['personal'], 'preserved')
                    self.assertEqual(saver.read_settings()[1][key], saver.save(key, value)[key])
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertEqual(len(list(path.parent.iterdir())), 2)

    def test_invalid_settings_cannot_modify_saved_values(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {'XDG_CONFIG_HOME': directory}):
            saver.save('effect', 'rain')
            original = saver.config_path().read_bytes()
            for key, value in [('enabled', 'yes'), ('timeout', '0'), ('timeout', '600'),
                               ('timeout', '1; echo unsafe'), ('effect', 'bad'), ('branding', '../logo'), ('bad', 'on')]:
                with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                    saver.save(key, value)
                self.assertEqual(saver.config_path().read_bytes(), original)

    def test_corrupt_settings_are_preserved(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {'XDG_CONFIG_HOME': directory}):
            path = saver.config_path()
            path.parent.mkdir()
            for contents in ('[]', '{bad json'):
                path.write_text(contents)
                with self.assertRaises(ValueError):
                    saver.save('enabled', 'off')
                self.assertEqual(path.read_text(), contents)

    def session_responses(self, locked='no', active='yes', locker=1, inhibitors=None):
        return [subprocess.CompletedProcess([], 0, f'LockedHint={locked}\nActive={active}\nType=wayland\n', ''),
                subprocess.CompletedProcess([], locker, b'', b''),
                subprocess.CompletedProcess([], 0, json.dumps(inhibitors or []), '')]

    def test_session_lock_activity_and_inhibitors_gate_activation(self):
        scenarios = [(self.session_responses(), True), (self.session_responses(locked='yes'), False),
                     (self.session_responses(active='no'), False), (self.session_responses(locker=0), False),
                     (self.session_responses(inhibitors=[{'what': 'idle:sleep', 'mode': 'block'}]), False),
                     (self.session_responses(inhibitors=[{'what': 'sleep', 'mode': 'delay'}]), True)]
        for responses, allowed in scenarios:
            with self.subTest(allowed=allowed), patch.object(saver.subprocess, 'run', side_effect=responses):
                self.assertEqual(saver.session_state()['allowed'], allowed)

    def test_session_failure_is_closed(self):
        responses = self.session_responses()
        responses[0].returncode = 1
        with patch.object(saver.subprocess, 'run', side_effect=responses):
            self.assertFalse(saver.session_state()['allowed'])

    def test_branding_masks_are_bounded_and_logo_falls_back(self):
        with tempfile.TemporaryDirectory() as directory:
            logo = Path(directory) / 'logo.png'
            image = Image.new('RGBA', (200, 200))
            image.paste('white', (50, 20, 150, 180))
            image.save(logo)
            with patch.object(saver, 'LOGO', logo):
                masks = saver.masks()
            for mask in masks.values():
                self.assertGreater(len(mask['points']), 20)
                self.assertLessEqual(len(mask['points']), 700)
                self.assertTrue(all(0 <= coordinate <= 1 for point in mask['points'] for coordinate in point))
            self.assertAlmostEqual(masks['logo']['aspect'], 100 / 160, places=1)
            with patch.object(saver, 'LOGO', Path(directory) / 'missing.png'):
                self.assertEqual(saver.masks()['logo']['points'], [])

    def test_packaging_and_adoption_include_screensaver(self):
        recipe = ROOT / 'packages/spectrum-desktop/PKGBUILD'
        if not recipe.exists():
            recipe = Path('/startdir/PKGBUILD')
        self.assertIn('screensaver-adapter', recipe.read_text())
        self.assertIn("'quickshell>=0.3.0'", recipe.read_text())
        self.assertIn('scripts/screensaver-adapter', (ROOT / 'install.sh').read_text())
        self.assertIn('ScreensaverController', (ROOT / 'configs/spectrum-shell/shell.qml').read_text())
        self.assertIn('ScreensaverControls', (ROOT / 'configs/spectrum-shell/DisplayWidgetContent.qml').read_text())
