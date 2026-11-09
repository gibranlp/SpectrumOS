from importlib.machinery import SourceFileLoader
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest
from unittest import mock
from urllib.error import URLError

TOOL = Path(__file__).resolve().parents[1] / "scripts/spectrum-shell-tools"
spec = importlib.util.spec_from_loader("currency_tools", SourceFileLoader("currency_tools", str(TOOL)))
tools = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tools)
RATES = {"USD": "1.1", "MXN": "22", "GBP": "0.85", "CAD": "1.5", "JPY": "165", "CHF": "0.95"}
STAMP = "2026-10-23"


class CurrencyConversionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.environment = mock.patch.dict(os.environ, {"XDG_CACHE_HOME": self.temporary.name})
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.path = Path(self.temporary.name) / "spectrumos/currency-rates.json"

    def response(self, rows=None):
        rows = rows if rows is not None else [
            {"date": STAMP, "base": "EUR", "quote": code, "rate": float(rate)} for code, rate in RATES.items()]
        return io.BytesIO(json.dumps(rows).encode())

    def call(self, value="2", source="USD", target="MXN"):
        output = io.StringIO()
        with mock.patch("sys.stdout", output):
            code = tools.convert_currency(json.dumps({"value": value, "from": source, "to": target}))
        return code, json.loads(output.getvalue())

    def seed(self, **changes):
        data = {"schema": 1, "date": STAMP, "rates": {"EUR": "1", **RATES},
                "checked_at": time.time(), "retry_after": 0, **changes}
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(json.dumps(data))
        return data

    def test_usd_mxn_fetches_reference_rates_and_saves_the_observation_date(self):
        with mock.patch.object(tools, "urlopen", return_value=self.response()) as fetch:
            code, data = self.call()
        self.assertEqual(code, 0, data)
        self.assertEqual(data["result"], "40 MXN")
        self.assertEqual(data["currency"]["date"], STAMP)
        self.assertFalse(data["currency"]["offline"])
        self.assertEqual(json.loads(self.path.read_text())["rates"]["MXN"], "22.0")
        self.assertNotIn("value=", fetch.call_args.args[0].full_url)

    def test_fresh_cache_avoids_network_and_works_in_a_new_process(self):
        self.seed()
        with mock.patch.object(tools, "urlopen") as fetch:
            code, data = self.call()
            fetch.assert_not_called()
        self.assertEqual(code, 0)
        self.assertEqual(data["result"], "40 MXN")
        process = subprocess.run([str(TOOL), "convert-currency", '{"value":"3","from":"USD","to":"MXN"}'],
                                 capture_output=True, text=True, timeout=5)
        self.assertEqual(process.returncode, 0, process.stdout)
        self.assertEqual(json.loads(process.stdout)["result"], "60 MXN")

    def test_offline_fallback_preserves_rate_date_and_last_successful_check(self):
        previous = self.seed(checked_at=time.time() - 7200)
        with mock.patch.object(tools, "urlopen", side_effect=URLError("offline")) as fetch:
            code, data = self.call()
            self.assertEqual(fetch.call_count, 1)
            self.assertEqual(code, 0)
            self.assertTrue(data["currency"]["offline"])
            self.assertEqual(data["result"], "40 MXN")
            self.assertEqual(data["currency"]["date"], STAMP)
            self.assertEqual(data["currency"]["checked_at"], previous["checked_at"])
            self.assertEqual(self.call("3")[1]["result"], "60 MXN")
            self.assertEqual(fetch.call_count, 1)
        saved = json.loads(self.path.read_text())
        self.assertEqual(saved["date"], STAMP)
        self.assertGreater(saved["retry_after"], time.time())

    def test_offline_without_cache_has_an_actionable_error_and_no_result(self):
        with mock.patch.object(tools, "urlopen", side_effect=URLError("offline")):
            code, data = self.call()
        self.assertEqual(code, 1)
        self.assertIn("Connect to the internet", data["error"])
        self.assertNotIn("result", data)
        self.assertFalse(self.path.exists())

    def test_bad_provider_data_never_replaces_a_valid_saved_table(self):
        previous = self.seed(checked_at=0)
        rows = [{"date": STAMP, "base": "EUR", "quote": code, "rate": float(rate)} for code, rate in RATES.items()]
        rows[0]["rate"] = -1
        with mock.patch.object(tools, "urlopen", return_value=self.response(rows)):
            code, data = self.call()
        self.assertEqual(code, 0)
        self.assertTrue(data["currency"]["offline"])
        self.assertEqual(json.loads(self.path.read_text())["rates"], previous["rates"])

    def test_corrupt_cache_is_not_presented_as_a_rate(self):
        self.seed(rates={"EUR": "1", **RATES, "MXN": "NaN"})
        with mock.patch.object(tools, "urlopen", side_effect=URLError("offline")):
            code, data = self.call()
        self.assertEqual(code, 1)
        self.assertNotIn("result", data)

    def test_same_currency_and_invalid_amounts_do_not_need_network(self):
        with mock.patch.object(tools, "urlopen") as fetch:
            self.assertEqual(self.call("12.50", "USD", "USD")[1]["result"], "12.5 USD")
            for amount in ("", "NaN", "Infinity", "1e999", "1e9999999", "2+3"):
                code, data = self.call(amount)
                self.assertEqual(code, 1)
                self.assertIn("valid currency amount", data["error"])
            fetch.assert_not_called()

    def test_inverse_cross_rates_and_negative_amounts(self):
        self.seed()
        self.assertEqual(self.call("40", "MXN", "USD")[1]["result"], "2 USD")
        self.assertEqual(self.call("2", "EUR", "MXN")[1]["result"], "44 MXN")
        self.assertEqual(self.call("-2")[1]["result"], "-40 MXN")

    def test_mismatched_observation_dates_are_rejected(self):
        rows = [{"date": STAMP, "base": "EUR", "quote": code, "rate": float(rate)} for code, rate in RATES.items()]
        rows[0]["date"] = "2026-10-22"
        with mock.patch.object(tools, "urlopen", return_value=self.response(rows)):
            code, data = self.call()
        self.assertEqual(code, 1)
        self.assertNotIn("result", data)
