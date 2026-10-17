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


if __name__ == "__main__":
    unittest.main()
