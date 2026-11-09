import importlib.machinery
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
LOADER = importlib.machinery.SourceFileLoader("spectrum_network_adapter", str(ROOT / "scripts/network-adapter"))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
NETWORK = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(NETWORK)


class SpectrumShellNetworkTests(unittest.TestCase):
    def setUp(self):
        self.profiles = patch.object(NETWORK, "connection_profiles", return_value=[])
        self.profiles.start()
        self.addCleanup(self.profiles.stop)

    def test_connected_wifi_details_use_its_interface(self):
        responses = [
            subprocess.CompletedProcess([], 0, "wlp2s0:wifi:connected:Home\nenp1s0:ethernet:connected:Wired\n", ""),
            subprocess.CompletedProcess([], 0, "192.168.2.8/24\n", ""),
            subprocess.CompletedProcess([], 0, "fe80::1/64\n2001:db8::8/64\n", ""),
            subprocess.CompletedProcess([], 0, "192.168.2.1\n", ""),
        ]
        with patch.object(NETWORK, "run", side_effect=responses) as command, patch.object(
            NETWORK, "interface_throughput", return_value=("2.0 MiB/s", "1.0 MiB/s")
        ) as throughput:
            wifi = NETWORK.wifi_state("Home", 72, "300 Mbit/s")
        self.assertEqual(wifi["interface"], "wlp2s0")
        self.assertEqual(wifi["ipv6"], "2001:db8::8/64")
        self.assertEqual(wifi["speed"], "300 Mbit/s")
        self.assertEqual(wifi["download"], "2.0 MiB/s")
        self.assertEqual(command.call_args_list[1].args[-1], "wlp2s0")
        throughput.assert_called_once_with("wlp2s0")

    def test_ethernet_is_primary_when_both_links_are_connected(self):
        ethernet = {"connected": True, "speed": "1 Gbps", "ipv4": "192.0.2.10/24", "ipv6": "—", "public_ip": "203.0.113.10", "download": "3.0 MiB/s", "upload": "1.0 MiB/s"}
        wifi = {"connected": True, "ssid": "Home", "ipv4": "192.0.2.20/24", "ipv6": "—", "download": "2.0 MiB/s", "upload": "0 B/s"}
        responses = [
            subprocess.CompletedProcess([], 0, "", ""),
            subprocess.CompletedProcess([], 0, "enabled\n", ""),
            subprocess.CompletedProcess([], 0, "wlp2s0:wifi:connected:Home\n", ""),
            subprocess.CompletedProcess([], 0, "*:Home:72:WPA2:300 Mbit/s\n", ""),
        ]
        with patch.object(NETWORK, "run", side_effect=responses), patch.object(
            NETWORK, "ethernet_state", return_value=ethernet
        ), patch.object(NETWORK, "wifi_state", return_value=wifi), patch.object(
            NETWORK, "saved_wifi", return_value={}
        ), patch("sys.stdout", new_callable=io.StringIO) as output:
            NETWORK.state()
        state = json.loads(output.getvalue())
        self.assertEqual(state["connection_type"], "ethernet")
        self.assertEqual(state["download"], "3.0 MiB/s")
        self.assertEqual(state["wifi"]["ssid"], "Home")

    def test_wifi_is_primary_without_ethernet(self):
        ethernet = {"connected": False, "ipv4": "—", "ipv6": "—", "public_ip": "—", "download": "0 B/s", "upload": "0 B/s"}
        wifi = {"connected": True, "ssid": "Home", "ipv4": "192.0.2.20/24", "ipv6": "—", "download": "2.0 MiB/s", "upload": "1.0 MiB/s"}
        responses = [
            subprocess.CompletedProcess([], 0, "", ""),
            subprocess.CompletedProcess([], 0, "enabled\n", ""),
            subprocess.CompletedProcess([], 0, "wlp2s0:wifi:connected:Home\n", ""),
            subprocess.CompletedProcess([], 0, "*:Home:72:WPA2:300 Mbit/s\n", ""),
        ]
        with patch.object(NETWORK, "run", side_effect=responses), patch.object(
            NETWORK, "ethernet_state", return_value=ethernet
        ), patch.object(NETWORK, "wifi_state", return_value=wifi), patch.object(
            NETWORK, "saved_wifi", return_value={}
        ), patch.object(NETWORK, "public_ip", return_value="203.0.113.20"), patch(
            "sys.stdout", new_callable=io.StringIO
        ) as output:
            NETWORK.state()
        state = json.loads(output.getvalue())
        self.assertEqual(state["connection_type"], "wifi")
        self.assertEqual(state["ipv4"], "192.0.2.20/24")
        self.assertEqual(state["public_ip"], "203.0.113.20")

    def test_disabled_wifi_does_not_scan(self):
        ethernet = {"connected": True, "speed": "1 Gbps", "ipv4": "192.0.2.10/24", "ipv6": "—", "public_ip": "203.0.113.10", "download": "0 B/s", "upload": "0 B/s"}
        responses = [
            subprocess.CompletedProcess([], 0, "", ""),
            subprocess.CompletedProcess([], 0, "disabled\n", ""),
            subprocess.CompletedProcess([], 0, "enp1s0:ethernet:connected:Wired\n", ""),
        ]
        with patch.object(NETWORK, "run", side_effect=responses) as command, patch.object(
            NETWORK, "ethernet_state", return_value=ethernet
        ), patch.object(NETWORK, "saved_wifi", return_value={}), patch(
            "sys.stdout", new_callable=io.StringIO
        ):
            NETWORK.state()
        self.assertEqual(command.call_count, 3)

    def test_secured_connection_reads_password_from_stdin(self):
        completed = subprocess.CompletedProcess([], 0, "", "")
        with patch.object(NETWORK, "run", return_value=completed) as command, patch.object(
            NETWORK, "invalidate_public_ip"
        ) as invalidate, patch("sys.stdin", io.StringIO("sample passphrase\n")):
            NETWORK.action("connect-secured", "Example Wi-Fi")
        command.assert_called_once_with(
            "nmcli", "device", "wifi", "connect", "Example Wi-Fi", "password", "sample passphrase", timeout=60
        )
        invalidate.assert_called_once()

    def test_empty_password_does_not_attempt_connection(self):
        with patch.object(NETWORK, "run") as command, patch("sys.stdin", io.StringIO("\n")):
            with self.assertRaises(SystemExit):
                NETWORK.action("connect-secured", "Example Wi-Fi")
        command.assert_not_called()


