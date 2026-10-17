import contextlib
import json
import os
from pathlib import Path
import runpy
import signal
import subprocess
import sys
import time
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
MODULE = runpy.run_path(str(ROOT / 'scripts/spectrumdrop-adapter'))
G = MODULE['action'].__globals__
ADDRESS = '02:11:22:33:44:55'


class SpectrumDropTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.environment = patch.dict(os.environ, XDG_RUNTIME_DIR=self.tmp.name)
        self.environment.start()

    def tearDown(self):
        self.environment.stop()
        self.tmp.cleanup()

    def test_missing_backend_is_reported_without_starting_anything(self):
        with patch.dict(G, CLI=str(Path(self.tmp.name) / 'missing')):
            state = MODULE['status']()
        self.assertFalse(state['available'])
        self.assertFalse(state['receiving'])

    def test_peer_validation_rejects_option_or_command_injection(self):
        for value in ('--help', '$(touch /tmp/unexpected)', ADDRESS + '; true', 'Mac'):
            with self.assertRaises(ValueError):
                MODULE['peer'](value)
        self.assertEqual(MODULE['peer'](ADDRESS.upper()), ADDRESS)

    def test_peer_normalization_deduplicates_and_bounds_device_names(self):
        rows = [{'mac': ADDRESS, 'name': '<b>' + 'x' * 500}, {'mac': ADDRESS, 'name': 'Mac'},
                {'mac': 'invalid'}, None]
        self.assertEqual(MODULE['normalize_peers'](rows), [dict(mac=ADDRESS, name='Mac', rssi=None)])

    def test_private_atomic_state(self):
        MODULE['write_state']('transfer', dict(active=False, phase='complete'))
        self.assertEqual(MODULE['read_state']('transfer')['phase'], 'complete')
        self.assertEqual((MODULE['runtime']().stat().st_mode & 0o777), 0o700)
        self.assertEqual(((MODULE['runtime']() / 'transfer.json').stat().st_mode & 0o777), 0o600)

    def test_large_state_is_not_loaded(self):
        (MODULE['runtime']() / 'transfer.json').write_text(' ' * 10000)
        self.assertEqual(MODULE['read_state']('transfer'), {})

    def test_invalid_receive_duration_does_not_start_radio(self):
        with patch.dict(G, run=lambda *a, **k: self.fail('No command should run')):
            with self.assertRaises(ValueError):
                MODULE['receiving']('0')

    def test_failed_start_cleans_up_and_restores_disabled_wifi(self):
        commands = []
        def fake(args, **options):
            commands.append(args)
            if args[-1] == 'radio':
                return 'disabled\n', 0
            if 'on' in args and args[0] == G['CLI']:
                raise ValueError('Radio failed')
            return '', 0
        with patch.dict(G, run=fake, notify=lambda *a: None):
            with self.assertRaisesRegex(ValueError, 'Radio failed'):
                MODULE['receiving']('5')
        self.assertIn([G['CLI'], 'off', '--force'], commands)
        self.assertIn(['nmcli', 'radio', 'wifi', 'off'], commands)
        self.assertEqual(MODULE['read_state']('radio'), {})

    def test_send_requires_live_discovery(self):
        with patch.dict(G, status=lambda: dict(visible=False)):
            with self.assertRaisesRegex(ValueError, 'Enable receiving'):
                MODULE['send'](ADDRESS)

    def test_concurrent_send_is_rejected(self):
        with patch.dict(G, status=lambda: dict(visible=True), run=lambda *a, **k: ('active', 0)):
            with self.assertRaisesRegex(ValueError, 'already running'):
                MODULE['send'](ADDRESS)

    def test_stop_refuses_to_interrupt_active_transfer(self):
        MODULE['write_state']('transfer', dict(active=True))
        with self.assertRaisesRegex(ValueError, 'Cancel the send'):
            MODULE['action'](['stop'])

    def run_worker(self, body):
        script = Path(self.tmp.name) / 'fake-spectrumdrop'
        script.write_text('#!/bin/sh\n' + body)
        script.chmod(0o755)
        with patch.dict(G, CLI=str(script), notify=lambda *a: None), \
             patch('signal.signal'):
            MODULE['worker'](ADDRESS)
        return MODULE['read_state']('transfer')

    def test_worker_success_has_completed_status(self):
        state = self.run_worker("echo 'Preparing test image...'\nexit 0\n")
        self.assertFalse(state['active'])
        self.assertEqual(state['phase'], 'complete')

    def test_worker_failure_does_not_claim_delivery(self):
        state = self.run_worker("echo 'Recipient refused'\nexit 2\n")
        self.assertFalse(state['active'])
        self.assertEqual(state['phase'], 'failed')
        self.assertEqual(state['message'], 'Send failed: Recipient refused')

    def test_chooser_cancel_is_not_a_failed_send(self):
        self.assertEqual(self.run_worker('exit 1\n')['phase'], 'cancelled')

    def test_unreachable_recipient_is_an_explicit_failure(self):
        state = self.run_worker("echo 'Using self-signed certificates. Peers must be in Everyone mode.'\nexit 2\n")
        self.assertEqual(state['phase'], 'failed')
        self.assertIn('Send failed:', state['message'])
        self.assertIn('If Everyone is already enabled', state['message'])

    def test_sender_error_without_output_is_not_chooser_cancellation(self):
        state = self.run_worker('exit 2\n')
        self.assertEqual(state['phase'], 'failed')
        self.assertIn('Send failed:', state['message'])

    def test_cancelling_scan_stops_its_child_process(self):
        directory = Path(self.tmp.name)
        ready, stopped = directory / 'ready', directory / 'stopped'
        child = directory / 'child.py'
        child.write_text("import signal,time,sys\nfrom pathlib import Path\n"
                         + "def stop(*args):\n    Path(" + repr(str(stopped)) + ").write_text('stopped'); sys.exit(0)\n"
                         + "signal.signal(signal.SIGTERM,stop)\nPath(" + repr(str(ready)) + ").touch()\ntime.sleep(10)\n")
        code = "import runpy,sys; runpy.run_path(sys.argv[1])['run']([sys.executable,sys.argv[2]],timeout=10)"
        process = subprocess.Popen([sys.executable, '-c', code, str(ROOT / 'scripts/spectrumdrop-adapter'), str(child)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            deadline = time.monotonic() + 3
            while not ready.exists() and time.monotonic() < deadline:
                time.sleep(.01)
            self.assertTrue(ready.exists())
            process.send_signal(signal.SIGTERM)
            process.communicate(timeout=3)
            self.assertEqual(process.returncode, 143)
            self.assertTrue(stopped.exists())
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()

    def test_unknown_action_and_extra_arguments_rejected(self):
        for args in (['run', 'anything'], ['status', 'unexpected'], ['stop', '--force']):
            with self.assertRaises(ValueError):
                MODULE['action'](args)
