import os
from contextlib import closing
from pathlib import Path
import runpy
import sqlite3
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
sound = runpy.run_path(str(ROOT / "scripts/questline-sound"))


class QuestlineSoundTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.database = self.directory / "questline.db"
        with closing(sqlite3.connect(self.database)) as connection, connection:
            connection.execute("CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)")

    def settings(self, enabled, volume):
        with closing(sqlite3.connect(self.database)) as connection, connection:
            connection.executemany("INSERT OR REPLACE INTO settings VALUES (?, ?)",
                                   [("sound_effects_enabled", enabled), ("sound_effects_volume", volume)])

    def test_preferences_match_native_gain_and_ignore_music_volume(self):
        self.settings("true", "0.5")
        with closing(sqlite3.connect(self.database)) as connection, connection:
            connection.execute("INSERT INTO settings VALUES ('audio_volume', '0')")
        self.assertEqual(sound["effect_volume"](self.database), 10)
        self.settings("false", "1")
        self.assertEqual(sound["effect_volume"](self.database), 0)
        self.settings("true", "0")
        self.assertEqual(sound["effect_volume"](self.database), 0)

    def test_missing_profile_is_silent_without_creating_database(self):
        missing = self.directory / "missing.db"
        self.assertEqual(sound["effect_volume"](missing), 0)
        self.assertFalse(missing.exists())

    def test_playback_uses_profile_and_prevents_overlapping_same_effect(self):
        self.settings("true", "0.5")
        environment = {"QUESTLINE_STORAGE_DIR": str(self.directory), "XDG_RUNTIME_DIR": str(self.directory)}
        with patch.dict(os.environ, environment), patch("subprocess.run") as player:
            player.side_effect = lambda *args, **kwargs: sound["play"]("swarm")
            sound["play"]("swarm")
            self.assertEqual(player.call_count, 1)
            command = player.call_args.args[0]
            self.assertIn("10", command)
            self.assertTrue(command[-1].endswith("NotificationSwarm.mp3"))

    def test_disabled_effect_never_starts_player(self):
        self.settings("false", "1")
        with patch.dict(os.environ, {"QUESTLINE_STORAGE_DIR": str(self.directory)}), patch("subprocess.run") as player:
            sound["play"]("complete")
            player.assert_not_called()
