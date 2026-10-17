from pathlib import Path
import os
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
MENU = ROOT / "scripts" / "recorder-menu"


class RecorderMenuTests(unittest.TestCase):
    def test_script_is_valid_bash(self):
        result = subprocess.run(("bash", "-n", str(MENU)), capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_idle_status_is_valid_without_backend(self):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(
                ("bash", str(MENU), "--status"), env={**os.environ, "XDG_STATE_HOME": directory},
                capture_output=True, text=True, check=True,
            )
        self.assertIn('\"class\":\"idle\"', result.stdout)

    def test_capture_modes_and_audio_are_available(self):
        content = MENU.read_text(encoding="utf-8")
        for value in ("Record selected area", "Record selected window", "Record focused monitor", "Desktop audio", "Microphone"):
            self.assertIn(value, content)
        for target in ("area", "window", "monitor"):
            self.assertIn(f"{target})", content)
        for audio in ("none", "desktop", "microphone"):
            self.assertIn(audio, content)
        self.assertIn("--json", content)

    def test_failed_recorder_start_reports_error_and_clears_pid(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            commands = root / "bin"
            commands.mkdir()
            for name, body in {
                "wf-recorder": "echo 'Capture backend unavailable' >&2\nexit 1",
                "hyprctl": 'printf \'[{"name":"DP-1","focused":true}]\\n\'',
                "notify-send": "exit 0",
            }.items():
                command = commands / name
                command.write_text("#!/bin/sh\n" + body + "\n")
                command.chmod(0o755)
            result = subprocess.run(
                ("bash", str(MENU), "--start", "monitor", "none"),
                env={**os.environ, "PATH": f"{commands}:{os.environ['PATH']}",
                     "XDG_STATE_HOME": str(root / "state"), "XDG_VIDEOS_DIR": str(root / "videos")},
                capture_output=True, text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Screen recording could not start", result.stderr)
            self.assertIn("Capture backend unavailable", result.stderr)
            self.assertFalse((root / "state/spectrumos/recorder/pid").exists())

    def test_default_output_recording_target_was_removed(self):
        # Confusing to a user who doesn't know what wf-recorder's own "default output"
        # means -- recording only ever offers Area and Monitor.
        content = MENU.read_text(encoding="utf-8")
        self.assertNotIn("Record default output", content)
        self.assertNotIn("full)", content)
        self.assertNotIn("mode=Full", content)

    def test_encoding_options_reach_recorder_with_matching_extension(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            commands = root / "bin"
            commands.mkdir()
            for name, body in {
                "wf-recorder": 'printf "%s\\n" "$@" > "$CAPTURE_ARGS"\nexit 1',
                "hyprctl": 'printf \'[{"name":"DP-1","focused":true}]\\n\'',
                "pactl": 'printf "desktop\\n"',
                "notify-send": "exit 0",
            }.items():
                command = commands / name
                command.write_text("#!/bin/sh\n" + body + "\n")
                command.chmod(0o755)
            environment = {**os.environ, "PATH": f"{commands}:{os.environ['PATH']}",
                           "XDG_STATE_HOME": str(root / "state"), "XDG_VIDEOS_DIR": str(root / "videos"),
                           "CAPTURE_ARGS": str(root / "args")}
            for fmt, quality, fps, bitrate, video, audio, crf in (
                ("mp4", "balanced", "auto", "192", "libx264", "aac", "23"),
                ("mkv", "high", "60", "320", "libx264", "aac", "18"),
                ("webm", "small", "24", "96", "libvpx-vp9", "libopus", "40"),
            ):
                with self.subTest(format=fmt):
                    subprocess.run(("bash", str(MENU), "--start", "monitor", "desktop", fmt, quality, fps, bitrate),
                                   env=environment, capture_output=True, text=True)
                    args = (root / "args").read_text().splitlines()
                    self.assertTrue(args[args.index("-f") + 1].endswith("." + fmt))
                    self.assertEqual(args[args.index("-c") + 1], video)
                    self.assertEqual(args[args.index("-C") + 1], audio)
                    self.assertIn("crf=" + crf, args)
                    self.assertIn("b=" + bitrate + "k", args)
                    self.assertIn("--audio=desktop.monitor", args)
                    self.assertEqual("-r" in args, fps != "auto")
                    if fps != "auto":
                        self.assertEqual(args[args.index("-r") + 1], fps)
            subprocess.run(("bash", str(MENU), "--start", "monitor", "none"),
                           env=environment, capture_output=True, text=True)
            args = (root / "args").read_text().splitlines()
            self.assertNotIn("-C", args)
            self.assertNotIn("-P", args)

    def test_invalid_encoding_options_fail_before_selection(self):
        with tempfile.TemporaryDirectory() as directory:
            for options in (("avi",), ("mp4", "ultra"), ("mp4", "high", "120"),
                            ("mp4", "high", "30", "0")):
                with self.subTest(options=options):
                    result = subprocess.run(("bash", str(MENU), "--start", "area", "none", *options),
                                            env={**os.environ, "XDG_STATE_HOME": directory},
                                            capture_output=True, text=True, timeout=3)
                    self.assertEqual(result.returncode, 2)
                    self.assertIn("Unknown", result.stderr)

    def test_area_selection_finishes_with_parent_stdin_still_open(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            commands = root / "bin"
            commands.mkdir()
            for name, body in {
                "wf-recorder": "exit 1",
                "slurp": "cat >/dev/null\nexit 1",
            }.items():
                command = commands / name
                command.write_text("#!/bin/sh\n" + body + "\n")
                command.chmod(0o755)
            process = subprocess.Popen(
                ("bash", str(MENU), "--start", "area", "none"),
                env={**os.environ, "PATH": f"{commands}:{os.environ['PATH']}",
                     "XDG_STATE_HOME": str(root / "state"), "XDG_VIDEOS_DIR": str(root / "videos")},
                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            )
            try:
                self.assertEqual(process.wait(timeout=3), 0)
                self.assertFalse((root / "state/spectrumos/recorder/pid").exists())
            finally:
                if process.poll() is None:
                    process.kill()
                process.communicate()

    def test_open_creates_recordings_folder_and_launches_thunar(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            commands = root / "bin"
            commands.mkdir()
            launcher = commands / "uwsm"
            launcher.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
            launcher.chmod(0o755)
            videos = root / "My Videos"
            result = subprocess.run(
                ("bash", str(MENU), "--open"),
                env={**os.environ, "PATH": f"{commands}:{os.environ['PATH']}",
                     "XDG_STATE_HOME": str(root / "state"), "XDG_VIDEOS_DIR": str(videos)},
                capture_output=True, text=True, check=True,
            )
            self.assertEqual(result.stdout.splitlines(), ["app", "--", "thunar", str(videos / "Recordings")])
            self.assertTrue((videos / "Recordings").is_dir())

    def test_no_control_center_page_left_for_capture_or_recording(self):
        config = (ROOT / "configs/spectrum-shell/ControlCenter.qml").read_text(encoding="utf-8")
        self.assertNotIn('label: "Record area"', config)
        self.assertNotIn('label: "Record monitor"', config)
        self.assertTrue((ROOT / "configs/spectrum-shell/RecorderPanel.qml").exists())

    def test_waybar_recorder_widget_opens_the_wofi_menu_directly(self):
        # Clicking the Waybar recorder indicator used to open the (now-removed) Capture
        # page; it opens the standalone recorder-menu Wofi instead.
        layouts = (ROOT / "configs" / "waybar" / "layouts").glob("*.jsonc")
        for layout in layouts:
            content = layout.read_text(encoding="utf-8")
            self.assertIn('"custom/recorder"', content)
            self.assertNotIn("eww-open capture", content)

    def test_control_adapter_has_no_orphaned_volume_step_action(self):
        adapter = (ROOT / "scripts" / "control-adapter").read_text(encoding="utf-8")
        self.assertNotIn("output-step", adapter)
        self.assertNotIn("input-step", adapter)


if __name__ == "__main__":
    unittest.main()