class ProtonVpnTests(unittest.TestCase):
    def test_missing_cli_is_reported_without_launching_commands(self):
        with patch.object(NETWORK.shutil, "which", return_value=None), patch.object(NETWORK, "run") as run:
            self.assertFalse(NETWORK.proton_status()["installed"])
            run.assert_not_called()

    def test_signed_out_account_is_not_ready_to_connect(self):
        responses = [subprocess.CompletedProcess([], 0, "Status: Disconnected", ""),
                     subprocess.CompletedProcess([], 0, "Account: 'None'", "")]
        with patch.object(NETWORK.shutil, "which", return_value="/usr/bin/protonvpn"), patch.object(NETWORK, "run", side_effect=responses):
            state = NETWORK.proton_status()
        self.assertFalse(state["signed_in"])
        self.assertIn("Sign in", state["status"])

    def test_country_connection_uses_argument_array_and_invalidates_ip(self):
        with patch.object(NETWORK.shutil, "which", return_value="/usr/bin/protonvpn"), patch.object(
            NETWORK, "run", return_value=subprocess.CompletedProcess([], 0, "Connected", "")
        ) as run, patch.object(NETWORK, "invalidate_public_ip") as invalidate, patch("sys.stdout", io.StringIO()):
            NETWORK.proton_action("vpn-connect", "mx")
        run.assert_called_once_with("protonvpn", "connect", "--country", "MX", timeout=90)
        invalidate.assert_called_once()

    def test_signin_terminal_does_not_hold_widget_pipes_open(self):
        with patch.object(NETWORK.shutil, "which", return_value="/usr/bin/protonvpn"), patch.object(NETWORK.subprocess, "Popen") as launch:
            NETWORK.proton_action("vpn-signin", None)
        self.assertEqual(launch.call_args.args[0][-1], "vpn-signin-prompt")
        self.assertEqual(launch.call_args.kwargs["stdout"], subprocess.DEVNULL)
        self.assertEqual(launch.call_args.kwargs["stderr"], subprocess.DEVNULL)

    def test_signin_prompt_passes_username_and_preserves_interactive_password_input(self):
        with patch("builtins.input", return_value=" person@proton.me "), patch.object(
            NETWORK.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)
        ) as run:
            self.assertEqual(NETWORK.proton_signin_prompt(), 0)
        run.assert_called_once_with(["protonvpn", "signin", "--", "person@proton.me"], check=False)

    def test_empty_or_cancelled_signin_does_not_launch_proton(self):
        for result in ["", "  ", EOFError(), KeyboardInterrupt()]:
            with self.subTest(result=result), patch("builtins.input", side_effect=result if isinstance(result, BaseException) else None, return_value=result), patch.object(NETWORK.subprocess, "run") as run, patch("sys.stderr", io.StringIO()):
                self.assertEqual(NETWORK.proton_signin_prompt(), 1)
                run.assert_not_called()

    def test_invalid_country_and_settings_never_launch_cli(self):
        with patch.object(NETWORK.shutil, "which", return_value="/usr/bin/protonvpn"), patch.object(NETWORK, "run") as run:
            for operation, value in [("vpn-connect", "--help"), ("vpn-config", "kill-switch:on"), ("vpn-config", "unexpected:on")]:
                with self.subTest(operation=operation, value=value), self.assertRaises(ValueError):
                    NETWORK.proton_action(operation, value)
            run.assert_not_called()

    def test_free_plan_stderr_error_is_shown_without_dependency_warning(self):
        stderr = "EventletDeprecationWarning: dependency warning\nError: Location selection is not available on the free plan. Leave country empty.\n\nTry help."
        with patch.object(NETWORK.shutil, "which", return_value="/usr/bin/protonvpn"), patch.object(
            NETWORK, "run", return_value=subprocess.CompletedProcess([], 2, "", stderr)
        ), self.assertRaisesRegex(ValueError, "^Location selection is not available on the free plan. Leave country empty.$"):
            NETWORK.proton_action("vpn-connect", "MX")

    def test_authentication_error_is_returned_to_widget(self):
        with patch.object(NETWORK.shutil, "which", return_value="/usr/bin/protonvpn"), patch.object(
            NETWORK, "run", return_value=subprocess.CompletedProcess([], 1, "Authentication required", "")
        ), self.assertRaisesRegex(ValueError, "Authentication required"):
            NETWORK.proton_action("vpn-connect", None)


if __name__ == "__main__":
    unittest.main()
