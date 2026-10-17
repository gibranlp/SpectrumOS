import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load(name, filename):
    loader = importlib.machinery.SourceFileLoader(name, str(ROOT / 'scripts' / filename))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


backend = load('brightness_backend', 'brightness-adapter')
system = load('brightness_overview', 'system-adapter')


class BrightnessTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.backlight = self.root / 'backlight'
        self.drm = self.root / 'drm'
        self.backlight.mkdir()
        self.drm.mkdir()
        for name, value in [('BACKLIGHT', self.backlight), ('DRM', self.drm)]:
            patcher = patch.object(backend, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        environment = patch.dict(os.environ, XDG_RUNTIME_DIR=str(self.root))
        environment.start()
        self.addCleanup(environment.stop)

    def internal(self, name='intel_backlight', current=50, maximum=100, kind='raw'):
        path = self.backlight / name
        path.mkdir()
        for file, value in [('brightness', current), ('max_brightness', maximum), ('type', kind)]:
            (path / file).write_text(str(value))
        return path

    def external(self, name='card1-DP-1', bus=2, status='connected'):
        path = self.drm / name
        path.mkdir()
        (path / 'status').write_text(status)
        buspath = self.root / f'i2c-{bus}'
        buspath.mkdir(exist_ok=True)
        (path / 'ddc').symlink_to(buspath)
        return path

    def test_exact_macbook_overview_regression(self):
        with patch.object(system.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, 'apple_backlight,backlight,510,50%,1020\n')):
            self.assertEqual(system.brightness_state(), {'available': True, 'percent': 50})

    def test_overview_bad_measurements(self):
        for output in ('', 'invalid', 'intel,backlight,50,50%,0', 'intel,backlight,300,50%,100'):
            with self.subTest(output=output), patch.object(system.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, output)):
                self.assertFalse(system.brightness_state()['available'])

    def test_intel_amd_and_apple_readback(self):
        for name, maximum in [('intel_backlight', 6000), ('amdgpu_bl1', 255), ('apple_backlight', 1020)]:
            self.internal(name, maximum // 2, maximum)
        self.assertTrue(backend.state()['available'])
        self.assertEqual([item['percent'] for item in backend.state()['devices']], [50, 50, 50])

    def test_internal_change_is_targeted_and_reads_actual_value(self):
        path = self.internal('apple_backlight', 510, 1020)
        def command(arguments):
            self.assertEqual(arguments, ['brightnessctl', '--quiet', '--class=backlight', '--device', 'apple_backlight', 'set', '55%'])
            (path / 'brightness').write_text('560')
            return ''
        with patch.object(backend, 'run', side_effect=command):
            result = backend.change('up', 'backlight:apple_backlight')
        self.assertEqual(result['device']['current'], 560)
        self.assertEqual(result['device']['percent'], 55)

    def test_ddc_custom_range_change_and_readback(self):
        self.external()
        commands = []
        def command(arguments):
            commands.append(arguments)
            return 'VCP 10 C 50 200\n' if len(commands) == 1 else 'VCP 10 C 60 200\n'
        with patch.object(backend, 'run', side_effect=command):
            result = backend.change('up', 'ddc:card1-DP-1')
        self.assertEqual(commands[1], ['ddcutil', '--bus', '2', 'setvcp', '10', '60'])
        self.assertEqual(result['device']['percent'], 30)

    def test_limits_never_turn_display_off(self):
        path = self.internal(current=0)
        with patch.object(backend, 'run', return_value='') as command:
            backend.change('down', 'backlight:intel_backlight')
            self.assertEqual(command.call_args.args[0][-1], '1%')
            (path / 'brightness').write_text('100')
            backend.change('up', 'backlight:intel_backlight')
            self.assertEqual(command.call_args.args[0][-1], '100%')

    def test_hotplug_unavailable_and_permission_error(self):
        self.external()
        with patch.object(backend, 'run', side_effect=ValueError('Permission denied on /dev/i2c-2')):
            device = backend.state()['devices'][0]
            self.assertFalse(device['available'])
            self.assertIn('Permission denied', device['error'])
            with self.assertRaisesRegex(ValueError, 'Permission denied'):
                backend.change('up', device['id'])
        with self.assertRaisesRegex(ValueError, 'no longer connected'):
            backend.change('up', 'ddc:removed')

    def test_unsupported_and_malformed_ddc(self):
        self.external()
        for output in ('VCP 10 ERR', 'VCP 10 C 100 0', 'VCP 10 C 201 200', 'garbage'):
            with self.subTest(output=output), patch.object(backend, 'run', return_value=output):
                self.assertFalse(backend.state()['available'])

    def test_internal_and_disconnected_connectors_not_probed(self):
        self.external('card1-eDP-1')
        self.external('card1-HDMI-A-1', 3, 'disconnected')
        with patch.object(backend, 'run') as command:
            self.assertEqual(backend.state()['devices'], [])
            command.assert_not_called()

    def test_displayport_aux_bus_takes_precedence_over_ddc_link(self):
        path = self.external()
        (path / 'i2c-5').mkdir()
        self.assertEqual(backend.targets()[0]['bus'], '5')

    def test_default_prefers_raw_backlight(self):
        self.internal('acpi_video0', kind='firmware')
        self.internal('intel_backlight')
        self.assertEqual(backend.select(backend.targets(), None)['name'], 'intel_backlight')

    def test_external_default_follows_focused_monitor(self):
        self.external()
        self.external('card1-HDMI-A-1', 3)
        with patch.object(backend, 'run', return_value=json.dumps([{'name': 'HDMI-A-1', 'focused': True}])):
            self.assertEqual(backend.select(backend.targets(), None)['bus'], '3')

    def test_command_failure_timeout_and_missing_tool(self):
        for failure in (FileNotFoundError(), subprocess.TimeoutExpired('ddcutil', 4)):
            with patch.object(backend.subprocess, 'run', side_effect=failure):
                with self.assertRaises(ValueError):
                    backend.run(['ddcutil'])
        with patch.object(backend.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, '', 'Permission denied')):
            with self.assertRaisesRegex(ValueError, 'Permission denied'):
                backend.run(['brightnessctl'])

    def test_concurrent_action_is_bounded(self):
        self.internal()
        runtime = self.root / 'spectrumos'
        runtime.mkdir()
        with (runtime / 'brightness.lock').open('a') as lock:
            backend.fcntl.flock(lock, backend.fcntl.LOCK_EX | backend.fcntl.LOCK_NB)
            with self.assertRaisesRegex(ValueError, 'still changing'):
                backend.change('up', None)

    @unittest.skipUnless(shutil.which('qs'), 'Quickshell is not installed')
    def test_actual_process_readback_race_and_error_handling(self):
        result = subprocess.run([sys.executable, str(ROOT / 'tests/brightness_process_check.py')], capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('5 passed, 0 failed', result.stdout)

    def test_no_notifications_in_either_entrypoint(self):
        for name in ('brightness', 'brightness-adapter'):
            self.assertNotIn('notify-send', (ROOT / 'scripts' / name).read_text())

    def test_production_dependencies_and_installation(self):
        package = (ROOT / 'packages/spectrum-desktop/PKGBUILD').read_text()
        self.assertIn('ddcutil', package.split('makedepends=')[0])
        self.assertIn('brightness-adapter', package)
        self.assertIn('spectrumos-ddc.conf', package)
        self.assertIn('brightness-adapter', (ROOT / 'install.sh').read_text())
        self.assertIn('ddcutil', (ROOT / 'bootstrap/packages/desktop.txt').read_text().splitlines())
        self.assertIn('ddcutil', (ROOT / 'iso/spectrumos/packages.x86_64').read_text().splitlines())
