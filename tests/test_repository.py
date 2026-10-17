from pathlib import Path
import os
import subprocess
import sys
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "spectrum-repo"
PUBLISHER = ROOT / "scripts" / "spectrum-repo-publish"


class RepositoryTests(unittest.TestCase):
    def test_repository_channels_enforce_clean_release_builds(self):
        with (ROOT / "repo" / "config.toml").open("rb") as handle:
            config = tomllib.load(handle)

        self.assertFalse(config["channels"]["edge"]["clean_build_required"])
        self.assertTrue(config["channels"]["testing"]["clean_build_required"])
        self.assertTrue(config["channels"]["stable"]["clean_build_required"])

    def test_client_configuration_requires_trusted_package_and_database_signatures(self):
        result = subprocess.run(
            [sys.executable, SCRIPT, "client-config", "--channel", "stable"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )

        self.assertIn("SigLevel = Required DatabaseRequired TrustedOnly", result.stdout)
        self.assertIn("https://spectrum.gibranlp.dev/repo/stable/$arch", result.stdout)
        self.assertNotIn("TrustAll", result.stdout)

    def test_private_repository_state_is_ignored(self):
        ignore = (ROOT / ".gitignore").read_text(encoding="utf-8")

        self.assertIn("repo/state/", ignore)
        self.assertIn("repo/output/", ignore)
        marker = b"BEGIN PGP PRIVATE KEY"
        for path in (ROOT / "repo").rglob("*"):
            if not path.is_file():
                continue
            with path.open("rb") as handle:
                trailing = b""
                while chunk := handle.read(1024 * 1024):
                    self.assertNotIn(marker, trailing + chunk, str(path))
                    trailing = chunk[-len(marker):]

    def test_release_channels_reject_host_builds_by_default(self):
        source = SCRIPT.read_text(encoding="utf-8")

        self.assertIn("clean-chroot evidence is required", source)
        self.assertIn('"build_kind": build_kind', source)
        self.assertIn('"host-development"', source)

    def test_clean_import_requires_devtools_build_evidence(self):
        source = SCRIPT.read_text(encoding="utf-8")

        self.assertIn('single("buildtool") != "devtools"', source)
        self.assertIn('single("startdir") != "/startdir"', source)
        self.assertIn('single("builddir") != "/build"', source)
        self.assertIn('single("pkgbuild_sha256sum") != recipe_checksum', source)
        self.assertIn('"clean-chroot"', source)
        self.assertIn('manifest["build_evidence"] = build_evidence', source)

    def test_configured_public_key_passes_structural_audit(self):
        result = subprocess.run(
            [sys.executable, SCRIPT, "key", "audit-public"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )

        self.assertIn("Trusted primary fingerprint:", result.stdout)
        self.assertIn("Package signing fingerprint:", result.stdout)

    def test_production_audit_accepts_the_separated_signing_subkey(self):
        result = subprocess.run(
            [sys.executable, SCRIPT, "key", "audit-public", "--require-separated-signing-key"],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )

        self.assertEqual(result.returncode, 0)
        self.assertIn("Trusted primary fingerprint:", result.stdout)
        self.assertIn("Package signing fingerprint:", result.stdout)

    def test_production_signing_requires_an_external_gnupg_home(self):
        result = subprocess.run(
            [sys.executable, SCRIPT, "build", "--skip-checks"],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
            env={key: value for key, value in os.environ.items() if key != "SPECTRUM_REPO_GNUPGHOME"},
        )

        self.assertEqual(result.returncode, 1)
        self.assertIn("Production signing requires SPECTRUM_REPO_GNUPGHOME", result.stderr)

    def test_repository_verification_pins_signer_and_primary_fingerprints(self):
        source = SCRIPT.read_text(encoding="utf-8")

        self.assertIn('signer != expected_signer or primary != expected_primary', source)
        self.assertIn('"trusted_primary_fingerprint": primary_fingerprint', source)
        self.assertIn('signing_fingerprint_file', source)
        self.assertIn('SPECTRUM_REPO_GNUPGHOME', source)

    def test_client_first_run_tolerates_an_absent_key(self):
        source = (ROOT / "scripts" / "spectrum-repo-client").read_text(encoding="utf-8")

        self.assertIn("awk -F: '$1 == \"fpr\" { print $10; exit }' || true", source)

    def test_client_and_installer_pin_the_production_trust_root(self):
        client = (ROOT / "scripts" / "spectrum-repo-client").read_text(encoding="utf-8")
        installer = (ROOT / "installer" / "spectrum-installer-backend").read_text(encoding="utf-8")

        self.assertIn("repo/keys/spectrumos-production.asc", client)
        self.assertIn("repo/keys/spectrumos-production.fingerprint", client)
        self.assertIn("repo/keys/spectrumos-production.asc", installer)
        self.assertIn("repo/keys/spectrumos-production.fingerprint", installer)
        self.assertNotIn("repo/keys/spectrumos-development", client)
        self.assertNotIn("repo/keys/spectrumos-development", installer)

    def test_local_repository_is_deployed_outside_the_user_home(self):
        result = subprocess.run(
            [sys.executable, SCRIPT, "client-config", "--channel", "edge", "--local"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
        client = (ROOT / "scripts" / "spectrum-repo-client").read_text(encoding="utf-8")

        self.assertIn("file:///home/", result.stdout)
        self.assertIn('/var/lib/spectrumos/repository/$channel', client)
        self.assertIn('cp -a -- "$local_source/." "$local_repository/"', client)

    def test_publication_plan_targets_the_confirmed_web_root(self):
        result = subprocess.run(
            [sys.executable, PUBLISHER, "testing"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )

        self.assertIn("gibranlp.dev:/home2/gibranlp/spectrum.gibranlp.dev/repo/releases/", result.stdout)
        self.assertIn("https://spectrum.gibranlp.dev/repo/testing/x86_64", result.stdout)
        self.assertIn("Dry-run only", result.stdout)

    def test_repository_configuration_activates_production_signing(self):
        with (ROOT / "repo" / "config.toml").open("rb") as handle:
            config = tomllib.load(handle)

        self.assertEqual(config["signing"]["mode"], "production")
        self.assertEqual(config["signing"]["public_key"], "repo/keys/spectrumos-production.asc")
        self.assertEqual(
            config["signing"]["signing_fingerprint_file"],
            "repo/keys/spectrumos-production-signing.fingerprint",
        )

    def test_publication_requires_exact_confirmation(self):
        result = subprocess.run(
            [sys.executable, PUBLISHER, "testing", "--apply", "--confirm", "edge"],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )

        self.assertEqual(result.returncode, 1)
        self.assertIn("Publication requires --confirm testing", result.stderr)

    def test_publication_uses_versioned_staging_and_atomic_channel_links(self):
        source = PUBLISHER.read_text(encoding="utf-8")

        self.assertIn('"rsync", "--archive", "--checksum", "--delete-delay"', source)
        self.assertIn('["sha256sum", *expected_hashes]', source)
        self.assertIn('["ln", "-sfn", target, next_link]', source)
        self.assertIn('["mv", "-Tf", next_link', source)
        self.assertIn('Remote checksum mismatch', source)


if __name__ == "__main__":
    unittest.main()
