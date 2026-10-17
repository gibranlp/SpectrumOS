from pathlib import Path
import colorsys
import tempfile
import unittest

from spectrum_theme.extractors import (
    ExtractorError,
    extract_native_ppm,
    palette_from_matugen_data,
    palette_from_pixels,
    write_palette,
)
from spectrum_theme.palette import Palette, load_palette
from spectrum_theme.color import oklch


FALLBACK = Palette(
    name="Fallback",
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

LIGHT_FALLBACK = Palette(
    name="Light fallback",
    variant="light",
    source="test",
    roles={
        "background": "#f7f8fb",
        "surface": "#eef1f6",
        "surface_alt": "#e1e6ee",
        "foreground": "#1c2430",
        "muted": "#566273",
        "accent": "#245f9e",
        "accent_alt": "#6a3d91",
        "success": "#176b46",
        "warning": "#7a5200",
        "error": "#a3293d",
    },
)


def matugen_data():
    dark_values = {
        "background": "#101218",
        "surface_container": "#191c24",
        "surface_container_high": "#252a35",
        "on_background": "#e9edf5",
        "on_surface_variant": "#9ca6b8",
        "primary": "#76b7ff",
        "secondary": "#c49aff",
        "error": "#ff8c9a",
    }
    light_values = {
        "background": "#f7f8fb",
        "surface_container": "#eef1f6",
        "surface_container_high": "#e1e6ee",
        "on_background": "#1c2430",
        "on_surface_variant": "#566273",
        "primary": "#245f9e",
        "secondary": "#6a3d91",
        "error": "#a3293d",
    }
    return {
        "colors": {
            role: {
                "dark": {"color": color},
                "light": {"color": light_values[role]},
            }
            for role, color in dark_values.items()
        }
    }


class ExtractorTests(unittest.TestCase):
    def test_native_extraction_is_deterministic_and_valid(self):
        pixels = [(18, 24, 35)] * 12 + [(28, 120, 220)] * 5 + [(190, 55, 150)] * 3

        first = palette_from_pixels(pixels, "fixture.ppm", FALLBACK)
        second = palette_from_pixels(list(reversed(pixels)), "fixture.ppm", FALLBACK)

        self.assertEqual(first, second)
        self.assertEqual(first.variant, "dark")
        self.assertEqual(first.source, "native:spectrum:fixture.ppm")

    def test_native_modes_produce_distinct_palettes(self):
        pixels = []
        for index in range(240):
            color = ((index * 37) % 256, (index * 71 + 30) % 256, (index * 19 + 80) % 256)
            pixels.extend([color] * (1 + index % 7))

        palettes = {
            mode: palette_from_pixels(pixels, "fixture.ppm", FALLBACK, mode)
            for mode in ("spectrum", "clustered", "median-cut", "weighted-regions")
        }

        self.assertEqual(len({tuple(palette.roles.values()) for palette in palettes.values()}), 4)
        for mode, palette in palettes.items():
            self.assertEqual(palette.source, f"native:{mode}:fixture.ppm")

    def test_native_modes_give_the_accent_a_distinct_personality(self):
        pixels = [(18, 24, 35)] * 60 + [(28, 120, 220)] * 30 + [(190, 60, 150)] * 10

        def saturation(palette):
            return oklch(palette.rgb("accent"))[1]

        saturations = {
            mode: saturation(palette_from_pixels(pixels, "fixture.ppm", FALLBACK, mode))
            for mode in ("spectrum", "clustered", "median-cut", "weighted-regions")
        }

        self.assertGreater(saturations["spectrum"], saturations["clustered"])
        self.assertGreater(saturations["median-cut"], saturations["clustered"])

    def test_native_modes_change_the_canvas_and_surfaces(self):
        pixels = (
            [(12, 24, 40)] * 55
            + [(30, 120, 220)] * 25
            + [(230, 60, 100)] * 15
            + [(250, 180, 30)] * 5
        )
        for variant in ("dark", "light"):
            palettes = [
                palette_from_pixels(pixels, "fixture.ppm", FALLBACK, mode, LIGHT_FALLBACK, variant)
                for mode in ("spectrum", "clustered", "median-cut", "weighted-regions")
            ]
            for role in ("background", "surface", "surface_alt", "foreground", "muted"):
                self.assertEqual(len({palette.color(role) for palette in palettes}), 4, (variant, role))

    def test_median_cut_preserves_a_chromatic_accent_against_bright_surfaces(self):
        pixels = (
            [(12, 24, 40)] * 55
            + [(30, 120, 220)] * 25
            + [(230, 60, 100)] * 15
            + [(250, 180, 30)] * 5
        )
        palette = palette_from_pixels(pixels, "fixture.ppm", FALLBACK, "median-cut", LIGHT_FALLBACK, "dark")
        accent = palette.rgb("accent")
        self.assertGreater(max(accent) - min(accent), 25)

    def test_all_modes_survive_a_contrast_stress_sweep(self):
        fixtures = [
            [(255, 255, 255)] * 220 + [(3, 253, 128)] * 12,
            [(0, 0, 0)] * 220 + [(255, 40, 40)] * 12,
            [(250, 245, 240)] * 200 + [(20, 200, 255)] * 8,
            [(10, 10, 10)] * 200 + [(255, 255, 0)] * 8,
        ]
        for pixels in fixtures:
            for mode in ("spectrum", "clustered", "median-cut", "weighted-regions"):
                for variant in ("dark", "light"):
                    try:
                        palette_from_pixels(pixels, "fixture.ppm", FALLBACK, mode, LIGHT_FALLBACK, variant)
                    except ExtractorError as error:
                        self.fail(f"{mode}/{variant} raised on a forced-variant edge case: {error}")

    def test_native_neutral_image_stays_neutral(self):
        palette = palette_from_pixels([(32, 32, 32), (80, 80, 80)], "neutral.ppm", FALLBACK)

        for role in ("background", "surface", "surface_alt", "foreground", "muted", "accent", "accent_alt"):
            color = palette.color(role)
            channels = [int(color[index : index + 2], 16) for index in (1, 3, 5)]
            self.assertLessEqual(max(channels) - min(channels), 1, role)

    def test_median_cut_keeps_source_blue_hues(self):
        palette = palette_from_pixels(
            [(8, 18, 35)] * 70 + [(22, 92, 210)] * 25 + [(60, 130, 235)] * 5,
            "blue.ppm",
            FALLBACK,
            "median-cut",
        )

        hues = []
        for role in ("accent", "accent_alt"):
            color = palette.color(role)
            rgb = tuple(int(color[index : index + 2], 16) / 255 for index in (1, 3, 5))
            hues.append(colorsys.rgb_to_hls(*rgb)[0])
        distance = abs(hues[0] - hues[1])
        self.assertLess(min(distance, 1 - distance), 0.03)

    def test_small_chromatic_noise_does_not_color_a_monochrome_image(self):
        pixels = [(20, 20, 20)] * 970 + [(21, 22, 24)] * 25 + [(20, 25, 32)] * 5
        palette = palette_from_pixels(pixels, "noisy-black.ppm", FALLBACK)

        for role in ("accent", "accent_alt"):
            self.assertLess(oklch(palette.rgb(role))[1], 0.001)

    def test_native_selects_light_variant(self):
        palette = palette_from_pixels(
            [(245, 242, 235)] * 4, "light.ppm", FALLBACK, light_fallback=LIGHT_FALLBACK
        )

        self.assertEqual(palette.variant, "light")
        self.assertNotEqual(palette.color("success"), palette.color("warning"))

    def test_native_can_force_light_variant_for_dark_pixels(self):
        palette = palette_from_pixels(
            [(20, 24, 30)] * 4,
            "dark.ppm",
            FALLBACK,
            light_fallback=LIGHT_FALLBACK,
            variant="light",
        )

        self.assertEqual(palette.variant, "light")
        self.assertNotEqual(palette.color("success"), palette.color("warning"))

    def test_native_reads_ppm_fixture(self):
        with tempfile.TemporaryDirectory() as directory:
            image = Path(directory) / "fixture.ppm"
            image.write_bytes(b"P6\n2 1\n255\n" + bytes((10, 20, 30, 40, 120, 220)))
            palette = extract_native_ppm(image, FALLBACK)

        self.assertEqual(palette.source, "native:spectrum:fixture.ppm")

    def test_native_rejects_empty_pixel_input(self):
        with self.assertRaisesRegex(ExtractorError, "at least one pixel"):
            palette_from_pixels([], "empty.ppm", FALLBACK)

    def test_maps_matugen_roles_and_keeps_stable_status_colors(self):
        palette = palette_from_matugen_data(matugen_data(), "wallpaper.png", FALLBACK)

        self.assertEqual(palette.color("accent"), "#76b7ff")
        self.assertEqual(palette.color("success"), FALLBACK.color("success"))
        self.assertEqual(palette.source, "matugen:dark:wallpaper.png")

    def test_rejects_incomplete_matugen_data(self):
        data = matugen_data()
        del data["colors"]["primary"]

        with self.assertRaisesRegex(ExtractorError, "missing required color data"):
            palette_from_matugen_data(data, "wallpaper.png", FALLBACK)

    def test_matugen_light_uses_light_semantic_status_colors(self):
        palette = palette_from_matugen_data(
            matugen_data(), "wallpaper.png", LIGHT_FALLBACK, "light"
        )

        self.assertEqual(palette.variant, "light")
        self.assertEqual(palette.color("success"), LIGHT_FALLBACK.color("success"))
        self.assertEqual(palette.source, "matugen:light:wallpaper.png")

    def test_written_palette_can_be_loaded(self):
        palette = palette_from_matugen_data(matugen_data(), "wallpaper.png", FALLBACK)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "palette.toml"
            write_palette(path, palette)
            loaded = load_palette(path)

        self.assertEqual(loaded, palette)


if __name__ == "__main__":
    unittest.main()
