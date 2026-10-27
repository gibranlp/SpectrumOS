from pathlib import Path
import json
import os
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]



class WaybarTests(unittest.TestCase):

    def test_menu_persists_layout_style_and_theme_choices(self):
        menu = (ROOT / "scripts" / "waybar-menu").read_text(encoding="utf-8")
        shell = (ROOT / "configs/spectrum-shell/shell.qml").read_text(encoding="utf-8")

        for choice in ("Minimal", "Multimedia", "Productivity", "Detailed", "Gaming", "Hidden"):
            self.assertIn(choice, menu)
        for style in ("Spectrum", "Square"):
            self.assertIn(style, menu)
        for theme in ("Unified", "Tonal", "Prism"):
            self.assertIn(theme, menu)
        self.assertIn("XDG_STATE_HOME", menu)
        self.assertIn("--restart", menu)
        self.assertNotIn("systemctl --user restart spectrum-waybar.service", menu)
        self.assertIn('setBarProfile(profile: string)', shell)



    def test_cava_bridge_uses_the_active_spectrum_accents(self):
        bridge = (ROOT / "scripts" / "waybar-cava").read_text(encoding="utf-8")
        self.assertIn("spectrumos/theme/current/palette.json", bridge)
        self.assertNotIn("/var/lib/spectrumos/appearance/colors.conf", bridge)
        self.assertIn('roles["accent"]', bridge)
        self.assertIn('roles["accent_alt"]', bridge)
        self.assertIn("<span foreground=", bridge)




    def test_workspace_icons_are_visible_in_control_center(self):
        config = (ROOT / "configs/spectrum-shell/ControlCenter.qml").read_text(encoding="utf-8")
        self.assertIn('text: qsTranslate("Spectrum", "WORKSPACE ICONS")', config)
        self.assertIn('model: center.theme.workspaceIcons.sets || []', config)
        self.assertIn('center.theme.backend("waybar-workspace-icons")', config)

    def test_workspace_icon_sets_are_shared_between_menu_and_launcher(self):
        icons = (ROOT / "scripts" / "waybar-workspace-icons").read_text(encoding="utf-8")
        shell = (ROOT / "configs/spectrum-shell/shell.qml").read_text(encoding="utf-8")
        menu = (ROOT / "scripts" / "waybar-menu").read_text(encoding="utf-8")

        self.assertIn('DEFAULT_KEY = "pacman"', icons)
        for key in (
            "kanji", "pacman", "computers", "cosmos", "arcade", "garden", "music", "code",
        ):
            self.assertIn(f'"{key}"', icons)
        for removed in ("circles", "squares", "triangles", "hexagons", "rectangles", "labels"):
            self.assertNotIn(f'"{removed}":', icons)
        self.assertIn("range(1, MAX_WORKSPACE + 1)", icons)

        self.assertIn('shell.backend("waybar-workspace-icons")', shell)

        self.assertIn("waybar-workspace-icons set", menu)
        self.assertIn("waybar-workspace-icons list", menu)
        self.assertIn("Workspace icons", menu)

        # waybar-workspace-icons is the sole writer of this preference (via `set`, called
        # by both the eww button and the wofi menu); everyone reading it back -- the menu's
        # own label lookup, and system-adapter for eww -- must agree on the exact filename,
        # or a change would silently never show up as "current" anywhere.
        adapter = (ROOT / "scripts" / "system-adapter").read_text(encoding="utf-8")
        self.assertIn('spectrumos/waybar/workspace_icons"', icons)
        self.assertIn("$state_dir/workspace_icons", menu)
        self.assertIn('"workspace_icons", "pacman"', adapter)

    def test_workspace_icon_script_stages_and_persists_choices(self):
        script = ROOT / "scripts" / "waybar-workspace-icons"
        with tempfile.TemporaryDirectory() as directory:
            environment = {**os.environ, "XDG_STATE_HOME": directory, "XDG_CACHE_HOME": directory}
            layout = Path(directory) / "layout.jsonc"
            layout.write_text(
                json.dumps({"hyprland/workspaces": {"format": "{icon}"}, "modules-left": ["hyprland/workspaces"]}),
                encoding="utf-8",
            )

            default_stage = subprocess.run(
                ("python", str(script), "stage", str(layout)),
                check=True, capture_output=True, text=True, env=environment,
            )
            default_config = json.loads(Path(default_stage.stdout.strip()).read_text(encoding="utf-8"))
            self.assertEqual(default_config["hyprland/workspaces"]["format-icons"], {
                "active": "󰮯", "persistent": "󰊠", "default": "󰊠", "empty": "•",
            })

            (Path(directory) / "spectrumos/waybar").mkdir(parents=True, exist_ok=True)
            (Path(directory) / "spectrumos/waybar/workspace_icons").write_text("kanji", encoding="utf-8")

            staged = subprocess.run(
                ("python", str(script), "stage", str(layout)),
                check=True, capture_output=True, text=True, env=environment,
            ).stdout.strip()
            merged = json.loads(Path(staged).read_text(encoding="utf-8"))
            self.assertEqual(
                merged["hyprland/workspaces"]["format-icons"],
                {str(n): glyph for n, glyph in enumerate("一二三四五六", start=1)},
            )

            selected = subprocess.run(
                ("python", str(script), "--json"),
                check=True, capture_output=True, text=True, env=environment,
            )
            self.assertEqual(json.loads(selected.stdout)["current"], "kanji")

            listing = subprocess.run(
                ("python", str(script), "list"), check=True, capture_output=True, text=True, env=environment
            ).stdout
            self.assertIn("*\tkanji\tKanji Numbers", listing)

            rejected = subprocess.run(
                ("python", str(script), "set", "not-a-real-set"), capture_output=True, text=True, env=environment
            )
            self.assertEqual(rejected.returncode, 2)






    def test_pomodoro_widget_persists_state(self):
        widget = ROOT / "scripts" / "waybar-widgets"
        with tempfile.TemporaryDirectory() as directory:
            environment = {**os.environ, "XDG_STATE_HOME": directory}
            initial = subprocess.run(
                ("python", str(widget), "pomodoro"),
                check=True,
                capture_output=True,
                text=True,
                env=environment,
            )
            subprocess.run(
                ("python", str(widget), "pomodoro-toggle"), check=True, env=environment
            )
            running = subprocess.run(
                ("python", str(widget), "pomodoro"),
                check=True,
                capture_output=True,
                text=True,
                env=environment,
            )

        self.assertEqual(json.loads(initial.stdout)["class"], "idle")
        self.assertEqual(json.loads(running.stdout)["class"], "work")


if __name__ == "__main__":
    unittest.main()
