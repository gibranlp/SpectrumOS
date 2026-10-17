import importlib.machinery
import importlib.util
import io
import subprocess
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
LOADER = importlib.machinery.SourceFileLoader(
    "spectrum_pre_upgrade_snapshot", str(ROOT / "scripts" / "pre-upgrade-snapshot")
)
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
HOOK = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(HOOK)


def completed(returncode: int, stdout: str = "", stderr: str = "") -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess(args=[], returncode=returncode, stdout=stdout, stderr=stderr)


class PreUpgradeSnapshotTests(unittest.TestCase):
    def test_reports_only_identifier_after_btrfs_progress_output(self):
        identifier = "20261015T152710Z-pre-upgrade"
        result = completed(0, "Create readonly snapshot of source in destination\n" + identifier + "\n")
        output = io.StringIO()
        with mock.patch.object(HOOK, "snapshot_supported", return_value=True), \
             mock.patch.object(HOOK, "create_snapshot", return_value=result), \
             mock.patch.object(HOOK, "enforce_cap", return_value=completed(0)), \
             mock.patch("sys.stdout", output):
            self.assertEqual(HOOK.main(), 0)
        self.assertEqual(output.getvalue(), "spectrum: created pre-upgrade restore point " + identifier + "\n")

    def test_skips_without_aborting_when_root_is_not_btrfs(self):
        with mock.patch.object(HOOK, "snapshot_supported", return_value=False):
            with mock.patch.object(HOOK, "create_snapshot") as create, mock.patch.object(
                HOOK, "enforce_cap"
            ) as cap:
                self.assertEqual(HOOK.main(), 0)
                create.assert_not_called()
                cap.assert_not_called()

    def test_creates_a_labeled_restore_point_and_enforces_the_cap_when_supported(self):
        with mock.patch.object(HOOK, "snapshot_supported", return_value=True):
            with mock.patch.object(
                HOOK, "create_snapshot", return_value=completed(0, stdout="20260905T000000Z-pre-upgrade\n")
            ) as create, mock.patch.object(
                HOOK, "enforce_cap", return_value=completed(0, stdout="pruned: 20260101T000000Z-pre-upgrade\n")
            ) as cap:
                self.assertEqual(HOOK.main(), 0)
                create.assert_called_once_with(HOOK.SNAPSHOT_LABEL)
                cap.assert_called_once_with(HOOK.RESTORE_POINT_CAP)

    def test_aborts_the_transaction_when_snapshot_creation_fails(self):
        with mock.patch.object(HOOK, "snapshot_supported", return_value=True):
            with mock.patch.object(
                HOOK, "create_snapshot", return_value=completed(1, stderr="No space left on device")
            ), mock.patch.object(HOOK, "enforce_cap") as cap:
                self.assertEqual(HOOK.main(), 1)
                cap.assert_not_called()

    def test_a_cap_enforcement_failure_does_not_abort_an_already_safe_upgrade(self):
        with mock.patch.object(HOOK, "snapshot_supported", return_value=True):
            with mock.patch.object(
                HOOK, "create_snapshot", return_value=completed(0, stdout="20260905T000000Z-pre-upgrade\n")
            ), mock.patch.object(
                HOOK, "enforce_cap", return_value=completed(1, stderr="Restore point does not exist")
            ):
                self.assertEqual(HOOK.main(), 0)

    def test_snapshot_supported_reflects_the_status_exit_code(self):
        with mock.patch.object(subprocess, "run", return_value=completed(0)) as run:
            self.assertTrue(HOOK.snapshot_supported())
            run.assert_called_once_with(
                ["spectrum-snapshot", "status"], capture_output=True, text=True, check=False
            )
        with mock.patch.object(subprocess, "run", return_value=completed(1)):
            self.assertFalse(HOOK.snapshot_supported())


if __name__ == "__main__":
    unittest.main()
