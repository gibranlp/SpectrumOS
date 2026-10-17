import importlib.machinery
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    loader = importlib.machinery.SourceFileLoader(name.replace("-", "_"), str(ROOT / "scripts" / name))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


AUDIO = load("control-adapter")
NETWORK = load("network-adapter")
TERMINAL = load("spectrum-terminal-config")
UUID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"


class AudioDeviceTests(unittest.TestCase):
    def test_per_device_volume_and_mute_do_not_change_default(self):
        devices = {"sinks":[{"id":"3","name":"speaker"}], "sources":[{"id":"9","name":"microphone"}]}
        for action, device, command in [("output-volume","3",("pactl","set-sink-volume","speaker","42%")),
                                         ("input-volume","9",("pactl","set-source-volume","microphone","42%")),
                                         ("input-mute","9",("pactl","set-source-mute","microphone","toggle"))]:
            with patch.object(AUDIO, "audio_state", return_value=devices), patch.object(AUDIO, "run", return_value=subprocess.CompletedProcess([],0,"","")) as run:
                AUDIO.audio_action(action, device, "42")
                run.assert_called_once_with(command)

    def test_audio_validation_and_command_failure(self):
        with patch.object(AUDIO, "audio_state", return_value={"sinks":[{"id":"1","name":"speaker"}],"sources":[]}), patch.object(AUDIO, "run", return_value=subprocess.CompletedProcess([],1,"","Permission refused")):
            for value in ("-1","101","nan","42;whoami"):
                with self.assertRaises(ValueError): AUDIO.audio_action("output-volume","1",value)
            with self.assertRaisesRegex(ValueError,"Unknown"): AUDIO.audio_action("output-volume","9","10")
            with self.assertRaisesRegex(ValueError,"Permission refused"): AUDIO.audio_action("output","1")


class ConnectionIpTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        environment = patch.dict(NETWORK.os.environ, {"XDG_STATE_HOME": self.directory.name})
        environment.start()
        self.addCleanup(environment.stop)

    def test_saved_ethernet_and_wifi_profiles_include_both_permissions(self):
        rows = f"{UUID}:Wired:802-3-ethernet\n{UUID}:Home:802-11-wireless\n{UUID}:VPN:vpn\n"
        responses = [subprocess.CompletedProcess([],0,rows,""), subprocess.CompletedProcess([],0,"manual\ndisabled\n",""), subprocess.CompletedProcess([],0,"auto\nauto\n","")]
        with patch.object(NETWORK,"run",side_effect=responses): profiles = NETWORK.connection_profiles()
        self.assertEqual([p["type"] for p in profiles], ["ethernet","wifi"])
        self.assertFalse(profiles[0]["ipv6_enabled"])
        self.assertTrue(profiles[1]["ipv6_enabled"])

    def test_disabling_saves_manual_configuration_atomically(self):
        values = {"connection.type":"802-3-ethernet","ipv4.method":"manual","ipv6.method":"auto", "ipv4.addresses":"192.0.2.8/24","ipv4.gateway":"192.0.2.1", "ipv4.dns":"192.0.2.53","ipv4.dns-search":"example.test","ipv4.link-local":"0 (default)","GENERAL.DEVICES":"--"}
        with patch.object(NETWORK,"profile_value",side_effect=lambda _,field:values[field]), patch.object(NETWORK,"run",return_value=subprocess.CompletedProcess([],0,"","")) as run, patch.object(NETWORK,"invalidate_public_ip"):
            NETWORK.set_ip_family(UUID,"ipv4","off")
        command = run.call_args.args
        backup = NETWORK.ip_backup_path(UUID, "ipv4")
        self.assertEqual(backup.stat().st_mode & 0o777, 0o600)
        saved = json.loads(backup.read_text())
        self.assertEqual(saved["method"],"manual")
        self.assertEqual(saved["dns"],"192.0.2.53")
        self.assertEqual(command[command.index("ipv4.method")+1],"disabled")
        self.assertEqual(command[command.index("ipv4.addresses")+1],"")

    def test_restore_manual_values_and_reapply_only_selected_device(self):
        saved = {"method":"manual","addresses":"2001:db8::8/64","gateway":"2001:db8::1","dns":"2001:db8::53","dns-search":"example.test"}
        backup = NETWORK.ip_backup_path(UUID, "ipv6")
        NETWORK.save_ip_backup(backup, saved)
        values = {"connection.type":"802-11-wireless","ipv6.method":"disabled","GENERAL.DEVICES":"wlan0"}
        with patch.object(NETWORK,"profile_value",side_effect=lambda _,field:values[field]), patch.object(NETWORK,"run",return_value=subprocess.CompletedProcess([],0,"","")) as run, patch.object(NETWORK,"invalidate_public_ip"):
            NETWORK.set_ip_family(UUID,"ipv6","on")
        command = run.call_args_list[0].args
        self.assertEqual(command[command.index("ipv6.addresses")+1],saved["addresses"])
        self.assertFalse(backup.exists())
        self.assertEqual(run.call_args_list[1].args,("nmcli","device","reapply","wlan0"))

    def test_failed_save_keeps_restore_backup(self):
        values = {"connection.type": "ethernet", "ipv6.method": "manual", "ipv4.method": "auto", "ipv6.addresses": "2001:db8::8/64", "ipv6.gateway": "", "ipv6.dns": "", "ipv6.dns-search": ""}
        with patch.object(NETWORK, "profile_value", side_effect=lambda _, field: values[field]), patch.object(NETWORK, "run", return_value=subprocess.CompletedProcess([], 1, "", "Permission denied")):
            with self.assertRaisesRegex(ValueError, "Permission denied"):
                NETWORK.set_ip_family(UUID, "ipv6", "off")
        self.assertEqual(json.loads(NETWORK.ip_backup_path(UUID, "ipv6").read_text())["addresses"], "2001:db8::8/64")

    def test_corrupt_backup_is_reported_without_changing_profile(self):
        NETWORK.ip_backup_path(UUID, "ipv6").write_text("broken")
        with patch.object(NETWORK, "profile_value", side_effect=lambda _, field: "ethernet" if field == "connection.type" else "disabled"), patch.object(NETWORK, "run") as run:
            with self.assertRaisesRegex(ValueError, "Saved IP settings are invalid"):
                NETWORK.set_ip_family(UUID, "ipv6", "on")
            run.assert_not_called()

    def test_initially_disabled_protocol_enables_automatic_configuration(self):
        values = {"connection.type": "ethernet", "ipv6.method": "disabled", "GENERAL.DEVICES": "--"}
        with patch.object(NETWORK, "profile_value", side_effect=lambda _, field: values[field]), patch.object(NETWORK, "run", return_value=subprocess.CompletedProcess([], 0, "", "")) as run, patch.object(NETWORK, "invalidate_public_ip"):
            NETWORK.set_ip_family(UUID, "ipv6", "on")
        self.assertEqual(run.call_args.args, ("nmcli", "connection", "modify", "uuid", UUID, "ipv6.method", "auto"))

    def test_no_disabling_both_or_invalid_arguments(self):
        with patch.object(NETWORK,"profile_value",side_effect=lambda _,field:"ethernet" if field=="connection.type" else "auto" if field=="ipv4.method" else "disabled"), patch.object(NETWORK,"run") as run:
            with self.assertRaisesRegex(ValueError,"at least one"): NETWORK.set_ip_family(UUID,"ipv4","off")
            with self.assertRaises(ValueError): NETWORK.set_ip_family(";whoami","ipv4","off")
            run.assert_not_called()


