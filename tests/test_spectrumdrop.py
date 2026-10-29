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
        self.lan_environment = patch.dict(G, LAN=str(Path(self.tmp.name) / 'missing-lan'))
        self.lan_environment.start()

    def tearDown(self):
        self.lan_environment.stop()
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

    def test_network_send_keeps_access_code_out_of_process_arguments(self):
        identifier='a'*32
        MODULE['write_state']('lan-peers',{'peers':[{'mac':'lan:'+identifier,'id':identifier,'name':'Spectrum','addresses':['127.0.0.1'],'port':8857,'fingerprint':'b'*64}]})
        commands=[]
        def fake(args,**options):
            commands.append(args)
            return ('inactive',1) if 'is-active' in args else ('',0)
        with patch.dict(G,run=fake,status=lambda *args: {'ok':True}):
            MODULE['send_lan']('lan:'+identifier,{'code':'ABCD-EFGH-JKLM-NPQR'})
        self.assertTrue(any('worker-lan' in command for command in commands))
        self.assertFalse(any('ABCD' in part for command in commands for part in command))
        jobs=list(MODULE['runtime']().glob('lan-job-*.json'))
        self.assertEqual(len(jobs),1)
        self.assertEqual(jobs[0].stat().st_mode & 0o777,0o600)
        self.assertEqual(json.loads(jobs[0].read_text())['code'],'ABCD-EFGH-JKLM-NPQR')

    def test_paired_send_uses_saved_pc_without_code_or_discovery(self):
        identifier='d'*32
        saved={'id':identifier,'name':'Saved PC','addresses':['127.0.0.1'],'port':8857,'fingerprint':'b'*64}
        commands=[]
        def run(command, **kwargs):
            commands.append(command)
            return ('inactive',3) if command[:3]==['systemctl','--user','is-active'] else ('',0)
        with patch.dict(G,run=run,lan_status=lambda:{'paired':[saved]},status=lambda *args:{'ok':True}):
            MODULE['send_lan']('lan:'+identifier,{})
        job=json.loads(next(MODULE['runtime']().glob('lan-job-*.json')).read_text())
        self.assertEqual(job['code'],'');self.assertEqual(job['peer']['fingerprint'],'b'*64)
        self.assertTrue(any('worker-lan' in command for command in commands))

    def test_pairing_preserves_selected_files_and_requires_a_code(self):
        identifier='d'*32
        MODULE['write_state']('lan-peers',{'peers':[{'mac':'lan:'+identifier,'id':identifier,'name':'PC','addresses':['127.0.0.1'],'port':8857}]})
        MODULE['write_state']('selection',{'paths':['keep-selection']})
        def run(command, **kwargs):
            return ('inactive',3) if command[:3]==['systemctl','--user','is-active'] else ('',0)
        with patch.dict(G,run=run,status=lambda *args:{'ok':True}):
            with self.assertRaises(ValueError):
                MODULE['send_lan']('lan:'+identifier,{},pair=True)
            MODULE['send_lan']('lan:'+identifier,{'code':'ABCD-EFGH-JKLM-NPQR'},pair=True)
        job=json.loads(next(MODULE['runtime']().glob('lan-job-*.json')).read_text())
        self.assertTrue(job['pair']);self.assertNotIn('paths',job)
        self.assertTrue((MODULE['runtime']()/'selection.json').exists())

    def test_paired_discovery_identity_change_does_not_queue_a_send(self):
        identifier='d'*32
        MODULE['write_state']('lan-peers',{'peers':[{'mac':'lan:'+identifier,'id':identifier,'fingerprint':'c'*64}]})
        with patch.dict(G,lan_status=lambda:{'paired':[{'id':identifier,'fingerprint':'b'*64}]}):
            with self.assertRaisesRegex(ValueError,'identity changed'):
                MODULE['send_lan']('lan:'+identifier,{})
        self.assertEqual(list(MODULE['runtime']().glob('lan-job-*.json')),[])

    def test_network_actions_do_not_toggle_or_require_wifi_radio(self):
        calls=[]
        with patch.dict(G,lan_command=lambda *args,**kwargs:calls.append(args) or {'ok':True},status=lambda *args:{'ok':True},run=lambda *args,**kwargs:self.fail('No radio or external process should run')):
            MODULE['action'](['receive-lan','5'])
            MODULE['action'](['stop-lan'])
        self.assertEqual(calls,[('receive','5'),('stop',)])

    def test_network_status_does_not_query_the_apple_backend(self):
        with patch.dict(G,CLI='/missing-apple-cli',LAN=__file__,lan_status=lambda:{'available':True,'receiving':False},run=lambda *args,**kwargs:self.fail('No Apple backend or radio process should run')):
            value=MODULE['status']('lan')
        self.assertTrue(value['available']);self.assertTrue(value['lan']['available'])

    def test_unknown_action_and_extra_arguments_rejected(self):
        for args in (['run', 'anything'], ['status', 'unexpected'], ['stop', '--force']):
            with self.assertRaises(ValueError):
                MODULE['action'](args)

    def selected_fixture(self):
        source=Path(self.tmp.name)/"file ' $().txt"
        source.write_text('temporary selected file')
        return source

    def test_thunar_selection_prepares_private_paths_without_any_network_or_service(self):
        source=self.selected_fixture()
        with patch.dict(G,run=lambda *a,**k:self.fail('Preparing must not launch a process')):
            value=MODULE['action'](['prepare-selection'],{'paths':[str(source)]})
        self.assertTrue(value['ok']);self.assertEqual(value['selection']['count'],1)
        self.assertEqual(MODULE['selection']()['paths'],[str(source)])
        self.assertFalse(MODULE['read_state']('transfer').get('active'))
        self.assertEqual((MODULE['runtime']()/'selection.json').stat().st_mode & 0o777,0o600)

    def test_selection_rejects_missing_relative_directory_symlink_and_excessive_paths(self):
        source=self.selected_fixture();link=source.with_name('link');link.symlink_to(source)
        for values in ([],['relative'],[self.tmp.name],[str(link)],[str(source)+'missing'],[str(source)]*129):
            with self.subTest(values=values[:2]),self.assertRaises(ValueError):MODULE['selected_files'](values)

    def test_expired_selection_is_not_used(self):
        source=self.selected_fixture()
        MODULE['write_state']('selection',{'paths':[str(source)],'expires':time.time()-1})
        self.assertEqual(MODULE['selection_summary']()['count'],0)

    def test_lan_send_copies_selection_into_private_job_and_does_not_repeat_picker(self):
        source=self.selected_fixture();MODULE['prepare_selection']({'paths':[str(source)]})
        identifier='a'*32;MODULE['write_state']('lan-peers',{'peers':[{'mac':'lan:'+identifier,'name':'Other PC','addresses':['127.0.0.1'],'port':8857}]})
        commands=[]
        with patch.dict(G,run=lambda args,**kwargs:commands.append(args) or ('',3 if 'is-active' in args else 0),status=lambda *args:{'ok':True}):
            MODULE['send_lan']('lan:'+identifier,{'code':'ABCDEFGHIJKLMNOP'})
        job=next(MODULE['runtime']().glob('lan-job-*.json'))
        self.assertEqual(json.loads(job.read_text())['paths'],[str(source)])
        self.assertEqual(MODULE['selection'](),{})
        self.assertTrue(any('worker-lan' in command for command in commands))

    def test_apple_worker_uses_explicit_files_without_file_picker(self):
        source=self.selected_fixture();job='b'*32
        MODULE['write_state']('apple-job-'+job,{'paths':[str(source)]})
        record=Path(self.tmp.name)/'arguments.json';script=Path(self.tmp.name)/'fake-apple'
        script.write_text('#!/usr/bin/python\nimport json,sys\nfrom pathlib import Path\nPath('+repr(str(record))+').write_text(json.dumps(sys.argv))\nprint("Sent temporary fixture")\n')
        script.chmod(0o755)
        with patch.dict(G,CLI=str(script),notify=lambda *a:None),patch('signal.signal'):
            MODULE['worker'](ADDRESS,job)
        args=json.loads(record.read_text())
        self.assertNotIn('--pick',args);self.assertEqual(args[-2:],['--',str(source)])
        self.assertEqual(MODULE['read_state']('transfer')['phase'],'complete')

    def test_missing_selected_file_does_not_mark_a_transfer_active(self):
        source=self.selected_fixture();MODULE['prepare_selection']({'paths':[str(source)]});source.unlink()
        with patch.dict(G,status=lambda *args:{'visible':True},run=lambda *args,**kwargs:('',3)):
            with self.assertRaises(ValueError):MODULE['send'](ADDRESS)
        self.assertFalse(MODULE['read_state']('transfer').get('active'))

    def test_launch_failure_preserves_selection_for_retry(self):
        source=self.selected_fixture();MODULE['prepare_selection']({'paths':[str(source)]})
        def run(args,**kwargs):
            if 'is-active' in args:return '',3
            raise ValueError('fixture launch failed')
        with patch.dict(G,status=lambda *args:{'visible':True},run=run):
            with self.assertRaises(ValueError):MODULE['send'](ADDRESS)
        self.assertEqual(MODULE['selection']()['paths'],[str(source)])
        self.assertFalse(MODULE['read_state']('transfer').get('active'))
        self.assertFalse(list(MODULE['runtime']().glob('apple-job-*')))

    def test_lan_worker_reads_large_selection_jobs_without_opening_the_picker(self):
        paths=[]
        for index in range(40):
            source=Path(self.tmp.name)/(str(index)+'-'+'x'*200+'.txt');source.write_text('fixture');paths.append(str(source))
        job='c'*32;payload={'paths':paths,'code':'ABCDEFGHIJKLMNOP','peer':{'addresses':['127.0.0.1'],'port':8857}}
        MODULE['write_state']('lan-job-'+job,payload)
        self.assertGreater((MODULE['runtime']()/('lan-job-'+job+'.json')).stat().st_size,8192)
        record=Path(self.tmp.name)/'lan-input.json';script=Path(self.tmp.name)/'fake-lan.py'
        script.write_text('import json,sys\nfrom pathlib import Path\nvalue=json.load(sys.stdin)\nPath('+repr(str(record))+').write_text(json.dumps(value))\nprint(json.dumps({"ok":True,"phase":"complete","message":"Fixture complete"}))\n')
        with patch.dict(G,LAN=str(script),notify=lambda *a:None,
                        run=lambda *a,**k:self.fail('No picker should open for explicit files'),
                        lan_status=lambda:self.fail('No chooser directory is needed')),patch('signal.signal'):
            MODULE['worker_lan'](job)
        self.assertEqual(json.loads(record.read_text())['paths'],paths)
        self.assertEqual(MODULE['read_state']('transfer')['phase'],'complete')
