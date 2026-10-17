from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
import tempfile
import unittest

from spectrum_theme.cli import main


class CliTests(unittest.TestCase):
    def test_native_extract_writes_valid_palette(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            image = root / "fixture.ppm"
            output = root / "palette.toml"
            image.write_text("P3\n2 1\n255\n10 20 30 40 120 220\n", encoding="ascii")
            stdout = StringIO()
            stderr = StringIO()

            with redirect_stdout(stdout), redirect_stderr(stderr):
                exit_code = main(
                    [
                        "extract",
                        "native",
                        str(image),
                        "--mode",
                        "median-cut",
                        "--output",
                        str(output),
                    ]
                )

            self.assertEqual(exit_code, 0, stderr.getvalue())
            self.assertTrue(output.is_file())
            self.assertIn("Extracted palette", stdout.getvalue())
            self.assertIn('source = "native:median-cut:fixture.ppm"', output.read_text(encoding="utf-8"))

    def test_invalid_palette_uses_fallback(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            invalid = root / "invalid.toml"
            invalid.write_text("invalid = true\n", encoding="utf-8")
            output = root / "output"
            stdout = StringIO()
            stderr = StringIO()

            with redirect_stdout(stdout), redirect_stderr(stderr):
                exit_code = main(["render", "--palette", str(invalid), "--output", str(output)])

            self.assertEqual(exit_code, 0)
            self.assertIn("Using packaged fallback palette", stderr.getvalue())
            self.assertIn("Spectrum Dark", stdout.getvalue())
            self.assertTrue((output / "current" / "palette.json").is_file())

    def test_strict_mode_rejects_invalid_palette(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            invalid = root / "invalid.toml"
            invalid.write_text("invalid = true\n", encoding="utf-8")
            stderr = StringIO()

            with redirect_stderr(stderr):
                exit_code = main(
                    ["render", "--strict", "--palette", str(invalid), "--output", str(root / "output")]
                )

            self.assertEqual(exit_code, 1)
            self.assertIn("must contain [palette] and [roles]", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
