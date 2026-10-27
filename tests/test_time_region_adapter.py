import importlib.machinery
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
LOADER = importlib.machinery.SourceFileLoader('time_region_adapter', str(ROOT / 'scripts/time-region-adapter'))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
ADAPTER = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(ADAPTER)


class TimeRegionAdapterTests(unittest.TestCase):
    def test_status_keeps_interface_language_separate_from_regional_formats(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / 'locale.conf'
            config.write_text('LANG=en_US.UTF-8\nLC_MESSAGES=es_MX.UTF-8\nLC_TIME=pt_BR.UTF-8\n')
            with patch.object(ADAPTER, 'LOCALE_CONF', config), patch.object(ADAPTER, 'run', return_value=''), \
                    patch.object(ADAPTER, 'active', return_value=False), \
                    patch.object(ADAPTER, 'timesyncd_available', return_value=False), \
                    patch.object(ADAPTER, 'supported_locales', return_value=[]), \
                    patch.object(ADAPTER, 'NTP_CONF', Path(directory) / 'missing'):
                result = ADAPTER.state()
            self.assertEqual(result['language'], 'es_MX.UTF-8')
            self.assertEqual(result['region'], 'pt_BR.UTF-8')

    def test_server_validation_accepts_dns_and_ip_but_rejects_config_injection(self):
        self.assertEqual(ADAPTER.validate_servers('time.example.org 192.0.2.1 2001:db8::1'),
                         ['time.example.org', '192.0.2.1', '2001:db8::1'])
        self.assertEqual(ADAPTER.validate_servers(''), [])
        for value in ('pool.ntp.org\nFallbackNTP=evil', '-option', 'bad/name', 'bad;name',
                      'a..org', '[Time]', 'a' * 64 + '.org', ' '.join(['pool.ntp.org'] * 9)):
            with self.subTest(value=value), self.assertRaises(ValueError):
                ADAPTER.validate_servers(value)

    def test_time_validation_rejects_invalid_date_and_automatic_time(self):
        with patch('sys.argv', ['adapter', 'time', '2026-02-30 12:00:00']), patch.object(ADAPTER, 'run') as run:
            with self.assertRaises(ValueError):
                ADAPTER.main()
            run.assert_not_called()
        with patch('sys.argv', ['adapter', 'time', '2026-09-30 12:00:00']), patch.object(ADAPTER, 'run', return_value='NTP=yes') as run:
            with self.assertRaisesRegex(ValueError, 'automatic time'):
                ADAPTER.main()
            self.assertEqual(run.call_count, 1)

    def test_timezone_is_validated_before_mutation(self):
        with patch('sys.argv', ['adapter', 'timezone', '../etc/passwd']), patch.object(ADAPTER, 'run', return_value='America/Cancun\nUTC') as run:
            with self.assertRaises(ValueError):
                ADAPTER.main()
            self.assertEqual(run.call_count, 1)

    def test_generated_locales_preserve_adjacent_lines_and_set_regional_categories(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / 'locale.gen'
            config.write_text('# Heading\n#en_US.UTF-8 UTF-8  \n#es_MX.UTF-8 UTF-8\n# Keep this\n')
            with patch.object(ADAPTER, 'LOCALE_GEN', config), patch.object(ADAPTER, 'supported_locales', return_value=['en_US.UTF-8', 'es_MX.UTF-8']), patch.object(ADAPTER.os, 'geteuid', return_value=0), patch.object(ADAPTER, 'run') as run:
                ADAPTER.apply_locales('en_US.UTF-8', 'es_MX.UTF-8')
            self.assertEqual(config.read_text(), '# Heading\nen_US.UTF-8 UTF-8\nes_MX.UTF-8 UTF-8\n# Keep this\n')
            self.assertEqual(run.call_args_list[0].args, ('locale-gen',))
            args = run.call_args_list[1].args
            self.assertIn('LANG=en_US.UTF-8', args)
            for category in ('LC_TIME', 'LC_NUMERIC', 'LC_MONETARY', 'LC_MEASUREMENT'):
                self.assertIn(category + '=es_MX.UTF-8', args)

    def test_failed_locale_generation_restores_configuration(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / 'locale.gen'
            original = '#en_US.UTF-8 UTF-8\n'
            config.write_text(original)
            with patch.object(ADAPTER, 'LOCALE_GEN', config), patch.object(ADAPTER, 'supported_locales', return_value=['en_US.UTF-8']), patch.object(ADAPTER.os, 'geteuid', return_value=0), patch.object(ADAPTER, 'run', side_effect=RuntimeError('generation failed')):
                with self.assertRaises(RuntimeError):
                    ADAPTER.apply_locales('en_US.UTF-8', 'en_US.UTF-8')
            self.assertEqual(config.read_text(), original)

    def test_locale_request_uses_fixed_authenticated_helper(self):
        with patch.object(ADAPTER, 'supported_locales', return_value=['en_US.UTF-8']), patch.object(ADAPTER.os, 'geteuid', return_value=1000), patch.object(ADAPTER, 'run') as run:
            ADAPTER.apply_locales('en_US.UTF-8', 'en_US.UTF-8')
            run.assert_called_once_with('pkexec', ADAPTER.HELPER, 'locale', 'en_US.UTF-8', 'en_US.UTF-8', timeout=180)
            with self.assertRaises(ValueError):
                ADAPTER.apply_locales('en_US.UTF-8\nEVIL=yes', 'en_US.UTF-8')

    def test_servers_preserve_disabled_ntp_and_default_reset_removes_only_managed_file(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / '90-spectrumos.conf'
            other = Path(directory) / 'admin.conf'
            other.write_text('[Time]\nFallbackNTP=admin.example.org\n')
            with patch.object(ADAPTER, 'NTP_CONF', config), patch.object(ADAPTER, 'timesyncd_available', return_value=True), patch.object(ADAPTER.os, 'geteuid', return_value=0), patch.object(ADAPTER, 'active', return_value=False), patch.object(ADAPTER, 'run') as run:
                ADAPTER.configure_servers('pool.ntp.org')
                self.assertEqual(config.read_text(), '[Time]\nNTP=\nNTP=pool.ntp.org\n')
                ADAPTER.configure_servers('')
                run.assert_not_called()
            self.assertFalse(config.exists())
            self.assertTrue(other.exists())

    def test_failed_ntp_restart_restores_previous_servers(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / 'ntp.conf'
            original = '[Time]\nNTP=old.example.org\n'
            config.write_text(original)
            with patch.object(ADAPTER, 'NTP_CONF', config), patch.object(ADAPTER, 'timesyncd_available', return_value=True), patch.object(ADAPTER.os, 'geteuid', return_value=0), patch.object(ADAPTER, 'active', return_value=True), patch.object(ADAPTER, 'run', side_effect=[RuntimeError('failed'), '']) as run:
                with self.assertRaises(RuntimeError):
                    ADAPTER.configure_servers('new.example.org')
                self.assertEqual(run.call_count, 2)
            self.assertEqual(config.read_text(), original)

    def test_other_ntp_provider_blocks_server_edits(self):
        with patch.object(ADAPTER, 'timesyncd_available', return_value=False), patch.object(ADAPTER, 'run') as run:
            with self.assertRaises(ValueError):
                ADAPTER.configure_servers('pool.ntp.org')
            run.assert_not_called()

    def test_widget_shortcut_and_packaging_routes(self):
        self.assertIn('SHIFT + T', (ROOT / 'configs/hyprland/keybindings.lua').read_text())
        self.assertIn('time) method=toggleTimeRegion', (ROOT / 'scripts/spectrum-shell-open').read_text())
        self.assertIn('dashboard.actionRequested("time")', (ROOT / 'configs/spectrum-shell/Dashboard.qml').read_text())
        self.assertIn('time-region-adapter', (ROOT / 'install.sh').read_text())
        recipe = ROOT / 'packages/spectrum-desktop/PKGBUILD'
        if not recipe.is_file():
            recipe = Path('/startdir/PKGBUILD')
        self.assertIn('time-region-adapter', recipe.read_text())


if __name__ == '__main__':
    unittest.main()