class TerminalIncludesTests(unittest.TestCase):
    def test_fresh_install_and_idempotence_use_package_defaults(self):
        with tempfile.TemporaryDirectory() as directory:
            home=Path(directory)
            TERMINAL.configure(home)
            kitty=home/".config/kitty/kitty.conf"; alacritty=home/".config/alacritty/alacritty.toml"
            before=(kitty.read_text(),alacritty.read_text())
            self.assertIn(TERMINAL.KITTY_INCLUDE,before[0])
            self.assertEqual(tomllib.loads(before[1])["general"]["import"],[TERMINAL.ALACRITTY_INCLUDE])
            TERMINAL.configure(home)
            self.assertEqual(before,(kitty.read_text(),alacritty.read_text()))

    def test_legacy_defaults_migrate_and_preserve_personal_overrides(self):
        with tempfile.TemporaryDirectory() as directory:
            home=Path(directory); kitty=home/".config/kitty"; alacritty=home/".config/alacritty"
            kitty.mkdir(parents=True); alacritty.mkdir()
            (kitty/"spectrum.conf").write_text("include ~/.cache/spectrumos/theme/current/kitty.conf\nfont_size 15\nmap ctrl+c copy_to_clipboard\n")
            (kitty/"kitty.conf").write_text("include spectrum.conf\nfont_size 17\n")
            (alacritty/"alacritty.toml").write_text((ROOT/"configs/terminal/alacritty-spectrum.toml").read_text())
            TERMINAL.configure(home)
            self.assertIn("font_size 15",(kitty/"spectrum.conf").read_text())
            self.assertEqual((kitty/"kitty.conf").read_text(),"include spectrum.conf\nfont_size 17\n")
            self.assertEqual(tomllib.loads((alacritty/"alacritty.toml").read_text())["general"]["import"],[TERMINAL.ALACRITTY_INCLUDE])

    def test_custom_alacritty_remains_an_override_and_linked_configs_are_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            home=Path(directory); folder=home/".config/alacritty"; folder.mkdir(parents=True)
            original='[font]\nsize = 17\n'
            (folder/"alacritty.toml").write_text(original)
            TERMINAL.configure(home)
            self.assertEqual((folder/"spectrum-local.toml").read_text(),original)
            self.assertEqual(tomllib.loads((folder/"alacritty.toml").read_text())["general"]["import"],[TERMINAL.ALACRITTY_INCLUDE,"spectrum-local.toml"])
            (folder/"alacritty.toml").unlink(); (folder/"alacritty.toml").symlink_to(folder/"spectrum-local.toml")
            with self.assertRaises(ValueError): TERMINAL.configure(home)
            self.assertEqual((folder/"spectrum-local.toml").read_text(),original)
