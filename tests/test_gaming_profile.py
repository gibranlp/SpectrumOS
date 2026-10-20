from importlib.machinery import SourceFileLoader
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]


def load():
    loader = SourceFileLoader('gaming_session', str(ROOT / 'scripts/spectrum-gaming-session'))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class GamingProfileTests(unittest.TestCase):
    def test_gaming_preserves_and_restores_monitor_preferences(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / 'spectrumos/shell.json'
            config.parent.mkdir()
            original = {'bar_profile': 'minimal', 'bar_profiles': {'DP-1': 'detailed', 'HDMI-A-1': 'multimedia'},
                        'igor_enabled': True, 'desktop_logo_enabled': True, 'widget_bounce_enabled': True}
            config.write_text(json.dumps(original))
            env = dict(os.environ, XDG_CONFIG_HOME=directory, XDG_RUNTIME_DIR=directory + "/runtime")
            for args, active in [(('set-profile', 'gaming', 'DP-1'), True), (('set-gaming', 'off'), False)]:
                subprocess.run([str(ROOT / 'scripts/spectrum-shell-layout'), *args], env=env, check=True)
                state = json.loads(config.read_text())
                self.assertEqual(state.pop('gaming_enabled'), active)
                self.assertEqual(state, original)

    def test_automatic_session_never_registers_or_changes_power(self):
        module = load()
        for previous in (True, False):
            with mock.patch.object(module, 'animation_state', return_value=previous), \
                 mock.patch.object(module, 'set_animations') as animations, \
                 mock.patch.object(module, 'run') as run, \
                 mock.patch.object(module.ctypes, 'CDLL') as library:
                session = module.AutomaticGamingSession()
                session.start()
                session.stop()
                session.stop()
                self.assertEqual(animations.call_args_list, [mock.call(False), mock.call(previous)])
                library.assert_not_called()
                run.assert_not_called()

    def test_automatic_profile_tracks_last_external_client_without_feedback(self):
        module = load()
        with tempfile.TemporaryDirectory() as directory, \
             mock.patch.object(module, 'RUNTIME', Path(directory)), \
             mock.patch.object(module, 'game_active', side_effect=[False, True, True, False]), \
             mock.patch.object(module, 'AutomaticGamingSession') as automatic, \
             mock.patch.object(module, 'GamingSession') as manual:
            controller = module.GamingController()
            automatic.return_value.stop.return_value = ''
            self.assertFalse(controller.update(False)['active'])
            self.assertTrue(controller.update(False)['automatic'])
            self.assertTrue(controller.update(False)['automatic'])
            self.assertFalse(controller.update(False)['active'])
            automatic.return_value.start.assert_called_once()
            automatic.return_value.stop.assert_called_once()
            manual.assert_not_called()

    def test_manual_and_automatic_sessions_transfer_animation_ownership(self):
        module = load()
        with tempfile.TemporaryDirectory() as directory, \
             mock.patch.object(module, 'RUNTIME', Path(directory)), \
             mock.patch.object(module, 'game_active', return_value=True), \
             mock.patch.object(module, 'AutomaticGamingSession') as automatic, \
             mock.patch.object(module, 'GamingSession') as manual:
            automatic.return_value.stop.return_value = manual.return_value.stop.return_value = ''
            controller = module.GamingController()
            self.assertTrue(controller.update(False)['automatic'])
            self.assertFalse(controller.update(True)['automatic'])
            automatic.return_value.stop.assert_called_once()
            self.assertTrue(controller.update(False)['automatic'])
            manual.return_value.stop.assert_called_once()
            controller.stop()
            self.assertEqual(automatic.return_value.stop.call_count, 2)

    def test_explicit_profile_override_lasts_until_game_exits(self):
        module = load()
        with tempfile.TemporaryDirectory() as directory, \
             mock.patch.object(module, 'RUNTIME', Path(directory)), \
             mock.patch.object(module, 'game_active', side_effect=[True, True, False, True]), \
             mock.patch.object(module, 'AutomaticGamingSession') as automatic:
            marker = Path(directory) / 'gaming-auto-suppressed'
            automatic.return_value.stop.return_value = ''
            controller = module.GamingController()
            self.assertTrue(controller.update(False)['automatic'])
            marker.touch()
            self.assertFalse(controller.update(False)['automatic'])
            self.assertFalse(controller.update(False)['automatic'])
            self.assertFalse(marker.exists())
            self.assertTrue(controller.update(False)['automatic'])

    def test_temporary_query_failure_preserves_automatic_profile(self):
        module = load()
        with tempfile.TemporaryDirectory() as directory, \
             mock.patch.object(module, 'RUNTIME', Path(directory)), \
             mock.patch.object(module, 'game_active', side_effect=[True, RuntimeError('Bus unavailable'), False]), \
             mock.patch.object(module, 'AutomaticGamingSession') as automatic:
            automatic.return_value.stop.return_value = ''
            controller = module.GamingController()
            self.assertTrue(controller.update(False)['automatic'])
            status = controller.update(False)
            self.assertTrue(status['automatic'])
            self.assertEqual(status['error'], 'Bus unavailable')
            self.assertFalse(controller.update(False)['automatic'])

    def test_automatic_shutdown_restores_animations(self):
        module = load()
        with tempfile.TemporaryDirectory() as directory, \
             mock.patch.object(module, 'RUNTIME', Path(directory)), \
             mock.patch.object(module, 'game_active', return_value=True), \
             mock.patch.object(module, 'AutomaticGamingSession') as automatic:
            automatic.return_value.stop.return_value = ''
            controller = module.GamingController()
            controller.update(False)
            self.assertEqual(controller.stop(), '')
            automatic.return_value.stop.assert_called_once()

    def test_failed_registration_restores_animation_and_power(self):
        module = load()
        library = mock.Mock()
        library.real_gamemode_request_start.return_value = -1
        with mock.patch.object(module, 'power_state', return_value={}), \
             mock.patch.object(module, 'animation_state', return_value=True), \
             mock.patch.object(module, 'set_animations') as animations, \
             mock.patch.object(module, 'run', return_value=mock.Mock(returncode=0)) as run, \
             mock.patch.object(module.ctypes, 'CDLL', return_value=library):
            session = module.GamingSession()
            with self.assertRaises(RuntimeError):
                session.start()
            self.assertEqual(animations.call_args_list, [mock.call(False), mock.call(True)])
            self.assertEqual([call.args[-1] for call in run.call_args_list], ['--game-start', '--game-end'])
            library.real_gamemode_request_end.assert_not_called()

    def test_successful_session_restores_both_prior_animation_states(self):
        for previous in (True, False):
            module = load()
            library = mock.Mock()
            library.real_gamemode_request_start.return_value = 0
            library.real_gamemode_request_end.return_value = 0
            library.real_gamemode_query_status.return_value = 2
            with mock.patch.object(module, 'power_state', return_value={}), \
             mock.patch.object(module, 'animation_state', return_value=previous), \
                 mock.patch.object(module, 'set_animations') as animations, \
                 mock.patch.object(module, 'run', return_value=mock.Mock(returncode=0)), \
                 mock.patch.object(module.ctypes, 'CDLL', return_value=library):
                session = module.GamingSession()
                session.start()
                session.stop()
                session.stop()
                self.assertEqual(animations.call_args_list, [mock.call(False), mock.call(previous)])
                library.real_gamemode_request_end.assert_called_once()

    def test_stale_game_hooks_do_not_block_performance_or_restoration(self):
        module = load()
        library = mock.Mock()
        library.real_gamemode_request_start.return_value = 0
        library.real_gamemode_request_end.return_value = 0
        library.real_gamemode_query_status.side_effect = [2, 0]
        balanced = {'available': True, 'mode': 'balanced', 'modes': ['balanced', 'performance']}
        performance = dict(balanced, mode='performance')
        with mock.patch.object(module, 'power_state', side_effect=[balanced, balanced, performance]), \
             mock.patch.object(module, 'animation_state', return_value=True), \
             mock.patch.object(module, 'set_animations'), \
             mock.patch.object(module, 'run', return_value=mock.Mock(returncode=0)) as run, \
             mock.patch.object(module.ctypes, 'CDLL', return_value=library):
            session = module.GamingSession()
            session.start()
            session.stop()
            self.assertEqual([call.args[1:] for call in run.call_args_list],
                             [('--game-start',), ('--set', 'performance'), ('--game-end',), ('--set', 'balanced')])

    def test_configuration_reload_cannot_enable_animation_during_gaming(self):
        module = load()
        session = module.GamingSession()
        session.library = mock.Mock()
        session.library.real_gamemode_query_status.return_value = 2
        with mock.patch.object(module, 'power_state', return_value={}), \
             mock.patch.object(module, 'animation_state', return_value=True), \
             mock.patch.object(module, 'set_animations') as animations:
            session.maintain()
            animations.assert_called_once_with(False)

    def test_library_failure_restores_animation_without_claiming_power(self):
        module = load()
        with mock.patch.object(module, 'power_state', return_value={}), \
             mock.patch.object(module, 'animation_state', return_value=True), \
             mock.patch.object(module, 'set_animations') as animations, \
             mock.patch.object(module, 'run') as run, \
             mock.patch.object(module.ctypes, 'CDLL', side_effect=OSError('GameMode is unavailable')):
            with self.assertRaises(OSError):
                module.GamingSession().start()
            self.assertEqual(animations.call_args_list, [mock.call(False), mock.call(True)])
            run.assert_not_called()
