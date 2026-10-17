import base64
import configparser
from pathlib import Path
import unittest
import os
import runpy
import tempfile
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]


class FlatpakIntegrationTests(unittest.TestCase):
    def test_catalog_refresh_discovers_flatpak_installs_and_removals(self):
        catalog = runpy.run_path(str(ROOT / "scripts/application-adapter"))
        with tempfile.TemporaryDirectory() as temporary:
            data = Path(temporary)
            user = data / "user"
            system = data / "system"
            environment = {"XDG_DATA_HOME": str(user), "XDG_DATA_DIRS": str(system)}
            with patch.dict(os.environ, environment):
                before = {item["id"] for item in catalog["applications"]()}
                exported = user / "flatpak/exports/share/applications/org.example.Flatpak.desktop"
                exported.parent.mkdir(parents=True)
                exported.write_text("[Desktop Entry]\nType=Application\nName=Flatpak Fixture\nExec=/bin/true\nIcon=org.example.Flatpak\nKeywords=fixture;test;\n")
                apps = {item["id"]: item for item in catalog["applications"]()}
                self.assertNotIn("org.example.Flatpak", before)
                self.assertEqual(apps["org.example.Flatpak"]["icon"], "org.example.Flatpak")
                self.assertIn("fixture", apps["org.example.Flatpak"]["keywords"])
                exported.unlink()
                self.assertNotIn("org.example.Flatpak", {item["id"] for item in catalog["applications"]()})

    def test_duplicate_xdg_roots_are_scanned_once(self):
        catalog = runpy.run_path(str(ROOT / "scripts/application-adapter"))
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            (root/"applications").mkdir()
            (root/"applications/test.desktop").write_text("[Desktop Entry]\nType=Application\nName=Fixture\nExec=/bin/true\n")
            actual=Path.rglob
            calls=[]
            def scan(path, pattern):
                calls.append(path.resolve())
                return actual(path,pattern)
            with patch.dict(os.environ, XDG_DATA_HOME=str(root), XDG_DATA_DIRS=str(root)+":"+str(root)), patch.object(Path,"rglob",scan):
                catalog["desktop_files"]()
            self.assertEqual(calls.count((root/"applications").resolve()),1)

    def test_catalog_preserves_xdg_precedence_hidden_overrides_and_nested_ids(self):
        catalog = runpy.run_path(str(ROOT / "scripts/application-adapter"))
        with tempfile.TemporaryDirectory() as temporary:
            data = Path(temporary)
            user = data / "user"
            system = data / "system"
            for root in (user, system):
                (root / "applications/vendor").mkdir(parents=True)
                (root / "applications/vendor/App.desktop").write_text("[Desktop Entry]\nType=Application\nName=Fixture\nExec=/bin/true\n")
            (user / "applications/vendor/App.desktop").write_text("[Desktop Entry]\nType=Application\nHidden=true\n")
            with patch.dict(os.environ, {"XDG_DATA_HOME": str(user), "XDG_DATA_DIRS": str(system)}):
                self.assertNotIn("vendor-App", {item["id"] for item in catalog["applications"]()})
                (user / "applications/vendor/App.desktop").unlink()
                app = next(item for item in catalog["applications"]() if item["id"] == "vendor-App")
                self.assertEqual(app["desktop_id"], "vendor-App.desktop")

    def test_orphaned_flatpak_desktop_entries_are_filtered_using_installed_inventory(self):
        catalog = runpy.run_path(str(ROOT / "scripts/application-adapter"))
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            apps = root / "applications"
            apps.mkdir()
            for name in ("Installed", "Removed"):
                (apps / (name + ".desktop")).write_text(f"[Desktop Entry]\nType=Application\nName={name} Flatpak Fixture\nExec=/usr/bin/flatpak run org.example.{name}\nX-Flatpak=org.example.{name}\n")
            inventory = {"org.example.Installed"}
            with patch.dict(os.environ, {"XDG_DATA_HOME": str(root), "XDG_DATA_DIRS": str(root / "system")}), patch.dict(catalog["applications"].__globals__, {"flatpak_applications": lambda: inventory}):
                items = {item["id"]: item for item in catalog["applications"]()}
                self.assertEqual(items["Installed"]["source"], "Flatpak")
                self.assertNotIn("Removed", items)
                inventory.clear()
                self.assertNotIn("Installed", {item["id"] for item in catalog["applications"]()})
                self.assertTrue((apps / "Installed.desktop").exists())
                self.assertTrue((apps / "Removed.desktop").exists())
                with patch.dict(catalog["applications"].__globals__, {"flatpak_applications": lambda: None}):
                    self.assertIn("Installed", {item["id"] for item in catalog["applications"]()})

    def test_flatpak_commands_without_metadata_and_inventory_failure(self):
        catalog = runpy.run_path(str(ROOT / "scripts/application-adapter"))
        entry = {"Exec": "flatpak run --branch=stable org.example.Application"}
        self.assertEqual(catalog["flatpak_id"](entry, ["env", "FOO=bar", "flatpak", "run", "--arch", "x86_64", "--branch=stable", "org.example.Application", "%U"]), "org.example.Application")
        self.assertEqual(catalog["flatpak_id"]({}, ["flatpak", "run", "app/org.example.Application/x86_64/stable"]), "org.example.Application")
        with patch("subprocess.run", side_effect=OSError("unavailable")):
            self.assertIsNone(catalog["flatpak_applications"]())

    def test_appimage_duplicates_prefer_managed_entry_and_missing_exec_is_hidden(self):
        catalog = runpy.run_path(str(ROOT / "scripts/application-adapter"))
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            apps = root / "data/applications"
            apps.mkdir(parents=True)
            identifier = "a" * 32
            directory = root / "Applications/SpectrumOS" / identifier
            directory.mkdir(parents=True)
            binary = directory / (("b" * 32) + ".AppImage")
            binary.write_text("fixture")
            binary.chmod(0o700)
            (directory / "metadata.json").write_text('{"file":"' + binary.name + '"}')
            (apps / "duplicate.desktop").write_text(f'[Desktop Entry]\nType=Application\nName=Fixture AppImage\nExec="{binary}" %U\n')
            (apps / "managed.desktop").write_text(f'[Desktop Entry]\nType=Application\nName=Fixture AppImage\nExec=/usr/lib/spectrumos/appimage-adapter launch {identifier}\n')
            (apps / "missing.desktop").write_text('[Desktop Entry]\nType=Application\nName=Missing Fixture\nExec=/missing/fixture-binary\n')
            with patch.dict(os.environ, {"HOME": str(root), "XDG_DATA_HOME": str(root / "data"), "XDG_DATA_DIRS": str(root / "system")}):
                items = catalog["applications"]()
                matching = [item for item in items if item["name"] == "Fixture AppImage"]
                self.assertEqual(len(matching), 1)
                self.assertEqual(matching[0]["id"], "managed")
                self.assertEqual(matching[0]["source"], "AppImage")
                self.assertNotIn("missing", {item["id"] for item in items})
                binary.unlink()
                self.assertFalse(any(item["name"] == "Fixture AppImage" for item in catalog["applications"]()))

    def test_flathub_definition_is_signed_and_shipped_on_every_desktop_path(self):
        remote = ROOT / "system/flatpak-flathub.flatpakrepo"
        config = configparser.ConfigParser()
        self.assertEqual(config.read(remote), [str(remote)])
        self.assertEqual(config["Flatpak Repo"]["Url"], "https://dl.flathub.org/repo/")
        self.assertGreater(len(base64.b64decode(config["Flatpak Repo"]["GPGKey"], validate=True)), 1000)

        manifest = (ROOT / "bootstrap/packages/desktop.txt").read_text(encoding="utf-8").splitlines()
        live_packages = (ROOT / "iso/spectrumos/packages.x86_64").read_text(encoding="utf-8").splitlines()
        self.assertIn("flatpak", manifest)
        self.assertIn("flatpak", live_packages)

        package = (ROOT / "packages/spectrum-desktop/PKGBUILD").read_text(encoding="utf-8")
        metadata = (ROOT / "packages/spectrum-desktop/.SRCINFO").read_text(encoding="utf-8")
        installer = (ROOT / "install.sh").read_text(encoding="utf-8")
        builder = (ROOT / "scripts/build-iso").read_text(encoding="utf-8")
        self.assertIn(" flatpak ", package)
        self.assertIn("\tdepends = flatpak\n", metadata)
        for source in (installer, builder):
            self.assertIn("system/flatpak-flathub.flatpakrepo", source)
        self.assertIn("/etc/flatpak/remotes.d/flathub.flatpakrepo", installer)
        self.assertIn("/etc/flatpak/remotes.d/flathub.flatpakrepo", builder)
        self.assertNotIn("/usr/share/flatpak/remotes.d/flathub.flatpakrepo", package)


if __name__ == "__main__":
    unittest.main()
