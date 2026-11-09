from importlib.machinery import SourceFileLoader
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def module(name):
    spec = importlib.util.spec_from_loader(name.replace("-", "_"), SourceFileLoader(name.replace("-", "_"), str(ROOT / "scripts" / name)))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


class LiveDesktopTests(unittest.TestCase):
    def test_stages_stock_theme_with_live_paths_and_writable_user_settings(self):
        with tempfile.TemporaryDirectory() as directory:
            temporary = Path(directory)
            theme = temporary / "theme"
            current = theme / "generations/original"
            current.mkdir(parents=True)
            (theme / "current").symlink_to("generations/original")
            (current / "generation.json").write_text(json.dumps({"wallpaper": "/build/source/S30.png"}))
            (current / "hyprland.lua").write_text('wallpaper = "/build/source/S30.png"')
            destination = temporary / "live"
            module("stage-live-desktop").stage(ROOT, destination, theme)
            home = destination / "home/spectrum"
            active = home / ".cache/spectrumos/theme/current"
            self.assertTrue((active / "hyprland.lua").is_file())
            self.assertNotIn("/build/source", (active / "hyprland.lua").read_text())
            self.assertEqual(json.loads((active / "generation.json").read_text())["wallpaper"],
                             "/usr/share/backgrounds/spectrumos/S30.png")
            self.assertEqual((home / "Pictures/Wallpapers").readlink(), Path("/usr/share/backgrounds/spectrumos"))
            self.assertEqual((home / ".config/kitty/kitty.conf").read_bytes(),
                             (ROOT / "configs/terminal/kitty-user.conf").read_bytes())
            self.assertFalse((home / ".config/spectrumos/language.json").exists())

    def test_current_desktop_is_required_in_the_indexed_package(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            project = root / "project"
            (project / "configs/spectrum-shell").mkdir(parents=True)
            source = project / "configs/spectrum-shell/shell.qml"
            source.write_text("current")
            payload = root / "payload/usr/share/spectrumos/spectrum-shell"
            payload.mkdir(parents=True)
            (payload / "shell.qml").write_text("current")
            package = root / "spectrum-desktop-fixture.pkg.tar.zst"
            subprocess.run(["bsdtar", "-cf", str(package), "-C", str(root / "payload"), "usr"], check=True)
            index = root / "index/spectrum-desktop-1/desc"
            index.parent.mkdir(parents=True)
            index.write_text("%NAME%\nspectrum-desktop\n%FILENAME%\n" + package.name + "\n")
            subprocess.run(["bsdtar", "-cf", str(root / "spectrumos.db.tar.zst"), "-C",
                            str(root / "index"), "spectrum-desktop-1"], check=True)
            checker = module("check-live-desktop")
            checker.check(project, root)
            source.write_text("newer")
            with self.assertRaisesRegex(ValueError, "Rebuild and sign spectrum-desktop"):
                checker.check(project, root)

    def test_only_live_sessions_expose_the_installer_and_share_language(self):
        session = (ROOT / "installer/spectrum-live-session").read_text()
        shell = (ROOT / "configs/spectrum-shell/shell.qml").read_text()
        controls = (ROOT / "configs/spectrum-shell/BarControls.qml").read_text()
        self.assertIn("export SPECTRUM_LIVE_SESSION=1", session)
        self.assertIn("export SPECTRUM_TRANSLATIONS_DIR=", session)
        self.assertIn('Quickshell.env("SPECTRUM_LIVE_SESSION") === "1"', shell)
        self.assertIn('action === "install" && shell.liveSession', shell)
        self.assertIn('theme.liveSession === true ? ["install"] : []', controls)
        builder = (ROOT / "scripts/build-iso").read_text()
        self.assertIn('GPGDir = ', builder)
        self.assertIn('Required DatabaseRequired TrustedOnly', builder)
        self.assertIn('file_permissions[', builder)
        self.assertIn("1000:1000:", builder)
        for locale in ("en_US", "es_MX", "pt_BR"):
            self.assertIn(locale + ".UTF-8 UTF-8", (ROOT / "iso/spectrumos/airootfs/etc/locale.gen").read_text())
