import importlib.machinery
import importlib.util
import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
LOADER = importlib.machinery.SourceFileLoader("spectrum_update", str(ROOT / "scripts" / "spectrum"))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
SPECTRUM = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(SPECTRUM)
RELEASE = ROOT / "system" / "release" / "release.toml"
MANIFEST = ROOT / "migrations" / "manifest.toml"


def result(returncode=0, stdout="", stderr=""):
    return subprocess.CompletedProcess([], returncode, stdout, stderr)


class UpdatePlanTests(unittest.TestCase):
    def test_manifest_is_ordered_and_declares_external_completion_state(self):
        manifest = SPECTRUM.read_migration_manifest(MANIFEST)
        identifiers = [item["id"] for item in manifest["migrations"]]

        self.assertEqual(identifiers, sorted(identifiers))
        self.assertEqual(len(identifiers), len(set(identifiers)))
        for migration in manifest["migrations"]:
            self.assertEqual(
                migration["completion"]["marker"],
                f"/var/lib/spectrumos/migrations/{migration['id']}.complete",
            )

    def test_manifest_rejects_a_completion_marker_outside_the_state_boundary(self):
        content = MANIFEST.read_text(encoding="utf-8").replace(
            "/var/lib/spectrumos/migrations/0001-release-foundation.complete",
            "/tmp/complete",
        )
        with tempfile.TemporaryDirectory() as temporary:
            manifest = Path(temporary) / "manifest.toml"
            manifest.write_text(content, encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "completion contract"):
                SPECTRUM.read_migration_manifest(manifest)

    def test_completion_marker_must_match_the_migration(self):
        migration = SPECTRUM.read_migration_manifest(MANIFEST)["migrations"][0]
        with tempfile.TemporaryDirectory() as temporary:
            system_root = Path(temporary)
            marker = SPECTRUM.projected_path(migration["completion"]["marker"], system_root)
            marker.parent.mkdir(parents=True)
            marker.write_text(
                json.dumps({"schema_version": 1, "migration_id": "0002-wrong"}),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "does not match"):
                SPECTRUM.completion_state(migration, system_root)

    def test_update_plan_is_executable_after_clean_preflight(self):
        with tempfile.TemporaryDirectory() as temporary:
            system_root = Path(temporary)
            release_target = system_root / "usr/share/spectrumos/release.toml"
            release_target.parent.mkdir(parents=True)
            release_target.write_text(RELEASE.read_text(encoding="utf-8"), encoding="utf-8")

            def run(command):
                if command == ["spectrum-snapshot", "status"]:
                    return result(stdout="supported\n")
                if command == ["pacman", "-Qu"]:
                    return result(1)
                if command == ["pacman", "-Qm"]:
                    return result(stdout="spectrum-base 0.1.0-11\nparu 2.1.0\n")
                if command[0] == "vercmp":
                    return result(stdout="1\n")
                return result(stdout="spectrum-base 0.1.0-11\n")

            usage = mock.Mock(free=20 * 1024**3)
            with mock.patch.object(SPECTRUM, "command_result", side_effect=run), mock.patch.object(
                SPECTRUM.shutil, "disk_usage", return_value=usage
            ):
                plan = SPECTRUM.collect_update_plan(RELEASE, MANIFEST, system_root)

        self.assertTrue(plan["ready_for_dry_run"])
        self.assertTrue(plan["execution_enabled"])
        self.assertTrue(plan["ready_for_execution"])
        self.assertEqual(plan["packages"]["local_spectrum"]["names"], ["spectrum-base"])
        self.assertEqual(plan["packages"]["foreign"]["names"], ["paru"])
        self.assertEqual(
            {gate["id"]: gate["status"] for gate in plan["safety_gates"]},
            {
                "snapshot-retention": "pass",
                "interrupted-transaction-recovery": "pass",
                "migration-executor": "pass",
            },
        )

    def test_pacman_lock_is_a_preflight_blocker(self):
        with tempfile.TemporaryDirectory() as temporary:
            system_root = Path(temporary)
            release_target = system_root / "usr/share/spectrumos/release.toml"
            release_target.parent.mkdir(parents=True)
            release_target.write_text(RELEASE.read_text(encoding="utf-8"), encoding="utf-8")
            lock = SPECTRUM.projected_path(str(SPECTRUM.PACMAN_LOCK), system_root)
            lock.parent.mkdir(parents=True)
            lock.touch()
            usage = mock.Mock(free=20 * 1024**3)
            def run(command):
                if command[0] == "vercmp":
                    return result(stdout="1\n")
                return result(stdout="spectrum-base 0.1.0-11\n")
            with mock.patch.object(
                SPECTRUM,
                "command_result",
                side_effect=run,
            ), mock.patch.object(SPECTRUM.shutil, "disk_usage", return_value=usage):
                plan = SPECTRUM.collect_update_plan(RELEASE, MANIFEST, system_root)

        self.assertEqual(plan["preflight"]["pacman_lock"]["status"], "fail")
        self.assertIn("Pacman database lock is present", plan["blockers"])
        self.assertFalse(plan["ready_for_dry_run"])

    def test_unmatched_pacman_transaction_start_is_a_preflight_blocker(self):
        with tempfile.TemporaryDirectory() as temporary:
            system_root = Path(temporary)
            release_target = system_root / "usr/share/spectrumos/release.toml"
            release_target.parent.mkdir(parents=True)
            release_target.write_text(RELEASE.read_text(encoding="utf-8"), encoding="utf-8")
            log = SPECTRUM.projected_path(str(SPECTRUM.PACMAN_LOG), system_root)
            log.parent.mkdir(parents=True)
            log.write_text(
                "[2026-09-01T10:00:00+0000] [ALPM] transaction completed\n"
                "[2026-09-01T11:00:00+0000] [ALPM] transaction started\n",
                encoding="utf-8",
            )
            usage = mock.Mock(free=20 * 1024**3)

            def run(command):
                if command == ["spectrum-snapshot", "status"]:
                    return result(stdout="supported\n")
                if command in (["pacman", "-Qu"], ["pacman", "-Qm"]):
                    return result(1)
                if command[0] == "vercmp":
                    return result(stdout="1\n")
                return result(stdout="spectrum-base 0.1.0-11\n")

            with mock.patch.object(SPECTRUM, "command_result", side_effect=run), mock.patch.object(
                SPECTRUM.shutil, "disk_usage", return_value=usage
            ):
                plan = SPECTRUM.collect_update_plan(RELEASE, MANIFEST, system_root)

        self.assertEqual(plan["preflight"]["pacman_transaction"]["status"], "fail")
        self.assertIn("Pacman log indicates an interrupted transaction", plan["blockers"])

    def test_completed_pacman_transaction_history_passes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            log = SPECTRUM.projected_path(str(SPECTRUM.PACMAN_LOG), root)
            log.parent.mkdir(parents=True)
            log.write_text(
                "[2026-09-01T10:00:00+0000] [ALPM] transaction started\n"
                "[2026-09-01T10:01:00+0000] [ALPM] transaction completed\n",
                encoding="utf-8",
            )
            state = SPECTRUM.pacman_transaction_state(root)
        self.assertEqual(state, {"status": "pass", "last_event": "completed"})

    def test_successful_boot_restore_clears_an_older_interrupted_transaction(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            log = SPECTRUM.projected_path(str(SPECTRUM.PACMAN_LOG), root)
            log.parent.mkdir(parents=True)
            log.write_text(
                "[2026-09-01T11:00:00+0000] [ALPM] transaction started\n",
                encoding="utf-8",
            )
            marker = SPECTRUM.projected_path(str(SPECTRUM.BOOT_RESTORE_MARKER), root)
            marker.parent.mkdir(parents=True)
            marker.write_text(
                json.dumps({"schema": 1, "restored_utc": "2026-09-01T11:05:00Z"}),
                encoding="utf-8",
            )
            state = SPECTRUM.pacman_transaction_state(root)
        self.assertEqual(state, {"status": "pass", "last_event": "restored"})

    def test_boot_restore_does_not_clear_a_newer_interrupted_transaction(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            log = SPECTRUM.projected_path(str(SPECTRUM.PACMAN_LOG), root)
            log.parent.mkdir(parents=True)
            log.write_text(
                "[2026-09-01T11:10:00+0000] [ALPM] transaction started\n",
                encoding="utf-8",
            )
            marker = SPECTRUM.projected_path(str(SPECTRUM.BOOT_RESTORE_MARKER), root)
            marker.parent.mkdir(parents=True)
            marker.write_text(
                json.dumps({"schema": 1, "restored_utc": "2026-09-01T11:05:00Z"}),
                encoding="utf-8",
            )
            state = SPECTRUM.pacman_transaction_state(root)
        self.assertEqual(state, {"status": "fail", "last_event": "started"})

    def test_package_requirement_parser_rejects_shell_syntax(self):
        for requirement in ("pkg >= 1", "pkg;command", "$(command)"):
            with self.assertRaises(ValueError):
                SPECTRUM.package_requirement(requirement)

    def test_migration_apply_writes_an_atomic_valid_marker_and_is_idempotent(self):
        migrations = SPECTRUM.read_migration_manifest(MANIFEST)["migrations"]
        migration = migrations[0]
        with tempfile.TemporaryDirectory() as temporary:
            system_root = Path(temporary)
            release = SPECTRUM.projected_path("/usr/share/spectrumos/release.toml", system_root)
            release.parent.mkdir(parents=True)
            release.write_text(RELEASE.read_text(encoding="utf-8"), encoding="utf-8")
            with mock.patch.object(SPECTRUM.os, "geteuid", return_value=0), mock.patch.object(
                SPECTRUM, "requirement_satisfied", return_value=True
            ):
                first = SPECTRUM.apply_migrations(MANIFEST, system_root)
                second = SPECTRUM.apply_migrations(MANIFEST, system_root)
            marker = SPECTRUM.projected_path(migration["completion"]["marker"], system_root)
            payload = json.loads(marker.read_text(encoding="utf-8"))

        self.assertEqual(first["applied"], [item["id"] for item in migrations])
        self.assertEqual(second["already_completed"], [item["id"] for item in migrations])
        self.assertEqual(payload["schema_version"], 1)
        self.assertEqual(payload["migration_id"], migration["id"])
        self.assertEqual(payload["to_version"], migration["to_version"])
        self.assertIn("completed_at", payload)

    def test_migration_apply_preflights_everything_before_writing_state(self):
        migration = SPECTRUM.read_migration_manifest(MANIFEST)["migrations"][0]
        with tempfile.TemporaryDirectory() as temporary:
            system_root = Path(temporary)
            marker = SPECTRUM.projected_path(migration["completion"]["marker"], system_root)
            with mock.patch.object(SPECTRUM.os, "geteuid", return_value=0), mock.patch.object(
                SPECTRUM, "requirement_satisfied", return_value=True
            ):
                with self.assertRaisesRegex(ValueError, "migration preflight failed"):
                    SPECTRUM.apply_migrations(MANIFEST, system_root)
            self.assertFalse(marker.exists())

    def test_migration_apply_refuses_a_pacman_lock(self):
        migration = SPECTRUM.read_migration_manifest(MANIFEST)["migrations"][0]
        with tempfile.TemporaryDirectory() as temporary:
            system_root = Path(temporary)
            release = SPECTRUM.projected_path("/usr/share/spectrumos/release.toml", system_root)
            release.parent.mkdir(parents=True)
            release.write_text(RELEASE.read_text(encoding="utf-8"), encoding="utf-8")
            lock = SPECTRUM.projected_path(str(SPECTRUM.PACMAN_LOCK), system_root)
            lock.parent.mkdir(parents=True)
            lock.touch()
            with mock.patch.object(SPECTRUM.os, "geteuid", return_value=0), mock.patch.object(
                SPECTRUM, "requirement_satisfied", return_value=True
            ):
                with self.assertRaisesRegex(ValueError, "Pacman database lock"):
                    SPECTRUM.apply_migrations(MANIFEST, system_root)
            marker = SPECTRUM.projected_path(migration["completion"]["marker"], system_root)
            self.assertFalse(marker.exists())

    def test_interrupted_marker_replace_leaves_no_completed_migration(self):
        migration = SPECTRUM.read_migration_manifest(MANIFEST)["migrations"][0]
        with tempfile.TemporaryDirectory() as temporary:
            system_root = Path(temporary)
            release = SPECTRUM.projected_path("/usr/share/spectrumos/release.toml", system_root)
            release.parent.mkdir(parents=True)
            release.write_text(RELEASE.read_text(encoding="utf-8"), encoding="utf-8")
            marker = SPECTRUM.projected_path(migration["completion"]["marker"], system_root)
            with mock.patch.object(SPECTRUM.os, "geteuid", return_value=0), mock.patch.object(
                SPECTRUM, "requirement_satisfied", return_value=True
            ), mock.patch.object(SPECTRUM.os, "replace", side_effect=OSError("interrupted")):
                with self.assertRaisesRegex(OSError, "interrupted"):
                    SPECTRUM.apply_migrations(MANIFEST, system_root)
            self.assertFalse(marker.exists())
            self.assertEqual(list(marker.parent.glob(".*.tmp")), [])

    def test_migration_rollback_requires_exact_confirmation_and_is_idempotent(self):
        migration = SPECTRUM.read_migration_manifest(MANIFEST)["migrations"][-1]
        with tempfile.TemporaryDirectory() as temporary:
            system_root = Path(temporary)
            release = SPECTRUM.projected_path("/usr/share/spectrumos/release.toml", system_root)
            release.parent.mkdir(parents=True)
            release.write_text(RELEASE.read_text(encoding="utf-8"), encoding="utf-8")
            with mock.patch.object(SPECTRUM.os, "geteuid", return_value=0), mock.patch.object(
                SPECTRUM, "requirement_satisfied", return_value=True
            ):
                SPECTRUM.apply_migrations(MANIFEST, system_root)
                with self.assertRaisesRegex(ValueError, "--confirm"):
                    SPECTRUM.rollback_migration(MANIFEST, system_root, migration["id"], "wrong")
                first = SPECTRUM.rollback_migration(
                    MANIFEST, system_root, migration["id"], migration["id"]
                )
                second = SPECTRUM.rollback_migration(
                    MANIFEST, system_root, migration["id"], migration["id"]
                )

        self.assertEqual(first["rolled_back"], [migration["id"]])
        self.assertEqual(second["already_pending"], [migration["id"]])

    def test_migration_changes_require_root(self):
        with tempfile.TemporaryDirectory() as temporary, mock.patch.object(
            SPECTRUM.os, "geteuid", return_value=1000
        ):
            with self.assertRaisesRegex(ValueError, "require root"):
                SPECTRUM.apply_migrations(MANIFEST, Path(temporary))

    def test_completion_marker_rejects_symlinks(self):
        migration = SPECTRUM.read_migration_manifest(MANIFEST)["migrations"][0]
        with tempfile.TemporaryDirectory() as temporary:
            system_root = Path(temporary)
            marker = SPECTRUM.projected_path(migration["completion"]["marker"], system_root)
            marker.parent.mkdir(parents=True)
            marker.symlink_to(Path(temporary) / "missing")
            with self.assertRaisesRegex(ValueError, "cannot be a symlink"):
                SPECTRUM.completion_state(migration, system_root)

    def test_tmpfiles_owns_the_root_only_migration_state_directory(self):
        policy = (ROOT / "system/tmpfiles.d/spectrumos-appearance.conf").read_text(encoding="utf-8")
        self.assertIn("d /var/lib/spectrumos/migrations 0755 root root -", policy)

    def test_migration_rollback_refuses_to_skip_a_later_completion(self):
        first = copy.deepcopy(SPECTRUM.read_migration_manifest(MANIFEST)["migrations"][0])
        second = copy.deepcopy(first)
        second["id"] = "0002-later"
        second["completion"]["marker"] = "/var/lib/spectrumos/migrations/0002-later.complete"
        manifest = {"schema_version": 1, "release_api": 1, "migrations": [first, second]}
        with tempfile.TemporaryDirectory() as temporary:
            system_root = Path(temporary)
            SPECTRUM.write_completion_marker(first, system_root)
            SPECTRUM.write_completion_marker(second, system_root)
            with mock.patch.object(SPECTRUM.os, "geteuid", return_value=0), mock.patch.object(
                SPECTRUM, "read_migration_manifest", return_value=manifest
            ):
                with self.assertRaisesRegex(ValueError, "newest completed migration"):
                    SPECTRUM.rollback_migration(MANIFEST, system_root, first["id"], first["id"])


if __name__ == "__main__":
    unittest.main()
