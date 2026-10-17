import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
PICKER = ROOT / "scripts/spectrum-shell-picker"


class SpectrumShellPickerTests(unittest.TestCase):
    def test_menu_request_and_selection(self):
        with tempfile.TemporaryDirectory() as directory:
            fake_qs = Path(directory) / "qs"
            fake_qs.write_text(
                "#!/usr/bin/env python3\n"
                "import json, pathlib, sys\n"
                "folder = pathlib.Path(sys.argv[-1])\n"
                "request = json.loads((folder / 'request.json').read_text())\n"
                "assert request == {'prompt': 'Choose', 'password': False, 'rows': ['Alpha', 'Beta']}\n"
                "(folder / 'response').write_text('Beta\\n')\n",
                encoding="utf-8",
            )
            fake_qs.chmod(0o755)
            result = subprocess.run(
                (str(PICKER), "left", "--dmenu", "--prompt", "Choose"),
                input="Alpha\nBeta\n", capture_output=True, text=True,
                env={**os.environ, "PATH": f"{directory}:{os.environ['PATH']}"},
                timeout=5,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "Beta\n")

    def test_password_request_has_no_choice_rows(self):
        with tempfile.TemporaryDirectory() as directory:
            fake_qs = Path(directory) / "qs"
            fake_qs.write_text(
                "#!/usr/bin/env python3\n"
                "import json, pathlib, sys\n"
                "folder = pathlib.Path(sys.argv[-1])\n"
                "request = json.loads((folder / 'request.json').read_text())\n"
                "assert request['password'] and request['rows'] == []\n"
                "(folder / 'response').write_text('secret phrase\\n')\n",
                encoding="utf-8",
            )
            fake_qs.chmod(0o755)
            result = subprocess.run(
                (str(PICKER), "network", "--dmenu", "--password"),
                input="\n", capture_output=True, text=True,
                env={**os.environ, "PATH": f"{directory}:{os.environ['PATH']}"},
                timeout=5,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "secret phrase\n")


if __name__ == "__main__":
    unittest.main()
