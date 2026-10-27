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
BACKEND = ROOT / 'scripts/default-apps-adapter'
loader = importlib.machinery.SourceFileLoader('default_apps', str(BACKEND))
spec = importlib.util.spec_from_loader(loader.name, loader)
MODULE = importlib.util.module_from_spec(spec)
loader.exec_module(MODULE)
VIDEO = next(types for key, _, types in MODULE.GROUPS if key == 'video')


class DefaultAppsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.config = self.home / 'config'
        self.apps = self.home / 'share/applications'
        self.config.mkdir()
        self.apps.mkdir(parents=True)
        self.env = {**os.environ, 'HOME': str(self.home), 'XDG_CONFIG_HOME': str(self.config),
            'XDG_CONFIG_DIRS': str(self.home / 'system-config'), 'XDG_DATA_HOME': str(self.home / 'user-share'),
            'XDG_DATA_DIRS': str(self.home / 'share'), 'XDG_STATE_HOME': str(self.home / 'state'),
            'XDG_CACHE_HOME': str(self.home / 'cache'), 'XDG_CURRENT_DESKTOP': 'Hyprland', 'DE': 'generic'}
        for key in ['KDE_FULL_SESSION', 'GNOME_DESKTOP_SESSION_ID']:
            self.env.pop(key, None)
        self.desktop('test-player.desktop', 'Test Player', VIDEO)
        self.desktop('test-other.desktop', 'Other Player', ['video/x-matroska'])
        self.desktop('test-browser.desktop', 'Test Browser', ['video/webm', 'x-scheme-handler/http', 'x-scheme-handler/https', 'text/html', 'application/xhtml+xml'])
        self.desktop('test-editor.desktop', 'Test Editor', ['text/plain'])
        subprocess.run(['update-desktop-database', str(self.apps)], env=self.env, check=True, capture_output=True)
        mime = self.home / 'share/mime'
        mime.mkdir()
        (mime / 'globs2').write_text('50:video/x-matroska:*.mkv\n50:video/mp4:*.mp4\n')
        self.path = self.config / 'mimeapps.list'
        self.original = b'# Keep my preferences\n[Default Applications]\nvideo/mp4=test-player.desktop;\nvideo/x-matroska=test-other.desktop;\nvideo/webm=test-browser.desktop;\nvideo/matroska=legacy.desktop;\ntext/plain=test-editor.desktop;\n\n[Added Associations]\nvideo/mp4=test-other.desktop;\n\n[Removed Associations]\nvideo/mp4=test-player.desktop;other.desktop;\n'
        self.path.write_bytes(self.original)

    def desktop(self, name, label, types):
        (self.apps / name).write_text('[Desktop Entry]\nType=Application\nName=' + label + '\nExec=/usr/bin/touch ' + str(self.home / 'MUST-NOT-LAUNCH') + ' %U\nMimeType=' + ';'.join(types) + ';\n')

    def command(self, action, request):
        result = subprocess.run(['python3', str(BACKEND), action, json.dumps(request)], env=self.env, capture_output=True, text=True, timeout=30)
        try:
            return result.returncode, json.loads(result.stdout)
        except ValueError:
            self.fail(result.stdout + result.stderr)

    def test_read_only_status_shows_mixed_defaults_and_real_mkv_type(self):
        code, result = self.command('status', {'group': 'video', 'catalogue': True})
        self.assertEqual(code, 0, result)
        self.assertEqual(self.path.read_bytes(), self.original)
        self.assertEqual([app['id'] for app in result['apps']], ['test-player.desktop'])
        rows = {row['mime']: row['desktop'] for row in result['defaults']}
        self.assertEqual(rows['video/x-matroska'], 'test-other.desktop')
        self.assertEqual(rows['video/webm'], 'test-browser.desktop')
        mkv = next(t for t in result['file_types'] if t['id'] == 'video/x-matroska')
        self.assertIn('.mkv', mkv['extensions'])
        self.assertFalse((self.home / 'MUST-NOT-LAUNCH').exists())

    def test_apply_updates_all_video_types_and_preserves_other_preferences(self):
        code, result = self.command('set', {'group': 'video', 'desktop': 'test-player.desktop'})
        self.assertEqual(code, 0, result)
        self.assertTrue(all(row['desktop'] == 'test-player.desktop' for row in result['defaults']))
        saved = self.path.read_text()
        self.assertIn('# Keep my preferences', saved)
        self.assertIn('text/plain=test-editor.desktop;', saved)
        self.assertIn('video/matroska=legacy.desktop;', saved)
        parsed = MODULE.parser_for(self.path.read_bytes())
        self.assertEqual(parsed.get('Removed Associations', 'video/mp4'), 'other.desktop;')
        self.assertEqual(parsed.get('Added Associations', 'video/mp4'), 'test-player.desktop;test-other.desktop;')
        self.assertEqual((Path(result['backup']) / '0').read_bytes(), self.original)
        self.assertFalse((self.home / 'MUST-NOT-LAUNCH').exists())
        for mime in VIDEO:
            actual = subprocess.check_output(['xdg-mime', 'query', 'default', mime], env=self.env, text=True).strip()
            self.assertEqual(actual, 'test-player.desktop')

    def test_desktop_specific_override_is_updated_without_changing_other_entries(self):
        specific = self.config / 'hyprland-mimeapps.list'
        specific.write_text('[Default Applications]\nvideo/x-matroska=test-other.desktop;\ntext/plain=test-editor.desktop;\n')
        code, result = self.command('set', {'mime': 'video/x-matroska', 'desktop': 'test-player.desktop'})
        self.assertEqual(code, 0, result)
        self.assertIn('video/x-matroska=test-player.desktop;', specific.read_text())
        self.assertIn('text/plain=test-editor.desktop;', specific.read_text())
        self.assertNotIn('[Added Associations]', specific.read_text())
        self.assertIn('video/webm=test-browser.desktop;', self.path.read_text())

    def test_unsupported_application_cannot_replace_video_defaults(self):
        code, result = self.command('set', {'group': 'video', 'desktop': 'test-editor.desktop'})
        self.assertEqual(code, 1)
        self.assertFalse(result['ok'])
        self.assertEqual(self.path.read_bytes(), self.original)

    def test_unknown_type_and_option_like_desktop_are_rejected(self):
        for request in [{'mime': 'video/not-a-registered-type', 'desktop': 'test-player.desktop'},
                        {'group': 'video', 'desktop': '-bad.desktop'}]:
            code, result = self.command('set', request)
            self.assertEqual(code, 1)
            self.assertFalse(result['ok'])
            self.assertEqual(self.path.read_bytes(), self.original)

    def test_verification_failure_restores_both_original_files(self):
        specific = self.config / 'hyprland-mimeapps.list'
        before = b'[Default Applications]\nvideo/x-matroska=test-other.desktop;\n'
        specific.write_bytes(before)
        with patch.dict(os.environ, self.env, clear=True), patch.object(MODULE, 'status', return_value={'apps': [{'id': 'test-player.desktop'}]}), patch.object(MODULE, 'query', return_value='different.desktop'):
            with self.assertRaisesRegex(ValueError, 'previous associations were restored'):
                MODULE.set_default({'group': 'video', 'desktop': 'test-player.desktop'})
        self.assertEqual(self.path.read_bytes(), self.original)
        self.assertEqual(specific.read_bytes(), before)

    def test_root_cannot_change_user_defaults(self):
        with patch.object(MODULE.os, 'geteuid', return_value=0):
            with self.assertRaisesRegex(ValueError, 'normal desktop user'):
                MODULE.set_default({'group': 'video', 'desktop': 'test-player.desktop'})

    def test_duplicate_target_keys_crlf_and_unrelated_sections_survive(self):
        data = b'# original\r\n[Default Applications]\r\nvideo/mp4=one.desktop;\r\nvideo/mp4=two.desktop;\r\n[Other]\r\nkey=value\r\n'
        result = MODULE.associations(data, ['video/mp4'], 'test-player.desktop')
        self.assertEqual(result.count(b'video/mp4=test-player.desktop;'), 3)
        self.assertIn(b'[Other]\r\nkey=value\r\n', result)
        self.assertIn(b'# original\r\n', result)
