from pathlib import Path
import json
import subprocess
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]
MENU = ROOT / "scripts" / "theme-menu"


class ThemeMenuTests(unittest.TestCase):
    def test_shell_refresh_precedes_wallpaper_and_success_waits_for_fade(self):
        content = MENU.read_text(encoding="utf-8")
        generation = content.split("apply_generation() {", 1)[1].split("\n}\n", 1)[0]
        for shell_active, reply in ((True, "true"), (True, "false"), (False, "true")):
            with self.subTest(shell_active=shell_active, reply=reply), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "current").mkdir()
                (root / "current/palette.json").write_text('{"roles":{"surface":"#123456"}}')
                generation_body = generation.replace("/usr/lib/spectrumos/", "")
                script = '''
set -euo pipefail
cache_dir=$1
state_dir=$1
last_rendered_file=$1/last-rendered-wallpaper
events=$1/events
qs() { :; }
timeout() { printf 'refresh\\n' >> "$events"; printf '%s\\n' "$reply"; }
systemctl() { return "$service_status"; }
awww() { printf 'wallpaper %s\\n' "$*" >> "$events"; }
hyprctl() { :; }
pkill() { :; }
waybar-menu() { :; }
appearance-sync() { :; }
appearance-stage() { :; }
notify-send() { printf 'notification %s\\n' "$*" >> "$events"; }
service_status=$2
reply=$3
'''
                script += "apply_generation() {" + generation_body + "\n}\n"
                script += 'apply_generation example.png\nprintf "success\\n" >> "$events"\n'
                started = time.monotonic()
                result = subprocess.run(
                    ["bash", "-c", script, "bash", str(root), "0" if shell_active else "3", reply],
                    capture_output=True, text=True,
                )
                events = (root / "events").read_text().splitlines()
                if shell_active and reply == "false":
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse(any(event.startswith("wallpaper") for event in events))
                    self.assertNotIn("success", events)
                else:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertGreaterEqual(time.monotonic() - started, 1)
                    self.assertEqual(events[-1], "success")
                    wallpaper_event = next(event for event in events if event.startswith("wallpaper"))
                    self.assertIn("--transition-fps 60", wallpaper_event)
                    if shell_active:
                        self.assertEqual(events[0], "refresh")
                    else:
                        self.assertNotIn("refresh", events)

    def test_open_shell_refresh_uses_the_latest_generation_after_symlink_switch(self):
        content = MENU.read_text(encoding="utf-8")
        generation = content.split("apply_generation() {", 1)[1].split("\n}\n", 1)[0]
        generation = generation.replace("/usr/lib/spectrumos/", "")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            script = r'''
set -euo pipefail
cache_dir=$1
state_dir=$1
last_rendered_file=$1/last-rendered-wallpaper
qs() { printf '%s' "${@: -1}" > "$cache_dir/refreshed-palette.json"; printf 'true\n'; }
timeout() { shift; "$@"; }
systemctl() { return 0; }
awww() { :; }
hyprctl() { :; }
pkill() { :; }
waybar-menu() { :; }
appearance-sync() { :; }
appearance-stage() { :; }
notify-send() { :; }
'''
            script += "apply_generation() {" + generation + "\n}\napply_generation example.png\n"
            for name, color in (("first", "#123456"), ("second", "#abcdef"), ("third", "#554433")):
                folder = root / name
                folder.mkdir()
                palette = {"roles": {"surface": color}}
                (folder / "palette.json").write_text(json.dumps(palette))
                pending = root / "next"
                pending.symlink_to(name)
                pending.replace(root / "current")
                result = subprocess.run(["bash", "-c", script, "bash", str(root)], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads((root / "refreshed-palette.json").read_text()), palette)

    def test_menu_exposes_all_native_modes_and_random_choices(self):
        content = MENU.read_text(encoding="utf-8")
        for mode in ("spectrum", "clustered", "median-cut", "weighted-regions"):
            self.assertIn(mode, content)
        self.assertIn("Random mode", content)
        self.assertIn("Random Dark", content)
        self.assertIn("Random Light", content)
        self.assertIn("--variant", content)
        self.assertIn("Random wallpaper", content)
        self.assertIn("Previous theme", content)
        self.assertIn("--previous", content)

    def test_menu_uses_atomic_theme_cli_pipeline(self):
        content = MENU.read_text(encoding="utf-8")
        self.assertIn("spectrum_theme.cli extract native", content)
        self.assertIn("spectrum_theme.cli render --strict", content)
        self.assertIn("awww img", content)
        self.assertIn('rollback)', content)
        self.assertIn('--wallpaper "$wallpaper"', content)

    def test_random_wallpaper_uses_persistent_shuffled_cycles(self):
        content = MENU.read_text(encoding="utf-8")
        picker = content.split("random_wallpaper() {", 1)[1].split("\n}\n", 1)[0]
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            images = [str(state / f"image-{index}.png") for index in range(4)]
            last = state / "last-wallpaper"
            last.write_text(images[0] + "\n", encoding="utf-8")
            script = (
                "set -euo pipefail\n"
                f"random_wallpaper() {{{picker}\n}}\n"
                "state_dir=$1\nlast_wallpaper_file=$state_dir/last-wallpaper\n"
                "shift\nwallpapers=(\"$@\")\nrandom_wallpaper\n"
            )

            def draw(collection):
                result = subprocess.run(
                    ["bash", "-c", script, "bash", str(state), *collection],
                    check=True,
                    capture_output=True,
                    text=True,
                )
                picked = result.stdout.strip()
                self.assertNotEqual(picked, last.read_text(encoding="utf-8").strip())
                last.write_text(picked + "\n", encoding="utf-8")
                return picked

            draws = [draw(images) for _ in range(8)]
            self.assertEqual(set(draws[:4]), set(images))
            self.assertEqual(set(draws[4:]), set(images))
            for _ in range(3):
                draw(images)
            pending = (state / "random-wallpaper-queue").read_text(encoding="utf-8").strip()
            last.write_text(pending + "\n", encoding="utf-8")
            draw(images)
            self.assertEqual(draw(images), pending)
            added = str(state / "new-image.png")
            self.assertEqual(set(draw(images + [added]) for _ in range(5)), set(images + [added]))

    def test_surprise_me_also_randomizes_the_color_scheme(self):
        content = MENU.read_text(encoding="utf-8")
        self.assertIn("random_scheme()", content)
        self.assertIn('local -a choices=(none)', content)
        self.assertIn('"$gowall_bin" list', content)
        random_block = content.split("elif [[ $random_only == true ]]; then", 1)[1].split("elif [[ $random_wallpaper_only == true ]]; then", 1)[0]
        self.assertIn("mode=$(printf '%s\\n' \"${modes[@]}\" | shuf -n 1)", random_block)
        self.assertIn("scheme=$(random_scheme)", random_block)

    def test_random_wallpaper_only_keeps_the_current_palette_variant_and_scheme(self):
        # Super+R (theme-menu --random-wallpaper) is deliberately narrower than "Surprise
        # me" (--random, tested above): it only rerolls the wallpaper, leaving mode/variant/
        # scheme exactly as load_preferences already set them from the persisted choices.
        content = MENU.read_text(encoding="utf-8")
        self.assertIn("--random-wallpaper) random_wallpaper_only=true ;;", content)
        random_wallpaper_block = content.split(
            "elif [[ $random_wallpaper_only == true ]]; then", 1
        )[1].split("else", 1)[0]
        self.assertIn("wallpaper=$(random_wallpaper)", random_wallpaper_block)
        self.assertNotIn("mode=", random_wallpaper_block)
        self.assertNotIn("variant=", random_wallpaper_block)
        self.assertNotIn("scheme=", random_wallpaper_block)

    def test_theme_consumers_reload_after_activation(self):
        content = MENU.read_text(encoding="utf-8")
        self.assertIn("pkill -USR1 -x kitty", content)
        self.assertIn("waybar-menu --restart", content)
        self.assertIn("appearance-sync --apply", content)
        # The dunst restart-with-fallback chain and its is-paused poll loop are shared with
        # font-size-menu and font-family-menu -- see scripts/dunst-reload and
        # tests/test_dunst_reload.py for that logic itself.
        self.assertNotIn("/usr/lib/spectrumos/dunst-reload", content)

    def test_a_failed_waybar_restart_does_not_abort_the_rest_of_the_pipeline(self):
        # waybar-menu --restart can fail (waybar not reappearing in hyprctl layers within
        # its own retry window) -- under set -e an unguarded call here would abort before
        # appearance-stage, the dunst restart, and the final eww-refresh ever ran.
        content = MENU.read_text(encoding="utf-8")
        generation = content.split("apply_generation() {", 1)[1].split("\nrestore_previous()", 1)[0]
        self.assertIn("if ! /usr/lib/spectrumos/waybar-menu --restart; then", generation)

    def test_wallpaper_menu_uses_shell_picker(self):
        content = MENU.read_text(encoding="utf-8")

        self.assertIn("/usr/lib/spectrumos/spectrum-shell-picker wallpaper", content)
        self.assertIn('"${candidate##*/}"', content)

    def test_a_failed_generation_reverts_the_current_wallpaper_marker(self):
        # mark_current_wallpaper runs before extract/render on purpose (a palette-backend
        # change made while that pipeline is still in flight must see the *new* wallpaper
        # as current, not race back to the old one -- see mark_current_wallpaper's own
        # comment). But if extract/render itself fails, apply_generation never runs and
        # the desktop keeps the old theme, so last-wallpaper must be put back or the
        # gallery would show a wallpaper that was never actually applied as "current".
        content = MENU.read_text(encoding="utf-8")
        self.assertIn('previous_wallpaper=$(cat -- "$last_wallpaper_file"', content)
        apply_block = content.split('mark_current_wallpaper "$wallpaper"\n\npalette=', 1)[1]
        before_call = apply_block.split('apply_generation "$render_wallpaper"', 1)[0]
        self.assertIn("if ! PYTHONPATH=$theme_root python -m spectrum_theme.cli extract native", before_call)
        self.assertIn('mark_current_wallpaper "$previous_wallpaper"', before_call)
        self.assertIn("exit 1", before_call)

    def test_restore_previous_recolors_through_the_active_scheme(self):
        # Without this, "Previous theme" restored the correct palette/config but showed
        # the plain original wallpaper instead of the gowall-recolored one that was
        # actually on screen for that generation.
        content = MENU.read_text(encoding="utf-8")
        restore_previous = content.split("restore_previous() {", 1)[1].split("\n}\n", 1)[0]
        self.assertIn('render_wallpaper=$(render_wallpaper_for_scheme "$wallpaper" "$scheme")', restore_previous)
        self.assertIn('apply_generation "$render_wallpaper"', restore_previous)


if __name__ == "__main__":
    unittest.main()
