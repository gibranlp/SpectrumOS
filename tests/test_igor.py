import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class IgorTests(unittest.TestCase):
    def layout(self, config, *args):
        result = subprocess.run([str(ROOT / "scripts/spectrum-shell-layout"), *args],
                                env={**os.environ, "XDG_CONFIG_HOME": str(config)},
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def test_mascot_toggle_preserves_other_settings(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory)
            path = config / "spectrumos/shell.json"
            path.parent.mkdir()
            original = {"bar_position": "top", "bar_profile": "detailed",
                        "bar_profiles": {"DP-1": "multimedia"}, "custom": "preserved"}
            path.write_text(json.dumps(original))
            self.layout(config, "set-mascot", "off")
            saved = json.loads(path.read_text())
            self.assertEqual(saved, {**original, "igor_enabled": False})
            self.assertFalse(json.loads(self.layout(config, "--json"))["igor_enabled"])
            self.layout(config, "set-mascot", "on")
            self.assertEqual(json.loads(path.read_text()), {**original, "igor_enabled": True})
            self.assertTrue(json.loads(self.layout(config, "--json"))["igor_enabled"])

    def test_first_install_enables_igor(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertTrue(json.loads(self.layout(Path(directory), "--json"))["igor_enabled"])



if __name__ == "__main__":
    unittest.main()
