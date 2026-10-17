import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/ukvm-adapter"
loader = importlib.machinery.SourceFileLoader("ukvm_adapter", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
adapter = importlib.util.module_from_spec(spec)
loader.exec_module(adapter)
NODE = "a" * 64
CODE = "1234-5678"


class AdapterTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.directory = Path(self.temp.name)
        self.binary = self.directory / "ukvm"
        self.environment = dict(os.environ, XDG_STATE_HOME=str(self.directory / "state"), SPECTRUM_UKVM_BINARY=str(self.binary))
        self.env = patch.dict(os.environ, self.environment)
        self.env.start()

    def tearDown(self):
        self.env.stop()
        self.temp.cleanup()

    def fake(self, body):
        self.binary.write_text("#!/usr/bin/env python3\nimport json,sys,time,os,signal\n" + body)
        self.binary.chmod(0o755)

    def invoke(self, args):
        return subprocess.run([str(SCRIPT), "request", json.dumps(args)], capture_output=True, text=True, env=self.environment)

    def test_local_setup_is_explicit_and_marks_apply_without_pairing(self):
        self.fake("assert sys.argv[1:]==['setup','--local','--name','My computer','--json']\nprint(json.dumps(dict(schema_version=1,command='setup',ok=True,data=dict(initialized=True,trust_changed=False,consent_requested=False),error=None)))\n")
        record = json.loads(self.invoke(["setup", "--local", "--name", "My computer"]).stdout)
        self.assertTrue(record["ok"])
        self.assertTrue(record["apply_pending"])
        for args in [["setup"], ["setup", "--yes"], ["setup", "--local", "--name", ""], ["setup", "--local", "--name", "bad\nname"]]:
            with self.assertRaises(ValueError):
                adapter.arguments(args)

    def test_missing_detection(self):
        result = self.invoke(["status"])
        record = json.loads(result.stdout)
        self.assertEqual(record["error"]["code"], "not_installed")
        self.assertFalse(record["installed"])
        self.assertNotEqual(result.returncode, 0)

    def test_desktop_authorization_reset_requires_explicit_confirmation(self):
        for args in [["authorization", "reset"], ["authorization", "reset", "--yes", "unexpected"], ["authorization", "grant"], ["authorization", "token"]]:
            with self.assertRaises(ValueError):
                adapter.arguments(args)
        self.assertEqual(adapter.arguments(["authorization", "status"]), ["authorization", "status"])
        self.fake("assert sys.argv[1:]==['authorization','reset','--yes','--json']\nprint(json.dumps(dict(schema_version=1,command='authorization',ok=True,data=dict(reset=True,trust_changed=False,control_permissions_changed=False,service_restarted=False),error=None)))\n")
        record = json.loads(self.invoke(["authorization", "reset", "--yes"]).stdout)
        self.assertTrue(record["ok"])
        self.assertFalse(record["data"]["trust_changed"])
        self.assertFalse(record["data"]["service_restarted"])

    def test_old_cli_is_not_parsed(self):
        self.fake("print('UniversalKVM usage --json unsupported')\nsys.exit(1)\n")
        record = json.loads(self.invoke(["status"]).stdout)
        self.assertEqual(record["error"]["code"], "invalid_response")
        self.assertTrue(record["installed"])

    def test_structured_service_health_and_exit(self):
        self.fake("assert sys.argv[1:]==['service','status','--json']\nprint(json.dumps(dict(schema_version=1,command='service',ok=True,data=dict(active_state='inactive',available=True),error=None)))\n")
        record = json.loads(self.invoke(["service", "status"]).stdout)
        self.assertTrue(record["ok"])
        self.assertEqual(record["data"]["active_state"], "inactive")

    def test_schema_and_command_mismatch(self):
        for version, command in [(2, "status"), (1, "peers")]:
            self.fake(f"print(json.dumps(dict(schema_version={version},command={command!r},ok=True,data={{}},error=None)))\n")
            self.assertFalse(json.loads(self.invoke(["status"]).stdout)["ok"])

    def test_no_shell_and_allowlist(self):
        for args in [["run"], ["unpair", NODE], ["service", "uninstall"], ["peer", "allow", NODE, "debug-input"], ["layout", "place", "0; touch /tmp/unsafe", "1", NODE]]:
            with self.assertRaises(ValueError):
                adapter.arguments(args)
        self.assertEqual(adapter.arguments(["layout", "move", NODE, "-1", "0"])[2], NODE)

    def test_mutation_arguments_and_apply_marker(self):
        self.fake("print(json.dumps(dict(schema_version=1,command=sys.argv[1],ok=True,data=dict(applied=True,apply_required=True),error=None)))\n")
        for args in [["layout", "place", "1", "0", NODE], ["layout", "move", NODE, "-1", "0"], ["peer", "allow", NODE, "control-this-node"], ["peer", "deny", NODE, "control-this-node"], ["layout", "remove", NODE, "--yes"], ["unpair", NODE, "--yes"]]:
            self.assertTrue(json.loads(self.invoke(args).stdout)["apply_pending"])
        self.assertFalse(json.loads(self.invoke(["apply"]).stdout)["apply_pending"])

    def test_clipboard_is_separate_and_live_without_apply(self):
        self.fake("assert sys.argv[-2:]==['share-clipboard','--json']\nprint(json.dumps(dict(schema_version=1,command='peer',ok=True,data=dict(permissions=dict(share_clipboard=sys.argv[2]=='allow',control_this_node=False),apply_required=False),error=None)))\n")
        for action in ("allow", "deny"):
            record = json.loads(self.invoke(["peer", action, NODE, "share-clipboard"]).stdout)
            self.assertTrue(record["ok"])
            self.assertFalse(record["apply_pending"])
            self.assertFalse(record["data"]["permissions"]["control_this_node"])
            self.assertEqual(record["data"]["permissions"]["share_clipboard"], action == "allow")
        adapter.save_pending(True)
        self.assertTrue(json.loads(self.invoke(["peer", "deny", NODE, "share-clipboard"]).stdout)["apply_pending"])
        with self.assertRaises(ValueError):
            adapter.arguments(["peer", "allow", NODE, "clipboard-content"])

    def test_receive_files_permission_is_live_independent_and_not_pending(self):
        self.fake("assert sys.argv[-2:]==['receive-files','--json']\nprint(json.dumps(dict(schema_version=1,command='peer',ok=True,data=dict(permissions=dict(receive_files=sys.argv[2]=='allow',share_clipboard=True,control_this_node=True),apply_required=False),error=None)))\n")
        for action in ("allow", "deny"):
            record = json.loads(self.invoke(["peer", action, NODE, "receive-files"]).stdout)
            self.assertTrue(record["ok"])
            self.assertFalse(record["apply_pending"])
            self.assertEqual(record["data"]["permissions"]["receive_files"], action == "allow")
            self.assertTrue(record["data"]["permissions"]["share_clipboard"])
            self.assertTrue(record["data"]["permissions"]["control_this_node"])

    def test_screen_view_permission_is_live_and_independent(self):
        self.fake("print(json.dumps(dict(schema_version=1,command='peer',ok=True,data=dict(permissions=dict(view_screen=sys.argv[2]=='allow',control_this_node=False),apply_required=False),error=None)))\n")
        for action in ("allow", "deny"):
            record = json.loads(self.invoke(["peer", action, NODE, "view-screen"]).stdout)
            self.assertTrue(record["ok"])
            self.assertFalse(record["apply_pending"])
            self.assertEqual(record["data"]["permissions"]["view_screen"], action == "allow")
            self.assertFalse(record["data"]["permissions"]["control_this_node"])
        adapter.save_pending(True)
        self.assertTrue(json.loads(self.invoke(["peer", "deny", NODE, "view-screen"]).stdout)["apply_pending"])

    def test_remote_launch_is_detached_native_and_identity_bounded(self):
        with patch.object(adapter.subprocess, "Popen") as launch:
            launch.return_value.pid = 123
            record = adapter.request(["remote", NODE], str(self.binary))
            self.assertTrue(record["data"]["launched"])
            launch.assert_called_once_with([str(self.binary), "remote", NODE], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, start_new_session=True)
        self.assertFalse(adapter.pending())
        for peer in ("io", "a" * 63, "a" * 64 + ";exit", "--help"):
            with self.assertRaises(ValueError):
                adapter.arguments(["remote", peer])
        with self.assertRaises(ValueError):
            adapter.arguments(["remote", NODE, "--json"])
        self.assertFalse(adapter.request(["remote", NODE], None)["ok"])

    def test_local_picker_paths_and_no_shell_interpretation(self):
        self.assertEqual(adapter.send_paths(dict(peer=NODE, paths=["file:///tmp/a%20b%3B%24x.txt", "file://localhost/tmp/%E4%BD%A0%E5%A5%BD"])), ["/tmp/a b;$x.txt", "/tmp/你好", NODE])
        for value in ["https://example.com/x", "file://remote/tmp/a", "file:///tmp/a?query", "file:///tmp/a#fragment", "file:///tmp/%00", "relative", "file:relative"]:
            with self.assertRaises(ValueError):
                adapter.send_paths(dict(peer=NODE, paths=[value]))
        with self.assertRaises(ValueError):
            adapter.send_paths(dict(peer="bad", paths=["file:///tmp/a"]))

    def test_transfer_jsonl_and_errors_are_not_terminal_parsing(self):
        self.fake("assert sys.argv[1:]==['send','/tmp/a b.txt'," + repr(NODE) + ",'--json']\nprint(json.dumps(dict(schema_version=1,command='send',event='started',data=dict(id='b'*32,peer_id='a'*64,direction='send',state='connecting',bytes=0,total_bytes=4))))\nprint(json.dumps(dict(schema_version=1,command='send',event='result',ok=False,data=None,error=dict(code='operation_failed',message='receive-files denied'))))\nsys.exit(1)\n")
        result = subprocess.run([str(SCRIPT), "send", json.dumps(dict(peer=NODE, paths=["file:///tmp/a%20b.txt"]))], capture_output=True, text=True, env=self.environment)
        records = [json.loads(line) for line in result.stdout.splitlines()]
        self.assertEqual([r["event"] for r in records], ["started", "result"])
        self.assertEqual(records[-1]["error"]["message"], "receive-files denied")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(adapter.pending())
        with self.assertRaises(ValueError):
            adapter.validate(dict(schema_version=1,command="send",event="progress",data=dict(id="b"*32,peer_id=NODE,direction="send",state="transferring",bytes=9,total_bytes=2)), "send", streaming=True)
        self.assertEqual(adapter.arguments(["files", "cancel", "b"*32]), ["files", "cancel", "b"*32])
        with self.assertRaises(ValueError):
            adapter.arguments(["files", "cancel", "../x"])

    def test_operation_error_and_partial_change_marker(self):
        self.fake("print(json.dumps(dict(schema_version=1,command=sys.argv[1],ok=False,data=None,error=dict(code='operation_failed',message='Outer placement depends on inner neighbour'))))\nsys.exit(1)\n")
        result = self.invoke(["layout", "remove", NODE, "--yes"])
        record = json.loads(result.stdout)
        self.assertTrue(record["apply_pending"])
        self.assertEqual(record["error"]["message"], "Outer placement depends on inner neighbour")
        self.assertEqual(result.returncode, 1)

    def test_timeout_and_unsuccessful_exit(self):
        with patch.object(adapter.subprocess, "run", side_effect=subprocess.TimeoutExpired("ukvm", 20)):
            self.assertEqual(adapter.request(["status"], str(self.binary))["error"]["code"], "timeout")
        self.fake("print(json.dumps(dict(schema_version=1,command='status',ok=True,data={},error=None)))\nsys.exit(1)\n")
        self.assertFalse(json.loads(self.invoke(["status"]).stdout)["ok"])

    def pair_fake(self, after=""):
        self.fake(f"print(json.dumps(dict(schema_version=1,command='pair',event='confirmation_required',data=dict(remote_name='<b>untrusted name</b>',remote_node_id={NODE!r},verification_code={CODE!r}))),flush=True)\nreply=json.loads(sys.stdin.readline())\nassert reply['remote_node_id']=={NODE!r} and reply['verification_code']=={CODE!r}\n{after}\nprint(json.dumps(dict(schema_version=1,command='pair',event='result',ok=reply['accept'],data={{'peer':{{}}}} if reply['accept'] else None,error=None if reply['accept'] else {{'code':'pairing_failed','message':'Rejected'}})),flush=True)\n")

    def ceremony(self):
        process = subprocess.Popen([str(SCRIPT), "pair", "127.0.0.1:7777", "--expected-node-id", NODE], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=self.environment)
        self.addCleanup(lambda: process.kill() if process.poll() is None else None)
        offer = json.loads(process.stdout.readline())
        self.assertEqual(offer["event"], "confirmation_required")
        return process

    def test_explicit_bound_approval_and_rejection(self):
        for accept in (True, False):
            self.pair_fake()
            process = self.ceremony()
            process.stdin.write(json.dumps(dict(accept=accept, remote_node_id=NODE, verification_code=CODE)) + "\n")
            process.stdin.flush()
            out, err = process.communicate(timeout=5)
            record = json.loads(out)
            self.assertEqual(record["ok"], accept)
            self.assertEqual(process.returncode, 0 if accept else 1)

    def test_stale_code_fails_closed(self):
        self.pair_fake()
        process = self.ceremony()
        out, _ = process.communicate(json.dumps(dict(accept=True, remote_node_id=NODE, verification_code="WRONG")) + "\n", timeout=5)
        self.assertFalse(json.loads(out)["ok"])
        self.assertNotEqual(process.returncode, 0)
        self.assertFalse(adapter.pending())

    def test_close_stdin_and_sigterm_cancel(self):
        for terminate in (False, True):
            self.pair_fake("time.sleep(0.1)")
            process = self.ceremony()
            if terminate:
                process.terminate()
            out, _ = process.communicate(timeout=5)
            self.assertFalse(json.loads(out)["ok"])
            self.assertNotEqual(process.returncode, 0)

    def test_pair_success_requires_user_approval(self):
        self.fake("print(json.dumps(dict(schema_version=1,command='pair',event='result',ok=True,data={},error=None)),flush=True)\n")
        result = subprocess.run([str(SCRIPT), "pair"], input="", capture_output=True, text=True, env=self.environment, timeout=5)
        self.assertFalse(json.loads(result.stdout)["ok"])
        self.assertFalse(adapter.pending())

    def test_concurrent_frontend_mutations_are_rejected(self):
        self.fake("raise SystemExit('must not execute')\n")
        with adapter.operation_lock(True):
            result = self.invoke(["layout", "remove", NODE, "--yes"])
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Another UKVM frontend operation", json.loads(result.stdout)["error"]["message"])
        self.assertFalse(adapter.pending())

    def test_packaged_install_is_complete(self):
        destination = self.directory / "root"
        subprocess.run([str(ROOT / "integrations/ukvm/install"), str(ROOT), str(destination)], check=True)
        self.assertTrue((destination / "usr/bin/spectrum-ukvm").is_file())
        self.assertTrue((destination / "usr/share/spectrumos/spectrum-ukvm/UkvmPage.qml").is_file())
        self.assertTrue((destination / "usr/lib/spectrumos/ukvm-adapter").is_file())


@unittest.skipUnless(os.environ.get("UKVM_FRONTEND_TEST_BINARY"), "Set UKVM_FRONTEND_TEST_BINARY for isolated real-CLI acceptance")
class InstalledContractTests(unittest.TestCase):
    def test_real_cli_topology_permissions_service_and_apply(self):
        import socket
        binary = os.environ["UKVM_FRONTEND_TEST_BINARY"]
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            shim = root / "bin"
            shim.mkdir()
            systemctl = shim / "systemctl"
            systemctl.write_text("#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$UKVM_TEST_LOG\"\ncase \"$*\" in *show*) printf 'LoadState=loaded\\nActiveState=inactive\\nSubState=dead\\nUnitFileState=enabled\\nMainPID=0\\n';; esac\nexit 0\n")
            systemctl.chmod(0o700)
            environment = dict(os.environ, SPECTRUM_UKVM_BINARY=binary, XDG_CONFIG_HOME=str(root / "config"), XDG_DATA_HOME=str(root / "data"), XDG_STATE_HOME=str(root / "state"), XDG_RUNTIME_DIR=str(root), WAYLAND_DISPLAY="wayland-test", XDG_CURRENT_DESKTOP="test", DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent/m17-test-bus", PATH=str(shim) + ":/usr/bin:/bin", UKVM_TEST_LOG=str(root / "systemctl.log"))
            with socket.socket(socket.AF_UNIX) as wayland:
                wayland.bind(str(root / "wayland-test"))
                wayland.listen(16)
                subprocess.run([binary, "identity", "--state-dir", str(root / "remote-identity")], env=environment, check=True, capture_output=True)
                subprocess.run([binary, "peer", "add", str(root / "remote-identity/node.der"), "--name", "Test machine", "--address", "127.0.0.1:24800"], input=b"yes\n", env=environment, check=True, capture_output=True)

                def run(args, success=True):
                    result = subprocess.run([str(SCRIPT), "request", json.dumps(args)], env=environment, capture_output=True, text=True, timeout=25)
                    record = json.loads(result.stdout)
                    self.assertEqual(record["ok"], success, record)
                    self.assertEqual(result.returncode, 0 if success else 1)
                    return record

                peer = run(["peers"])["data"]["peers"][0]["node_id"]
                initial = run(["peer", "permissions", peer])["data"]["permissions"]
                self.assertFalse(initial["control_this_node"])
                self.assertFalse(initial["share_clipboard"])
                self.assertFalse(initial["receive_files"])
                self.assertFalse(initial["view_screen"])
                for action in ("allow", "deny"):
                    viewing = run(["peer", action, peer, "view-screen"])
                    self.assertFalse(viewing["apply_pending"])
                    self.assertEqual(viewing["data"]["permissions"]["view_screen"], action == "allow")
                    self.assertFalse(viewing["data"]["permissions"]["control_this_node"])
                self.assertFalse(run(["status"])["data"]["health"]["identity_initialized"])
                run(["layout", "place", "1", "0", peer])
                layout = run(["layout"])["data"]
                self.assertEqual(layout["nodes"][1]["x"], 1)
                run(["layout", "place", "-1", "0", peer], False)
                run(["layout", "move", peer, "0", "-1"])
                self.assertEqual(run(["layout"])["data"]["nodes"][1]["y"], -1)
                run(["peer", "allow", peer, "share-clipboard"])
                run(["peer", "allow", peer, "receive-files"])
                self.assertFalse(run(["peer", "permissions", peer])["data"]["permissions"]["control_this_node"])
                grant = run(["peer", "allow", peer, "control-this-node"])
                self.assertTrue(grant["apply_pending"])
                self.assertFalse(run(["apply"])["apply_pending"])
                saved = run(["peer", "permissions", peer])["data"]["permissions"]
                self.assertTrue(saved["control_this_node"])
                self.assertTrue(saved["share_clipboard"])
                self.assertTrue(saved["receive_files"])
                run(["peer", "deny", peer, "control-this-node"])
                for action in ("install", "enable", "start", "stop", "restart", "disable", "status"):
                    run(["service", action])
                self.assertFalse(run(["apply"])["apply_pending"])
                run(["layout", "remove", peer, "--yes"])
                self.assertEqual(len(run(["layout"])["data"]["nodes"]), 1)
                run(["unpair", peer, "--yes"])
                self.assertEqual(run(["peers"])["data"]["peers"], [])
                self.assertIn("--user restart ukvm.service", (root / "systemctl.log").read_text())
