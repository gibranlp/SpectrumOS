import importlib.machinery
import importlib.util
import json
import os
import shlex
import select
from pathlib import Path
import subprocess
import tempfile
import socket
import threading
import time
import unittest
from unittest.mock import patch
from unittest.mock import Mock

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    loader = importlib.machinery.SourceFileLoader(name.replace('-', '_'), str(ROOT/'scripts'/name))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class AppStoreTests(unittest.TestCase):
    def setUp(self):
        self.backend = load('app-store-adapter')
        self.privileged = load('app-store-privileged')

    def test_package_and_flatpak_identities_reject_options_and_paths(self):
        for name in ('--root=/tmp', '../fixture', 'pkg;touch /tmp/bad', 'a\nb', ''):
            with self.assertRaises(ValueError):
                self.backend.validate_target(dict(source='aur', name=name))
        for ref in ('org.example.App', 'app/org.example.App/x86_64/../../bad', '--command=sh'):
            with self.assertRaises(ValueError):
                self.backend.validate_target(dict(source='flatpak', ref=ref, scope='user', remote='flathub'))

    def test_install_opens_independent_terminal_and_logs_only_output(self):
        with tempfile.TemporaryDirectory() as temporary, patch.dict(os.environ, {'XDG_STATE_HOME':temporary}):
            def launch(argv, **kwargs):
                self.assertEqual(argv[:4], ['uwsm', 'app', '--', '/usr/bin/env'])
                self.assertEqual(argv[7], '--hold')
                self.assertIn('--log-out', argv)
                self.assertNotIn('--log-in', argv)
                self.assertNotIn('--log-io', argv)
                command = shlex.split(argv[-1])
                self.assertEqual(command[1], 'terminal')
                path = self.backend.job_path(command[2])
                self.assertEqual((path/'terminal.log').stat().st_mode & 0o777, 0o600)
                self.backend.atomic(path/'status.json', dict(active=False))
                return Mock()
            with patch.object(self.backend.subprocess, 'Popen', side_effect=launch) as launched:
                result = self.backend.start(dict(source='pacman', repository='extra', name='fixture'))
            self.assertTrue(result['ok'])
            launched.assert_called_once()

    def test_terminal_install_inherits_input_and_uses_terminal_sudo(self):
        with tempfile.TemporaryDirectory() as temporary, patch.dict(os.environ, {'XDG_STATE_HOME':temporary}):
            path = self.backend.job_path('e'*32)
            self.backend.atomic(path/'request.json', dict(source='pacman', repository='extra', name='fixture'))
            job = self.backend.TerminalJob('e'*32)
            with patch.object(self.backend.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)) as execute:
                code = job.command(['pkexec', '--disable-internal-agent', '/usr/lib/spectrumos/app-store-privileged', 'official', 'extra/fixture'])
            self.assertEqual(code, 0)
            self.assertEqual(execute.call_args.args[0], ['sudo', '/usr/lib/spectrumos/app-store-privileged', 'terminal-official', 'extra/fixture'])
            self.assertNotIn('stdin', execute.call_args.kwargs)
            self.assertNotIn('stdout', execute.call_args.kwargs)
            self.assertTrue(job.state['systemChanged'])

    def test_system_flatpak_password_is_requested_in_terminal(self):
        with tempfile.TemporaryDirectory() as temporary, patch.dict(os.environ, {'XDG_STATE_HOME':temporary}):
            path = self.backend.job_path('f'*32)
            target = dict(source='flatpak', remote='flathub', scope='system', ref='app/org.example.App/x86_64/stable')
            self.backend.atomic(path/'request.json', target)
            job = self.backend.TerminalJob('f'*32)
            with patch.object(self.backend.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)) as execute:
                job.command(['flatpak', 'install', '--system', '--', 'flathub', target['ref']])
            self.assertEqual(execute.call_args.args[0][:4], ['sudo', '/usr/bin/flatpak', 'install', '--system'])

    def test_terminal_official_keeps_full_upgrade_preflight_and_migrations(self):
        with tempfile.TemporaryFile() as stream:
            descriptor = os.dup(stream.fileno())
            with patch.object(self.privileged.os, 'geteuid', return_value=0), \
                 patch.object(self.privileged.os, 'open', return_value=descriptor), \
                 patch.object(self.privileged.os, 'fstat', return_value=Mock(st_uid=0)), \
                 patch.object(self.privileged.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)) as execute:
                self.assertEqual(self.privileged.execute(['terminal-official', 'extra/fixture']), 0)
            commands = [call.args[0] for call in execute.call_args_list]
            self.assertEqual(commands[0], ['/usr/bin/spectrum', 'update', 'plan'])
            self.assertEqual(commands[1][0:2], ['/usr/bin/pacman', '-Syu'])
            self.assertEqual(commands[1][-2:], ['--', 'extra/fixture'])
            self.assertEqual(commands[2], ['/usr/bin/spectrum', 'migrate', 'apply'])

    def test_terminal_paru_uses_native_sudo_and_review(self):
        with tempfile.TemporaryDirectory() as temporary, patch.dict(os.environ, {'XDG_STATE_HOME':temporary, 'PARU_CONF':'/usr/share/spectrumos/app-store/paru.conf'}):
            path = self.backend.job_path('e'*32)
            self.backend.atomic(path/'request.json', dict(source='aur', name='fixture'))
            job = self.backend.TerminalJob('e'*32)
            with patch.object(self.backend.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)) as execute:
                job.command(['paru', '-S', '--review', '--', 'aur/fixture'])
            self.assertEqual(execute.call_args.args[0], ['paru', '-S', '--review', '--sudo', '/usr/bin/sudo', '--sudoflags', '', '--', 'aur/fixture'])
            self.assertNotIn('PARU_CONF', execute.call_args.kwargs['env'])

    def test_terminal_activity_reads_recent_transcript(self):
        with tempfile.TemporaryDirectory() as temporary, patch.dict(os.environ, {'XDG_STATE_HOME':temporary}):
            path = self.backend.job_path('a'*32)
            self.backend.atomic(path/'status.json', dict(mode='terminal', active=False, phase='complete', log='old'))
            (path/'terminal.log').write_text('new terminal output\n')
            self.assertEqual(self.backend.jobs()[0]['log'], 'new terminal output\n')

    def test_terminal_transcript_does_not_record_hidden_password_input(self):
        import pty
        with tempfile.TemporaryDirectory() as temporary:
            transcript = Path(temporary)/'terminal.log'
            master, slave = pty.openpty()
            command = shlex.join(['/usr/bin/python3', '-c', 'import getpass; value=getpass.getpass("Password: "); print("Received",len(value))'])
            process = subprocess.Popen(['/usr/bin/script', '--quiet', '--return', '--flush', '--log-out', str(transcript), '--command', command],
                                       stdin=slave, stdout=slave, stderr=slave)
            os.close(slave)
            output = b''
            try:
                deadline = time.monotonic()+5
                while b'Password:' not in output and time.monotonic()<deadline:
                    if select.select([master], [], [], .1)[0]:
                        output += os.read(master, 4096)
                self.assertIn(b'Password:', output)
                os.write(master, b'test-only-hidden-input\n')
                self.assertEqual(process.wait(timeout=5), 0)
                recorded = transcript.read_text()
                self.assertIn('Received 22', recorded)
                self.assertNotIn('test-only-hidden-input', recorded)
            finally:
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=5)
                os.close(master)

    def test_privileged_bridge_restores_confirmation_and_full_upgrade(self):
        args = self.privileged.bridge_arguments(['-S', '--noconfirm', '--asdeps', '--', 'extra/fixture'])
        self.assertEqual(args[0], '-Syu')
        self.assertIn('--confirm', args)
        self.assertNotIn('--noconfirm', args)
        self.assertEqual(args[-1], 'extra/fixture')

    def test_privileged_bridge_rejects_arbitrary_root_options(self):
        for args in (['-R', 'fixture'], ['-S', '--root', '/tmp', 'fixture'],
                     ['-S', '--config', '/tmp/pacman.conf', 'fixture'],
                     ['-S', '--ask=4', 'fixture'], ['-S', '--overwrite=*', 'fixture'],
                     ['-S', '--', '--bad'], ['-S', '-U', 'fixture']):
            with self.assertRaises(ValueError, msg=str(args)):
                self.privileged.bridge_arguments(args)

    def test_local_package_archives_must_exist_and_be_absolute(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/'fixture.pkg.tar.zst'
            path.write_bytes(b'fixture')
            self.assertEqual(self.privileged.bridge_arguments(['-U', str(path)])[-1], str(path))
            for value in ('https://example.com/package.pkg.tar.zst', 'relative.pkg.tar.zst', '/bin/sh'):
                with self.assertRaises(ValueError):
                    self.privileged.bridge_arguments(['-U', value])

    def test_search_failure_is_isolated_and_exact_match_ranks_first(self):
        rows = [dict(source='pacman', repository='extra', name=name, title=name, installed=False)
                for name in ('fixture-extension', 'fixture')]
        with patch.object(self.backend.shutil, 'which', return_value='/usr/bin/tool'), \
             patch.object(self.backend, 'official_search', return_value=rows), \
             patch.object(self.backend, 'aur_search', side_effect=RuntimeError('offline')), \
             patch.object(self.backend, 'flatpak_search', return_value=[]):
            result = self.backend.search(dict(query='fixture'))
        self.assertEqual(result['results'][0]['name'], 'fixture')
        self.assertEqual(result['warnings'], ['AUR: offline'])

    def test_flatpak_scopes_have_distinct_result_identities(self):
        rows = [dict(source='flatpak', scope=scope, remote='flathub', ref='app/org.example.App/x86_64/stable',
                     name='org.example.App', title='Fixture', installed=False) for scope in ('system', 'user')]
        with patch.object(self.backend.shutil, 'which', return_value='/usr/bin/tool'), \
             patch.object(self.backend, 'flatpak_search', return_value=rows):
            result = self.backend.search(dict(query='Fixture', source='flatpak'))
        self.assertEqual(result['results'][0]['scope'], 'user')
        self.assertEqual(len({row['key'] for row in result['results']}), 2)

    def test_flatpak_installed_state_must_match_the_remote(self):
        ref = Mock()
        ref.format_ref.return_value = 'app/org.example.App/x86_64/stable'
        ref.get_origin.return_value = 'first-remote'
        installation = Mock()
        installation.list_installed_refs.return_value = [ref]
        output = 'org.example.App\tFixture\tDescription\t1\tstable\tfirst-remote,second-remote\n'
        with patch.object(self.backend, 'installations', return_value=[('user', installation)]), \
             patch.object(self.backend, 'run', return_value=output):
            rows = self.backend.flatpak_search('Fixture')
        self.assertTrue(rows[0]['installed'])
        self.assertFalse(rows[1]['installed'])

    def test_search_is_read_only_and_escapes_regular_expressions(self):
        output = 'extra/fixture 1.0\n    A graphical app\n'
        result = subprocess.CompletedProcess([], 0, output, '')
        with patch.object(self.backend, 'installed_packages', return_value={}), \
             patch.object(self.backend.subprocess, 'run', return_value=result) as run:
            rows = self.backend.official_search('fixture.*')
        self.assertEqual(run.call_args.args[0], ['pacman', '-Ss', '--', r'fixture\.\*'])
        self.assertEqual(rows[0]['repository'], 'extra')

    def test_prompt_adapter_never_invents_an_answer(self):
        self.assertEqual(self.backend.question('Proceed with installation? [Y/n] ')['kind'], 'confirm')
        self.assertEqual(self.backend.question('Enter a number (default=1): ')['kind'], 'selection')
        self.assertIsNone(self.backend.question('Executing post-transaction hooks…\n'))
        self.assertIsNone(self.backend.question('Unknown prompt: '))

    def test_review_reads_symlinked_paru_view_without_executing_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            actual = folder/'actual'; actual.mkdir()
            (actual/'PKGBUILD').write_text('pkgname=fixture\nexit 99\n')
            view = folder/'view'; view.mkdir()
            (view/'fixture').symlink_to(actual, target_is_directory=True)
            text = self.backend.review_files(view)
            self.assertIn('fixture/PKGBUILD', text)
            self.assertIn('exit 99', text)
            (actual/'oversized').write_bytes(b'x'*700_001)
            with self.assertRaises(ValueError):
                self.backend.review_files(view)

    def test_paru_review_excludes_cached_untracked_build_outputs(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            subprocess.run(['git', 'init', '-q', str(folder)], check=True)
            (folder/'PKGBUILD').write_text('pkgname=fixture\n')
            subprocess.run(['git', '-C', str(folder), 'add', 'PKGBUILD'], check=True)
            (folder/'cached-source.tar.gz').write_bytes(b'x'*800_000)
            self.assertIn('pkgname=fixture', self.backend.review_files(folder))
            self.assertNotIn('cached-source', self.backend.review_files(folder))

    def test_job_question_requires_matching_token_and_survives_new_reader(self):
        with tempfile.TemporaryDirectory() as temporary, patch.dict(os.environ, {'XDG_STATE_HOME':temporary, 'XDG_RUNTIME_DIR':str(Path(temporary)/'runtime')}):
            job_id = 'a'*32
            path = self.backend.job_path(job_id)
            self.backend.atomic(path/'request.json', dict(source='aur', name='fixture'))
            job = self.backend.Job(job_id)
            server = socket.socket(socket.AF_UNIX)
            server.bind(str(self.backend.socket_path(job_id))); server.listen(4)
            threading.Thread(target=job.serve, args=(server,), daemon=True).start()
            result = []
            thread = threading.Thread(target=lambda:result.append(job.command([
                '/usr/bin/python3', '-c', 'import sys; print("Package list: fixture",flush=True); answer=input("Proceed with installation? [Y/n] "); sys.exit(0 if answer=="y" else 1)'])))
            thread.start()
            deadline = time.monotonic()+5
            while not job.state.get('prompt') and time.monotonic()<deadline:
                time.sleep(.05)
            self.assertIsNotNone(job.state['prompt'])
            snapshot = self.backend.jobs()[0]
            self.assertIn('Package list', snapshot['log'])
            self.assertEqual(snapshot['prompt']['kind'], 'confirm')
            self.assertTrue(thread.is_alive())
            stale = self.backend.request(job_id, dict(action='answer', token='old-token', answer='y'))
            self.assertFalse(stale['ok'])
            self.assertIsNotNone(job.state['prompt'])
            accepted = self.backend.request(job_id, dict(action='answer', token=snapshot['prompt']['token'], answer='y'))
            self.assertTrue(accepted['ok'])
            thread.join(5)
            self.assertEqual(result, [0])
            job.save(active=False)
            server.close()

    def test_stale_process_is_reported_as_interrupted_not_replayed(self):
        with tempfile.TemporaryDirectory() as temporary, patch.dict(os.environ, {'XDG_STATE_HOME':temporary}):
            path = self.backend.job_path('b'*32)
            self.backend.atomic(path/'status.json', dict(active=True, pid=99999999, processStart='0', prompt={'text':'old'}))
            result = self.backend.jobs()[0]
            self.assertFalse(result['active'])
            self.assertEqual(result['phase'], 'interrupted')
            self.assertIsNone(result['prompt'])

    def test_long_state_path_does_not_lengthen_the_private_socket(self):
        with tempfile.TemporaryDirectory() as temporary:
            runtime = Path(temporary)/'runtime'
            state = Path(temporary)/('long-state-directory-'*8)
            with patch.dict(os.environ, {'XDG_STATE_HOME':str(state), 'XDG_RUNTIME_DIR':str(runtime)}):
                self.assertGreater(len(str(self.backend.job_path('c'*32))), 108)
                self.assertLess(len(str(self.backend.socket_path('c'*32))), 108)

    def test_socket_startup_failure_is_persisted_as_failed(self):
        with tempfile.TemporaryDirectory() as temporary, patch.dict(os.environ, {'XDG_STATE_HOME':temporary}):
            path = self.backend.job_path('d'*32)
            self.backend.atomic(path/'request.json', dict(source='aur', name='fixture'))
            job = self.backend.Job('d'*32)
            with patch.object(self.backend, 'socket_path', side_effect=ValueError('private runtime unavailable')):
                job.execute()
            self.assertFalse(job.state['active'])
            self.assertEqual(job.state['phase'], 'failed')
            self.assertIn('private runtime unavailable', job.state['message'])

    def test_new_shortcut_matches_the_wrapper_and_desktop_entry(self):
        bindings = (ROOT/'configs/hyprland/keybindings.lua').read_text()
        shortcuts = (ROOT/'configs/spectrum-shell/UtilityPanel.qml').read_text()
        self.assertIn('" + SHIFT + U", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open app-store")', bindings)
        self.assertIn('combo: "Super + Shift + U", action: qsTranslate("Spectrum", "App Store")', shortcuts)
        self.assertIn('app-store) method=toggleAppStore;', (ROOT/'scripts/spectrum-shell-open').read_text())


if __name__ == '__main__':
    unittest.main()
