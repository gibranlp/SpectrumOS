import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

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
            for key, values in [('enabled', ['off', 'on']), ('timeout', ['30', '180', '540', '600', '900'])]:
                for value in values:
                    saver.save(key, value)
                    self.assertEqual(json.loads(path.read_text())['personal'], 'preserved')
                    self.assertEqual(saver.read_settings()[1][key], saver.save(key, value)[key])
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertEqual(len(list(path.parent.iterdir())), 2)

    def test_invalid_settings_cannot_modify_saved_values(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {'XDG_CONFIG_HOME': directory}):
            saver.save('timeout', '180')
            original = saver.config_path().read_bytes()
            for key, value in [('enabled', 'yes'), ('timeout', '0'), ('timeout', '901'),
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

    def test_keep_awake_allows_screensaver_but_other_idle_inhibitors_still_block(self):
        keep_awake = {'who': 'SpectrumOS', 'why': 'SpectrumOS keep awake',
                      'uid': os.getuid(), 'what': 'sleep:idle', 'mode': 'block'}
        for entries, allowed in [([keep_awake], True),
                                 ([keep_awake, {'what': 'idle', 'mode': 'block'}], False),
                                 ([dict(keep_awake, uid=os.getuid() + 1)], False),
                                 ([dict(keep_awake, why='Other task')], False)]:
            with self.subTest(entries=entries), patch.object(
                    saver.subprocess, 'run', side_effect=self.session_responses(inhibitors=entries)):
                self.assertEqual(saver.session_state()['allowed'], allowed)

    def test_session_failure_is_closed(self):
        responses = self.session_responses()
        responses[0].returncode = 1
        with patch.object(saver.subprocess, 'run', side_effect=responses):
            self.assertFalse(saver.session_state()['allowed'])

    def test_legacy_visual_settings_do_not_restore_branding_or_other_effects(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {'XDG_CONFIG_HOME': directory}):
            path = saver.config_path()
            path.parent.mkdir()
            path.write_text('{"effect":"cycle","branding":"logo","timeout":600}')
            self.assertEqual(saver.read_settings()[1], {'enabled': True, 'timeout': 600})
            saver.save('enabled', 'off')
            self.assertEqual(json.loads(path.read_text())['branding'], 'logo')
            self.assertEqual(saver.read_settings()[1], {'enabled': False, 'timeout': 600})

    def test_packaging_and_adoption_include_screensaver(self):
        recipe = ROOT / 'packages/spectrum-desktop/PKGBUILD'
        if not recipe.exists():
            recipe = Path('/startdir/PKGBUILD')
        self.assertIn('screensaver-adapter', recipe.read_text())
        self.assertIn('configs/spectrum-shell/*.qsb', recipe.read_text())
        self.assertIn('configs/spectrum-shell/matrix-*', recipe.read_text())
        self.assertIn('Copyright (c) 2018 Rezmason', (ROOT / 'configs/spectrum-shell/matrix-LICENSE.txt').read_text())
        self.assertIn('configs/spectrum-shell/*.qsb', (ROOT / 'install.sh').read_text())
        self.assertIn("'quickshell>=0.3.0'", recipe.read_text())
        self.assertIn('scripts/screensaver-adapter', (ROOT / 'install.sh').read_text())
        self.assertIn('ScreensaverController', (ROOT / 'configs/spectrum-shell/shell.qml').read_text())
        self.assertIn('ScreensaverControls', (ROOT / 'configs/spectrum-shell/DisplayWidgetContent.qml').read_text())
