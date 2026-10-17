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
from spectrum_theme.interpretation import BACKEND_DEFAULTS, parameters
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
        evidence = {variant: {mode: [] for mode in NATIVE_MODES} for variant in ('dark', 'light')}
        for case in FIXTURES['CASES']:
            pixels = FIXTURES['make_pixels'](case, 36, 24)
            for variant in ('dark', 'light'):
                palettes = [palette_from_pixels(pixels, case, DARK, mode, LIGHT, variant,
                            image_size=(36, 24)) for mode in NATIVE_MODES]
                for palette in palettes:
                    validate_contrast(palette)
                for mode, palette in zip(NATIVE_MODES, palettes):
                    first, second = (oklch(palette.rgb(role)) for role in ('accent', 'accent_alt'))
                    evidence[variant][mode].append(((first[1] + second[1]) / 2,
                                                    hue_distance(first[2], second[2])))
                self.assertEqual(len({tuple(p.roles.values()) for p in palettes}), 4, (case, variant))
                self.assertGreaterEqual(len({p.color('background') for p in palettes}), 3, (case, variant))
        for variant in ('dark', 'light'):
            means = {mode: tuple(sum(value[index] for value in values) / len(values) for index in (0, 1))
                     for mode, values in evidence[variant].items()}
            for mode in ('clustered', 'median-cut', 'weighted-regions'):
                self.assertGreater(means['spectrum'][0], means[mode][0], (variant, mode, 'chroma'))

            self.assertLess(means['clustered'][1], 65, variant)

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
                    self.assertLess(abs(decision['hue_shift']), 5 if role == 'background' else 3,
                                    (name, variant, role))
                    self.assertIn(decision['source'], debug['selected_colors'])
                    if name == 'warm-gray':
                        self.assertNotEqual(decision['source'], '#6f7776')
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

    def test_spatial_positions_change_accent_for_identical_histograms(self):
        first = [(40, 70, 125)] * 100
        second = first.copy()
        positions_center = [y * 10 + x for y in range(4, 6) for x in range(4, 6)]
        positions_edge = [0, 1, 10, 11]
        for position in positions_center:
            first[position] = (240, 90, 30)
        for position in positions_edge:
            second[position] = (240, 90, 30)
        for mode in ('spectrum', 'clustered', 'median-cut'):
            self.assertEqual(palette_from_pixels(first, 'same', DARK, mode),
                             palette_from_pixels(second, 'same', DARK, mode))
        center = extract_colors(first, 'weighted-regions', (10, 10), BACKEND_DEFAULTS['weighted-regions'])
        edge = extract_colors(second, 'weighted-regions', (10, 10), BACKEND_DEFAULTS['weighted-regions'])
        warm = lambda values: next(value for value in values if value.color == (240, 90, 30))
        self.assertGreater(warm(center).center, warm(edge).center * 5)
        central = palette_from_pixels(first, 'same', DARK, 'weighted-regions', image_size=(10, 10))
        peripheral = palette_from_pixels(second, 'same', DARK, 'weighted-regions', image_size=(10, 10))
        self.assertNotEqual(central.color('accent'), peripheral.color('accent'))

    def test_parameter_validation_and_spatial_controls(self):
        for overrides in ({'random': 1}, {'center_weight': True}, {'spatial_grid_size': 4.5},
                          {'edge_weight': float('nan')}, {'edge_weight': -1}):
            with self.assertRaises(ValueError):
                parameters('weighted-regions', overrides)
        pixels = [(40, 70, 125)] * 100
        for position in (44, 45, 54, 55):
            pixels[position] = (240, 90, 30)
        focal = palette_from_pixels(pixels, 'same', DARK, 'weighted-regions', image_size=(10, 10))
        no_focal = palette_from_pixels(pixels, 'same', DARK, 'weighted-regions', image_size=(10, 10),
                                      parameters={'center_weight': 0, 'focal_weight': 0})
        self.assertNotEqual(focal.color('accent'), no_focal.color('accent'))

    def test_small_vivid_focal_object_is_not_rejected_as_gray_noise(self):
        pixels = [(30, 30, 30)] * 995 + [(245, 90, 20)] * 5
        for variant in ('dark', 'light'):
            palette = palette_from_pixels(pixels, 'focal', DARK, 'spectrum', LIGHT, variant)
            self.assertGreater(oklch(palette.rgb('accent'))[1], 0.12)

    def test_cinematic_focal_subject_competes_with_curated_environment(self):
        pixels = FIXTURES['make_pixels']('small-vivid-focal', 64, 40)
        for variant in ('dark', 'light'):
            weighted = palette_from_pixels(pixels, 'focal', DARK, 'weighted-regions', LIGHT,
                                           variant, image_size=(64, 40))
            clustered = palette_from_pixels(pixels, 'focal', DARK, 'clustered', LIGHT, variant)
            self.assertLess(hue_distance(oklch(weighted.rgb('accent'))[2], 45), 20)
            self.assertLess(hue_distance(oklch(clustered.rgb('accent'))[2], 260), 25)

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
