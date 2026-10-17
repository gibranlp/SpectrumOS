import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "configs/fastfetch/config.jsonc"


@unittest.skipUnless(shutil.which("fastfetch"), "Fastfetch is not installed")
class FastfetchTests(unittest.TestCase):
    def test_system_information_and_safe_piped_output(self):
        result = subprocess.run(
            ["fastfetch", "--config", str(CONFIG), "--format", "json"],
            capture_output=True, text=True, check=True,
        )
        modules = json.loads(result.stdout)
        self.assertTrue(any(item["type"] == "CPU" and "result" in item for item in modules))
        output = subprocess.check_output(["fastfetch", "--config", str(CONFIG), "--pipe", "true"])
        self.assertNotIn(b"\x89PNG", output)
        self.assertIn(b"CPU:", output)

    def test_live_configuration_staging_uses_the_shared_branding(self):
        builder = (ROOT / "scripts/build-iso").read_text()
        match = re.search(
            r'python - "\$project_root/configs/fastfetch/config.jsonc".*?<<\x27PY\x27\n(.*?)\nPY',
            builder, re.DOTALL,
        )
        self.assertIsNotNone(match)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "config.jsonc"
            subprocess.run(["python3", "-c", match[1], str(CONFIG), str(output)], check=True)
            live = json.loads(output.read_text())
            self.assertEqual(live["logo"]["type"], "sixel")
            self.assertEqual(live["logo"]["source"], "/var/lib/spectrumos/appearance/lock-branding.png")
            subprocess.run(["fastfetch", "--config", str(output), "--format", "json"],
                           stdout=subprocess.DEVNULL, check=True)
