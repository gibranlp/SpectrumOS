from pathlib import Path
import tempfile
import unittest

from spectrum_theme.cli import light_palette_path
from spectrum_theme.palette import PaletteError, contrast_results, load_palette


VALID_PALETTE = """\
[palette]
schema_version = 1
name = "Test"
variant = "dark"
source = "test"

[roles]
background = "#101218"
surface = "#191c24"
surface_alt = "#252a35"
foreground = "#e9edf5"
muted = "#9ca6b8"
accent = "#76b7ff"
accent_alt = "#c49aff"
success = "#78dba9"
warning = "#f2c66d"
error = "#ff8c9a"
"""


class PaletteTests(unittest.TestCase):
    def load(self, content: str):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "palette.toml"
            path.write_text(content, encoding="utf-8")
            return load_palette(path)

    def test_loads_valid_palette(self):
        palette = self.load(VALID_PALETTE)
        self.assertEqual(palette.name, "Test")
        self.assertEqual(palette.color("accent"), "#76b7ff")

    def test_rejects_missing_role(self):
        with self.assertRaisesRegex(PaletteError, "Missing palette roles: error"):
            self.load(VALID_PALETTE.replace('error = "#ff8c9a"\n', ""))

    def test_rejects_invalid_color(self):
        with self.assertRaisesRegex(PaletteError, "must be a #RRGGBB color"):
            self.load(VALID_PALETTE.replace("#76b7ff", "blue"))

    def test_rejects_unknown_schema_version(self):
        with self.assertRaisesRegex(PaletteError, "schema_version must be 1"):
            self.load(VALID_PALETTE.replace("schema_version = 1", "schema_version = 2"))

    def test_rejects_low_foreground_contrast(self):
        with self.assertRaisesRegex(PaletteError, "Foreground/background contrast"):
            self.load(VALID_PALETTE.replace("#e9edf5", "#15171c"))

    def test_rejects_low_semantic_status_contrast(self):
        with self.assertRaisesRegex(PaletteError, "Success/background contrast"):
            self.load(VALID_PALETTE.replace("#78dba9", "#111319"))

    def test_light_fallback_passes_every_consumer_contract(self):
        palette = load_palette(light_palette_path())

        self.assertEqual(palette.variant, "light")
        self.assertTrue(all(result["passes"] for result in contrast_results(palette)))


if __name__ == "__main__":
    unittest.main()
