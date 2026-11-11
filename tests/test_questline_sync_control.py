import importlib.machinery
import importlib.util
import io
import json
from pathlib import Path
import unittest
from unittest.mock import MagicMock, patch


ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('questline_sync_control', str(ROOT / 'scripts/questline-sync-control'))
spec = importlib.util.spec_from_loader(loader.name, loader)
control = importlib.util.module_from_spec(spec)
loader.exec_module(control)


class SyncProgressTests(unittest.TestCase):
    def run_operation(self, request, responses, decision=None):
        process = MagicMock()
        process.stdout = io.StringIO(''.join(json.dumps(item) + '\n' for item in responses))
        process.wait.return_value = 0
        process.poll.return_value = 0
        output = io.StringIO()
        requests = [request] + ([decision] if decision is not None else [])
        with patch.object(control, 'read_request', side_effect=requests), \
             patch.object(control.Path, 'is_file', return_value=True), \
             patch.object(control.os, 'access', return_value=True), \
             patch.object(control.subprocess, 'run', return_value=type('Help', (), {'returncode': 0, 'stdout': 'sync-json'})()), \
             patch.object(control.subprocess, 'Popen', return_value=process), \
             patch.object(control, 'preserve_drafts') as drafts, \
             patch.object(control.sys, 'stdout', output):
            control.main()
        return [json.loads(line) for line in output.getvalue().splitlines()], process, drafts

    def test_backup_emits_progress_before_result(self):
        result = {'ok': True, 'message': 'Backup created', 'path': '/tmp/backup.db'}
        events, _, drafts = self.run_operation({'action': 'backup'}, [result])
        self.assertEqual(events[0]['phase'], 'progress')
        self.assertIn('backup', events[0]['message'])
        self.assertEqual(events[-1], result)
        drafts.assert_not_called()

    def test_restore_confirmation_preserves_preview_and_decision(self):
        preview = {'phase': 'preview', 'token': 'confirm-token', 'incoming': {'name': 'Hero'}}
        result = {'ok': True, 'profile_replaced': True}
        events, process, drafts = self.run_operation(
            {'action': 'restore_cloud'}, [preview, result], {'confirm': 'confirm-token'})
        self.assertEqual([item.get('phase') for item in events], ['progress', 'preview', 'progress', None])
        self.assertEqual(events[1], preview)
        self.assertIn('applying', events[2]['message'])
        drafts.assert_called_once()
        self.assertEqual(json.loads(process.stdin.write.call_args_list[-1].args[0]), {'confirm': 'confirm-token'})

    def test_cancel_does_not_archive_or_apply(self):
        events, process, drafts = self.run_operation(
            {'action': 'restore_backup', 'path': '/tmp/saved.json'},
            [{'phase': 'preview', 'token': 'confirm-token'}, {'ok': True, 'cancelled': True}],
            {'cancel': True})
        self.assertIn('Canceling', events[-2]['message'])
        self.assertTrue(events[-1]['cancelled'])
        self.assertEqual(json.loads(process.stdin.write.call_args_list[-1].args[0]), {'cancel': True})
        drafts.assert_not_called()

    def test_error_remains_terminal_after_progress(self):
        result = {'ok': False, 'error': 'Could not download backup'}
        events, _, _ = self.run_operation({'action': 'restore_cloud'}, [result])
        self.assertEqual(events[0]['phase'], 'progress')
        self.assertEqual(events[-1], result)


if __name__ == '__main__':
    unittest.main()
