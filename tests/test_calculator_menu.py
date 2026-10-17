from pathlib import Path
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
MENU = ROOT / "scripts" / "calculator-menu"

EXAMPLES = (
    "12 + 4 * 3",
    "240 * 15%",
    "2^10",
    "sqrt(2)",
    "sin(30 deg)",
    "6.022e23",
    "60 mph -> km/h",
    "5 ft + 8 in -> cm",
    "25 °C -> °F",
    "1 GiB -> MiB",
    "2 min + 30 s -> s",
    "log10(1000)",
)


class CalculatorMenuTests(unittest.TestCase):
    def test_script_is_valid_bash(self):
        result = subprocess.run(("bash", "-n", str(MENU)), capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_examples_cover_a_wide_spread_of_what_numbat_handles(self):
        # Arithmetic, percentages, powers/roots, trig, scientific notation, and unit
        # conversions across several different domains (speed, length, temperature, data
        # size, time) -- not just a half-dozen entries that lean almost entirely on unit
        # conversions like the previous list did.
        content = MENU.read_text(encoding="utf-8")
        for example in EXAMPLES:
            self.assertIn(example, content)

    def test_reset_and_close_are_offered_alongside_the_examples(self):
        content = MENU.read_text(encoding="utf-8")
        self.assertIn("'reset'", content)
        self.assertIn("'close'", content)

    def test_wofi_reopens_after_each_calculation_instead_of_exiting(self):
        # `wofi --dmenu` is a single-shot picker -- looping back into a fresh prompt after
        # every result (until Escape or "close") is what makes this behave like a
        # calculator that stays open across a session instead of closing after one
        # expression.
        content = MENU.read_text(encoding="utf-8")
        self.assertIn("while true; do", content)
        self.assertIn('[[ -n $selection ]] || break', content)
        self.assertIn('[[ $selection == close ]] && break', content)
        loop_body = content.split("while true; do", 1)[1]
        self.assertIn("/usr/lib/spectrumos/spectrum-shell-picker calculator --dmenu", loop_body)
        self.assertIn("continue", loop_body)
        self.assertIn("done", loop_body)

    def test_prompt_shows_the_running_result_for_the_next_expression(self):
        content = MENU.read_text(encoding="utf-8")
        self.assertIn('prompt="= $last_result', content)
        self.assertIn("last_result=$result", content)
        # Starts empty, and is cleared again on reset and on a failed calculation, so a
        # stale result never gets shown as if it were still the current one.
        self.assertEqual(content.count('last_result=""'), 3)

    def test_reset_clears_history_but_keeps_the_calculator_open(self):
        content = MENU.read_text(encoding="utf-8")
        reset_block = content.split('if [[ $selection == reset ]]; then', 1)[1].split("\n    fi", 1)[0]
        self.assertIn(': > "$history_file"', reset_block)
        self.assertIn("continue", reset_block)
        self.assertNotIn("break", reset_block)

    def test_uses_numbat_without_evaluating_shell_input(self):
        content = MENU.read_text(encoding="utf-8")
        self.assertIn('numbat "${arguments[@]}"', content)
        self.assertNotIn("eval ", content)


if __name__ == "__main__":
    unittest.main()
