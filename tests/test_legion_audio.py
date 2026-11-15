import importlib.machinery
import importlib.util
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
LOADER = importlib.machinery.SourceFileLoader("legion_audio", str(ROOT / "scripts/legion-audio"))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
AUDIO = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(AUDIO)


def write(root, path, content=""):
    target = root / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content)
    return target


def hardware(root, ssid="17aa3907"):
    write(root, "sys/class/dmi/id/sys_vendor", "LENOVO\n")
    write(root, "sys/class/dmi/id/product_name", "83F5\n")
    (root / "sys/bus/acpi/devices/AWDZ8399:00").mkdir(parents=True)
    write(root, "proc/asound/card1/codec#0", f"Codec: Realtek ALC287\nSubsystem Id: 0x{ssid}\n")


class LegionAudioTests(unittest.TestCase):
    def test_kernel_updates_prepare_firmware_before_initramfs(self):
        hook = ROOT / "system/pacman-hooks/85-spectrumos-legion-audio.hook"
        content = hook.read_text()
        self.assertIn("Operation = Install", content)
        self.assertIn("Operation = Upgrade", content)
        self.assertIn("Target = linux\n", content)
        self.assertIn("Target = linux-*\n", content)
        self.assertIn("When = PostTransaction", content)
        self.assertIn("Exec = /usr/bin/spectrum-legion-audio setup", content)
        self.assertLess(hook.name, "90-mkinitcpio-install.hook")

    def test_only_matching_hardware_is_detected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.assertIsNone(AUDIO.detect_hardware(root))
            hardware(root)
            self.assertEqual(AUDIO.detect_hardware(root), "17aa3907")
            write(root, "sys/class/dmi/id/product_name", "different-model")
            self.assertIsNone(AUDIO.detect_hardware(root))

    def test_other_codec_or_missing_amplifier_is_not_supported(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            hardware(root, "17aa3938")
            self.assertIsNone(AUDIO.detect_hardware(root))
            write(root, "proc/asound/card1/codec#0", "Codec: Realtek ALC287\nSubsystem Id: 0x17aa3906\n")
            self.assertEqual(AUDIO.detect_hardware(root), "17aa3906")
            (root / "sys/bus/acpi/devices/AWDZ8399:00").rmdir()
            self.assertIsNone(AUDIO.detect_hardware(root))

    def test_status_is_read_only_and_reports_missing_driver(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            hardware(root)
            with mock.patch.object(AUDIO, "driver_available", return_value=False), mock.patch.object(
                AUDIO, "download_firmware"
            ) as download:
                report = AUDIO.status(root)
            self.assertFalse(report["driver_available"])
            self.assertEqual(len(report["missing_firmware"]), 2)
            self.assertIn("7.3", report["kernel_action"])
            self.assertFalse((root / "usr").exists())
            download.assert_not_called()

    def test_install_prepares_legacy_and_model_specific_names(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with mock.patch.object(AUDIO, "download_firmware", return_value=b"verified firmware") as download:
                installed = AUDIO.install_missing_firmware("17aa3907", root)
                self.assertEqual(len(installed), 2)
                for path in AUDIO.firmware_paths("17aa3907", root):
                    self.assertEqual(path.read_bytes(), b"verified firmware")
                    self.assertEqual(path.stat().st_mode & 0o777, 0o644)
                self.assertEqual(AUDIO.install_missing_firmware("17aa3907", root), [])
                download.assert_called_once()
            self.assertFalse(list((root / "usr/lib/firmware").glob("**/.spectrum-aw88399-*")))

    def test_existing_native_or_compressed_firmware_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            legacy, modern = AUDIO.firmware_paths("17aa3907", root)
            legacy.parent.mkdir(parents=True)
            legacy.write_bytes(b"native legacy")
            modern.parent.mkdir()
            compressed = Path(str(modern) + ".zst")
            compressed.write_bytes(b"native compressed")
            with mock.patch.object(AUDIO, "download_firmware") as download:
                self.assertEqual(AUDIO.install_missing_firmware("17aa3907", root), [])
                download.assert_not_called()
            self.assertEqual(legacy.read_bytes(), b"native legacy")
            self.assertFalse(modern.exists())
            self.assertEqual(compressed.read_bytes(), b"native compressed")

    def test_bad_download_leaves_no_firmware_or_directories(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            response = mock.MagicMock()
            response.__enter__.return_value.read.return_value = b"bad firmware"
            with mock.patch.object(AUDIO.urllib.request, "urlopen", return_value=response):
                with self.assertRaisesRegex(ValueError, "verification failed"):
                    AUDIO.install_missing_firmware("17aa3907", root)
            self.assertFalse((root / "usr").exists())

    def test_same_size_wrong_checksum_is_rejected(self):
        response = mock.MagicMock()
        response.__enter__.return_value.read.return_value = b"x" * AUDIO.FIRMWARE_SIZE
        with mock.patch.object(AUDIO.urllib.request, "urlopen", return_value=response):
            with self.assertRaisesRegex(ValueError, "verification failed"):
                AUDIO.download_firmware()

    def test_network_failure_leaves_no_partial_firmware(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with mock.patch.object(AUDIO.urllib.request, "urlopen", side_effect=OSError("offline")):
                with self.assertRaisesRegex(OSError, "offline"):
                    AUDIO.install_missing_firmware("17aa3907", root)
            self.assertFalse((root / "usr").exists())

    def test_verified_existing_firmware_can_prepare_new_name_offline(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            legacy, modern = AUDIO.firmware_paths("17aa3907", root)
            legacy.parent.mkdir(parents=True)
            payload = b"verified existing firmware"
            legacy.write_bytes(payload)
            with mock.patch.object(AUDIO, "FIRMWARE_SIZE", len(payload)), mock.patch.object(
                AUDIO, "FIRMWARE_SHA256", hashlib.sha256(payload).hexdigest()
            ), mock.patch.object(AUDIO, "download_firmware") as download:
                self.assertEqual(AUDIO.install_missing_firmware("17aa3907", root), [str(modern)])
                download.assert_not_called()
            self.assertEqual(modern.read_bytes(), payload)

    def test_setup_skips_other_hardware_without_network_or_root(self):
        with mock.patch.object(AUDIO, "status", return_value={"supported_hardware": False, "action": "none"}), mock.patch.object(
            AUDIO.os, "geteuid", return_value=1000
        ), mock.patch.object(AUDIO, "download_firmware") as download, mock.patch(
            "sys.argv", ["legion-audio", "setup"]
        ), mock.patch("builtins.print") as output:
            self.assertEqual(AUDIO.main(), 0)
            self.assertFalse(json.loads(output.call_args.args[0])["supported_hardware"])
            download.assert_not_called()

    def test_setup_requires_root_on_supported_hardware(self):
        with mock.patch.object(AUDIO, "status", return_value={"supported_hardware": True}), mock.patch.object(
            AUDIO.os, "geteuid", return_value=1000
        ), mock.patch("sys.argv", ["legion-audio", "setup"]), mock.patch("sys.stderr"):
            with self.assertRaises(SystemExit) as error:
                AUDIO.main()
            self.assertEqual(error.exception.code, 2)

    def test_driver_probe_does_not_load_modules(self):
        with mock.patch.object(AUDIO.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as command:
            self.assertTrue(AUDIO.driver_available())
            self.assertEqual(command.call_args.args[0], ["modinfo", "-F", "filename", AUDIO.DRIVER])


if __name__ == "__main__":
    unittest.main()
