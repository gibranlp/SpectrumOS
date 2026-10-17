import base64
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("mksquashfs") and shutil.which("unsquashfs"), "SquashFS tools are required")
class AppImageTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.environment = patch.dict(os.environ, {"HOME": str(self.home), "XDG_DATA_HOME": str(self.home / "data")})
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.api = runpy.run_path(str(ROOT / "scripts/appimage-adapter"))
        tree = self.home / "payload"
        tree.mkdir()
        (tree / "fixture.desktop").write_text("[Desktop Entry]\nType=Application\nName=Fixture Application\nIcon=fixture\nExec=AppRun\n")
        (tree / "AppRun").write_text("#!/bin/sh\ntouch '" + str(self.home / "executed") + "'\n")
        (tree / "AppRun").chmod(0o755)
        (tree / "fixture.png").write_bytes(base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWQAAAABJRU5ErkJggg=="))
        filesystem = self.home / "image.squashfs"
        subprocess.run(["mksquashfs", str(tree), str(filesystem), "-noappend", "-processors", "1", "-quiet"], check=True, stdout=subprocess.DEVNULL)
        runtime = bytearray(Path("/bin/true").read_bytes())
        runtime[8:11] = b"AI\x02"
        self.source = self.home / "Fixture's 100% new.AppImage"
        self.source.write_bytes(runtime + filesystem.read_bytes())

    def test_add_reads_embedded_metadata_without_execution_and_creates_launcher(self):
        identifier = self.api["integrate"](self.source)
        state = self.api["status"]()
        self.assertEqual(len(state["applications"]), 1)
        item = state["applications"][0]
        self.assertEqual(item["name"], "Fixture Application")
        self.assertTrue(Path(item["icon"]).read_bytes().startswith(b"\x89PNG"))
        self.assertEqual(Path(item["path"]).read_bytes(), self.source.read_bytes())
        self.assertTrue(os.access(item["path"], os.X_OK))
        self.assertFalse((self.home / "executed").exists())
        desktop = self.api["desktop_dir"]() / ("spectrum-appimage-" + identifier + ".desktop")
        self.assertIn("launch " + identifier, desktop.read_text())
        subprocess.run(["desktop-file-validate", str(desktop)], check=True, capture_output=True)

    def test_replace_keeps_identity_and_removal_preserves_original_and_settings(self):
        identifier = self.api["integrate"](self.source)
        old = self.api["read_app"](identifier)
        self.api["integrate"](self.source, identifier)
        item = self.api["read_app"](identifier)
        self.assertEqual(item["name"], old["name"])
        self.assertNotEqual(item["path"], old["path"])
        self.assertFalse(Path(old["path"]).exists())
        settings = self.home / ".config/fixture/settings.json"
        settings.parent.mkdir(parents=True)
        settings.write_text("keep me")
        self.api["remove"](identifier)
        self.assertEqual(self.api["status"]()["applications"], [])
        self.assertTrue(self.source.exists())
        self.assertEqual(settings.read_text(), "keep me")
        self.assertFalse(list(self.api["desktop_dir"]().glob("*.desktop")))

    def test_invalid_replacement_preserves_installed_version(self):
        identifier = self.api["integrate"](self.source)
        before = self.api["read_app"](identifier)
        broken = self.home / "broken.AppImage"
        broken.write_bytes(b"not an AppImage")
        with self.assertRaises(ValueError):
            self.api["integrate"](broken, identifier)
        self.assertEqual(self.api["read_app"](identifier), before)
        self.assertEqual(len(list(self.api["app_dir"](identifier).glob("*.AppImage"))), 1)

    def test_invalid_identifiers_and_tampered_paths_are_refused(self):
        with self.assertRaises(ValueError):
            self.api["remove"]("../outside")
        identifier = self.api["integrate"](self.source)
        metadata = self.api["app_dir"](identifier) / "metadata.json"
        item = json.loads(metadata.read_text())
        item["file"] = "../../outside"
        metadata.write_text(json.dumps(item))
        with self.assertRaises(ValueError):
            self.api["launch"](identifier)

    def test_cancelled_chooser_and_launch_use_safe_argv(self):
        with patch("subprocess.run", return_value=subprocess.CompletedProcess([], 1, stdout="")):
            self.assertEqual(self.api["main"](["choose-add"]), {"ok": True, "cancelled": True})
        identifier = self.api["integrate"](self.source)
        with patch("subprocess.Popen") as spawn:
            self.api["launch"](identifier)
        self.assertEqual(spawn.call_args.args[0], ["uwsm", "app", "--", self.api["read_app"](identifier)["path"]])


class AppImagePackagingTests(unittest.TestCase):
    def test_every_installation_path_ships_manager_and_dependencies(self):
        recipe = (ROOT / "packages/spectrum-desktop/PKGBUILD").read_text()
        installer = (ROOT / "install.sh").read_text()
        for source in (recipe, installer):
            self.assertIn("appimage-adapter", source)
            self.assertIn("system/spectrum-appimages.desktop", source)
        for dependency in ("fuse2", "squashfs-tools"):
            self.assertIn(dependency, recipe)
            self.assertIn(dependency, (ROOT / "bootstrap/packages/desktop.txt").read_text().splitlines())
            self.assertIn("\tdepends = " + dependency + "\n", (ROOT / "packages/spectrum-desktop/.SRCINFO").read_text())
        self.assertIn('toggleAppImages', (ROOT / "scripts/spectrum-shell-open").read_text())


if __name__ == "__main__":
    unittest.main()
