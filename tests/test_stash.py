from pathlib import Path
import json
import io
import os
import subprocess
import tempfile
import tarfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class StashIntegrationTests(unittest.TestCase):
    def test_launcher_preserves_paths_with_spaces(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            kitty = directory / "kitty"
            kitty.write_text("#!/usr/bin/env python3\nimport json, os, sys\nfrom pathlib import Path\nPath(os.environ['STASH_TEST_ARGUMENTS']).write_text(json.dumps(sys.argv[1:]))\n")
            kitty.chmod(0o755)
            output = directory / "arguments.json"
            track = "/music/Artist Name/Album Name/01 Song.flac"
            environment = {**os.environ, "PATH": f"{directory}:{os.environ['PATH']}",
                           "STASH_BINARY": "/usr/bin/true", "STASH_TEST_ARGUMENTS": str(output)}
            subprocess.run(["bash", str(ROOT / "scripts/stash-open"), track], env=environment, check=True)
            self.assertEqual(json.loads(output.read_text()), ["--class", "stash", "-e", "/usr/bin/true", track])

    def test_missing_binary_fails_before_starting_terminal(self):
        result = subprocess.run(["bash", str(ROOT / "scripts/stash-open")],
                                env={**os.environ, "STASH_BINARY": "/nonexistent/stash"},
                                text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 1)
        self.assertIn("Install or update spectrum-desktop", result.stderr)

    def test_launcher_entry_is_valid(self):
        subprocess.run(["desktop-file-validate", str(ROOT / "integrations/stash/stash.desktop")], check=True)

    def test_iso_target_gets_stash_from_signed_desktop_package(self):
        recipe_path = ROOT / "packages/spectrum-desktop/PKGBUILD"
        if not recipe_path.exists():
            recipe_path = Path("/startdir/PKGBUILD")
        recipe = recipe_path.read_text()
        backend = (ROOT / "installer/spectrum-installer-backend").read_text()
        self.assertIn('"$srcdir/stash-$_stash_version-linux-x86_64" "$pkgdir/usr/bin/stash"', recipe)
        self.assertIn('"$srcdir/questline-$_questline_version-linux-x86_64" "$pkgdir/usr/bin/questline"', recipe)
        self.assertIn('pacman -Syu --needed --noconfirm spectrum-desktop', backend)
        self.assertIn('run arch-chroot "$target" test -x /usr/bin/stash', backend)
        self.assertIn('run arch-chroot "$target" /usr/bin/questline --version', backend)
        self.assertIn('bash "$project_root/scripts/check-bundled-apps" "$repository"',
                      (ROOT / "scripts/build-iso").read_text())
        self.assertIn('SigLevel = Required DatabaseRequired TrustedOnly', backend)
        self.assertNotIn('cargo', backend)

    def test_iso_preflight_checks_indexed_package_for_both_apps(self):
        required = ("usr/bin/stash", "usr/bin/questline", "usr/lib/spectrumos/stash-open",
                    "usr/lib/spectrumos/questline-open", "usr/share/applications/stash.desktop")
        with tempfile.TemporaryDirectory() as temporary:
            repository = Path(temporary)
            filename = "spectrum-desktop-0.1.0-162-x86_64.pkg.tar.zst"
            with tarfile.open(repository / "spectrumos.db.tar.zst", "w") as archive:
                payload = f"%NAME%\nspectrum-desktop\n\n%FILENAME%\n{filename}\n".encode()
                entry = tarfile.TarInfo("spectrum-desktop-0.1.0-162/desc")
                entry.size = len(payload)
                archive.addfile(entry, io.BytesIO(payload))
            for missing in (None, *required):
                with self.subTest(missing=missing):
                    with tarfile.open(repository / filename, "w") as archive:
                        for name in required:
                            if name != missing:
                                archive.addfile(tarfile.TarInfo(name))
                    result = subprocess.run(["bash", str(ROOT / "scripts/check-bundled-apps"), str(repository)],
                                            capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0 if missing is None else 1, result.stderr)
                    if missing:
                        self.assertIn(missing, result.stderr)
            (repository / filename).unlink()
            result = subprocess.run(["bash", str(ROOT / "scripts/check-bundled-apps"), str(repository)],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn("indexed spectrum-desktop artifact", result.stderr)
