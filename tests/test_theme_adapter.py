from importlib.machinery import SourceFileLoader
from pathlib import Path
import importlib.util
import os
import json
import subprocess
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "theme-adapter"


def load_module():
    loader = SourceFileLoader("theme_adapter", str(SCRIPT))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class ThemeAdapterTests(unittest.TestCase):
    def setUp(self):
        self.module = load_module()
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.env_patch = mock.patch.dict(
            os.environ,
            {
                "XDG_STATE_HOME": str(self.root / "state"),
                "XDG_PICTURES_DIR": str(self.root / "pictures"),
                "XDG_CACHE_HOME": str(self.root / "cache"),
                "HOME": str(self.root / "home"),
            },
        )
        self.env_patch.start()
        self.addCleanup(self.env_patch.stop)

    def wallpaper_dir(self) -> Path:
        directory = self.root / "pictures" / "Wallpapers"
        directory.mkdir(parents=True, exist_ok=True)
        return directory

    def set_current_wallpaper(self, path: Path) -> None:
        state_dir = self.root / "state" / "spectrumos" / "theme"
        state_dir.mkdir(parents=True, exist_ok=True)
        (state_dir / "last-wallpaper").write_text(f"{path}\n", encoding="utf-8")

    def test_script_compiles(self):
        source = SCRIPT.read_text(encoding="utf-8")
        compile(source, str(SCRIPT), "exec")

    def test_corrupt_wallpaper_does_not_hide_valid_images(self):
        wallpaper_dir = self.wallpaper_dir()
        wallpaper_dir.mkdir(parents=True, exist_ok=True)
        (wallpaper_dir / "broken.png").write_bytes(b"not an image")
        valid = wallpaper_dir / "valid.png"
        valid.write_bytes(
            b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
            b"\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDAT\x08\xd7c\xf8\xcf\xc0\x00\x00"
            b"\x03\x01\x01\x00\x18\xdd\x8d\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
        )
        with mock.patch.object(self.module, "wallpaper_dir", return_value=wallpaper_dir):
            result = self.module.state()
        self.assertEqual(result["count"], 1)
        self.assertEqual(result["wallpapers"][0]["name"], "valid")

    def test_same_filename_in_different_directories_has_independent_thumbnail(self):
        from PIL import Image
        first = self.root / "one/wallpaper.png"
        second = self.root / "two/wallpaper.png"
        for path, color in ((first,"red"),(second,"blue")):
            path.parent.mkdir()
            Image.new("RGB",(600,400),color).save(path)
        import os
        os.utime(second, (1,1))
        one = self.module.thumbnail_for(first)
        two = self.module.thumbnail_for(second)
        self.assertNotEqual(one,two)
        with Image.open(two) as thumbnail:
            red, green, blue = thumbnail.getpixel((150,84))
        self.assertGreater(blue,red)

    def test_palette_and_alpha_thumbnails_preserve_rgb_resampling(self):
        import io
        from PIL import Image, ImageOps
        images = [Image.effect_noise((400,400),50).convert("P"), Image.new("RGBA",(400,400),(255,64,0,0))]
        for index, image in enumerate(images):
            with self.subTest(mode=image.mode):
                path=self.root/(str(index)+".png")
                image.save(path)
                with Image.open(path) as source:
                    expected=ImageOps.fit(source.convert("RGB"),(300,168),method=Image.Resampling.LANCZOS)
                    buffer=io.BytesIO()
                    expected.save(buffer,"JPEG",quality=82,optimize=True)
                self.assertEqual(self.module.thumbnail_for(path).read_bytes(),buffer.getvalue())

    def test_current_wallpaper_is_none_without_state(self):
        self.assertIsNone(self.module.current_wallpaper())

    def test_current_wallpaper_ignores_a_stale_missing_file(self):
        self.set_current_wallpaper(self.wallpaper_dir() / "gone.png")
        self.assertIsNone(self.module.current_wallpaper())

    def test_current_wallpaper_resolves_the_recorded_file(self):
        wallpaper = self.wallpaper_dir() / "sunset.png"
        wallpaper.write_bytes(b"fake")
        self.set_current_wallpaper(wallpaper)

        self.assertEqual(self.module.current_wallpaper(), wallpaper.resolve())

    def test_apply_to_current_wallpaper_is_a_no_op_without_an_active_wallpaper(self):
        with mock.patch.object(self.module, "launch") as launch:
            self.module.apply_to_current_wallpaper()

        launch.assert_not_called()

    def test_apply_to_current_wallpaper_relaunches_theme_menu_on_the_active_wallpaper(self):
        wallpaper = self.wallpaper_dir() / "sunset.png"
        wallpaper.write_bytes(b"fake")
        self.set_current_wallpaper(wallpaper)

        with mock.patch.object(self.module, "launch") as launch:
            self.module.apply_to_current_wallpaper()

        launch.assert_called_once_with(
            ["/usr/lib/spectrumos/theme-menu", "--refresh"]
        )

    def test_mode_command_saves_the_preference_and_previews_it_live(self):
        wallpaper = self.wallpaper_dir() / "sunset.png"
        wallpaper.write_bytes(b"fake")
        self.set_current_wallpaper(wallpaper)

        with mock.patch.object(self.module, "sys") as fake_sys, mock.patch.object(self.module, "launch") as launch:
            fake_sys.argv = ["theme-adapter", "mode", "weighted-regions"]
            exit_code = self.module.main()

        self.assertEqual(exit_code, 0)
        self.assertEqual(self.module.preferences()["mode"], "weighted-regions")
        launch.assert_called_once_with(
            ["/usr/lib/spectrumos/theme-menu", "--refresh"]
        )

    def test_mode_command_rejects_an_unknown_backend(self):
        with mock.patch.object(self.module, "sys") as fake_sys, mock.patch.object(self.module, "launch") as launch:
            fake_sys.argv = ["theme-adapter", "mode", "not-a-real-mode"]
            exit_code = self.module.main()

        self.assertEqual(exit_code, 2)
        launch.assert_not_called()

    def test_gowall_scheme_names_returns_empty_without_the_binary(self):
        with mock.patch.object(self.module, "gowall_bin", return_value=None):
            self.assertEqual(self.module.gowall_scheme_names(), [])

    def test_gowall_scheme_names_parses_and_caches_the_output(self):
        fake_gowall = self.root / "bin" / "gowall"
        fake_gowall.parent.mkdir(parents=True, exist_ok=True)
        fake_gowall.write_text("#!/usr/bin/env bash\nprintf 'nord\\ncatppuccin\\n'\n", encoding="utf-8")
        fake_gowall.chmod(0o755)

        with mock.patch.object(self.module, "gowall_bin", return_value=str(fake_gowall)):
            first = self.module.gowall_scheme_names()
            with mock.patch.object(self.module.subprocess, "run") as run:
                second = self.module.gowall_scheme_names()

        self.assertEqual(first, ["catppuccin", "nord"])
        self.assertEqual(second, first)
        run.assert_not_called()

    def test_gowall_scheme_names_returns_empty_when_gowall_fails(self):
        fake_gowall = self.root / "bin" / "gowall"
        fake_gowall.parent.mkdir(parents=True, exist_ok=True)
        fake_gowall.write_text("#!/usr/bin/env bash\nexit 1\n", encoding="utf-8")
        fake_gowall.chmod(0o755)

        with mock.patch.object(self.module, "gowall_bin", return_value=str(fake_gowall)):
            self.assertEqual(self.module.gowall_scheme_names(), [])

    def test_preferences_default_scheme_is_none(self):
        self.assertEqual(self.module.preferences()["scheme"], "none")

    def test_preferences_drops_a_scheme_gowall_no_longer_offers(self):
        state_dir = self.root / "state" / "spectrumos" / "theme"
        state_dir.mkdir(parents=True, exist_ok=True)
        (state_dir / "preferences").write_text("mode=spectrum\nvariant=dark\nscheme=retired-theme\n", encoding="utf-8")

        with mock.patch.object(self.module, "gowall_scheme_names", return_value=["nord"]):
            self.assertEqual(self.module.preferences()["scheme"], "none")

    def test_gowall_state_reports_not_installed_without_the_binary(self):
        with mock.patch.object(self.module, "gowall_scheme_names", return_value=[]):
            state = self.module.gowall_state()

        self.assertFalse(state["installed"])
        self.assertEqual(state["schemes"], [{"name": "none", "label": "None — original colors", "current": True}])

    def test_gowall_state_marks_the_active_scheme_as_current(self):
        state_dir = self.root / "state" / "spectrumos" / "theme"
        state_dir.mkdir(parents=True, exist_ok=True)
        (state_dir / "preferences").write_text("mode=spectrum\nvariant=dark\nscheme=nord\n", encoding="utf-8")

        with mock.patch.object(self.module, "gowall_scheme_names", return_value=["catppuccin", "nord"]):
            state = self.module.gowall_state()

        self.assertTrue(state["installed"])
        current = {entry["name"]: entry["current"] for entry in state["schemes"]}
        self.assertEqual(current, {"none": False, "catppuccin": False, "nord": True})
        # "None" always leads the list, regardless of how gowall orders/how many real
        # schemes there are -- the control center relies on this to show it as the first
        # (top) row of the inline scheme list without hardcoding it separately.
        self.assertEqual(state["schemes"][0]["name"], "none")

    def test_scheme_command_saves_the_preference_and_previews_it_live(self):
        wallpaper = self.wallpaper_dir() / "sunset.png"
        wallpaper.write_bytes(b"fake")
        self.set_current_wallpaper(wallpaper)

        with mock.patch.object(self.module, "gowall_scheme_names", return_value=["nord"]), \
             mock.patch.object(self.module, "sys") as fake_sys, \
             mock.patch.object(self.module, "launch") as launch:
            fake_sys.argv = ["theme-adapter", "scheme", "nord"]
            exit_code = self.module.main()

        self.assertEqual(exit_code, 0)
        self.assertEqual(self.module.preferences()["scheme"], "nord")
        launch.assert_called_once_with(
            ["/usr/lib/spectrumos/theme-menu", "--refresh"]
        )

    def test_scheme_command_rejects_a_scheme_gowall_does_not_offer(self):
        with mock.patch.object(self.module, "gowall_scheme_names", return_value=["nord"]), \
             mock.patch.object(self.module, "sys") as fake_sys, \
             mock.patch.object(self.module, "launch") as launch:
            fake_sys.argv = ["theme-adapter", "scheme", "not-a-real-scheme"]
            exit_code = self.module.main()

        self.assertEqual(exit_code, 2)
        launch.assert_not_called()

    def test_scheme_command_accepts_none_even_without_gowall_installed(self):
        with mock.patch.object(self.module, "gowall_scheme_names", return_value=[]), \
             mock.patch.object(self.module, "sys") as fake_sys, \
             mock.patch.object(self.module, "launch"):
            fake_sys.argv = ["theme-adapter", "scheme", "none"]
            exit_code = self.module.main()

        self.assertEqual(exit_code, 0)
        self.assertEqual(self.module.preferences()["scheme"], "none")

    def test_variant_command_saves_the_preference_and_previews_it_live(self):
        wallpaper = self.wallpaper_dir() / "sunset.png"
        wallpaper.write_bytes(b"fake")
        self.set_current_wallpaper(wallpaper)

        with mock.patch.object(self.module, "sys") as fake_sys, mock.patch.object(self.module, "launch") as launch:
            fake_sys.argv = ["theme-adapter", "variant", "light"]
            exit_code = self.module.main()

        self.assertEqual(exit_code, 0)
        self.assertEqual(self.module.preferences()["variant"], "light")
        launch.assert_called_once_with(
            ["/usr/lib/spectrumos/theme-menu", "--refresh"]
        )

    def test_all_variants_survive_a_new_backend_process(self):
        for variant in ("auto", "dark", "light"):
            with self.subTest(variant=variant):
                subprocess.run([str(SCRIPT), "variant", variant], check=True, capture_output=True)
                state = subprocess.run([str(SCRIPT), "--json"], check=True, capture_output=True, text=True)
                self.assertEqual(json.loads(state.stdout)["palette"]["variant"], variant)


if __name__ == "__main__":
    unittest.main()
