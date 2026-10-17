import configparser
import importlib.machinery
import importlib.util
import io
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader("ukvm_package_check", str(ROOT / "scripts/check-ukvm-packages"))
spec = importlib.util.spec_from_loader(loader.name, loader)
checker = importlib.util.module_from_spec(spec)
loader.exec_module(checker)


def write_archive(path, files):
    with tarfile.open(path, "w") as archive:
        for name, content in files.items():
            data = content.encode()
            info = tarfile.TarInfo(name)
            info.size = len(data)
            archive.addfile(info, io.BytesIO(data))


class ProductionPackagingTests(unittest.TestCase):
    def repository(self, path, omitted=None):
        entries = {}
        for name, files in checker.REQUIRED.items():
            if name == omitted:
                continue
            filename = name + "-1-1-x86_64.pkg.tar.zst"
            write_archive(path / filename, {file: "" for file in files})
            entries[name + "-1-1/desc"] = f"%NAME%\n{name}\n\n%FILENAME%\n{filename}\n"
        write_archive(path / "spectrumos.db.tar.zst", entries)

    def test_complete_offline_repository_passes(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary)
            self.repository(path)
            self.assertIn("managed Hyprland portal", checker.check(path))

    def test_missing_backend_blocks_future_iso(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary)
            self.repository(path, "spectrum-xdg-desktop-portal-hyprland")
            with self.assertRaisesRegex(ValueError, "missing its indexed"):
                checker.check(path)

    def test_partial_frontend_package_is_not_accepted(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary)
            self.repository(path)
            write_archive(path / "spectrum-desktop-1-1-x86_64.pkg.tar.zst", {})
            with self.assertRaisesRegex(ValueError, "missing required UKVM files"):
                checker.check(path)

    def test_remote_session_package_requires_installed_usage_guides(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary)
            self.repository(path)
            retained = {file: "" for file in checker.REQUIRED["ukvm"]
                        if file != "usr/share/doc/ukvm/REMOTE_SESSIONS.md"}
            write_archive(path / "ukvm-1-1-x86_64.pkg.tar.zst", retained)
            with self.assertRaisesRegex(ValueError, "REMOTE_SESSIONS.md"):
                checker.check(path)

    def test_package_dropins_bind_to_current_session_and_order_backend(self):
        root = ROOT / "packages/spectrum-xdg-desktop-portal-hyprland"
        units = {}
        for name in ("backend", "frontend"):
            parser = configparser.ConfigParser(strict=False, interpolation=None)
            parser.optionxform = str
            parser.read(root / (name + ".conf"))
            units[name] = parser
            self.assertIn("graphical-session.target", parser["Unit"]["BindsTo"])
            self.assertEqual(parser["Unit"]["ConditionEnvironment"], "")
            self.assertEqual(parser["Service"]["Restart"], "on-failure")
            self.assertEqual(parser["Service"]["RestartSec"], "5")
            self.assertIn("/usr/lib/ukvm/ukvm-portal-session", parser["Service"]["ExecStart"])
            self.assertNotIn("/tmp", (root / (name + ".conf")).read_text())
        self.assertIn("xdg-desktop-portal-hyprland.service", units["frontend"]["Unit"]["After"])
        self.assertIn("xdg-desktop-portal-hyprland.service", units["frontend"]["Unit"]["PartOf"])
        self.assertIn("xdg-desktop-portal.service", units["backend"]["Unit"]["Wants"])

    def test_source_export_excludes_dirty_and_untracked_checkout_files(self):
        source_loader = importlib.machinery.SourceFileLoader("ukvm_source_builder", str(ROOT / "scripts/build-ukvm-source"))
        source_spec = importlib.util.spec_from_loader(source_loader.name, source_loader)
        builder = importlib.util.module_from_spec(source_spec)
        source_loader.exec_module(builder)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repository = root / "checkout"
            repository.mkdir()
            def git(*args):
                return subprocess.run(["git", "-C", str(repository), *args], check=True, capture_output=True, text=True).stdout.strip()
            git("init", "--quiet")
            (repository / "source.txt").write_text("committed source")
            git("add", "source.txt")
            git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "--quiet", "-m", "Fixture")
            revision = git("rev-parse", "HEAD")
            (repository / "source.txt").write_text("uncommitted edits")
            (repository / "private.txt").write_text("untracked data")
            package = root / "packages/ukvm"
            package.mkdir(parents=True)
            (package / "PKGBUILD").write_text(f"pkgver=0.1.0.r18\n_revision={revision}\nsha256sums=('pending')\n")
            builder.ROOT = root
            builder.build(repository)
            archive = next((root / "repo/sources").glob("*.tar.zst"))
            before = archive.read_bytes()
            self.assertFalse((package / archive.name).is_symlink())
            content = subprocess.run(["bsdtar", "-xOf", str(archive), f"UKVM-{revision}/source.txt"], check=True, capture_output=True, text=True).stdout
            self.assertEqual(content, "committed source")
            self.assertNotIn("private.txt", checker.archive(archive, "-tf"))
            builder.build(repository)
            self.assertEqual(before, archive.read_bytes())
            archive.write_bytes(b"different immutable source")
            with self.assertRaisesRegex(ValueError, "immutable UKVM archive"):
                builder.build(repository)

    def test_managed_backend_package_metadata_and_immutable_sources(self):
        result = subprocess.run(["makepkg", "--printsrcinfo"], cwd=ROOT / "packages/spectrum-xdg-desktop-portal-hyprland", check=True, capture_output=True, text=True)
        self.assertIn("conflicts = xdg-desktop-portal-hyprland", result.stdout)
        self.assertIn("provides = xdg-desktop-portal-hyprland=1.4.1", result.stdout)
        self.assertIn("0204ffbbcb3cef72af76804cdf59f114f2e2f6d9", result.stdout)
        self.assertNotIn("SKIP", result.stdout)
        self.assertNotIn("/tmp", result.stdout)
