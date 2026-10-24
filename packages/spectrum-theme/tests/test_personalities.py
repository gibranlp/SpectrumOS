from pathlib import Path
import json
import random
import runpy
import tempfile
import unittest
from unittest.mock import patch

from spectrum_theme.cli import default_palette_path, light_palette_path, main
from spectrum_theme.color import hue_distance, oklch, rgb
from spectrum_theme.comparison import compare_wallpapers
from spectrum_theme.extractors import NATIVE_MODES, ExtractorError, extract_colors, palette_from_pixels
from spectrum_theme.interpretation import parameters
from spectrum_theme.palette import load_palette, validate_contrast

FIXTURES = runpy.run_path(str(Path(__file__).resolve().parents[3] / 'scripts/theme-personality-fixtures'))
DARK = load_palette(default_palette_path())
LIGHT = load_palette(light_palette_path())


class ColorScienceTests(unittest.TestCase):
    def test_primary_red_matches_oklab_reference(self):
        lightness, chroma, hue = oklch((255, 0, 0))
        self.assertAlmostEqual(lightness, 0.627955, places=5)
        self.assertAlmostEqual(chroma, 0.257683, places=5)
        self.assertAlmostEqual(hue, 29.234, places=2)

    def test_srgb_roundtrip_including_boundaries(self):
        generator = random.Random(327)
        for color in [(0, 0, 0), (255, 255, 255), (255, 0, 0), (0, 255, 0), (0, 0, 255)] + [
            tuple(generator.randrange(256) for _ in range(3)) for _ in range(1000)]:
            self.assertEqual(rgb(oklch(color)), color)

    def test_out_of_gamut_reduces_chroma_without_rotating_hue(self):
        final = oklch(rgb((0.65, 0.4, 155)))
        self.assertAlmostEqual(final[0], 0.65, delta=0.003)
        self.assertLess(final[1], 0.4)
        self.assertLess(hue_distance(final[2], 155), 1)


