import json
from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]
COMMAND = ROOT / "scripts" / "spectrum"
RELEASE = ROOT / "system" / "release" / "release.toml"
MIGRATIONS = ROOT / "migrations" / "manifest.toml"


class SpectrumInfoTests(unittest.TestCase):
    def test_release_record_has_stable_identity_and_compatibility_versions(self):
        with RELEASE.open("rb") as handle:
            release = tomllib.load(handle)

        self.assertEqual(release["schema_version"], 1)
        self.assertEqual(release["id"], "spectrumos")
        self.assertEqual(release["version"], "1.0.0")
        self.assertEqual(release["channel"], "stable")
        self.assertEqual(release["compatibility"]["release_api"], 1)
        self.assertEqual(release["compatibility"]["migration_api"], 1)

    def test_migration_manifest_declares_idempotency_boundaries(self):
        with MIGRATIONS.open("rb") as handle:
            manifest = tomllib.load(handle)

        self.assertEqual(manifest["schema_version"], 1)
        migration = manifest["migrations"][0]
        self.assertEqual(migration["id"], "0001-release-foundation")
        self.assertTrue(migration["completion"]["marker"].startswith("/var/lib/spectrumos/migrations/"))
        self.assertTrue(migration["preconditions"]["packages"])
        self.assertIn("supported", migration["rollback"])
        self.assertTrue(migration["rollback"]["notes"])

    def test_json_output_is_machine_readable_and_omits_sensitive_identity(self):
        result = subprocess.run(
            ["python", str(COMMAND), "info", "--json", "--release-file", str(RELEASE)],
            check=True,
            capture_output=True,
            text=True,
        )
        info = json.loads(result.stdout)

        self.assertEqual(info["release"]["version"], "1.0.0")
        self.assertIn("kernel", info["system"])
        self.assertIn("gpus", info["system"])
        self.assertIn("spectrum-base", info["packages"])
        serialized = result.stdout.lower()
        for forbidden in ("hostname", "username", "machine_id", "serial", "ip_address", "home"):
            self.assertNotIn(forbidden, serialized)

    def test_invalid_release_metadata_fails_closed(self):
        with tempfile.TemporaryDirectory() as temporary:
            release = Path(temporary) / "release.toml"
            release.write_text('schema_version = 99\nname = "Invalid"\n', encoding="utf-8")
            result = subprocess.run(
                ["python", str(COMMAND), "info", "--release-file", str(release)],
                check=False,
                capture_output=True,
                text=True,
            )

        self.assertEqual(result.returncode, 2)
        self.assertIn("missing or invalid", result.stderr)


if __name__ == "__main__":
    unittest.main()

