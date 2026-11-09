import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import socket
import tempfile
import threading
import unittest
from unittest.mock import patch

loader = importlib.machinery.SourceFileLoader('magnet_adapter', str(Path(__file__).resolve().parents[1] / 'scripts/magnet-adapter'))
spec = importlib.util.spec_from_loader(loader.name, loader)
adapter = importlib.util.module_from_spec(spec)
loader.exec_module(adapter)


class MagnetAdapterTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='magnet-test-', dir='/tmp')
        self.environment = patch.dict(os.environ, {'XDG_RUNTIME_DIR': self.directory.name, 'MAGNET_DATA_DIR': '/test/magnet'})
        self.environment.start()

    def tearDown(self):
        self.environment.stop()
        self.directory.cleanup()

    def exchange(self, args, response):
        received = []
        with socket.socket(socket.AF_UNIX) as server:
            server.bind(str(adapter.socket_path()))
            server.listen(1)
            def serve():
                connection, _ = server.accept()
                with connection, connection.makefile('rb') as stream:
                    received.append(json.loads(stream.readline()))
                    connection.sendall(json.dumps(response).encode() + b'\n')
            thread = threading.Thread(target=serve)
            thread.start()
            try:
                result = adapter.main(args)
            finally:
                thread.join(timeout=5)
            return result, received

    def test_idle_does_not_start_daemon(self):
        self.assertFalse(adapter.main(['status'])['running'])
        self.assertFalse(adapter.socket_path().exists())

    def test_status_preserves_progress_and_pending_ids(self):
        rows = [{'id': 1 << 40, 'state': 'Starting', 'done': 0, 'total': 0}]
        result, received = self.exchange(['status'], {'rows': rows})
        self.assertEqual(result['rows'], rows)
        self.assertTrue(result['running'])
        self.assertEqual(received, [{'cmd': 'rows'}])

    def test_remove_always_keeps_files(self):
        result, received = self.exchange(['remove', '7'], {})
        self.assertTrue(result['ok'])
        self.assertEqual(received, [{'cmd': 'remove', 'id': 7, 'delete_files': False}])

    def test_delete_requests_file_deletion(self):
        result, received = self.exchange(['delete', '7'], {})
        self.assertTrue(result['ok'])
        self.assertEqual(received, [{'cmd': 'remove', 'id': 7, 'delete_files': True}])

    def test_pause_uses_existing_daemon(self):
        _, received = self.exchange(['toggle', '9'], {})
        self.assertEqual(received, [{'cmd': 'toggle', 'id': 9}])

    def test_daemon_error_is_reported(self):
        with self.assertRaisesRegex(ValueError, 'no such torrent'):
            self.exchange(['toggle', '9'], {'error': 'no such torrent'})

    def test_negative_id_is_rejected(self):
        with self.assertRaises(ValueError):
            adapter.main(['remove', '-1'])

    def test_search_keeps_query_as_one_argument_and_partial_sources(self):
        document = {'results': [{'name': 'Linux', 'magnet': 'magnet:?xt=urn:btih:' + 'a' * 40}],
                    'sources': [{'source': 'one', 'ok': False}, {'source': 'two', 'ok': True}]}
        query = 'Linux; $(touch /tmp/magnet-unwanted) "quoted"'
        with patch.object(adapter.shutil, 'which', return_value='/usr/bin/magnet'), patch.object(adapter.subprocess, 'run') as run:
            run.return_value.returncode = 0
            run.return_value.stdout = json.dumps(document)
            result = adapter.main(['search', query, 'other'])
            self.assertEqual(run.call_args.args[0], ['/usr/bin/magnet', 'search', '--category', 'other', query])
            self.assertEqual(result['sources'], document['sources'])
            self.assertTrue(result['ok'])

    def test_top100_and_empty_browse(self):
        for query, suffix in [('top100', ['--top']), ('', [])]:
            with self.subTest(query=query), patch.object(adapter.shutil, 'which', return_value='/usr/bin/magnet'), patch.object(adapter.subprocess, 'run') as run:
                run.return_value.returncode = 0
                run.return_value.stdout = '{"results":[],"sources":[]}'
                adapter.main(['search', query, 'all'])
                self.assertEqual(run.call_args.args[0], ['/usr/bin/magnet', 'search', '--category', 'all', *suffix])

    def test_search_rejects_bad_category_and_flag_query(self):
        with patch.object(adapter.shutil, 'which', return_value='/usr/bin/magnet'), patch.object(adapter.subprocess, 'run') as run:
            for args in (['search', 'linux', 'bad'], ['search', '--top', 'all']):
                with self.assertRaises(ValueError):
                    adapter.main(args)
            run.assert_not_called()

    def test_search_failure_does_not_become_empty_success(self):
        with patch.object(adapter.shutil, 'which', return_value='/usr/bin/magnet'), patch.object(adapter.subprocess, 'run') as run:
            run.return_value.returncode = 1
            run.return_value.stderr = 'search failed'
            with self.assertRaisesRegex(ValueError, 'search failed'):
                adapter.main(['search', 'linux', 'other'])

    def test_add_starts_daemon_and_sends_magnet_and_name(self):
        magnet = 'magnet:?xt=urn:btih:' + 'b' * 40
        with patch.object(adapter, 'ensure_daemon') as start:
            result, received = self.exchange(['add', magnet, 'Example Linux'], {'id': 1 << 40})
            start.assert_called_once()
        self.assertEqual(result['id'], 1 << 40)
        self.assertEqual(received, [{'cmd': 'add', 'magnet': magnet, 'name': 'Example Linux'}])

    def test_invalid_magnet_does_not_start_daemon(self):
        with patch.object(adapter, 'ensure_daemon') as start:
            for value in ('https://example.org', 'magnet:?xt=urn:btih:invalid'):
                with self.assertRaises(ValueError):
                    adapter.main(['add', value])
            start.assert_not_called()

    def test_daemon_started_detached_only_when_needed(self):
        with patch.object(adapter, 'request', side_effect=[FileNotFoundError(), FileNotFoundError(), {}]), patch.object(adapter.shutil, 'which', return_value='/usr/bin/magnet'), patch.object(adapter.subprocess, 'Popen') as spawn, patch.dict(os.environ, {'MAGNET_DATA_DIR': self.directory.name + '/data'}):
            adapter.ensure_daemon()
            self.assertEqual(spawn.call_args.args[0], ['/usr/bin/magnet', 'daemon'])
            self.assertTrue(spawn.call_args.kwargs['start_new_session'])
            self.assertEqual(spawn.call_args.kwargs['stdin'], adapter.subprocess.DEVNULL)

    def test_running_daemon_is_reused(self):
        with patch.object(adapter, 'request', return_value={}) as request, patch.object(adapter.subprocess, 'Popen') as spawn:
            adapter.ensure_daemon()
            request.assert_called_once_with({'cmd': 'hello'})
            spawn.assert_not_called()
