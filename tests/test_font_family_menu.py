from pathlib import Path
import json
import os
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
MENU = ROOT / "scripts" / "font-family-menu"
CLI = ROOT / "packages" / "spectrum-theme" / "src" / "spectrum_theme" / "cli.py"
REGISTRY = ROOT / "system" / "spectrumos" / "font-families.conf"

FAMILY_KEYS = (
    "jetbrains-mono", "fira-code", "source-code-pro", "cascadia-code", "hack",
    "ibm-plex-mono", "iosevka", "victor-mono", "ubuntu-mono", "meslo",
)


class FontFamilyMenuTests(unittest.TestCase):
    def test_script_is_valid_bash(self):
        for script in (MENU,):
            result = subprocess.run(("bash", "-n", str(script)), capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_status_defaults_to_jetbrains_mono(self):
        with tempfile.TemporaryDirectory() as directory:
            environment = {**os.environ, "XDG_STATE_HOME": directory, "SPECTRUM_FONT_FAMILIES_FILE": str(REGISTRY)}
            result = subprocess.run(
                ("bash", str(MENU), "--status"), env=environment, check=True, capture_output=True, text=True
            )
        status = json.loads(result.stdout)
        self.assertEqual(status["text"], "Aa")
        self.assertIn("JetBrains Mono", status["tooltip"])

    def test_list_marks_the_persisted_choice_as_current(self):
        with tempfile.TemporaryDirectory() as directory:
            typography = Path(directory) / "spectrumos/typography"
            typography.mkdir(parents=True)
            (typography / "font-family").write_text("fira-code\n", encoding="utf-8")
            environment = {**os.environ, "XDG_STATE_HOME": directory, "SPECTRUM_FONT_FAMILIES_FILE": str(REGISTRY)}
            result = subprocess.run(
                ("bash", str(MENU), "--list"), env=environment, check=True, capture_output=True, text=True
            )
        self.assertIn("*\tfira-code\tFira Code", result.stdout)
        self.assertIn(" \tjetbrains-mono\tJetBrains Mono", result.stdout)

    def test_list_falls_back_to_jetbrains_mono_for_an_unknown_persisted_key(self):
        with tempfile.TemporaryDirectory() as directory:
            typography = Path(directory) / "spectrumos/typography"
            typography.mkdir(parents=True)
            (typography / "font-family").write_text("not-a-real-font\n", encoding="utf-8")
            environment = {**os.environ, "XDG_STATE_HOME": directory, "SPECTRUM_FONT_FAMILIES_FILE": str(REGISTRY)}
            result = subprocess.run(
                ("bash", str(MENU), "--list"), env=environment, check=True, capture_output=True, text=True
            )
        self.assertIn("*\tjetbrains-mono\tJetBrains Mono", result.stdout)

    def test_set_rejects_an_unknown_key_without_persisting_or_reloading(self):
        with tempfile.TemporaryDirectory() as directory:
            environment = {**os.environ, "XDG_STATE_HOME": directory, "SPECTRUM_FONT_FAMILIES_FILE": str(REGISTRY)}
            result = subprocess.run(
                ("bash", str(MENU), "--set", "not-a-real-font"),
                env=environment, capture_output=True, text=True,
            )
        self.assertEqual(result.returncode, 0)
        self.assertFalse((Path(directory) / "spectrumos/typography/font-family").exists())

    def test_menu_reload_pipeline_matches_font_size_menu(self):
        content = MENU.read_text(encoding="utf-8")
        self.assertIn("rerender-current", content)
        self.assertIn("pkill -USR1 -x kitty", content)
        # A bare `pkill -USR2` only asks waybar to reload in place, with no guarantee it
        # actually picks up the fresh CSS (confirmed live: a font-family change left the
        # running bar showing the previous font indefinitely) -- a full restart through the
        # same path layout/style/theme changes already use reliably reads the current file.
        self.assertNotIn("pkill -USR2 -x waybar", content)
        self.assertIn("/usr/lib/spectrumos/waybar-menu --restart", content)
        self.assertIn("appearance-sync --apply", content)
        self.assertNotIn("/usr/lib/spectrumos/eww-refresh", content)
        # The dunst restart-with-fallback chain and its is-paused poll loop are shared with
        # font-size-menu and theme-menu -- see scripts/dunst-reload and
        # tests/test_dunst_reload.py for that logic itself.
        self.assertNotIn("/usr/lib/spectrumos/dunst-reload", content)

    def test_a_failed_waybar_restart_does_not_abort_the_rest_of_the_pipeline(self):
        content = MENU.read_text(encoding="utf-8")
        self.assertIn("if ! /usr/lib/spectrumos/waybar-menu --restart; then", content)

    def test_concurrent_set_calls_are_serialized_and_debounced(self):
        # Same race as font-size-menu's own fix: picking several families back to back used
        # to spawn one of these per click with nothing stopping them from racing on the same
        # hyprctl/waybar/eww steps, which could leave dunstrc updated but dunst itself never
        # reloaded onto it. The lock plus a re-read-and-compare right after it ensures only
        # the run whose family is still the persisted one (i.e. the last click) ever reaches
        # the heavy apply/reload steps.
        content = MENU.read_text(encoding="utf-8")
        lock_section, _, rest = content.partition("flock 9")
        self.assertIn('exec 9>"$lock_dir/font-family-menu.lock"', lock_section)
        self.assertIn('[[ $current == "$selected" ]] || exit 0', rest)
        self.assertLess(rest.index('[[ $current == "$selected" ]] || exit 0'), rest.index("rerender-current"))

    def test_menu_keys_match_the_cli_font_family_registry(self):
        # The menu itself no longer hardcodes slugs/labels -- it reads the shared
        # registry (also read by system-adapter) so the two never drift apart again.
        registry = REGISTRY.read_text(encoding="utf-8")
        cli = CLI.read_text(encoding="utf-8")
        for key in FAMILY_KEYS:
            self.assertIn(key, registry)
            self.assertIn(f'"{key}"', cli)

    def test_menu_reads_slugs_and_labels_from_the_shared_registry(self):
        menu = MENU.read_text(encoding="utf-8")
        self.assertIn("/usr/share/spectrumos/font-families.conf", menu)
        self.assertNotIn('"jetbrains-mono"', menu)


if __name__ == "__main__":
    unittest.main()
