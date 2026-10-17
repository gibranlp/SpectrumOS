import importlib.machinery
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
LOADER = importlib.machinery.SourceFileLoader("spectrum_media_adapter", str(ROOT / "scripts/media-adapter"))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
MEDIA = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(MEDIA)


def result(stdout: str, code: int = 0) -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess([], code, stdout, "")


class MediaAdapterTests(unittest.TestCase):
    def test_playing_player_wins_over_paused_player(self):
        responses = [result("browser\nspotify\n"), result("Paused\n"), result("Playing\n"), result("Song\nArtist\nAlbum\n")]
        with patch.object(MEDIA, "playerctl", side_effect=responses) as command:
            state = MEDIA.media_state()
        self.assertEqual(state["title"], "Song")
        self.assertTrue(state["playing"])
        self.assertEqual(command.call_args_list[-1].args[:2], ("--player", "spotify"))

    def test_transport_targets_selected_player(self):
        responses = [result("browser\nspotify\n"), result("Paused\n"), result("Playing\n"), result("")]
        with patch.object(MEDIA, "playerctl", side_effect=responses) as command, patch("sys.argv", ["media-adapter", "next"]):
            self.assertEqual(MEDIA.main(), 0)
        self.assertEqual(command.call_args_list[-1].args, ("--player", "spotify", "next"))

    def test_missing_title_uses_media_filename(self):
        responses = [result("vlc\n"), result("Playing\n"), result("\n\n\n"), result("file:///Music/Evening%20Song.flac\n")]
        with patch.object(MEDIA, "playerctl", side_effect=responses):
            state = MEDIA.media_state()
        self.assertEqual(state["title"], "Evening Song.flac")


if __name__ == "__main__":
    unittest.main()
