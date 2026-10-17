from pathlib import Path
import tempfile
import unittest

from spectrum_theme.evaluation import _render_html


class EvaluationTests(unittest.TestCase):
    def test_report_contains_metrics_swatches_and_consumer_previews(self):
        with tempfile.TemporaryDirectory() as directory:
            wallpaper = Path(directory) / "wallpaper.png"
            wallpaper.touch()
            report = _render_html(
                [
                    {
                        "wallpaper": str(wallpaper),
                        "mode": "spectrum",
                        "variant": "dark",
                        "elapsed_ms": 12.5,
                        "passes": True,
                        "contrast_checks": [
                            {
                                "name": "Foreground/background",
                                "ratio": 10.2,
                                "minimum": 4.5,
                                "passes": True,
                            }
                        ],
                        "roles": {
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
                    }
                ]
            )

        self.assertIn("10.20:1 / 4.50:1", report)
        self.assertIn("PASS", report)
        self.assertIn("Kitty", report)
        self.assertIn("Dunst", report)
        self.assertIn("Hyprland", report)
        self.assertIn("Password", report)
        self.assertIn("#76b7ff", report)
