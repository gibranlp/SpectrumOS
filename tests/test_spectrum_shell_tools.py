from pathlib import Path
import json
import os
import shutil
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

    def test_color_history_keeps_sixty_unique_recent_colors(self):
        with tempfile.TemporaryDirectory() as directory:
            environment = {**os.environ, "XDG_STATE_HOME": directory}
            for value in ("#112233", "#445566", "#778899", "#AABBCC", "#DDEEFF", "#112233"):
                result = subprocess.run([str(TOOL), "color-add", value], env=environment, check=True, capture_output=True, text=True)
            self.assertEqual(json.loads(result.stdout), ["#112233", "#DDEEFF", "#AABBCC", "#778899", "#445566"])
            subprocess.run([str(TOOL), "color-add", "#000000"], env=environment, check=True, capture_output=True, text=True)
            result = subprocess.run([str(TOOL), "colors"], env=environment, check=True, capture_output=True, text=True)
            self.assertEqual(json.loads(result.stdout), ["#000000", "#112233", "#DDEEFF", "#AABBCC", "#778899", "#445566"])
            for number in range(70):
                result = subprocess.run([str(TOOL), "color-add", f"#{number:06X}"], env=environment, check=True, capture_output=True, text=True)
            result = subprocess.run([str(TOOL), "colors"], env=environment, check=True, capture_output=True, text=True)
            self.assertEqual(json.loads(result.stdout), [f"#{number:06X}" for number in range(69, 9, -1)])
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


@unittest.skipUnless(shutil.which("numbat"), "Numbat is unavailable")
class CalculatorChainTests(unittest.TestCase):
    def calculate(self, expression, steps=None):
        process = subprocess.run([str(TOOL), "calculate-json", json.dumps({"expression": expression, "steps": steps or []})],
                                 capture_output=True, text=True)
        return process.returncode, json.loads(process.stdout)

    def value(self, expression, steps=None):
        code, response = self.calculate(expression, steps)
        self.assertEqual(code, 0, response)
        self.assertTrue(response["ok"])
        return response

    def test_reported_decimal_product_preserves_precision(self):
        result = self.value("10414.81*1.16")
        self.assertEqual(result["result"], "12081.1796")

    def test_conversions_return_values_with_their_units(self):
        length = self.value("(1) m -> cm")
        self.assertEqual(length["result"], "100 cm")
        temperature = self.value("(20) °C -> °F")
        self.assertAlmostEqual(float(temperature["result"]), 68)

    def test_continuous_operations_and_relative_percentage(self):
        result = self.value("100 + 20")
        result = self.value("* 2", result["steps"])
        result = self.value("+ 15%", result["steps"])
        self.assertAlmostEqual(float(result["result"].replace("_", "")), 276)

    def test_percentage_multiplication_and_fresh_entry(self):
        result = self.value("100 + 15%")
        self.assertAlmostEqual(float(result["result"].replace("_", "")), 115)
        result = self.value("* 15%", result["steps"])
        self.assertAlmostEqual(float(result["result"].replace("_", "")), 17.25)
        fresh = self.value("7", result["steps"])
        self.assertEqual(len(fresh["steps"]), 1)
        self.assertAlmostEqual(float(fresh["result"]), 7)

    def test_answer_reuses_computation_before_display_rounding(self):
        result = self.value("1 / 3")
        result = self.value("ans * 3", result["steps"])
        self.assertAlmostEqual(float(result["result"]), 1)

    def test_failed_expression_does_not_replace_the_answer(self):
        previous = self.value("10")
        code, error = self.calculate("sqrt(", previous["steps"])
        self.assertNotEqual(code, 0)
        self.assertFalse(error["ok"])
        self.assertNotIn("steps", error)
        result = self.value("+ 5", previous["steps"])
        self.assertAlmostEqual(float(result["result"]), 15)


if __name__ == "__main__":
    unittest.main()


class SearchLocationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.home = self.base / 'home'
        self.home.mkdir()
        self.drive = self.base / 'external music'
        self.drive.mkdir()
        self.env = {**os.environ, 'HOME': str(self.home), 'XDG_STATE_HOME': str(self.base / 'state')}

    def call(self, action, payload=None):
        args = [str(TOOL), action]
        if payload is not None:
            args.append(json.dumps(payload) if isinstance(payload, dict) else str(payload))
        result = subprocess.run(args, env=self.env, capture_output=True, text=True, timeout=15)
        return result.returncode, json.loads(result.stdout)

    def test_home_default_and_custom_drive_survive_new_processes(self):
        code, result = self.call('search-state')
        self.assertEqual(code, 0)
        self.assertEqual(result['root'], str(self.home))
        code, result = self.call('search-root', self.drive)
        self.assertEqual(code, 0, result)
        code, result = self.call('search-state')
        self.assertEqual(result['root'], str(self.drive))
        self.assertIn(str(self.drive), [row['path'] for row in result['locations']])

    def test_only_selected_drive_is_searched_case_insensitively(self):
        (self.home / 'track-home.flac').touch()
        target = self.drive / 'TRACK-café.flac'
        target.touch()
        (self.drive / 'Album').mkdir()
        nested = self.drive / 'Album/track-two.flac'
        nested.touch()
        code, result = self.call('search-json', {'root': str(self.drive), 'query': 'track', 'request_id': 17})
        self.assertEqual(code, 0, result)
        self.assertEqual(set(result['matches']), {str(target), str(nested)})
        self.assertEqual(result['request_id'], 17)

    def test_hidden_entries_and_directory_links_are_not_traversed(self):
        hidden = self.drive / '.hidden'
        hidden.mkdir()
        (hidden / 'track-secret.flac').touch()
        (self.drive / '.track.flac').touch()
        (self.home / 'track-outside.flac').touch()
        (self.drive / 'linked-home').symlink_to(self.home, target_is_directory=True)
        (self.drive / 'loop').symlink_to(self.drive, target_is_directory=True)
        (self.drive / 'track-visible.flac').touch()
        code, result = self.call('search-json', {'root': str(self.drive), 'query': 'track'})
        self.assertEqual(code, 0, result)
        self.assertEqual(result['matches'], [str(self.drive / 'track-visible.flac')])

    def test_invalid_folder_does_not_change_saved_location(self):
        self.call('search-root', self.drive)
        saved = self.base / 'state/spectrumos/search.json'
        before = saved.read_bytes()
        code, result = self.call('search-root', self.base / 'missing')
        self.assertEqual(code, 1)
        self.assertIn('unavailable', result['error'])
        self.assertEqual(saved.read_bytes(), before)
        code, result = self.call('search-root', 'relative/folder')
        self.assertEqual(code, 1)
        self.assertIn('absolute', result['error'])

    def test_disconnected_drive_does_not_fall_back_to_home(self):
        self.call('search-root', self.drive)
        self.drive.rmdir()
        (self.home / 'track-home.flac').touch()
        code, result = self.call('search-state')
        self.assertEqual(code, 1)
        self.assertEqual(result['root'], str(self.drive))
        code, result = self.call('search-json', {'root': str(self.drive), 'query': 'track', 'request_id': 2})
        self.assertEqual(code, 1)
        self.assertEqual(result['matches'], [])
        self.assertEqual(result['request_id'], 2)

    def test_home_expansion_and_literal_query_characters(self):
        target = self.home / 'song[demo].flac'
        target.touch()
        code, result = self.call('search-root', '~')
        self.assertEqual(code, 0)
        self.assertEqual(result['root'], str(self.home))
        code, result = self.call('search-json', {'root': '~', 'query': '[demo]'})
        self.assertEqual(result['matches'], [str(target)])

    def test_sixty_result_limit_and_short_queries(self):
        for i in range(80):
            (self.drive / f'track-{i:03}.flac').touch()
        code, result = self.call('search-json', {'root': str(self.drive), 'query': 'track'})
        self.assertEqual(code, 0)
        self.assertEqual(len(result['matches']), 60)
        self.assertTrue(result['limited'])
        code, result = self.call('search-json', {'root': str(self.drive), 'query': 'x'})
        self.assertEqual(result['matches'], [])

    def test_time_budget_and_escaped_mount_names(self):
        import importlib.machinery
        import importlib.util
        from unittest.mock import patch
        loader = importlib.machinery.SourceFileLoader('scoped_search_tools', str(TOOL))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        module = importlib.util.module_from_spec(spec)
        loader.exec_module(module)
        (self.drive / 'track.flac').touch()
        with patch.object(module.time, 'monotonic', side_effect=[0, 9]):
            result = module.scoped_search({'root': str(self.drive), 'query': 'track'})
        self.assertTrue(result['timed_out'])
        original = Path.read_text
        def mount_data(path, *args, **kwargs):
            if str(path) == '/proc/self/mountinfo':
                return '21 20 8:1 / /media/My\\040Music rw - ext4 /dev/sdb1 rw\n22 20 0:1 / /proc rw - proc proc rw\n'
            return original(path, *args, **kwargs)
        with patch.object(Path, 'read_text', mount_data):
            locations = module.search_locations({'root': str(self.home), 'recent': []})
        self.assertIn('/media/My Music', [row['path'] for row in locations])
        self.assertNotIn('/proc', [row['path'] for row in locations])
