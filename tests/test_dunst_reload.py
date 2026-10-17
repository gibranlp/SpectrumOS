from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RetiredNotificationTests(unittest.TestCase):
    def test_retired_reload_helper_is_removed(self):
        self.assertFalse((ROOT / "scripts/dunst-reload").exists())
        for name in ("font-size-menu", "font-family-menu", "theme-menu"):
            self.assertNotIn("/usr/lib/spectrumos/dunst-reload", (ROOT / "scripts" / name).read_text())
