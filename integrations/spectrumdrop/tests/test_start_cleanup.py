import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPECTRUMDROP = ROOT / "runtime" / "bin" / "spectrumdrop"


class FailedRadioStartCleanupTests(unittest.TestCase):
    def test_receiver_first_failure_stops_a_partially_started_radio(self):
        source = SPECTRUMDROP.read_text()
        start = source.index("  if (( receiver_first )); then")
        fragment = source[start:source.index("\n  fi", start) + 5]
        with tempfile.TemporaryDirectory() as directory:
            helper = Path(directory) / "spectrumdrop-discoverable"
            helper.write_text("#!/bin/sh\n")
            helper.chmod(0o755)
            capture = Path(directory) / "events"
            harness = f'''\nset -uo pipefail\nreceiver_first=1\nRADIO_ERR="supervisor did not start"\nUNIT=spectrumdrop-receiver.service\nDISCOVERABLE={helper}\nCAPTURE={capture}\nstart_receiver(){{ return 0; }}\nradio_up(){{ return 1; }}\nsystemctl(){{ :; }}\npkexec(){{ printf 'pkexec %s\\n' "$*" >> "$CAPTURE"; }}\ndie(){{ printf 'die %s\\n' "$*" >> "$CAPTURE"; exit 9; }}\n{fragment}\n'''
            result = subprocess.run(
                ["bash", "-c", harness], capture_output=True, text=True
            )
            events = capture.read_text()

        self.assertEqual(result.returncode, 9, result.stdout + result.stderr)
        self.assertIn(f"pkexec {helper} stop", events)
        self.assertLess(events.index("pkexec"), events.index("die"))


if __name__ == "__main__":
    unittest.main()
