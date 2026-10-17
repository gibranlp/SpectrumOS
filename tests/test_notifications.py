from pathlib import Path
import os
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
class NotificationTests(unittest.TestCase):
    def test_brightness_wrapper_is_safe_and_valid(self):
        script = ROOT / "scripts/brightness"
        result = subprocess.run(("bash", "-n", str(script)), capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        content = script.read_text(encoding="utf-8")
        self.assertIn("brightness-adapter", content)
        self.assertNotIn("notify-send", content)
        self.assertNotIn("notify-send", (ROOT / "scripts/brightness-adapter").read_text())

    def test_volume_changes_only_the_sink_without_starting_widget_helpers(self):
        cases = ((["up"], "set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 2%+"),
                 (["down"], "set-volume @DEFAULT_AUDIO_SINK@ 2%-"),
                 (["mute"], "set-mute @DEFAULT_AUDIO_SINK@ toggle"),
                 (["set", "32", "--quiet"], "set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 32%"))
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            log = target / "commands"
            wpctl = target / "wpctl"
            wpctl.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$VOLUME_TEST_LOG"\n')
            wpctl.chmod(0o755)
            for name in ("qs", "notify-send", "cava", "awk"):
                helper = target / name
                helper.write_text('#!/bin/sh\nprintf "unexpected helper\\n" >> "$VOLUME_TEST_LOG"\nexit 1\n')
                helper.chmod(0o755)
            environment = dict(os.environ, PATH=str(target), VOLUME_TEST_LOG=str(log))
            for arguments, expected in cases:
                with self.subTest(arguments=arguments):
                    log.unlink(missing_ok=True)
                    subprocess.run(["/bin/bash", str(ROOT / "scripts/volume"), *arguments], env=environment, check=True)
                    self.assertEqual(log.read_text().strip(), expected)
            for value in ("101", "-1", "text"):
                log.unlink(missing_ok=True)
                result = subprocess.run(["/bin/bash", str(ROOT / "scripts/volume"), "set", value], env=environment)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(log.exists())

    def test_shell_session_does_not_restore_retired_notifications(self):
        session = (ROOT / "scripts/spectrum-shell-session").read_text()
        service = (ROOT / "system/systemd/user/spectrum-shell.service").read_text()
        self.assertNotIn("dunst", session)
        self.assertNotIn("dunst", service)

    def test_hyprland_starts_resource_monitor_after_notifications(self):
        autostart = (ROOT / "configs" / "hyprland" / "autostart.lua").read_text(encoding="utf-8")

        self.assertIn("systemctl --user start spectrum-resource-monitor.service", autostart)
        self.assertLess(
            autostart.index("systemctl --user start spectrum-resource-monitor.service"),
            autostart.index("systemctl --user start spectrum-shell.service"),
        )


if __name__ == "__main__":
    unittest.main()
