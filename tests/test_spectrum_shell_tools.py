from pathlib import Path
import json
import os
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "scripts/spectrum-shell-tools"


class SpectrumShellToolsTests(unittest.TestCase):
    def generate(self, options: str) -> str:
        result = subprocess.run(
            [str(TOOL), "password", "32", options],
            check=True, capture_output=True, text=True,
        )
        return result.stdout.strip()

    def test_password_character_selectors(self):
        letters = self.generate("l")
        numbers = self.generate("n")
        symbols = self.generate("s")
        mixed = self.generate("lns")
        self.assertRegex(letters, r"^[A-Za-z]{32}$")
        self.assertRegex(numbers, r"^[0-9]{32}$")
        self.assertRegex(symbols, r"^[!@#$%_+=-]{32}$")
        self.assertEqual(len(mixed), 32)
        self.assertRegex(mixed, r"[A-Za-z]")
        self.assertRegex(mixed, r"[0-9]")
        self.assertRegex(mixed, r"[!@#$%_+=-]")

    def test_password_rejects_no_character_class(self):
        result = subprocess.run(
            [str(TOOL), "password", "20", ""],
            check=False, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 2)

    def test_emoji_picker_starts_with_smileys(self):
        result = subprocess.run([str(TOOL), "emoji", ""], check=True, capture_output=True, text=True)
        emojis = json.loads(result.stdout)
        self.assertEqual(emojis[0]["character"], "😀")
        self.assertEqual(emojis[0]["name"], "Grinning Face")

    def test_color_history_keeps_five_unique_recent_colors(self):
        with tempfile.TemporaryDirectory() as directory:
            environment = {**os.environ, "XDG_STATE_HOME": directory}
            for value in ("#112233", "#445566", "#778899", "#AABBCC", "#DDEEFF", "#112233"):
                result = subprocess.run([str(TOOL), "color-add", value], env=environment, check=True, capture_output=True, text=True)
            self.assertEqual(json.loads(result.stdout), ["#112233", "#DDEEFF", "#AABBCC", "#778899", "#445566"])
            subprocess.run([str(TOOL), "color-add", "#000000"], env=environment, check=True, capture_output=True, text=True)
            result = subprocess.run([str(TOOL), "colors"], env=environment, check=True, capture_output=True, text=True)
            self.assertEqual(json.loads(result.stdout), ["#000000", "#112233", "#DDEEFF", "#AABBCC", "#778899"])
            invalid = subprocess.run([str(TOOL), "color-add", "#GGGGGG"], env=environment, capture_output=True, text=True)
            self.assertEqual(invalid.returncode, 2)

    def test_questline_campaign_survives_new_tool_processes(self):
        with tempfile.TemporaryDirectory() as directory:
            environment = {**os.environ, "XDG_STATE_HOME": directory}
            subprocess.run([str(TOOL), "questline-campaign", "project-123"], env=environment, check=True)
            result = subprocess.run([str(TOOL), "questline-campaign"], env=environment, check=True, capture_output=True, text=True)
            self.assertEqual(result.stdout.strip(), "project-123")
            subprocess.run([str(TOOL), "questline-campaign", "project-456"], env=environment, check=True)
            result = subprocess.run([str(TOOL), "questline-campaign"], env=environment, check=True, capture_output=True, text=True)
            self.assertEqual(result.stdout.strip(), "project-456")


if __name__ == "__main__":
    unittest.main()
