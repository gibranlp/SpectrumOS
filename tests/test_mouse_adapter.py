from importlib.machinery import SourceFileLoader
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]


def load():
    loader = SourceFileLoader("mouse_adapter", str(ROOT / "scripts/mouse-adapter"))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class MouseTests(unittest.TestCase):
    def test_invalid_values_never_apply_or_save(self):
        module = load()
        for key, value in (("sensitivity", "nan"), ("sensitivity", "2"),
                           ("scroll_factor", "0"), ("scroll_factor", "inf"),
                           ("cursor_size", "999"), ("natural_scroll", "yes"),
                           ("adaptive_cursor", "yes"), ("bogus", "1")):
            with self.subTest(key=key, value=value), tempfile.TemporaryDirectory() as directory:
                module.STATE = Path(directory) / "mouse.json"
                module.STATE.write_text(json.dumps(module.DEFAULTS))
                before = module.STATE.read_bytes()
                with mock.patch.object(module, "run") as run:
                    with self.assertRaises(ValueError):
                        module.main(["--set", key, value])
                    run.assert_not_called()
                self.assertEqual(module.STATE.read_bytes(), before)

    def test_recolor_preserves_animation_hotspots_outline_and_alpha(self):
        module = load()
        pixels = bytes((255, 255, 255, 255, 10, 10, 10, 255, 128, 128, 128, 128))
        frame = struct.pack("<9I", 36, 0xFFFD0002, 24, 1, 3, 1, 1, 0, 150) + pixels
        offset = 16 + 24
        source = struct.pack("<4I", 0x72756358, 16, 1, 2)
        source += struct.pack("<3I", 0xFFFD0002, 24, offset)
        source += struct.pack("<3I", 0xFFFD0002, 24, offset + len(frame))
        source += frame + frame
        tinted = module.recolor(source, "#804020")
        self.assertEqual(len(tinted), len(source))
        for start in (offset, offset + len(frame)):
            self.assertEqual(tinted[start:start + 36], source[start:start + 36])
            self.assertEqual(tinted[start + 36:start + 40], bytes((32, 64, 128, 255)))
            self.assertEqual(tinted[start + 40:start + 44], bytes((10, 10, 10, 255)))
            self.assertEqual(tinted[start + 44:start + 48], bytes((16, 32, 64, 128)))

    def test_truncated_cursor_rejected(self):
        module = load()
        with self.assertRaises((ValueError, struct.error)):
            module.recolor(b"Xcur", "#abcdef")

    def test_theme_generation_reuses_all_installed_shapes(self):
        module = load()
        with tempfile.TemporaryDirectory() as directory:
            module.DATA = Path(directory) / "data"
            module.CACHE = Path(directory) / "cache"
            palette = module.CACHE / "spectrumos/theme/current/palette.json"
            palette.parent.mkdir(parents=True)
            palette.write_text(json.dumps({"roles": {"accent": "#804020"}}))
            name = module.cursor_theme({**module.DEFAULTS, "adaptive_cursor": True})
            target = module.DATA / "icons" / name / "cursors"
            self.assertEqual({p.name for p in target.iterdir()}, {p.name for p in module.BASE.iterdir()})
            for path in module.BASE.iterdir():
                if path.is_symlink():
                    self.assertEqual((target / path.name).readlink(), path.readlink())
                else:
                    self.assertEqual(len((target / path.name).read_bytes()), len(path.read_bytes()))
            self.assertEqual(module.cursor_theme({**module.DEFAULTS, "adaptive_cursor": True}), name)
            palette.write_text(json.dumps({"roles": {"accent": "#abcdef"}}))
            self.assertNotEqual(module.cursor_theme({**module.DEFAULTS, "adaptive_cursor": True}), name)

    def test_cursor_settings_preserve_existing_gtk_preferences(self):
        module = load()
        with tempfile.TemporaryDirectory() as directory:
            module.CONFIG = Path(directory)
            path = module.CONFIG / "gtk-3.0/settings.ini"
            path.parent.mkdir()
            path.write_text("[Settings]\ngtk-font-name=Personal 15\ngtk-theme-name=Custom\n")
            with mock.patch.object(module, "run") as run:
                module.sync_cursor({**module.DEFAULTS, "cursor_size": 48})
                self.assertIn(mock.call("hyprctl", "setcursor", "Adwaita", "48"), run.call_args_list)
            self.assertIn("gtk-font-name = Personal 15", path.read_text())
            self.assertIn("gtk-theme-name = Custom", path.read_text())
            self.assertIn("gtk-cursor-theme-size = 48", path.read_text())

    def test_apply_persists_and_cursor_refresh_keeps_input_unchanged(self):
        module = load()
        with tempfile.TemporaryDirectory() as directory:
            module.CONFIG = Path(directory)
            module.STATE = module.CONFIG / "spectrumos/mouse.json"
            module.STATE.parent.mkdir()
            module.STATE.write_text(json.dumps(module.DEFAULTS))
            with mock.patch.object(module, "run") as run, mock.patch.object(module, "sync_cursor"):
                module.main(["--set", "scroll_factor", "2.5"])
                self.assertEqual(json.loads(module.STATE.read_text())["scroll_factor"], 2.5)
                generated = module.CONFIG / "spectrumos/mouse.lua"
                self.assertIn("scroll_factor = 2.5", generated.read_text())
                before = generated.read_bytes()
                run.reset_mock()
                module.main(["--cursor"])
                run.assert_not_called()
                self.assertEqual(generated.read_bytes(), before)
                module.main(["--reset-input"])
                self.assertEqual(json.loads(module.STATE.read_text())["scroll_factor"], 1)
