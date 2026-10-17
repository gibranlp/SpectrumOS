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
            env = dict(os.environ, XDG_CONFIG_HOME=directory)
            for args, active in [(('set-profile', 'gaming', 'DP-1'), True), (('set-gaming', 'off'), False)]:
                subprocess.run([str(ROOT / 'scripts/spectrum-shell-layout'), *args], env=env, check=True)
                state = json.loads(config.read_text())
                self.assertEqual(state.pop('gaming_enabled'), active)
                self.assertEqual(state, original)

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