class PersonalityTests(unittest.TestCase):
    def test_all_nine_wallpapers_produce_valid_distinct_variants(self):
        for case in FIXTURES['CASES']:
            pixels = FIXTURES['make_pixels'](case, 36, 24)
            for variant in ('dark', 'light'):
                palettes = [palette_from_pixels(pixels, case, DARK, mode, LIGHT, variant,
                            image_size=(36, 24)) for mode in NATIVE_MODES]
                for palette in palettes:
                    validate_contrast(palette)
                self.assertEqual(len({tuple(p.roles.values()) for p in palettes}), 4, (case, variant))
                self.assertGreaterEqual(len({p.color('background') for p in palettes}), 3, (case, variant))

    def test_spectrum_keeps_all_roles_in_wallpaper_families(self):
        cases = {
            'blue': [(12, 25, 44)] * 70 + [(30, 100, 210)] * 25 + [(70, 155, 220)] * 5,
            'warm': [(175, 55, 75)] * 50 + [(240, 135, 80)] * 40 + [(110, 65, 90)] * 10,
            'single': [(160, 60, 90)] * 100,
            'warm-gray': [(189, 68, 82)] * 40 + [(249, 153, 106)] * 30 + [(111, 119, 118)] * 30,
            'gray': [(80, 80, 80)] * 100,
        }
        for name, pixels in cases.items():
            for variant in ('dark', 'light'):
                debug = {}
                palette = palette_from_pixels(pixels, name, DARK, 'spectrum', LIGHT, variant, debug=debug)
                validate_contrast(palette)
                for role, decision in debug['roles'].items():
                    self.assertIn(decision['source'], debug['selected_colors'])
                    if name == 'gray':
                        self.assertLess(oklch(palette.rgb(role))[1], 0.001)
                if name != 'gray':
                    self.assertGreater(oklch(palette.rgb('accent'))[1], 0.12)

    def test_single_family_keeps_distinct_status_tones(self):
        for pixels in ([(160, 60, 90)] * 100, [(170, 130, 20)] * 100, [(80, 80, 80)] * 100):
            for variant in ('dark', 'light'):
                palette = palette_from_pixels(pixels, 'single-family', DARK, 'spectrum', LIGHT, variant)
                validate_contrast(palette)
                tones = [oklch(palette.rgb(role))[0] for role in ('success', 'warning', 'error')]
                self.assertGreater(min(abs(a - b) for i, a in enumerate(tones) for b in tones[i + 1:]), 0.06)
                self.assertNotEqual(palette.color('success'), palette.color('accent'))

    def test_haishoku_uses_color_regions_independently_of_image_position(self):
        first = [(40, 70, 125)] * 100
        second = first.copy()
        for position in (44, 45, 54, 55):
            first[position] = (240, 90, 30)
        for position in (0, 1, 10, 11):
            second[position] = (240, 90, 30)
        for mode in NATIVE_MODES:
            self.assertEqual(palette_from_pixels(first, 'same', DARK, mode, image_size=(10, 10)),
                             palette_from_pixels(second, 'same', DARK, mode, image_size=(10, 10)))

    def test_parameters_match_backend_algorithms(self):
        for mode, overrides in (('weighted-regions', {'center_weight': 1}),
                                ('clustered', {'cluster_count': True}),
                                ('median-cut', {'color_count': 4.5}),
                                ('spectrum', {'color_count': float('nan')}),
                                ('spectrum', {'color_count': -1})):
            with self.assertRaises(ValueError):
                parameters(mode, overrides)
        self.assertEqual(parameters('clustered')['cluster_count'], 6)
        self.assertEqual(parameters('median-cut')['color_count'], 8)
        self.assertEqual(parameters('spectrum')['color_count'], 16)

    def test_small_vivid_focal_object_is_not_rejected_as_gray_noise(self):
        pixels = [(30, 30, 30)] * 995 + [(245, 90, 20)] * 5
        for variant in ('dark', 'light'):
            palette = palette_from_pixels(pixels, 'focal', DARK, 'spectrum', LIGHT, variant)
            self.assertGreater(oklch(palette.rgb('accent'))[1], 0.12)

    def test_haishoku_retains_only_eight_most_populous_regions(self):
        pixels = []
        for index in range(27):
            color = ((index // 9) * 127, ((index // 3) % 3) * 127, (index % 3) * 127)
            pixels.extend([color] * (index + 1))
        candidates = extract_colors(pixels, 'weighted-regions', None, {})
        self.assertEqual(len(candidates), 8)
        self.assertEqual(sorted(item.weight for item in candidates), list(range(20, 28)))

    def test_debug_explains_source_and_final_roles(self):
        debug = {}
        palette = palette_from_pixels([(20, 60, 100)] * 40 + [(200, 80, 20)] * 10,
                                     'debug', DARK, debug=debug)
        self.assertTrue(debug['selected_colors'])
        self.assertEqual(debug['roles']['accent']['final'], palette.color('accent'))
        self.assertIn('hue_shift', debug['roles']['accent'])
        self.assertIn('contrast_lightness_adjustment', debug['roles']['accent'])

    def test_compare_exports_eight_palettes_and_diagnostics(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            with patch('spectrum_theme.comparison.decode_native_image', return_value=(
                [(20, 40, 80), (230, 100, 40)], 2, 1)):
                data, html = compare_wallpapers([Path('same.png')], output, DARK, LIGHT)
            record = json.loads(data.read_text())['wallpapers'][0]
            self.assertEqual(len(record['palettes']), 8)
            self.assertEqual(len(list(output.glob('*.toml'))), 8)
            self.assertEqual(len(record['distances']['dark']), 6)
            self.assertIn('data:image/png;base64,', html.read_text())
            self.assertIn('Δh', html.read_text())
            for item in record['palettes']:
                self.assertTrue(all(check['ratio'] >= check['minimum'] for check in item['contrast'].values()))

    def test_cli_reports_invalid_nested_parameters(self):
        with tempfile.TemporaryDirectory() as directory:
            settings = Path(directory) / 'parameters.json'
            settings.write_text('{"weighted-regions": {"center_weight": -1}}')
            image = Path(directory) / 'test.ppm'
            image.write_bytes(b'P6\n1 1\n255\n\x01\x02\x03')
            self.assertEqual(main(['compare', str(image), '--output', str(Path(directory) / 'out'),
                                   '--parameters', str(settings)]), 1)

    def test_compare_rejects_non_object_parameters(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ExtractorError, 'object keyed'):
                compare_wallpapers([Path('same.png')], Path(directory), DARK, LIGHT, [])
