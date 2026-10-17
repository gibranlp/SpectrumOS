import datetime as dt
import importlib.machinery
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import subprocess
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
LOADER = importlib.machinery.SourceFileLoader("spectrum_snapshot", str(ROOT / "scripts" / "snapshot"))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
SNAPSHOT = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(SNAPSHOT)


class SnapshotTests(unittest.TestCase):
    def test_identifier_is_utc_and_normalizes_label(self):
        moment = dt.datetime(2026, 8, 31, 20, 15, 12, tzinfo=dt.timezone.utc)
        self.assertEqual(
            SNAPSHOT.snapshot_id("Before NVIDIA / kernel", moment),
            "20260831T201512Z-before-nvidia-kernel",
        )

    def test_identifier_rejects_empty_normalized_label(self):
        with self.assertRaises(SNAPSHOT.SnapshotError):
            SNAPSHOT.snapshot_id("---")

    def test_identifier_validation_blocks_paths(self):
        for value in ("../@", "/root", "20260831T201512Z_OK", "anything"):
            with self.assertRaises(SNAPSHOT.SnapshotError):
                SNAPSHOT.require_snapshot_id(value)

    def test_entries_only_returns_complete_named_metadata(self):
        with tempfile.TemporaryDirectory() as temporary:
            top = Path(temporary)
            complete = top / SNAPSHOT.SNAPSHOT_ROOT / "20260831T201512Z-upgrade"
            complete.mkdir(parents=True)
            (complete / "metadata.json").write_text(
                '{"id":"20260831T201512Z-upgrade","created_utc":"now","packages":[]}',
                encoding="utf-8",
            )
            incomplete = top / SNAPSHOT.SNAPSHOT_ROOT / "20260831T201513Z"
            incomplete.mkdir()
            self.assertEqual([item["id"] for item in SNAPSHOT.entries(top)], ["20260831T201512Z-upgrade"])

    def test_rollback_plan_requires_offline_root_and_boot_pair(self):
        plan = SNAPSHOT.rollback_plan({
            "id": "20260831T201512Z-upgrade",
            "snapshot_subvolume": "@snapshots/spectrumos/20260831T201512Z-upgrade/root",
        })
        self.assertIn("recovery media", plan)
        self.assertIn("EFI /boot", plan)
        self.assertIn("Do not replace the mounted live root", plan)

    def test_restore_confirmation_and_target_are_strict(self):
        with self.assertRaises(SNAPSHOT.SnapshotError):
            SNAPSHOT.require_root_subvolume("@/../../root")
        self.assertEqual(SNAPSHOT.require_root_subvolume("@"), "@")
        self.assertEqual(SNAPSHOT.require_root_subvolume("@system-old"), "@system-old")

    def test_restore_refuses_running_root_device(self):
        with self.assertRaises(SNAPSHOT.SnapshotError):
            SNAPSHOT.ensure_offline("/dev/vda2", "/dev/vda2")

    def test_retention_plan_is_conservative_and_never_enables_deletion(self):
        now = dt.datetime(2026, 9, 1, 12, 0, tzinfo=dt.timezone.utc)
        items = []
        for offset in range(20):
            created = now - dt.timedelta(days=offset)
            items.append(
                {
                    "id": f"202608{31 - offset:02d}T120000Z-test" if offset < 31 else "unused",
                    "created_utc": created.isoformat(),
                }
            )
        plan = SNAPSHOT.retention_plan(items, now)

        self.assertFalse(plan["deletion_enabled"])
        self.assertEqual(plan["mode"], "read-only")
        self.assertGreater(plan["counts"]["candidates"], 0)
        self.assertTrue(all(item["decision"] in {"retain", "candidate"} for item in plan["restore_points"]))
        self.assertEqual(
            [item["decision"] for item in plan["restore_points"][: SNAPSHOT.RETENTION_LATEST]],
            ["retain"] * SNAPSHOT.RETENTION_LATEST,
        )

    def test_retention_plan_always_keeps_protected_restore_points(self):
        now = dt.datetime(2026, 9, 1, tzinfo=dt.timezone.utc)
        old = {
            "id": "20250101T000000Z-protected",
            "created_utc": "2025-01-01T00:00:00+00:00",
            "protected": True,
        }
        newer = [
            {
                "id": f"202608{31 - offset:02d}T000000Z",
                "created_utc": (now - dt.timedelta(days=offset)).isoformat(),
            }
            for offset in range(5)
        ]
        plan = SNAPSHOT.retention_plan([old, *newer], now)
        protected = next(item for item in plan["restore_points"] if item["id"] == old["id"])

        self.assertEqual(protected["decision"], "retain")
        self.assertIn("protected", protected["reasons"])

    def test_retention_rejects_future_or_unzoned_creation_times(self):
        now = dt.datetime(2026, 9, 1, tzinfo=dt.timezone.utc)
        with self.assertRaises(SNAPSHOT.SnapshotError):
            SNAPSHOT.retention_plan([{"id": "future", "created_utc": "2026-09-02T00:00:00+00:00"}], now)
        with self.assertRaises(SNAPSHOT.SnapshotError):
            SNAPSHOT.retention_plan([{"id": "unzoned", "created_utc": "2026-08-01T00:00:00"}], now)

    def retention_fixture(self, top: Path):
        now = dt.datetime.now(dt.timezone.utc)
        identifiers = []
        for offset in range(12):
            created = now - dt.timedelta(days=offset * 35)
            identifier = created.strftime("%Y%m%dT%H%M%SZ")
            directory = top / SNAPSHOT.SNAPSHOT_ROOT / identifier
            directory.mkdir(parents=True)
            metadata = {
                "schema": 1,
                "id": identifier,
                "created_utc": created.isoformat(),
                "packages": ["base 1-1"],
            }
            (directory / "metadata.json").write_text(
                json.dumps(metadata), encoding="utf-8"
            )
            (directory / "boot.tar").touch()
            (directory / "root").mkdir()
            identifiers.append(identifier)
        return identifiers

    def test_prune_requires_exact_confirmation_and_candidate(self):
        with tempfile.TemporaryDirectory() as temporary:
            top = Path(temporary)
            identifiers = self.retention_fixture(top)
            candidate = identifiers[-1]
            retained = identifiers[0]
            with self.assertRaisesRegex(SNAPSHOT.SnapshotError, "confirmation"):
                SNAPSHOT.prune(top, candidate, "wrong")
            with self.assertRaisesRegex(SNAPSHOT.SnapshotError, "requires"):
                SNAPSHOT.prune(top, retained, retained)

    def test_interrupted_prune_is_quarantined_and_resumable(self):
        with tempfile.TemporaryDirectory() as temporary:
            top = Path(temporary)
            candidate = self.retention_fixture(top)[-1]

            with mock.patch.object(SNAPSHOT, "validate"), mock.patch.object(
                SNAPSHOT, "run", side_effect=SNAPSHOT.SnapshotError("interrupted")
            ):
                with self.assertRaisesRegex(SNAPSHOT.SnapshotError, "interrupted"):
                    SNAPSHOT.prune(top, candidate, candidate)

            quarantine = top / SNAPSHOT.PRUNING_ROOT / candidate
            self.assertTrue(quarantine.is_dir())
            self.assertFalse((top / SNAPSHOT.SNAPSHOT_ROOT / candidate).exists())

            def delete_subvolume(_command, capture=True):
                (quarantine / "root").rmdir()
                return ""

            with mock.patch.object(SNAPSHOT, "run", side_effect=delete_subvolume):
                self.assertEqual(SNAPSHOT.prune(top, candidate, candidate), candidate)
            self.assertFalse(quarantine.exists())

    def test_snapshot_cli_exposes_confirmed_prune(self):
        result = subprocess.run(
            ["python", str(ROOT / "scripts" / "snapshot"), "--help"],
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertIn("retention", result.stdout)
        self.assertNotIn("delete", result.stdout)
        self.assertIn("prune", result.stdout)
        self.assertIn("enforce-cap", result.stdout)

    def test_with_top_level_targets_an_explicit_device_without_reading_current_root(self):
        import contextlib

        @contextlib.contextmanager
        def fake_mount(source):
            yield Path(f"/fake/{source}")

        with mock.patch.object(SNAPSHOT, "mounted_top_level", side_effect=fake_mount) as mounted, \
                mock.patch.object(SNAPSHOT, "root_mount") as current_root:
            top, mount = None, None

            def capture(top_arg, mount_arg):
                nonlocal top, mount
                top, mount = top_arg, mount_arg

            SNAPSHOT.with_top_level(capture, "/dev/sdb2")

        current_root.assert_not_called()
        mounted.assert_called_once_with("/dev/sdb2")
        self.assertEqual(top, Path("/fake//dev/sdb2"))
        self.assertEqual(mount, {"source": "/dev/sdb2"})

    def test_snapshot_list_accepts_a_root_device_for_recovery_media(self):
        result = subprocess.run(
            ["python", str(ROOT / "scripts" / "snapshot"), "list", "--help"],
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertIn("--root-device", result.stdout)
        self.assertIn("recovery media", result.stdout)

    def test_enforce_cap_keeps_only_the_newest_limit_and_needs_no_confirmation(self):
        with tempfile.TemporaryDirectory() as temporary:
            top = Path(temporary)
            identifiers = self.retention_fixture(top)
            with mock.patch.object(SNAPSHOT, "validate"), mock.patch.object(SNAPSHOT, "run", return_value=""):
                removed = SNAPSHOT.enforce_cap(top, 3)

            self.assertEqual(set(removed), set(identifiers[3:]))
            self.assertEqual([item["id"] for item in SNAPSHOT.entries(top)], identifiers[:3])

    def test_enforce_cap_is_a_no_op_when_under_the_limit(self):
        with tempfile.TemporaryDirectory() as temporary:
            top = Path(temporary)
            identifiers = self.retention_fixture(top)
            self.assertEqual(SNAPSHOT.enforce_cap(top, len(identifiers) + 5), [])
            self.assertEqual(len(SNAPSHOT.entries(top)), len(identifiers))

    def test_enforce_cap_rejects_a_negative_limit(self):
        with tempfile.TemporaryDirectory() as temporary:
            top = Path(temporary)
            self.retention_fixture(top)
            with self.assertRaisesRegex(SNAPSHOT.SnapshotError, "negative"):
                SNAPSHOT.enforce_cap(top, -1)


if __name__ == "__main__":
    unittest.main()
