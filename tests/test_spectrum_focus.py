import json
import os
from pathlib import Path
import sqlite3
import subprocess
import tempfile
import time
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
CONTROLLER = ROOT / "scripts/spectrum-focus"


class FocusTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.database = self.root / "questline/questline.db"
        self.database.parent.mkdir()
        with sqlite3.connect(self.database) as connection:
            connection.execute("CREATE TABLE users (id TEXT PRIMARY KEY, username TEXT, class TEXT, level INTEGER, xp INTEGER, created_at TEXT)")
            connection.execute("INSERT INTO users VALUES (?, 'Focus test', 'Code Warlock', 1, 0, '2026-01-01T00:00:00Z')", (str(uuid.uuid4()),))
        self.environment = {**os.environ, "XDG_STATE_HOME": str(self.root / "state"),
                            "XDG_CONFIG_HOME": str(self.root / "config"), "QUESTLINE_STORAGE_DIR": str(self.database.parent)}
        commands = self.root / "bin"
        commands.mkdir()
        notification = commands / "notify-send"
        notification.write_text("#!/bin/sh\nexit 0\n")
        notification.chmod(0o755)
        self.environment["PATH"] = str(commands) + os.pathsep + os.environ["PATH"]

    def tearDown(self):
        self.call("reset")
        deadline = time.monotonic() + 3
        while self.state()["phase"] in {"starting", "work", "paused"} and time.monotonic() < deadline:
            time.sleep(0.05)
        self.directory.cleanup()

    def call(self, *arguments):
        return subprocess.run([str(CONTROLLER), *arguments], env=self.environment, capture_output=True, text=True)

    def state(self):
        result = self.call("state")
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def wait_for(self, phase):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            state = self.state()
            if state["phase"] == phase:
                return state
            if state["phase"] == "error":
                self.fail(state.get("message"))
            time.sleep(0.05)
        self.fail(f"Focus never entered {phase}: {state}")

    def test_invalid_options_do_not_start_a_session(self):
        for request in ({"duration": 0}, {"duration": 181}, {"duration": True},
                        {"duration": "25"}, {"soundscape": "unknown"}, {"project_id": "invalid"}):
            with self.subTest(request=request):
                self.assertNotEqual(self.call("start", json.dumps(request)).returncode, 0)
                self.assertEqual(self.state()["phase"], "idle")

    def test_pause_resume_reset_and_no_duplicate_session(self):
        request = {"duration": 5, "soundscape": "Silent"}
        self.assertEqual(self.call("start", json.dumps(request)).returncode, 0)
        self.wait_for("work")
        self.assertNotEqual(self.call("start", json.dumps(request)).returncode, 0)
        self.assertEqual(self.call("toggle").returncode, 0)
        paused = self.wait_for("paused")
        time.sleep(1.1)
        self.assertEqual(self.state()["remaining"], paused["remaining"])
        self.assertEqual(self.call("toggle").returncode, 0)
        self.wait_for("work")
        self.assertEqual(self.call("reset").returncode, 0)
        self.wait_for("idle")
        with sqlite3.connect(self.database) as connection:
            self.assertEqual(connection.execute("SELECT COUNT(*) FROM focus_sessions").fetchone()[0], 0)
            self.assertEqual(connection.execute("SELECT xp FROM users").fetchone()[0], 0)

    def test_missing_campaign_reports_an_error_without_rewards(self):
        request = {"duration": 5, "project_id": str(uuid.uuid4()), "soundscape": "Silent"}
        self.assertEqual(self.call("start", json.dumps(request)).returncode, 0)
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline and self.state()["phase"] == "starting":
            time.sleep(0.05)
        self.assertEqual(self.state()["phase"], "error")
        self.assertIn("Campaign no longer exists", self.state()["message"])


if __name__ == "__main__":
    unittest.main()
