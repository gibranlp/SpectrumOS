from pathlib import Path
import os
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
PANEL = ROOT / "scripts" / "panel"


class PanelTests(unittest.TestCase):
    def test_panel_is_valid_bash(self):
        result = subprocess.run(
            ("bash", "-n", str(PANEL)),
            cwd=ROOT,
            check=False,
            text=True,
            capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_panel_uses_spectrum_frontends(self):
        content = PANEL.read_text(encoding="utf-8")
        self.assertIn("/usr/lib/spectrumos/spectrum-shell-picker", content)
        self.assertIn("/usr/lib/spectrumos/theme-menu", content)
        self.assertIn("/usr/lib/spectrumos/waybar-menu", content)
        self.assertIn("/usr/lib/spectrumos/font-size-menu", content)
        self.assertIn("/usr/lib/spectrumos/appearance-sync --apply", content)

    def test_session_actions_run_directly(self):
        content = PANEL.read_text(encoding="utf-8")
        self.assertIn("Suspend) systemctl suspend", content)
        self.assertIn('"Log out") uwsm stop', content)
        self.assertIn("Restart) systemctl reboot", content)
        self.assertIn('"Power off") systemctl poweroff', content)
        self.assertNotIn("confirm()", content)

    def test_menu_flows_use_consistent_screen_edges(self):
        content = PANEL.read_text(encoding="utf-8")
        choose = content.split("choose() {", 1)[1].split("choose_right() {", 1)[0]
        system = content.split("system_menu() {", 1)[1].split("session_menu() {", 1)[0]
        session = content.split("session_menu() {", 1)[1].split("main() {", 1)[0]

        self.assertIn('"${wofi_left[@]}"', choose)
        self.assertIn("choice=$(choose_right System", system)
        self.assertIn("choice=$(choose_right 'Session", session)
        self.assertIn('cut -f2 | "${wofi_left[@]}"', content)

    def test_migrated_actions_show_legacy_shortcuts(self):
        content = PANEL.read_text(encoding="utf-8")
        for shortcut in (
            "Applications (Super+D)",
            "Audio (Super+A)",
            "Capture (Print)",
            "Screen recording (Super+Shift+S)",
            "File search (Super+S)",
            "Password generator (Super+G)",
            "Color picker (Super+I)",
            "Emoji picker (Super+V)",
            "System (Super+B)",
            "Session (Super+X)",
        ):
            self.assertIn(shortcut, content)

    def test_direct_shortcut_routes_are_supported(self):
        content = PANEL.read_text(encoding="utf-8")
        for route in ("--applications", "--appearance", "--audio", "--capture", "--utilities", "--password", "--search", "--emoji", "--color-picker", "--system", "--session"):
            self.assertIn(route, content)

    def test_calculator_uses_numbat_without_evaluating_shell_input(self):
        content = PANEL.read_text(encoding="utf-8")
        calculator = (ROOT / "scripts" / "calculator-menu").read_text(encoding="utf-8")
        self.assertIn('numbat "${arguments[@]}"', calculator)
        self.assertIn("60 mph -> km/h", calculator)
        self.assertNotIn("eval ", calculator)

    def test_calculator_uses_native_picker(self):
        calculator = (ROOT / "scripts/calculator-menu").read_text()
        self.assertIn("spectrum-shell-picker calculator", calculator)
        self.assertNotIn("/usr/lib/spectrumos/wofi", calculator)

    def test_focused_utility_choices(self):
        content = PANEL.read_text(encoding="utf-8")
        audio = content.split("audio_menu() {", 1)[1].split("screenshot_path()", 1)[0]
        self.assertIn('"Select output"', audio)
        self.assertIn('"Select input"', audio)
        self.assertNotIn("Volume up", audio)
        self.assertIn("10 12 14 16 20 24 32 48", content)
        self.assertIn('notice "Password generated · copied" "$password"', content)
        self.assertIn('--icon="$swatch"', content)
        self.assertIn('tuned-adm profile "$profile"', content)

    def test_area_screenshot_opens_annotation_editor(self):
        content = PANEL.read_text(encoding="utf-8")
        self.assertIn('grim -g "$geometry" "$temporary"', content)
        self.assertIn('satty --filename "$temporary"', content)
        self.assertIn('--output-filename "$destination"', content)
        self.assertIn("--actions-on-enter save-to-file", content)

    def test_window_screenshot_uses_hyprland_window_rectangles(self):
        content = PANEL.read_text(encoding="utf-8")
        self.assertIn('["hyprctl", "clients", "-j"]', content)
        self.assertIn("slurp -r", content)
        self.assertIn("--screenshot-window) take_screenshot Window", content)

    def test_capture_menu_is_screenshot_only(self):
        # Screen recording used to be folded into the Print capture_menu; it now has its own
        # top-level "Screen recording" entry that runs the standalone recorder-menu Wofi instead.
        content = PANEL.read_text(encoding="utf-8")
        capture = content.split("capture_menu() {", 1)[1].split("}", 1)[0]
        self.assertNotIn("Screen recording", capture)
        self.assertNotIn("recorder-menu", capture)
        self.assertIn('"Screen recording"*) exec /usr/lib/spectrumos/recorder-menu', content)

    def test_monitor_capture_selects_one_output_and_cancels_cleanly(self):
        for selected in ("HDMI-A-1", ""):
            with self.subTest(selected=selected), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                commands = root / "bin"
                commands.mkdir()
                for name, body in {
                    "slurp": 'cat >/dev/null\nprintf "%s\\n" "$@" > "$TEST_ROOT/slurp-args"\nprintf "%s" "$SELECTED_OUTPUT"',
                    "grim": 'printf "%s\\n" "$@" > "$TEST_ROOT/grim-args"\nprintf image > "$3"',
                    "wl-copy": 'cat > "$TEST_ROOT/clipboard"',
                    "notify-send": 'printf "%s\\n" "$@" > "$TEST_ROOT/notice"',
                }.items():
                    command = commands / name
                    command.write_text("#!/bin/sh\n" + body + "\n")
                    command.chmod(0o755)
                process = subprocess.Popen(
                    ("bash", str(PANEL), "--screenshot-quick-monitor"),
                    env={**os.environ, "PATH": f"{commands}:{os.environ['PATH']}",
                         "TEST_ROOT": str(root), "SELECTED_OUTPUT": selected,
                         "XDG_PICTURES_DIR": str(root / "Pictures")},
                    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                    text=True,
                )
                try:
                    process.wait(timeout=3)
                    stdout, stderr = process.communicate()
                finally:
                    if process.poll() is None:
                        process.kill()
                        process.communicate()
                self.assertEqual(process.returncode, 0, stderr)
                self.assertEqual((root / "slurp-args").read_text().splitlines(), ["-o", "-r", "-f", "%l"])
                if selected:
                    args = (root / "grim-args").read_text().splitlines()
                    self.assertEqual(args[:2], ["-o", selected])
                    self.assertFalse(Path(args[2]).exists())
                    self.assertEqual(len(list((root / "Pictures/Screenshots").glob("*.png"))), 1)
                    self.assertEqual((root / "clipboard").read_text(), "image")
                    self.assertIn("Screenshot saved", (root / "notice").read_text())
                else:
                    self.assertFalse((root / "grim-args").exists())
                    self.assertFalse((root / "clipboard").exists())
                    self.assertFalse((root / "notice").exists())


if __name__ == "__main__":
    unittest.main()
