import json
import os
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
ADAPTER = ROOT / "scripts" / "weather-adapter"


class WeatherAdapterTests(unittest.TestCase):
    def test_lockscreen_weather_uses_only_matching_recent_cache_and_escapes_markup(self):
        with tempfile.TemporaryDirectory() as directory:
            adapter = self.load_adapter(directory)
            state = {"active": "test", "locations": [{"token": "test", "name": "Town <North>", "region": "", "latitude": 1, "longitude": 2}]}
            forecast = {"current": {"temperature_2m": 27, "weather_code": 0}}
            adapter["atomic_write"](adapter["STATE_FILE"], state)
            adapter["atomic_write"](adapter["CACHE_FILE"], {"signature": adapter["signature"](state), "generated": 100000, "forecasts": [forecast]})
            with mock.patch.dict(adapter["lockscreen_weather"].__globals__, {
                "request_json": mock.Mock(side_effect=AssertionError("Network request")),
                "detect_location": mock.Mock(side_effect=AssertionError("Geolocation")),
            }), mock.patch("time.time", return_value=100100):
                self.assertIn("Town &lt;North&gt;\n27° · Clear", adapter["lockscreen_weather"]())
            with mock.patch("time.time", return_value=102000):
                self.assertIn("Updated", adapter["lockscreen_weather"]())
            with mock.patch("time.time", return_value=200000):
                self.assertEqual(adapter["lockscreen_weather"](), "")
            state["active"] = "another"
            adapter["atomic_write"](adapter["STATE_FILE"], state)
            with mock.patch("time.time", return_value=100100):
                self.assertEqual(adapter["lockscreen_weather"](), "")

    def test_lockscreen_weather_without_cache_stays_empty(self):
        with tempfile.TemporaryDirectory() as directory:
            adapter = self.load_adapter(directory)
            self.assertEqual(adapter["lockscreen_weather"](), "")

    def load_adapter(self, directory: str):
        environment = {
            "XDG_CONFIG_HOME": str(Path(directory) / "config"),
            "XDG_CACHE_HOME": str(Path(directory) / "cache"),
        }
        with mock.patch.dict(os.environ, environment):
            return runpy.run_path(str(ADAPTER), run_name="weather_adapter_test")

    def test_malformed_saved_state_and_coordinates_do_not_crash_or_trigger_geolocation(self):
        for value in ([], None, "invalid", {"locations": None}, {"locations": [None]},
                      {"locations": [{"token":"bad", "name":"Bad", "region":"", "latitude":"nan", "longitude":0}]}):
            with self.subTest(value=value), tempfile.TemporaryDirectory() as directory:
                adapter = self.load_adapter(directory)
                adapter["atomic_write"](adapter["STATE_FILE"], value)
                with mock.patch.dict(adapter["load_state"].__globals__, detect_location=mock.Mock(side_effect=AssertionError("Geolocation"))):
                    state = adapter["load_state"]()
                self.assertEqual(state["locations"], [adapter["DEFAULT_LOCATION"]])
                self.assertEqual(state["active"], adapter["DEFAULT_LOCATION"]["token"])
                self.assertEqual(json.loads(adapter["STATE_FILE"].read_text()), value)

    def test_corrupt_cache_falls_back_without_crashing_while_offline(self):
        for value in ([], {"generated":"invalid"}, {"generated":float("nan")}, {"generated":0,"forecasts":None}):
            with self.subTest(value=value), tempfile.TemporaryDirectory() as directory:
                adapter = self.load_adapter(directory)
                state={"active":"cancun-mx", "locations":[adapter["DEFAULT_LOCATION"]]}
                adapter["atomic_write"](adapter["STATE_FILE"], state)
                if isinstance(value, dict): value["signature"] = adapter["signature"](state)
                adapter["atomic_write"](adapter["CACHE_FILE"], value)
                with mock.patch.dict(adapter["weather"].__globals__, request_json=mock.Mock(side_effect=OSError("offline"))):
                    self.assertFalse(adapter["weather"]()["available"])

    def test_provider_is_keyless_and_requests_only_bounded_fields(self):
        source = ADAPTER.read_text(encoding="utf-8")
        self.assertIn("https://api.open-meteo.com/v1/forecast", source)
        self.assertIn("https://geocoding-api.open-meteo.com/v1/search", source)
        self.assertIn("CACHE_SECONDS = 900", source)
        self.assertIn('(\"systemd-run\", \"--user\", \"--collect\", \"--quiet\"', source)
        self.assertNotIn("api_key", source.lower())
        self.assertNotIn("shell=True", source)

    def test_normalizes_current_weather_and_five_day_forecast(self):
        with tempfile.TemporaryDirectory() as directory:
            adapter = self.load_adapter(directory)
            # No state file exists yet in this fresh temp dir -- load_state would otherwise
            # attempt a real IP-geolocation request; stub it out the same way a first run
            # with no network available falls back to DEFAULT_LOCATION.
            with mock.patch.dict(adapter["load_state"].__globals__, {"detect_location": mock.Mock(return_value=None)}):
                state = adapter["load_state"]()
            forecast = {
                "current": {
                    "temperature_2m": 29.4,
                    "apparent_temperature": 33.1,
                    "relative_humidity_2m": 75,
                    "weather_code": 1,
                    "wind_speed_10m": 12.2,
                },
                "daily": {
                    "time": ["2026-09-02"] * 6,
                    "weather_code": [0, 1, 2, 3, 61, 95],
                    "temperature_2m_max": [31] * 6,
                    "temperature_2m_min": [25] * 6,
                },
            }
            payload = adapter["normalize"](state, forecast, 1_788_300_000)
            self.assertTrue(payload["available"])
            self.assertEqual(payload["location"], "Cancún")
            self.assertEqual(payload["temperature"], "29°")
            self.assertEqual(payload["condition"], "Partly cloudy")
            self.assertEqual(len(payload["days"]), 5)
            self.assertEqual(payload["provider"], "Weather data by Open-Meteo")

    def test_first_run_seeds_the_active_location_from_ip_geolocation(self):
        with tempfile.TemporaryDirectory() as directory:
            adapter = self.load_adapter(directory)
            detected = {"token": "auto123", "name": "Guadalajara", "region": "Jalisco, Mexico", "latitude": 20.67, "longitude": -103.35}
            with mock.patch.dict(adapter["load_state"].__globals__, {"detect_location": mock.Mock(return_value=detected)}):
                state = adapter["load_state"]()
            self.assertEqual(state["active"], "auto123")
            self.assertEqual(state["locations"], [detected])
            # Persisted immediately -- a later load must read the same result back from
            # disk rather than attempting geolocation again.
            stored = json.loads(adapter["STATE_FILE"].read_text(encoding="utf-8"))
            self.assertEqual(stored["active"], "auto123")

    def test_first_run_falls_back_to_the_default_location_when_geolocation_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            adapter = self.load_adapter(directory)
            with mock.patch.dict(adapter["load_state"].__globals__, {"detect_location": mock.Mock(return_value=None)}):
                state = adapter["load_state"]()
        self.assertEqual(state["active"], "cancun-mx")
        self.assertEqual(state["locations"], [adapter["DEFAULT_LOCATION"]])

    def test_detect_location_rejects_malformed_or_error_responses(self):
        with tempfile.TemporaryDirectory() as directory:
            adapter = self.load_adapter(directory)
            detect_location = adapter["detect_location"]
            for bad_response in ({"error": True, "reason": "RateLimited"}, {"latitude": "not-a-number", "longitude": -103.35}, {}, []):
                fake_response = mock.MagicMock()
                fake_response.__enter__.return_value = fake_response
                with mock.patch.dict(
                    detect_location.__globals__,
                    {"urlopen": mock.Mock(return_value=fake_response), "json": mock.Mock(load=mock.Mock(return_value=bad_response))},
                ):
                    self.assertIsNone(detect_location(), bad_response)

    def test_detect_location_parses_a_real_shaped_response(self):
        with tempfile.TemporaryDirectory() as directory:
            adapter = self.load_adapter(directory)
            detect_location = adapter["detect_location"]
            response = {"city": "Cancún", "region": "Quintana Roo", "country_name": "Mexico", "latitude": 21.1619, "longitude": -86.8515, "ip": "203.0.113.5"}
            fake_response = mock.MagicMock()
            fake_response.__enter__.return_value = fake_response
            with mock.patch.dict(
                detect_location.__globals__,
                {"urlopen": mock.Mock(return_value=fake_response), "json": mock.Mock(load=mock.Mock(return_value=response))},
            ):
                location = detect_location()
        self.assertEqual(location["name"], "Cancún")
        self.assertEqual(location["region"], "Quintana Roo, Mexico")
        self.assertEqual(location["latitude"], 21.1619)
        self.assertEqual(location["longitude"], -86.8515)
        self.assertTrue(location["token"])

    def test_saved_location_state_is_validated(self):
        with tempfile.TemporaryDirectory() as directory:
            adapter = self.load_adapter(directory)
            adapter["STATE_FILE"].parent.mkdir(parents=True)
            adapter["STATE_FILE"].write_text(json.dumps({"active": "bad", "locations": [{"name": "Incomplete"}]}), encoding="utf-8")
            state = adapter["load_state"]()
            self.assertEqual(state["active"], "cancun-mx")
            self.assertEqual(len(state["locations"]), 1)

    def test_location_removal_preserves_one_location_and_reassigns_active(self):
        with tempfile.TemporaryDirectory() as directory:
            adapter = self.load_adapter(directory)
            first = dict(adapter["DEFAULT_LOCATION"])
            second = {"token": "merida-mx", "name": "Mérida", "region": "Yucatán, Mexico", "latitude": 20.9674, "longitude": -89.5926}
            adapter["atomic_write"](adapter["STATE_FILE"], {"active": second["token"], "locations": [first, second]})
            adapter["remove_location"](second["token"])
            state = adapter["load_state"]()
            self.assertEqual(state["active"], first["token"])
            self.assertEqual([location["token"] for location in state["locations"]], [first["token"]])

            with mock.patch("subprocess.run") as run:
                adapter["remove_location"](first["token"])
            self.assertIn("Keep one weather location", run.call_args.args[0])

    def test_location_search_does_not_launch_legacy_panel(self):
        with tempfile.TemporaryDirectory() as directory:
            adapter = self.load_adapter(directory)
            main = adapter["main"]
            launch = mock.Mock(return_value=True)
            with mock.patch.object(adapter["sys"], "argv", ["weather-adapter", "select"]), \
                    mock.patch.dict(main.__globals__, {"launch_job": launch}), \
                    mock.patch("subprocess.run") as run:
                main()
            launch.assert_called_once_with("_select")
            run.assert_not_called()

            select = mock.Mock()
            with mock.patch.object(adapter["sys"], "argv", ["weather-adapter", "_select"]), \
                    mock.patch.dict(main.__globals__, {"select_location": select}), \
                    mock.patch.object(adapter["time"], "sleep"), \
                    mock.patch("subprocess.run") as run:
                main()
            select.assert_called_once_with()
            run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
