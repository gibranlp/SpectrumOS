import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import subprocess
import time
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('hotkey', str(ROOT/'scripts/hotkey-adapter'))
spec = importlib.util.spec_from_loader(loader.name, loader)
hotkey = importlib.util.module_from_spec(spec)
loader.exec_module(hotkey)
ID = 'a'*32


class HotKeyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.env = patch.dict(os.environ, XDG_CONFIG_HOME=self.temp.name, XDG_RUNTIME_DIR=self.temp.name)
        self.env.start(); self.addCleanup(self.env.stop)
        self.engine = hotkey.Engine()
        self.engine.bindings = Mock(return_value=[])
        self.engine.register = Mock()
        self.engine.unregister = Mock()
        self.engine.keyboard = Mock()
        self.engine.keyboard.pending = None
        def send(identity, key, now):
            self.engine.keyboard.pending = identity
        def poll(now):
            identity = self.engine.keyboard.pending
            self.engine.keyboard.pending = None
            return identity
        self.engine.keyboard.send.side_effect = send
        self.engine.keyboard.poll.side_effect = poll
        self.engine.keyboard.close.side_effect = lambda: setattr(self.engine.keyboard, 'pending', None)
        self.addCleanup(self.engine.stop_all)

    def save(self, identity=ID, sequence='234', interval=50, shortcut='Control+Shift+2'):
        return self.engine.dispatch(['save',json.dumps(dict(id=identity,keys=sequence,interval_ms=interval,shortcut=shortcut))])

    def test_sequence_and_named_keys(self):
        self.assertEqual(hotkey.keys('234[Enter]a[Space]'),['2','3','4','Return','a','space'])
        for value in ('', 'x'*33, '[Unknown]', '[Ctrl]', '[', '\n', ';$(sh)', None):
            with self.assertRaises(ValueError): hotkey.keys(value)

    def test_shortcut_canonicalization_and_validation(self):
        self.assertEqual(hotkey.shortcut(' Shift + Control + 2 '),('CTRL + SHIFT + 2',5,'2'))
        for value in ('','Control+Control+2','Control+;touch /tmp/x','Super+', 'Hyper+2',None):
            with self.assertRaises(ValueError): hotkey.shortcut(value)

    def test_interval_and_identity_bounds(self):
        for interval in (0,9,60001,True,'50'):
            with self.assertRaises(ValueError): self.save(interval=interval)
        with self.assertRaises(ValueError): self.save(identity='../escape')
        self.save(interval=10)
        self.save(interval=60000)

    def test_save_is_stopped_private_and_reload_is_stopped(self):
        self.assertFalse(self.save()['rules'][0]['active'])
        self.assertEqual(hotkey.config_path().stat().st_mode & 0o777,0o600)
        self.engine.dispatch(['toggle',ID])
        self.assertTrue(self.engine.dispatch(['status'])['rules'][0]['active'])
        reloaded = hotkey.Engine()
        self.assertEqual(len(reloaded.rules),1)
        self.assertFalse(reloaded.active)

    def test_same_shortcut_toggles_on_and_off(self):
        self.save(sequence='2', shortcut='2')
        self.assertTrue(self.engine.dispatch(['toggle',ID])['rules'][0]['active'])
        self.assertFalse(self.engine.dispatch(['toggle',ID])['rules'][0]['active'])

    def test_sequence_then_pause_from_last_release_and_no_catch_up_queue(self):
        self.save(interval=1000)
        with patch.object(hotkey.time,'monotonic',return_value=0): self.engine.dispatch(['toggle',ID])
        injection=self.engine.keyboard.send
        self.engine.tick(.24); injection.assert_not_called()
        self.engine.tick(.25); self.assertEqual(injection.call_args.args,(ID,'2',.25))
        self.engine.tick(.26); self.assertEqual(injection.call_args.args[1],'3')
        self.engine.tick(.27); self.assertEqual(injection.call_args.args[1],'4')
        self.engine.tick(.28)
        self.engine.tick(1.279); self.assertEqual(injection.call_count,3)
        self.engine.tick(1.281); self.assertEqual(injection.call_args.args[1],'2')
        self.engine.tick(10); self.assertEqual(injection.call_args.args[1],'3')
        self.engine.tick(10.01); self.assertEqual(injection.call_args.args[1],'4')
        self.engine.tick(10.02); self.engine.tick(10.9)
        self.assertEqual(injection.call_count,6)
        self.engine.tick(11.021); self.assertEqual(injection.call_args.args[1],'2')

    def test_stop_mid_sequence_prevents_remaining_keys(self):
        self.save(shortcut='2')
        self.engine.dispatch(['toggle',ID]); self.engine.active[ID]['next']=0
        self.engine.tick(0)
        self.engine.dispatch(['toggle',ID]); self.engine.tick(.01)
        self.engine.keyboard.send.assert_called_once_with(ID,'2',0)

    def test_single_keys_and_named_shortcuts(self):
        for value, expected in [('2','2'),('a','A'),('Enter','Return'),('Space','space'),('F2','F2')]:
            self.assertEqual(hotkey.shortcut(value),(expected,0,expected))
        self.save(shortcut='2')
        with self.assertRaises(ValueError): self.save(identity='b'*32,shortcut='2')
        self.engine.bindings.return_value=[dict(modmask=0,key='F2',description='Foreign')]
        with self.assertRaises(ValueError): self.save(shortcut='F2')

    def test_independent_sequences_and_stop_all(self):
        self.save(sequence='2',interval=50)
        other='b'*32
        self.save(identity=other,sequence='4',interval=100,shortcut='Control+Shift+4')
        with patch.object(hotkey.time,'monotonic',return_value=0):
            self.engine.dispatch(['toggle',ID]); self.engine.dispatch(['toggle',other])
        injection=self.engine.keyboard.send
        self.engine.tick(.25); self.engine.tick(.251)
        self.assertEqual(injection.call_count,2)
        self.engine.tick(.301); self.assertEqual(injection.call_count,3)
        self.engine.tick(.302); self.engine.tick(.353); self.engine.tick(.354); self.engine.tick(.402); self.assertEqual(injection.call_count,5)
        self.engine.dispatch(['stop-all']); self.engine.tick(100)
        self.assertEqual(injection.call_count,5)
        self.engine.keyboard.close.assert_called()

    def test_waits_for_deadline_without_continuous_polling(self):
        self.assertEqual(self.engine.wait_timeout(0),.2)
        self.save(interval=1000)
        with patch.object(hotkey.time,'monotonic',return_value=0): self.engine.dispatch(['toggle',ID])
        self.assertEqual(self.engine.wait_timeout(0),.2)
        self.assertAlmostEqual(self.engine.wait_timeout(.24),.01)
        self.engine.keyboard.pending=ID
        self.assertEqual(self.engine.wait_timeout(.24),.005)

    def test_empty_service_does_not_query_compositor_bindings(self):
        self.engine.reconcile()
        self.engine.bindings.assert_not_called()

    def test_slow_key_delivery_never_overlaps_or_queues(self):
        self.save(); self.engine.dispatch(['toggle',ID]); self.engine.active[ID]['next']=0
        self.engine.keyboard.pending=ID
        self.engine.keyboard.poll.side_effect = None
        self.engine.keyboard.poll.return_value = None
        self.engine.tick(0); self.engine.tick(.2); self.engine.tick(.9)
        self.engine.keyboard.send.assert_not_called()
        self.engine.keyboard.poll.side_effect=ValueError('Wayland key delivery timed out; repetition stopped.')
        self.engine.tick(1.1)
        self.assertFalse(self.engine.active)
        self.assertIn('timed out',self.engine.errors[ID])

    def test_shared_keyboard_failure_stops_active_rules(self):
        self.save(); self.engine.dispatch(['toggle',ID]); self.engine.active[ID]['next']=0
        self.engine.keyboard.poll.side_effect=ValueError('Wayland keyboard disconnected; repetition stopped.')
        self.engine.tick(0)
        self.assertFalse(self.engine.active)
        self.assertIn('disconnected',self.engine.errors[ID])

    def test_conflicts_do_not_change_existing_bindings(self):
        self.engine.bindings.return_value=[dict(modmask=5,key='2',description='Existing desktop action')]
        with self.assertRaises(ValueError): self.save()
        self.engine.register.assert_not_called(); self.engine.unregister.assert_not_called()
        self.engine.bindings.return_value=[]
        self.save()
        with self.assertRaises(ValueError): self.save(identity='b'*32,shortcut='Shift+Control+2')
        self.assertEqual(len(self.engine.rules),1)

    def test_bound_rate_remove_and_edit_stop_input(self):
        self.save(sequence='2',interval=10); self.engine.dispatch(['toggle',ID])
        self.save(identity='b'*32,shortcut='Control+Shift+3',sequence='3',interval=10); self.engine.dispatch(['toggle','b'*32])
        self.save(identity='c'*32,shortcut='Control+Shift+4',sequence='4',interval=10)
        with self.assertRaises(ValueError): self.engine.dispatch(['toggle','c'*32])
        self.save(sequence='5'); self.assertNotIn(ID,self.engine.active)
        self.engine.dispatch(['remove','b'*32]); self.assertFalse(self.engine.active)
        with self.assertRaises(ValueError): self.engine.dispatch(['toggle','b'*32])

    def test_rate_limit_counts_every_key_in_each_sequence(self):
        self.save(sequence='234',interval=10)
        with self.assertRaises(ValueError): self.engine.dispatch(['toggle',ID])
        self.assertFalse(self.engine.active)
        self.save(sequence='234',interval=50)
        self.assertTrue(self.engine.dispatch(['toggle',ID])['rules'][0]['active'])

    def test_registration_uses_validated_lua_and_no_shell(self):
        item=hotkey.rule(dict(id=ID,keys='234',interval_ms=50,shortcut='Ctrl+Shift+2'))
        with patch.object(hotkey,'hypr') as hypr:
            hotkey.Engine.register(self.engine,item)
        code=hypr.call_args.args[1]
        self.assertNotIn('release=true',code)
        self.assertIn('/usr/lib/spectrumos/hotkey-adapter toggle '+ID,code)
        self.assertNotIn('234',code)
        self.assertIn('inclusive=false',code)
        self.assertIn('hl-virtual-keyboard-hotkey-keyboard',code)

    def test_unregister_never_removes_foreign_binding(self):
        self.save()
        self.engine.bindings.return_value=[dict(modmask=5,key='2',description='Foreign')]
        with patch.object(hotkey,'hypr') as hypr:
            hotkey.Engine.unregister(self.engine,self.engine.rules[0])
            hypr.assert_not_called()

    def test_failure_diagnostic_survives_reconciliation(self):
        self.save()
        self.engine.errors[ID]="Wayland key delivery failed; repetition stopped."
        self.engine.reconcile()
        self.assertIn('delivery failed',self.engine.errors[ID])
        self.assertFalse(self.engine.active)

    def test_rule_limit_malformed_commands_and_config(self):
        for args in ([], ['exec','sh'], ['toggle','../x'], ['status','extra']):
            with self.assertRaises(ValueError): self.engine.dispatch(args)
        hotkey.config_path().parent.mkdir(parents=True,exist_ok=True)
        hotkey.config_path().write_text(json.dumps(dict(version=1,rules=[{}]*33)))
        with self.assertRaises(ValueError): hotkey.Engine()

    def test_shell_and_package_integration(self):
        self.assertIn('toggleHotKey',(ROOT/'scripts/spectrum-shell-open').read_text())
        self.assertIn('" + H"',(ROOT/'configs/hyprland/keybindings.lua').read_text())
        self.assertIn('Super + H',(ROOT/'configs/spectrum-shell/UtilityPanel.qml').read_text())
        for filename in ('packages/spectrum-desktop/PKGBUILD','install.sh'):
            text=(ROOT/filename).read_text()
            self.assertIn('hotkey-adapter',text); self.assertIn('spectrum-hotkey.service',text)


class HotKeyDaemonTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.directory=Path(self.temp.name)
        binaries=self.directory/'bin'; binaries.mkdir()
        self.events=self.directory/'events.jsonl'
        self.locked=self.directory/'locked'
        programs={
            'hyprctl': "import sys,json\nif sys.argv[1:]==['-j','binds']: print('[]')\nelse: print('ok')\n",
            'loginctl': "import sys,os\nprint(('yes' if os.path.exists(os.environ['HOTKEY_TEST_LOCK']) else 'no') if sys.argv[1]=='show-session' else 'test')\n",
            'keyboard': "import os,sys,time,json\nwith open(os.environ['HOTKEY_TEST_EVENTS']+'.launch','a') as f: f.write('start\\n')\nfor line in sys.stdin:\n with open(os.environ['HOTKEY_TEST_EVENTS'],'a') as f: f.write(json.dumps(dict(key=line.strip().split()[1],at=time.monotonic()))+'\\n')\n print('ok',flush=True)\n"}
        for name,body in programs.items():
            path=binaries/name; path.write_text('#!/usr/bin/python3\n'+body); path.chmod(0o755)
        self.env=patch.dict(os.environ,PATH=str(binaries)+':'+os.environ['PATH'],XDG_CONFIG_HOME=self.temp.name,XDG_RUNTIME_DIR=self.temp.name,XDG_SESSION_ID='test',HOTKEY_TEST_EVENTS=str(self.events),HOTKEY_TEST_LOCK=str(self.locked),SPECTRUM_HOTKEY_KEYBOARD=str(binaries/'keyboard'))
        self.env.start(); self.addCleanup(self.env.stop)
        self.process=subprocess.Popen([str(ROOT/'scripts/hotkey-adapter'),'serve'],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        self.addCleanup(self.shutdown)
        deadline=time.monotonic()+3
        while not (hotkey.runtime_path()/'control.sock').exists():
            if time.monotonic()>deadline: self.fail('Test daemon did not start')
            time.sleep(.01)

    def shutdown(self):
        if self.process.poll() is None:
            self.process.terminate()
        try: self.process.communicate(timeout=3)
        except subprocess.TimeoutExpired: self.process.kill(); self.process.communicate()

    def save(self):
        result=hotkey.client(['save',json.dumps(dict(id=ID,keys='234',interval_ms=50,shortcut='Ctrl+Shift+2'))])
        self.assertTrue(result['ok'],result)
        self.assertFalse(result['rules'][0]['active'])

    def test_socket_sequence_order_timing_stop_and_shutdown_cleanup(self):
        self.save()
        self.assertEqual((hotkey.runtime_path()/'control.sock').stat().st_mode & 0o777,0o600)
        self.assertTrue(hotkey.client(['toggle',ID])['rules'][0]['active'])
        deadline=time.monotonic()+3
        records=[]
        while len(records)<5 and time.monotonic()<deadline:
            time.sleep(.02)
            if self.events.exists(): records=[json.loads(line) for line in self.events.read_text().splitlines()]
        self.assertGreaterEqual(len(records),5)
        self.assertEqual([r['key'] for r in records[:5]],['2','3','4','2','3'])
        self.assertEqual(Path(str(self.events)+'.launch').read_text().splitlines(),['start'])
        self.assertLess(records[1]['at']-records[0]['at'],.05)
        self.assertLess(records[2]['at']-records[1]['at'],.05)
        self.assertGreaterEqual(records[3]['at']-records[2]['at'],.05)
        self.assertFalse(hotkey.client(['toggle',ID])['rules'][0]['active'])
        time.sleep(.08); before=self.events.read_text(); time.sleep(.12)
        self.assertEqual(self.events.read_text(),before)
        self.shutdown(); self.assertFalse((hotkey.runtime_path()/'control.sock').exists())

    def test_lock_stops_repetition_and_never_restarts_it(self):
        self.save(); self.locked.touch()
        hotkey.client(['toggle',ID]); time.sleep(.4)
        self.assertFalse(hotkey.client(['status'])['rules'][0]['active'])
        self.assertFalse(self.events.exists())
        self.locked.unlink(); time.sleep(.1)
        self.assertFalse(hotkey.client(['status'])['rules'][0]['active'])

    def test_invalid_command_returns_error_and_preserves_service(self):
        self.assertFalse(hotkey.client(['toggle','../escape'])['ok'])
        self.assertTrue(hotkey.client(['status'])['ok'])


class NativeKeyboardTests(unittest.TestCase):
    def test_missing_link_flags_stop_before_compilation(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            helper = target / 'pkg-config'
            helper.write_text('#!/bin/sh\nprintf "Missing Wayland/xkbcommon metadata\\n" >&2\nexit 37\n')
            helper.chmod(0o755)
            for name in ('cc', 'wayland-scanner'):
                tool = target / name
                tool.write_text('#!/bin/sh\ntouch "$UNEXPECTED_BUILD_TOOL"\nexit 99\n')
                tool.chmod(0o755)
            output = target / 'keyboard'
            output.write_bytes(b'previous working helper')
            marker = target / 'unexpected-tool'
            result = subprocess.run(
                [str(ROOT / 'integrations/hotkey/build'), str(ROOT), str(output)],
                env=dict(os.environ, PATH=str(target) + os.pathsep + os.environ['PATH'],
                         UNEXPECTED_BUILD_TOOL=str(marker)), text=True, capture_output=True)
            self.assertEqual(result.returncode, 37, result.stderr)
            self.assertIn('Missing Wayland/xkbcommon metadata', result.stderr)
            self.assertFalse(marker.exists())
            self.assertEqual(output.read_bytes(), b'previous working helper')

    def test_stable_physical_keymap_without_connecting_to_wayland(self):
        with tempfile.TemporaryDirectory() as directory:
            binary=Path(directory)/'keyboard'
            subprocess.run([str(ROOT/'integrations/hotkey/build'),str(ROOT),str(binary)],check=True,capture_output=True)
            for name,expected in [('2','3 0'),('3','4 0'),('Return','28 0'),('a','30 0'),('A','30 1')]:
                result=subprocess.run([str(binary),'--check-key',name],text=True,capture_output=True)
                self.assertEqual(result.returncode,0,result.stderr)
                self.assertEqual(result.stdout.strip(),expected)
            self.assertNotEqual(subprocess.run([str(binary),'--check-key','not-a-key'],capture_output=True).returncode,0)
