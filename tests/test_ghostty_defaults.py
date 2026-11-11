import runpy
from pathlib import Path
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
TERMINAL = runpy.run_path(str(ROOT / 'scripts/spectrum-terminal-config'))


class GhosttyDefaultsTests(unittest.TestCase):
    def test_existing_users_receive_default_and_keep_personal_overrides(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            folder = home / '.config/ghostty'
            folder.mkdir(parents=True)
            config = folder / 'config'
            config.write_text('font-size = 18\nbackground-opacity = 0.95\n')
            terminals = home / '.config/xdg-terminals.list'
            terminals.write_text('kitty.desktop\nAlacritty.desktop\n')
            configure = TERMINAL['configure']
            configure(home)
            self.assertEqual(config.read_text(), TERMINAL['GHOSTTY_INCLUDE']+'\nfont-size = 18\nbackground-opacity = 0.95\n')
            self.assertEqual(config.with_name('config.pre-spectrum-managed').read_text(), 'font-size = 18\nbackground-opacity = 0.95\n')
            self.assertEqual(terminals.read_text().splitlines()[0], 'com.mitchellh.ghostty.desktop')
            before = config.read_text(), terminals.read_text()
            configure(home)
            self.assertEqual(before, (config.read_text(), terminals.read_text()))

    def test_modern_config_and_explicit_terminal_choice_are_preserved(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            folder = home / '.config/ghostty'
            folder.mkdir(parents=True)
            config = folder / 'config.ghostty'
            config.write_text('font-size = 17\n')
            terminals = home / '.config/xdg-terminals.list'
            terminals.write_text('org.wezfurlong.wezterm.desktop\nkitty.desktop\n')
            TERMINAL['configure'](home)
            self.assertIn('font-size = 17', config.read_text())
            self.assertFalse((folder / 'config').exists())
            self.assertEqual(terminals.read_text(), 'org.wezfurlong.wezterm.desktop\nkitty.desktop\n')

    def test_linked_config_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            folder = home / '.config/ghostty'
            folder.mkdir(parents=True)
            personal = home / 'personal.conf'
            personal.write_text('font-size = 19\n')
            (folder / 'config').symlink_to(personal)
            with self.assertRaises(ValueError):
                TERMINAL['configure'](home)
            self.assertEqual(personal.read_text(), 'font-size = 19\n')

    def test_old_palette_is_regenerated_before_ghostty_configuration(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            cache = home / '.cache/spectrumos/theme'
            current = cache / 'current'
            current.mkdir(parents=True)
            (current / 'palette.json').write_text('{}')
            with mock.patch.dict('os.environ', {'XDG_CACHE_HOME': str(home / '.cache')}), mock.patch('subprocess.run') as run:
                TERMINAL['configure'](home)
            self.assertEqual(run.call_args.args[0], ['spectrum-theme', 'rerender-current', '--output', str(cache)])
            (current / 'ghostty.conf').write_text('font-size = 14')
            with mock.patch.dict('os.environ', {'XDG_CACHE_HOME': str(home / '.cache')}), mock.patch('subprocess.run') as run:
                TERMINAL['configure'](home)
            run.assert_not_called()

    def test_update_installs_ghostty_and_seeds_new_accounts(self):
        recipe = (ROOT / 'packages/spectrum-desktop/PKGBUILD').read_text()
        self.assertIn(' ghostty ', recipe)
        self.assertIn('"$pkgdir/etc/skel/.config/ghostty/config"', recipe)
        self.assertIn('spectrum-terminal-config', (ROOT / 'scripts/spectrum-desktop-cleanup').read_text())
        self.assertIn('com.mitchellh.ghostty.desktop', (ROOT / 'configs/xdg/xdg-terminals.list').read_text().splitlines()[0])
