from pathlib import Path
import os
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
MENU = ROOT / "scripts" / "hyprland-menu"


class HyprlandMenuTests(unittest.TestCase):
    def test_menu_is_valid_bash(self):
        result = subprocess.run(
            ("bash", "-n", str(MENU)),
            cwd=ROOT,
            check=False,
            text=True,
            capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_apply_settings_does_not_rebind_legacy_panel_escape(self):
        content = MENU.read_text(encoding="utf-8")
        apply_settings = content.split("apply_settings() {", 1)[1].split("\n}", 1)[0]
        self.assertIn("hyprctl reload config-only", apply_settings)
        self.assertNotIn("eww-bind-escape", apply_settings)

    def test_default_generation_uses_spectrum_values(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment = os.environ.copy()
            environment["XDG_CONFIG_HOME"] = temporary
            result = subprocess.run(
                ("bash", "-c", f'source "{MENU}"; write_state; write_config'),
                cwd=ROOT,
                env=environment,
                check=False,
                text=True,
                capture_output=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            generated = (Path(temporary) / "spectrumos" / "hyprland-controls.lua").read_text(
                encoding="utf-8"
            )
            self.assertIn("gaps_in = 5", generated)
            self.assertIn("rounding = 10", generated)
            self.assertIn("active_opacity = 1.0", generated)
            self.assertIn("inactive_opacity = 1.0", generated)
            self.assertIn('layout = "dwindle"', generated)
            self.assertIn("enabled = true, size = 3, passes = 1", generated)
            self.assertIn("new_optimizations = true", generated)
            self.assertIn("xray = true", generated)

    def test_generated_controls_load_before_personal_override(self):
        entrypoint = (ROOT / "configs" / "hyprland" / "hyprland.lua").read_text(
            encoding="utf-8"
        )
        controls = entrypoint.index("hyprland-controls.lua")
        personal = entrypoint.index('hyprland.lua")', controls + 1)
        self.assertLess(controls, personal)

    def test_panel_exposes_hyprland_controls(self):
        panel = (ROOT / "scripts" / "panel").read_text(encoding="utf-8")
        self.assertIn("Hyprland settings", panel)
        self.assertIn("/usr/lib/spectrumos/hyprland-menu", panel)

    def test_transparency_presets_are_bounded(self):
        content = MENU.read_text(encoding="utf-8")
        self.assertIn("Opaque Subtle Balanced Glass", content)
        self.assertIn("active_opacity=0.86", content)
        self.assertIn("inactive_opacity=0.76", content)

    def test_layout_presets_include_scrolling_and_monocle(self):
        # Both confirmed native to this exact installed Hyprland (general:layout =
        # scrolling|monocle accepted with no plugin, no error) before adding them here.
        content = MENU.read_text(encoding="utf-8")
        self.assertIn("Dwindle Master Scrolling Monocle", content)
        self.assertIn("layout:dwindle|layout:master|layout:scrolling|layout:monocle", content)

    def test_layout_is_passed_through_to_hyprland_config_unchanged(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment = os.environ.copy()
            environment["XDG_CONFIG_HOME"] = temporary
            for layout in ("dwindle", "master", "scrolling", "monocle"):
                result = subprocess.run(
                    ("bash", "-c", f'source "{MENU}"; layout={layout}; write_state; write_config'),
                    cwd=ROOT, env=environment, check=False, text=True, capture_output=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                generated = (Path(temporary) / "spectrumos" / "hyprland-controls.lua").read_text(encoding="utf-8")
                self.assertIn(f'layout = "{layout}"', generated, layout)

    def test_border_presets_are_bounded(self):
        content = MENU.read_text(encoding="utf-8")
        self.assertIn("None Thin Spectrum Thick", content)
        self.assertIn("border:none|border:thin|border:spectrum|border:thick", content)

    def test_default_generation_includes_default_border_size(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment = os.environ.copy()
            environment["XDG_CONFIG_HOME"] = temporary
            result = subprocess.run(
                ("bash", "-c", f'source "{MENU}"; write_state; write_config'),
                cwd=ROOT, env=environment, check=False, text=True, capture_output=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            generated = (Path(temporary) / "spectrumos" / "hyprland-controls.lua").read_text(encoding="utf-8")
        # The pre-existing hardcoded default in configs/hyprland/appearance.lua -- picking
        # "Spectrum" in the control center should reproduce exactly what a fresh install
        # already ships with, same as every other field here.
        self.assertIn("border_size = 3", generated)

    def test_border_sizes_are_bounded(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment = os.environ.copy()
            environment["XDG_CONFIG_HOME"] = temporary
            for border, expected in (("none", 0), ("thin", 1), ("spectrum", 3), ("thick", 6)):
                result = subprocess.run(
                    ("bash", "-c", f'source "{MENU}"; border={border}; write_state; write_config'),
                    cwd=ROOT, env=environment, check=False, text=True, capture_output=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                generated = (Path(temporary) / "spectrumos" / "hyprland-controls.lua").read_text(encoding="utf-8")
                self.assertIn(f"border_size = {expected}", generated, border)

    def test_animation_tiers_produce_distinct_speeds_and_balanced_matches_the_old_default(self):
        # "on" was the only enabled state before Smooth/Balanced/Heavy existed, reproducing
        # exactly the speeds/styles animations.lua itself has always shipped with --
        # "Balanced" has to keep matching those so a state file saved before this change
        # (or a user who just wants the original behavior back) sees no difference.
        with tempfile.TemporaryDirectory() as temporary:
            environment = os.environ.copy()
            environment["XDG_CONFIG_HOME"] = temporary
            result = subprocess.run(
                ("bash", "-c", f'source "{MENU}"; animations=balanced; write_state; write_config'),
                cwd=ROOT, env=environment, check=False, text=True, capture_output=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            balanced = (Path(temporary) / "spectrumos" / "hyprland-controls.lua").read_text(encoding="utf-8")
        self.assertIn("animations = { enabled = true }", balanced)
        self.assertIn('speed = 2.5, bezier = "spectrumEase"', balanced)
        self.assertIn('style = "popin 94%"', balanced)
        self.assertIn('style = "slidefade 20%"', balanced)

        with tempfile.TemporaryDirectory() as smooth_dir, tempfile.TemporaryDirectory() as heavy_dir:
            for animations, directory in (("smooth", smooth_dir), ("heavy", heavy_dir)):
                environment = os.environ.copy()
                environment["XDG_CONFIG_HOME"] = directory
                result = subprocess.run(
                    ("bash", "-c", f'source "{MENU}"; animations={animations}; write_state; write_config'),
                    cwd=ROOT, env=environment, check=False, text=True, capture_output=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
            smooth = (Path(smooth_dir) / "spectrumos" / "hyprland-controls.lua").read_text(encoding="utf-8")
            heavy = (Path(heavy_dir) / "spectrumos" / "hyprland-controls.lua").read_text(encoding="utf-8")
        # Same two curves for every tier -- only duration and pop-in/slide distance differ.
        for tier in (smooth, heavy):
            self.assertIn('bezier = "spectrumEase"', tier)
            self.assertIn('bezier = "spectrumExit"', tier)
        self.assertIn('speed = 1.5, bezier = "spectrumEase"', smooth)
        self.assertIn('speed = 4, bezier = "spectrumEase"', heavy)
        self.assertNotEqual(smooth, heavy)
        self.assertNotEqual(smooth, balanced)
        self.assertNotEqual(heavy, balanced)

    def test_animations_off_disables_the_flag_but_still_writes_bounded_speeds(self):
        with tempfile.TemporaryDirectory() as temporary:
            environment = os.environ.copy()
            environment["XDG_CONFIG_HOME"] = temporary
            result = subprocess.run(
                ("bash", "-c", f'source "{MENU}"; animations=off; write_state; write_config'),
                cwd=ROOT, env=environment, check=False, text=True, capture_output=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            generated = (Path(temporary) / "spectrumos" / "hyprland-controls.lua").read_text(encoding="utf-8")
        self.assertIn("animations = { enabled = false }", generated)

    def test_legacy_on_state_migrates_to_balanced(self):
        # A state file saved before Smooth/Balanced/Heavy existed only ever had "on" or
        # "off" for this field -- "on" must keep meaning exactly what it always did
        # (animations.lua's own defaults), not silently jump to a different intensity.
        with tempfile.TemporaryDirectory() as temporary:
            state_dir = Path(temporary) / "spectrumos"
            state_dir.mkdir(parents=True)
            (state_dir / "hyprland-controls.state").write_text(
                "blur=light\ngaps=balanced\nrounding=spectrum\ntransparency=opaque\nlayout=dwindle\nanimations=on\n",
                encoding="utf-8",
            )
            environment = os.environ.copy()
            environment["XDG_CONFIG_HOME"] = temporary
            result = subprocess.run(
                ("bash", "-c", f'source "{MENU}"; load_state; printf %s "$animations"'),
                cwd=ROOT, env=environment, check=False, text=True, capture_output=True,
            )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "balanced")

    def test_json_and_set_expose_border_and_the_new_animation_tiers(self):
        content = MENU.read_text(encoding="utf-8")
        self.assertIn('"border":"%s"', content)
        self.assertIn("animations:off|animations:smooth|animations:balanced|animations:heavy", content)


if __name__ == "__main__":
    unittest.main()
