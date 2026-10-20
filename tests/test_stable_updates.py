from importlib.machinery import SourceFileLoader
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]


def load():
    loader = SourceFileLoader('stable_updates', str(ROOT/'scripts/spectrum-update-check'))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class StableUpdatesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.module = load()
        self.module.STATE = Path(self.temp.name)/'state'
        self.module.DATABASE = Path(self.temp.name)/'cache/database'
        self.packages = [{'name': 'spectrum-desktop', 'installed': '1.0.0-13', 'available': '1.0.0-14'}]

    def checked(self, packages=None, notified=True):
        with mock.patch.object(self.module, 'stable_configured', return_value=True), \
             mock.patch.object(self.module, 'available_updates', return_value=self.packages if packages is None else packages), \
             mock.patch.object(self.module, 'notify', return_value=notified) as notify:
            state = self.module.check()
        return state, notify

    def test_only_production_stable_configuration_is_eligible(self):
        for server, eligible in [('https://spectrum.gibranlp.dev/repo/stable/x86_64', True),
                                 ('https://spectrum.gibranlp.dev/repo/edge/x86_64', False),
                                 ('https://other.test/repo/stable/x86_64', False),
                                 ('http://spectrum.gibranlp.dev/repo/stable/x86_64', False),
                                 ('', False)]:
            with self.subTest(server=server), mock.patch.object(self.module, 'run', return_value=mock.Mock(returncode=0, stdout=server)):
                self.assertEqual(self.module.stable_configured(), eligible)

    def test_missing_repository_is_quiet(self):
        with mock.patch.object(self.module, 'stable_configured', return_value=False), mock.patch.object(self.module, 'available_updates') as check, mock.patch.object(self.module, 'notify') as notify:
            state = self.module.check()
        self.assertFalse(state['eligible'])
        self.assertEqual(state['packages'], [])
        check.assert_not_called()
        notify.assert_not_called()

    def test_filters_arch_and_foreign_updates_against_stable_catalog(self):
        updates = 'linux 1 -> 2\nspectrum-desktop 1.0.0-13 -> 1.0.0-14\nukvm 1 -> 3\n'
        catalog = 'spectrumos spectrum-desktop 1.0.0-14 [installed: 1.0.0-13]\nspectrumos ukvm 2\n'
        with mock.patch.object(self.module, 'run', side_effect=[mock.Mock(returncode=0, stdout=updates), mock.Mock(returncode=0, stdout=catalog)]) as run:
            self.assertEqual(self.module.available_updates(), self.packages)
            self.assertEqual(run.call_args_list[0].kwargs['env']['CHECKUPDATES_DB'], str(self.module.DATABASE))
            self.assertEqual(run.call_args_list[1].args, ('pacman', '--dbpath', str(self.module.DATABASE), '-Sl', 'spectrumos'))

    def test_checkupdates_no_update_exit_code_is_success(self):
        with mock.patch.object(self.module, 'run', return_value=mock.Mock(returncode=2, stdout='')) as run:
            self.assertEqual(self.module.available_updates(), [])
            self.assertEqual(run.call_count, 1)

    def test_failed_refresh_cannot_use_stale_repository_contents(self):
        with mock.patch.object(self.module, 'run', return_value=mock.Mock(returncode=1, stdout='spectrum-desktop 1 -> 2')) as run:
            with self.assertRaises(RuntimeError):self.module.available_updates()
            self.assertEqual(run.call_count, 1)

    def test_repository_read_failure_is_not_an_empty_success(self):
        with mock.patch.object(self.module, 'run', side_effect=[mock.Mock(returncode=0, stdout='a 1 -> 2'), mock.Mock(returncode=1)]):
            with self.assertRaises(RuntimeError):self.module.available_updates()

    def test_first_available_set_notifies_once_across_process_reloads(self):
        state, notify = self.checked()
        notify.assert_called_once_with(self.packages)
        self.assertEqual(state['error'], '')
        self.module = load()
        self.module.STATE = Path(self.temp.name)/'state'
        state, notify = self.checked()
        notify.assert_not_called()
        self.assertEqual(state['packages'], self.packages)

    def test_new_available_version_notifies_again(self):
        self.checked()
        newer = [dict(self.packages[0], available='1.0.0-15')]
        state, notify = self.checked(newer)
        notify.assert_called_once_with(newer)

    def test_failed_notification_delivery_retries_next_check(self):
        state, notify = self.checked(notified=False)
        self.assertEqual(state['last_notified'], '')
        state, notify = self.checked()
        notify.assert_called_once()

    def test_installed_updates_clear_availability_and_notification_marker(self):
        self.checked()
        state, notify = self.checked([])
        self.assertEqual(state['packages'], [])
        self.assertEqual(state['last_notified'], '')
        notify.assert_not_called()

    def test_offline_check_retains_known_state_without_renotifying(self):
        before, _ = self.checked()
        with mock.patch.object(self.module, 'stable_configured', return_value=True), mock.patch.object(self.module, 'available_updates', side_effect=RuntimeError('Offline')), mock.patch.object(self.module, 'notify') as notify:
            after = self.module.check()
        self.assertEqual(after['packages'], before['packages'])
        self.assertEqual(after['last_notified'], before['last_notified'])
        self.assertEqual(after['checked_at'], before['checked_at'])
        self.assertEqual(after['error'], 'Offline')
        notify.assert_not_called()

    def test_notification_has_open_updates_hint_and_no_blocking_wait(self):
        with mock.patch.object(self.module, 'run', return_value=mock.Mock(returncode=0)) as run:
            self.assertTrue(self.module.notify(self.packages))
        args = run.call_args.args
        self.assertIn('--hint=string:x-spectrumos-kind:stable-updates', args)
        self.assertNotIn('--wait', args)
        self.assertIn('1 SpectrumOS package update is ready.', args[-1])

    def test_saved_state_is_private_and_atomic(self):
        self.checked()
        path = self.module.STATE/'status.json'
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertFalse((self.module.STATE/'status.tmp').exists())
        self.assertEqual(json.loads(path.read_text())['packages'], self.packages)

    def test_corrupt_saved_state_recovers(self):
        self.module.STATE.mkdir()
        (self.module.STATE/'status.json').write_text('not json')
        state, notify = self.checked()
        self.assertEqual(state['packages'], self.packages)
        notify.assert_called_once()


if __name__ == '__main__':
    unittest.main()
