import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from tests.test_shell_idle import load

ROOT = Path(__file__).resolve().parents[1]


class SleepTests(unittest.TestCase):
    def setUp(self):
        self.module = load('spectrum-sleep')
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.module.SYS = self.root / 'sys'
        self.module.PROC = self.root / 'proc'
        self.module.STATE = self.root / 'state'
        self.module.MODE_CONFIG = self.root / 'sleep.conf.d/memory.conf'
        for path, value in {
            'sys/power/mem_sleep': '[s2idle]', 'sys/power/state': 'freeze mem disk',
            'sys/power/suspend_stats/success': '0', 'sys/power/suspend_stats/fail': '0',
            'proc/sys/kernel/random/boot_id': 'boot-a',
            'proc/swaps': 'Filename Type Size Used Priority\n/dev/zram0 partition 8192 0 100',
        }.items():
            self.write(path, value)

    def write(self, path, value):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(value)

    def test_snapshot_never_runs_commands_and_handles_missing_optional_files(self):
        with mock.patch.object(self.module.subprocess, 'run') as run:
            data = self.module.snapshot()
        run.assert_not_called()
        self.assertEqual(data['memory_sleep'], {'available': ['s2idle'], 'selected': 's2idle'})
        self.assertIsNone(data['wake_irq'])

    def test_unsupported_mode_preserves_existing_configuration(self):
        self.module.MODE_CONFIG.parent.mkdir()
        self.module.MODE_CONFIG.write_text('existing')
        with mock.patch.object(self.module.os, 'geteuid', return_value=0):
            with self.assertRaisesRegex(ValueError, 'not exposed'):
                self.module.configure_mode('deep')
        self.assertEqual(self.module.MODE_CONFIG.read_text(), 'existing')

    def test_modes_require_root_and_auto_resets_only_owned_override(self):
        with mock.patch.object(self.module.os, 'geteuid', return_value=1000):
            with self.assertRaisesRegex(ValueError, 'requires root'):
                self.module.configure_mode('s2idle')
        with mock.patch.object(self.module.os, 'geteuid', return_value=0):
            self.module.configure_mode('s2idle')
            self.assertIn('MemorySleepMode=s2idle', self.module.MODE_CONFIG.read_text())
            self.module.configure_mode('auto')
        self.assertEqual(self.module.MODE_CONFIG.read_text(), '[Sleep]\nMemorySleepMode=\n')

    def test_comparison_distinguishes_suspended_time_and_interval_drain(self):
        before = self.module.snapshot()
        before.update(boottime=100, monotonic=90)
        before['batteries'] = {'BAT0': {'capacity': '80', 'energy_now': '40000000'}}
        after = copy.deepcopy(before)
        after.update(boottime=3700, monotonic=100)
        after['stats']['success'] = '1'
        after['batteries']['BAT0'].update(capacity='78', energy_now='39000000')
        result = self.module.compare(before, after)
        self.assertEqual(result['suspended_seconds'], 3590)
        self.assertEqual(result['counter_changes']['success'], 1)
        self.assertEqual(result['battery_changes']['BAT0']['average_watts_over_interval'], 1)
        after['boot_id'] = 'another-boot'
        with self.assertRaises(ValueError):
            self.module.compare(before, after)

    def test_reversed_snapshots_are_rejected(self):
        before = self.module.snapshot()
        with self.assertRaises(ValueError):
            self.module.compare(before, before)

    def test_records_are_private_bounded_and_failed_attempts_not_called_success(self):
        with mock.patch.object(self.module.os, 'geteuid', return_value=0), \
             mock.patch.dict(self.module.os.environ, {'INVOCATION_ID': 'cycle-1', 'SERVICE_RESULT': 'exit-code'}), \
             mock.patch.object(self.module.subprocess, 'run') as run:
            for _ in range(23):
                self.module.record('pre', 'systemd-suspend.service')
                self.module.record('post', 'systemd-suspend.service')
        run.assert_not_called()
        self.assertEqual(len(list(self.module.STATE.glob('[0-9]*-*.json'))), 40)
        self.assertEqual(self.module.STATE.stat().st_mode & 0o777, 0o700)
        path = self.module.STATE / 'post.json'
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        data = json.loads(path.read_text())
        self.assertEqual(data['service_result'], 'exit-code')
        self.assertEqual(data['comparison']['counter_changes']['success'], 0)

    def test_unmatched_invocation_does_not_compare_stale_pre_record(self):
        with mock.patch.object(self.module.os, 'geteuid', return_value=0):
            with mock.patch.dict(self.module.os.environ, {'INVOCATION_ID': 'old'}):
                self.module.record('pre', 'systemd-suspend.service')
            with mock.patch.dict(self.module.os.environ, {'INVOCATION_ID': 'new'}):
                self.module.record('post', 'systemd-suspend.service')
        self.assertNotIn('comparison', json.loads((self.module.STATE / 'post.json').read_text()))

    def test_doctor_degrades_when_commands_are_unavailable(self):
        with mock.patch.object(self.module.subprocess, 'run', side_effect=FileNotFoundError('unavailable')):
            data = self.module.report()
        self.assertTrue(any('persistent swap' in item for item in data['findings']))
        self.assertTrue(any('Deep/S3 is unavailable' in item for item in data['findings']))
        self.assertIsNone(data['graphics']['exit_code'])

    def test_nvidia_notifier_path_does_not_require_legacy_services(self):
        data = self.module.snapshot()
        data.update(swap='', nvidia_parameters='UseKernelSuspendNotifiers: 1\nPreserveVideoMemoryAllocations: 1',
                    nvidia_services={'nvidia-suspend.service': {'output': 'disabled', 'error': ''}})
        notes = self.module.findings(data)
        self.assertFalse(any('inspect nvidia-suspend.service' in item for item in notes))
        data['nvidia_parameters'] = 'UseKernelSuspendNotifiers: 0\nPreserveVideoMemoryAllocations: 1'
        self.assertTrue(any('inspect nvidia-suspend.service' in item for item in self.module.findings(data)))

    def test_sleep_units_keep_collectors_best_effort(self):
        for unit in self.module.UNITS:
            source = (ROOT / 'system/systemd/system' / (unit + '.d') / '60-spectrumos-sleep.conf').read_text()
            self.assertIn('ExecStartPre=-/usr/bin/timeout 5s /usr/lib/spectrumos/spectrum-sleep record pre %n', source)
            self.assertIn('ExecStopPost=-/usr/bin/timeout 5s /usr/lib/spectrumos/spectrum-sleep record post %n', source)
            self.assertNotIn('\nExecStart=', source)


if __name__ == '__main__':
    unittest.main()
