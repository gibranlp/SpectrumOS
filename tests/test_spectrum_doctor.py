import importlib.machinery
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
LOADER = importlib.machinery.SourceFileLoader("spectrum_command", str(ROOT / "scripts" / "spectrum"))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
SPECTRUM = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(SPECTRUM)
RELEASE = ROOT / "system" / "release" / "release.toml"


def result(returncode=0, stdout="", stderr=""):
    return subprocess.CompletedProcess([], returncode, stdout, stderr)


class SpectrumDoctorTests(unittest.TestCase):
    def test_package_integrity_detects_pacman_summary_even_with_success_exit(self):
        def run(command):
            if command[:2] == ["pacman", "-Qkk"] and command[-1] == "spectrum-sddm":
                return result(stdout="spectrum-sddm: 29 total files, 2 altered files\n")
            if command[:2] == ["pacman", "-Qkk"]:
                return result(stdout=f"{command[-1]}: 10 total files, 0 altered files\n")
            return result(stdout=f"{command[-1]} 0.1.0-1\n")

        with mock.patch.object(SPECTRUM, "command_result", side_effect=run):
            check = SPECTRUM.package_integrity_check()

        self.assertEqual(check["status"], "fail")
        self.assertEqual(check["details"], ["integrity mismatch: spectrum-sddm"])

    def test_failed_services_are_reported_by_scope_without_log_content(self):
        responses = [
            result(stdout="example.service loaded failed failed Example\n"),
            result(stdout=""),
        ]
        with mock.patch.object(SPECTRUM, "command_result", side_effect=responses):
            check = SPECTRUM.failed_services_check()

        self.assertEqual(check["status"], "fail")
        self.assertEqual(check["details"], ["system: example.service"])

    def test_disk_thresholds_distinguish_warning_and_failure(self):
        with mock.patch.object(SPECTRUM, "command_output", side_effect=["btrfs", " 88%"]):
            warning = SPECTRUM.disk_check()
        with mock.patch.object(SPECTRUM, "command_output", side_effect=["btrfs", " 97%"]):
            failure = SPECTRUM.disk_check()

        self.assertEqual(warning["status"], "warn")
        self.assertEqual(failure["status"], "fail")

    def test_root_run_defers_user_session_services(self):
        with mock.patch.object(SPECTRUM.os, "geteuid", return_value=0), mock.patch.object(
            SPECTRUM, "command_result"
        ) as command:
            check = SPECTRUM.active_units_check("portals", ("portal.service",), "Desktop portal")

        self.assertEqual(check["status"], "warn")
        self.assertIn("session-user", check["summary"])
        command.assert_not_called()

    def test_doctor_overall_status_uses_the_most_severe_check(self):
        pass_check = SPECTRUM.check("one", "pass", "healthy")
        warn_check = SPECTRUM.check("two", "warn", "limited")
        fail_check = SPECTRUM.check("three", "fail", "broken")
        patches = (
            mock.patch.object(SPECTRUM, "release_check", return_value=pass_check),
            mock.patch.object(SPECTRUM, "package_integrity_check", return_value=fail_check),
            mock.patch.object(SPECTRUM, "failed_services_check", return_value=warn_check),
            mock.patch.object(SPECTRUM, "active_units_check", return_value=pass_check),
            mock.patch.object(SPECTRUM, "audio_check", return_value=pass_check),
            mock.patch.object(SPECTRUM, "disk_check", return_value=pass_check),
            mock.patch.object(SPECTRUM, "snapshot_check", return_value=pass_check),
            mock.patch.object(SPECTRUM, "bootloader_check", return_value=pass_check),
        )
        with patches[0], patches[1], patches[2], patches[3], patches[4], patches[5], patches[6], patches[7]:
            report = SPECTRUM.collect_doctor(RELEASE)

        self.assertEqual(report["overall"], "fail")
        self.assertEqual(report["counts"], {"pass": 6, "warn": 1, "fail": 1})

    def test_bootloader_check_accepts_readable_limine_config_with_flags(self):
        with tempfile.TemporaryDirectory() as temporary:
            config = Path(temporary) / "limine.conf"
            config.write_text("cmdline: rw quiet splash\n", encoding="utf-8")
            with mock.patch.object(SPECTRUM, "LIMINE_CONFIGS", (config,)), mock.patch.object(
                SPECTRUM, "command_result", return_value=result(stdout="limine 10.0\n")
            ), mock.patch.object(SPECTRUM.os, "geteuid", return_value=0):
                check = SPECTRUM.bootloader_check()

        self.assertEqual(check["status"], "pass")

    def test_bootloader_check_explains_it_needs_root_rather_than_reporting_broken(self):
        with mock.patch.object(SPECTRUM, "command_result", return_value=result(stdout="limine 10.0\n")), \
                mock.patch.object(SPECTRUM.os, "geteuid", return_value=1000):
            check = SPECTRUM.bootloader_check()

        self.assertEqual(check["status"], "warn")
        self.assertIn("requires a root", check["summary"])
        self.assertNotIn("not readable", check["summary"])

    def test_live_json_schema_contains_only_bounded_diagnostic_details(self):
        report = SPECTRUM.collect_doctor(RELEASE)
        payload = json.dumps(report).lower()

        self.assertEqual(report["schema_version"], 1)
        self.assertEqual(len(report["checks"]), 8)
        for forbidden in ("hostname", "username", "machine_id", "serial", "ip_address", "/home/"):
            self.assertNotIn(forbidden, payload)


if __name__ == "__main__":
    unittest.main()
