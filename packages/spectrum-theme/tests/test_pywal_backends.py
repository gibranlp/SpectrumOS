import colorsys
import subprocess
import unittest
from unittest.mock import patch

from spectrum_theme.color import rgb
from spectrum_theme.extractors import (
    ExtractorError, _clustered_candidates, _median_cut_candidates,
    _wal_candidates, _weighted_region_candidates,
)
from spectrum_theme.interpretation import Candidate, Interpretation, INTERPRETERS


class PywalBackendTests(unittest.TestCase):
    def test_colorz_clamps_value_before_clustering_and_orders_hues(self):
        pixels = [(30, 0, 0), (0, 255, 0), (0, 0, 50)]
        self.assertEqual(_clustered_candidates(pixels), [
            ((170, 0, 0), 1), ((0, 200, 0), 1), ((0, 0, 170), 1)])

    def test_colorz_clusters_unique_colors_rather_than_pixel_population(self):
        pixels = [(20, 40, 80), (100, 20, 180), (100, 200, 50), (240, 30, 50),
                  (30, 240, 250), (200, 180, 20), (50, 70, 90)]
        expected = _clustered_candidates(pixels, 4)
        self.assertEqual(_clustered_candidates(pixels + [pixels[0]] * 1000, 4), expected)
        self.assertEqual(_clustered_candidates(list(reversed(pixels)), 4), expected)

    def test_colorthief_filters_near_white_and_uses_five_bit_cells(self):
        self.assertEqual(_median_cut_candidates([(255, 255, 255)] * 50 + [(20, 140, 210)] * 3),
                         [((20, 140, 212), 3)])
        self.assertEqual(_median_cut_candidates([(255, 255, 255)]), [((252, 252, 252), 1)])

    def test_colorthief_populations_survive_all_splits(self):
        pixels = [(i, (i * 17) % 251, (i * 37) % 251) for i in range(250)]
        palette = _median_cut_candidates(pixels)
        self.assertEqual(len(palette), 8)
        self.assertEqual(sum(weight for _, weight in palette), 250)
        self.assertEqual(_median_cut_candidates(list(reversed(pixels))), palette)

    def test_haishoku_uses_exact_thirds_and_truncates_weighted_means(self):
        pixels = [(value, value, value) for value in (0, 84, 85, 169, 170, 255)]
        self.assertEqual(_weighted_region_candidates(pixels), [
            ((42, 42, 42), 2), ((127, 127, 127), 2), ((212, 212, 212), 2)])

    def test_wal_keeps_solid_images_and_quantizes_many_colors(self):
        self.assertEqual(_wal_candidates([(12, 24, 36)] * 6, (3, 2)), [((12, 24, 36), 6)])
        pixels = [(i, (i * 13) % 256, (i * 29) % 256) for i in range(256)]
        palette = _wal_candidates(pixels, (16, 16))
        self.assertGreaterEqual(len(palette), 16)
        self.assertEqual(sum(weight for _, weight in palette), len(pixels))
        self.assertEqual(palette, sorted(palette, key=lambda pair: (colorsys.rgb_to_yiq(*pair[0]), pair[0])))

    def test_wal_reports_missing_decoder_and_process_failures(self):
        with patch('spectrum_theme.extractors.shutil.which', return_value=None):
            with self.assertRaisesRegex(ExtractorError, 'ImageMagick is required'):
                _wal_candidates([(0, 0, 0)], None)
        with patch('spectrum_theme.extractors.subprocess.run', side_effect=subprocess.TimeoutExpired('magick', 30)):
            with self.assertRaisesRegex(ExtractorError, 'could not quantize'):
                _wal_candidates([(0, 0, 0)], None)

    def test_pywal_background_rules_before_accessibility_repair(self):
        candidates = [Candidate((40, 60, 80), 70), Candidate((120, 100, 180), 20),
                      Candidate((200, 220, 240), 10)]
        expected = {
            'spectrum': {'dark': (24, 36, 48), 'light': (246, 249, 252)},
            'clustered': {'dark': (8, 12, 16), 'light': (244, 245, 246)},
            'median-cut': {'dark': (8, 12, 16), 'light': (233, 235, 237)},
            'weighted-regions': {'dark': (25, 27, 30), 'light': (248, 249, 249)},
        }
        for mode, variants in expected.items():
            for variant, background in variants.items():
                context = Interpretation(candidates, variant, {})
                INTERPRETERS[mode](context)
                actual = rgb(context.roles['background'])
                for found, wanted in zip(actual, background):
                    self.assertAlmostEqual(found, wanted, delta=1, msg=(mode, variant, actual))
