from pathlib import Path
import hashlib
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]


class ReleaseCheckTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.module = runpy.run_path(str(ROOT / "scripts/check-release"))
        self.action = self.module["check"]
        (self.root / "system/release").mkdir(parents=True)
        (self.root / "system/release/release.toml").write_text('version = "1.0.0"\n')
        theme = self.root / "packages/spectrum-theme"
        (theme / "src/spectrum_theme").mkdir(parents=True)
        (theme / "pyproject.toml").write_text('[project]\nversion = "1.0.0"\n')
        (theme / "src/spectrum_theme/__init__.py").write_text('__version__ = "1.0.0"\n')
        (theme / "PKGBUILD").write_text('pkgver=1.0.0\n')
        (theme / "source.tar").write_bytes(b"source")
        self.info = 'pkgver = 1.0.0\npkgrel = 2\nsource = source.tar\nsha256sums = ' + hashlib.sha256(b"source").hexdigest() + '\n'
        (theme / ".SRCINFO").write_text(self.info)
        self.evidence = Mock(return_value={"buildtool":"devtools"})
        self.repo = {"PACKAGE_NAMES":("spectrum-theme",), "clean_build_evidence":self.evidence, "RepoError":RuntimeError}
        self.original_run = runpy.run_path

    def check(self, artifacts=False):
        def load(path):
            return self.repo if str(path).endswith('spectrum-repo') else self.original_run(path)
        with patch.dict(self.action.__globals__,ROOT=self.root), patch.object(runpy,"run_path",side_effect=load), \
             patch.object(subprocess,"run",return_value=subprocess.CompletedProcess([],0,self.info,"")), \
             patch.object(subprocess,"check_output",return_value="/tmp/artifact.pkg.tar.zst\n"):
            return self.action(artifacts)

    def test_sources_validate_without_claiming_artifact_verification(self):
        result=self.check()
        self.assertTrue(result['ok'])
        self.assertFalse(result['artifacts_checked'])
        self.evidence.assert_not_called()

    def test_stale_metadata_or_tampered_source_fails(self):
        (self.root/'packages/spectrum-theme/.SRCINFO').write_text('stale')
        (self.root/'packages/spectrum-theme/source.tar').write_bytes(b'tampered')
        result=self.check()
        self.assertFalse(result['ok'])
        self.assertEqual(len(result['packages'][0]['errors']),2)

    def test_artifact_reuses_strict_clean_build_evidence(self):
        self.evidence.side_effect=RuntimeError('Different PKGBUILD')
        result=self.check(artifacts=True)
        self.assertFalse(result['ok'])
        self.assertIn('Different PKGBUILD',result['packages'][0]['errors'])
