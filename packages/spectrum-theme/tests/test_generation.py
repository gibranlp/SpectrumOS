from pathlib import Path
import tempfile
import unittest

from spectrum_theme.generation import GenerationError, generate, rollback
from spectrum_theme.palette import Palette


PALETTE = Palette(
    name="Test",
    variant="dark",
    source="test",
    roles={
        "background": "#101218",
        "surface": "#191c24",
        "surface_alt": "#252a35",
        "foreground": "#e9edf5",
        "muted": "#9ca6b8",
        "accent": "#76b7ff",
        "accent_alt": "#c49aff",
        "success": "#78dba9",
        "warning": "#f2c66d",
        "error": "#ff8c9a",
    },
)


class GenerationTests(unittest.TestCase):
    def test_generates_all_consumers_and_current_link(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "theme"
            generation = generate(PALETTE, output)

            self.assertTrue((output / "current").is_symlink())
            self.assertEqual((output / "current").resolve(), generation.resolve())
            self.assertEqual(
                {path.name for path in generation.iterdir()},
                {
                    "generation.json",
                    "hyprland.lua",
                    "hyprlock.conf",
                    "kitty.conf",
                    "cava.theme",
                    "alacritty.toml",
                    "colors",
                    "gtk-3.css",
                    "gtk-4.css",
                    "Spectrum-folder.svg",
                    "Spectrum-folder-documents.svg",
                    "Spectrum-folder-downloads.svg",
                    "Spectrum-folder-music.svg",
                    "Spectrum-folder-pictures.svg",
                    "Spectrum-folder-videos.svg",
                    "Spectrum-user-home.svg",
                    "Spectrum.kvconfig",
                    "Spectrum.colors",
                    "Spectrum.svg",
                    "integrations",
                    "palette.json",
                },
            )
            self.assertTrue((generation / "colors" / "spectrum.lua").is_file())
            self.assertTrue((generation / "integrations/spectrum.tdesktop-theme").is_file())
            self.assertTrue((generation / "integrations/vencord-quickcss.css").is_file())
            self.assertTrue((generation / "integrations/zen-browser.css").is_file())
            self.assertTrue((generation / "integrations/zen-extension-manifest.json").is_file())

    def test_new_generation_replaces_current_link(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "theme"
            first = generate(PALETTE, output)
            second = generate(PALETTE, output)

            self.assertNotEqual(first, second)
            self.assertEqual((output / "current").resolve(), second.resolve())
            self.assertTrue(first.exists())

    def test_generation_records_and_renders_font_size(self):
        with tempfile.TemporaryDirectory() as directory:
            generation = generate(PALETTE, Path(directory) / "theme", font_size=18)

            self.assertIn("font-size: 18px", (generation / "gtk-4.css").read_text())
            self.assertIn("font-size: 18px", (generation / "gtk-4.css").read_text())
            self.assertIn('"font_size": 18', (generation / "generation.json").read_text())

    def test_generation_records_and_renders_font_family(self):
        with tempfile.TemporaryDirectory() as directory:
            generation = generate(PALETTE, Path(directory) / "theme", font_family="FiraCode Nerd Font")

            self.assertIn("font_family FiraCode Nerd Font", (generation / "kitty.conf").read_text())
            self.assertIn('family = "FiraCode Nerd Font"', (generation / "alacritty.toml").read_text())
            self.assertIn('"font_family": "FiraCode Nerd Font"', (generation / "generation.json").read_text())

    def test_generation_rejects_font_size_outside_range(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(GenerationError, "between 8 and 24"):
                generate(PALETTE, Path(directory) / "theme", font_size=25)

    def test_rollback_restores_previous_generation_and_wallpaper(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "theme"
            first_wallpaper = root / "first.png"
            second_wallpaper = root / "second.png"
            first_wallpaper.touch()
            second_wallpaper.touch()
            first = generate(PALETTE, output, first_wallpaper)
            generate(PALETTE, output, second_wallpaper)

            restored, wallpaper = rollback(output)

            self.assertEqual(restored, first)
            self.assertEqual(wallpaper, first_wallpaper)
            self.assertEqual((output / "current").resolve(), first)

    def test_rollback_rejects_missing_history(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            wallpaper = root / "wallpaper.png"
            wallpaper.touch()
            generate(PALETTE, root / "theme", wallpaper)

            with self.assertRaisesRegex(GenerationError, "No previous"):
                rollback(root / "theme")

    def test_new_generation_after_rollback_returns_to_actual_parent(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "theme"
            first_wallpaper = root / "first.png"
            second_wallpaper = root / "second.png"
            third_wallpaper = root / "third.png"
            for wallpaper in (first_wallpaper, second_wallpaper, third_wallpaper):
                wallpaper.touch()
            first = generate(PALETTE, output, first_wallpaper)
            generate(PALETTE, output, second_wallpaper)
            rollback(output)
            generate(PALETTE, output, third_wallpaper)

            restored, wallpaper = rollback(output)

            self.assertEqual(restored, first)
            self.assertEqual(wallpaper, first_wallpaper)

    def test_retention_keeps_bounded_complete_history(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            wallpaper = root / "wallpaper.png"
            wallpaper.touch()
            output = root / "theme"
            for _ in range(6):
                generate(PALETTE, output, wallpaper, retention=3)

            generations = [path for path in (output / "generations").iterdir() if path.is_dir()]
            self.assertEqual(len(generations), 3)
            self.assertIn((output / "current").resolve(), generations)

    def test_new_generation_removes_inactive_legacy_history(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "theme"
            wallpaper = root / "wallpaper.png"
            wallpaper.touch()
            first = generate(PALETTE, output)
            legacy = output / "generations" / "20000101T000000.000000Z-legacy"
            legacy.mkdir()
            generate(PALETTE, output, wallpaper)

            self.assertTrue(first.exists())
            self.assertFalse(legacy.exists())


if __name__ == "__main__":
    unittest.main()
