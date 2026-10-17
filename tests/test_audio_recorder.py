from importlib.machinery import SourceFileLoader
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
AUDIO = {"sources": [{"name": "mic", "recordable": True}],
         "sinks": [{"name": "speaker", "monitor": "speaker.capture", "recordable": True}]}


def load():
    loader = SourceFileLoader("audio_recorder", str(ROOT / "scripts/audio-recorder"))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class AudioRecorderTests(unittest.TestCase):
    def test_routes_input_output_and_mixed_recordings(self):
        module = load()
        for mode, names in (("input", ["mic"]), ("output", ["speaker.capture"]),
                            ("both", ["mic", "speaker.capture"])):
            args = module.command(dict(mode=mode, input="mic", output="speaker"), AUDIO, Path("out.mp3"))
            self.assertEqual([args[index + 1] for index, arg in enumerate(args) if arg == "-i"], names)
            self.assertEqual("-filter_complex" in args, mode == "both")
            if mode == "both":
                self.assertIn("amix=inputs=2", args[args.index("-filter_complex") + 1])
                self.assertIn("alimiter=", args[args.index("-filter_complex") + 1])
            self.assertIn("-nostdin", args)
            self.assertIn("-n", args)

    def test_invalid_or_disconnected_options_never_launch(self):
        module = load()
        for options in ({"mode": "both", "input": "mic", "output": "missing"},
                        {"input": "missing"}, {"input": "mic", "format": "bad"},
                        {"input": "mic", "bitrate": 999}, {"input": "mic", "sample_rate": 1},
                        {"input": "mic", "channels": True}, {"input": "mic", "mode": []},
                        {"input": "mic", "format": "opus", "sample_rate": 44100},
                        {"input": "mic", "extra": "x"}):
            with self.subTest(options=options), mock.patch.object(module, "active", return_value=False), \
                 mock.patch.object(module, "devices", return_value=AUDIO), \
                 mock.patch.object(module, "write") as write, mock.patch.object(module, "run") as run:
                with self.assertRaises(ValueError):
                    module.start(options)
                write.assert_not_called()
                run.assert_not_called()

    def test_duplicate_recording_refused(self):
        module = load()
        with mock.patch.object(module, "active", return_value=True), mock.patch.object(module, "devices") as devices:
            with self.assertRaisesRegex(ValueError, "already running"):
                module.start({"input": "mic"})
            devices.assert_not_called()

    def test_device_level_changes_only_selected_device(self):
        module = load()
        with mock.patch.object(module, "devices", return_value=AUDIO), mock.patch.object(module, "run") as run:
            module.device_action("output", "speaker", "volume", "75")
            run.assert_called_once_with("pactl", "set-sink-volume", "speaker", "75%")
            run.reset_mock()
            module.device_action("input", "mic", "mute", "on")
            run.assert_called_once_with("pactl", "set-source-mute", "mic", "1")
            run.reset_mock()
            for kind, name, key, value in (("output", "missing", "volume", "75"),
                                          ("output", "speaker", "volume", "151"),
                                          ("input", "mic", "mute", "toggle")):
                with self.assertRaises(ValueError):
                    module.device_action(kind, name, key, value)
            run.assert_not_called()

    def test_volume_averages_channels_and_monitors_are_not_inputs(self):
        module = load()
        output = {"name": "speaker", "description": "Speakers", "volume": {"left": {"value": 65536}, "right": {"value": 32768}}}
        source = {"name": "mic", "mute": True, "volume": {"mono": {"value": 32768}}}
        with mock.patch.object(module, "run", side_effect=[json.dumps([output]), json.dumps([source, {"name": "speaker.monitor"}]), "speaker", "mic"]):
            result = module.devices()
        self.assertEqual(result["sinks"][0]["volume"], 75)
        self.assertTrue(result["sinks"][0]["recordable"])
        self.assertEqual([row["name"] for row in result["sources"]], ["mic"])
        self.assertTrue(result["sources"][0]["muted"])

    def test_failed_worker_reports_error_in_persistent_status(self):
        module = load()
        with tempfile.TemporaryDirectory() as directory:
            module.STATE = Path(directory)
            module.write("job.json", {"command": ["ffmpeg"], "status": {"started": 0, "file": "missing"}})
            child = mock.Mock()
            child.wait.return_value = 1
            with mock.patch.object(module.signal, "signal"), mock.patch.object(module.subprocess, "Popen", return_value=child):
                with self.assertRaises(RuntimeError):
                    module.record()
            self.assertEqual(module.read("status.json")["phase"], "failed")
            self.assertFalse(module.read("status.json")["active"])
            self.assertIn("failed", module.read("status.json")["error"])

    def test_status_does_not_treat_stale_state_as_recording(self):
        module = load()
        with mock.patch.object(module, "read", return_value={"active": True, "phase": "recording"}), \
             mock.patch.object(module, "active", return_value=False):
            state = module.status()
        self.assertFalse(state["active"])
        self.assertIn("unexpectedly", state["error"])

    def test_all_formats_encode_playable_audio_with_requested_settings(self):
        module = load()
        with tempfile.TemporaryDirectory() as directory:
            for fmt, codec in (("mp3", "mp3"), ("opus", "opus"), ("aac", "aac"), ("flac", "flac"), ("wav", "pcm_s16le")):
                with self.subTest(format=fmt):
                    output = Path(directory) / ("tone." + module.FORMATS[fmt][0])
                    args = module.command(dict(input="mic", format=fmt, bitrate=128, channels=1, sample_rate=48000), AUDIO, output)
                    start = args.index("-thread_queue_size")
                    end = args.index("-map")
                    args[start:end] = ["-f", "lavfi", "-i", "sine=frequency=440:duration=0.25:sample_rate=48000"]
                    result = subprocess.run(args, capture_output=True, text=True, timeout=10)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    probe = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(output)]))
                    stream = probe["streams"][0]
                    self.assertEqual(stream["codec_name"], codec)
                    self.assertEqual(int(stream["sample_rate"]), 48000)
                    self.assertEqual(stream["channels"], 1)
                    self.assertGreater(float(probe["format"]["duration"]), 0)

    def test_control_center_omits_mouse_and_recorder_and_shortcuts_match_bindings(self):
        center = (ROOT / "configs/spectrum-shell/ControlCenter.qml").read_text()
        self.assertNotIn('label: "Mouse Settings"', center)
        self.assertNotIn('label: "Audio Recorder"', center)
        bindings = (ROOT / "configs/hyprland/keybindings.lua").read_text()
        shortcuts = (ROOT / "configs/spectrum-shell/UtilityPanel.qml").read_text()
        for key, page in (("M", "mouse"), ("A", "audio-recorder")):
            self.assertIn(f'" + SHIFT + {key}"', bindings)
            self.assertIn(f'Super + Shift + {key}', shortcuts)
            self.assertIn(f'"{page}"', shortcuts)
