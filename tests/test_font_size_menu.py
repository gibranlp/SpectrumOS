from pathlib import Path
import json
import os
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
MENU = ROOT / "scripts" / "font-size-menu"


class FontSizeMenuTests(unittest.TestCase):
    def test_script_is_valid_bash(self):
        result = subprocess.run(("bash", "-n", str(MENU)), capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_status_defaults_to_thirteen(self):
        with tempfile.TemporaryDirectory() as directory:
            environment = {**os.environ, "XDG_STATE_HOME": directory}
            result = subprocess.run(
                ("bash", str(MENU), "--status"),
                env=environment,
                check=True,
                capture_output=True,
                text=True,
            )
        status = json.loads(result.stdout)
        self.assertEqual(status["text"], "Aa")
        self.assertIn("13px", status["tooltip"])

    def test_selector_range_is_bounded(self):
        content = MENU.read_text(encoding="utf-8")
        self.assertIn("seq 8 24", content)
        self.assertIn("spectrum-shell-picker typography", content)
        self.assertIn('--prompt "Font size"', content)
        self.assertNotIn('--prompt "Font size ·', content)
        self.assertIn("rerender-current", content)
        self.assertIn('[[ ${1:-} == --set ]]', content)
        self.assertNotIn("/usr/lib/spectrumos/eww-refresh", content)
        # A bare `pkill -USR2` only asks waybar to reload in place, with no guarantee it
        # actually picks up the fresh CSS (confirmed live: a font change left the running
        # bar showing the previous font indefinitely) -- a full restart through the same
        # path layout/style/theme changes already use reliably reads the current file.
        self.assertNotIn("pkill -USR2 -x waybar", content)
        self.assertIn("/usr/lib/spectrumos/waybar-menu --restart", content)
        # The dunst restart-with-fallback chain and its is-paused poll loop are shared with
        # font-family-menu and theme-menu -- see scripts/dunst-reload and
        # tests/test_dunst_reload.py for that logic itself.
        self.assertNotIn("/usr/lib/spectrumos/dunst-reload", content)

    def test_a_failed_waybar_restart_does_not_abort_the_rest_of_the_pipeline(self):
        content = MENU.read_text(encoding="utf-8")
        self.assertIn("if ! /usr/lib/spectrumos/waybar-menu --restart; then", content)

    def test_concurrent_set_calls_are_serialized_and_debounced(self):
        # Picking several sizes back to back (the Eww grid's buttons call --set directly,
        # no wofi prompt serializing clicks for us) used to spawn one of these per click
        # with nothing stopping them from racing on the same hyprctl/waybar/eww steps --
        # confirmed live: dunstrc ended up with the newest size on disk while dunst itself
        # was still running the previous one because an earlier click's run reloaded before
        # a later click's write ever landed, and no run reloaded afterwards. The lock plus
        # a re-read-and-compare right after it ensures only the run whose size is still the
        # persisted one (i.e. the last click) ever reaches the heavy apply/reload steps.
        content = MENU.read_text(encoding="utf-8")
        lock_section, _, rest = content.partition("flock 9")
        self.assertIn('exec 9>"$lock_dir/font-size-menu.lock"', lock_section)
        self.assertIn('[[ $current == "$selected" ]] || exit 0', rest)
        self.assertLess(rest.index('[[ $current == "$selected" ]] || exit 0'), rest.index("rerender-current"))


if __name__ == "__main__":
    unittest.main()
