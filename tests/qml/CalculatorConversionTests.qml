import QtQuick
import QtTest
import Quickshell
import "../../configs/spectrum-shell" as Shell

Scope {
    FloatingWindow {
        visible: true
        implicitWidth: 680
        implicitHeight: 1000
        Shell.Calculator {
            id: calculator
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 20 }
            backendDir: Quickshell.env("SPECTRUM_CALCULATOR_TEST_DIR")
            theme: ({fontSize:13, fontFamily:"monospace", animationsEnabled:false,
                colors:{background:"#111111",surface_alt:"#333333",foreground:"#eeeeee",muted:"#aaaaaa",accent:"#66ccee",error:"#ff6666"}})
            property var seenResults: []
            onConversionResultChanged: if (conversionResult) seenResults = seenResults.concat([conversionResult])
        }
    }
    TestCase {
        name: "CalculatorConversions"
        when: true
        onCompletedChanged: if (completed) {
            console.log("Calculator conversions:", qtest_results.passCount, "passed", qtest_results.failCount, "failed");
            Qt.quit();
        }
        function field(name) { return findChild(calculator, "conversion-" + name); }
        function init() {
            calculator.advanced = false;
            tryCompare(calculator, "conversionBusy", false, 3000);
            calculator.advancedPage = "Conversions";
            calculator.setCategory(0);
            field("value").text = "1";
            calculator.advanced = true;
            tryCompare(calculator, "conversionResult", "100 cm", 3000);
            tryCompare(calculator, "conversionBusy", false, 3000);
            calculator.seenResults = [];
        }
        function test_value_unit_and_category_changes_convert_automatically() {
            field("value").text = "2";
            tryCompare(calculator, "conversionResult", "200 cm", 3000);
            calculator.fromUnit = "km";
            calculator.toUnit = "m";
            tryCompare(calculator, "conversionResult", "2000 m", 3000);
            calculator.setCategory(2);
            field("value").text = "25";
            tryCompare(calculator, "conversionResult", "77", 3000);
            compare(calculator.conversionResultUnit, "°F");
        }
        function test_swap_updates_the_result() {
            wait(30);
            mouseClick(field("swap"));
            tryCompare(calculator, "conversionResult", "0.01 m", 3000);
            compare(calculator.fromUnit, "cm");
            compare(calculator.toUnit, "m");
        }
        function test_currency_uses_saved_rates_and_displays_the_real_update_date() {
            calculator.setCategory(14);
            calculator.fromUnit = "USD";
            calculator.toUnit = "MXN";
            field("value").text = "2";
            tryCompare(calculator, "conversionResult", "40 MXN", 3000);
            compare(calculator.currencyRateDate, "2026-10-23");
            verify(calculator.currencyOffline);
            verify(field("currency-status").text.includes("23/10/2026"));
            verify(field("currency-status").text.includes("Offline"));
            verify(field("copy").enabled);
            field("value").text = "3";
            tryCompare(calculator, "conversionResult", "60 MXN", 3000);
        }
        function test_result_replaces_convert_and_copy_uses_accent() {
            const output = field("result");
            const copy = field("copy");
            verify(output.visible);
            compare(output.text, "100 cm");
            compare(copy.backgroundColor, calculator.theme.colors.accent);
            verify(copy.enabled);
            verify(output.x + output.width <= copy.x);
        }
        function test_pending_conversion_does_not_block_edits_or_show_stale_results() {
            calculator.backendDir = Quickshell.env("SPECTRUM_CALCULATOR_SLOW_DIR");
            field("value").text = "2";
            tryVerify(() => calculator.conversionBusy && !calculator.conversionPending, 2000);
            verify(field("value").enabled);
            verify(field("from").enabled);
            verify(field("to").enabled);
            field("value").text = "3";
            calculator.toUnit = "mm";
            verify(!field("copy").enabled);
            tryCompare(calculator, "conversionResult", "3000 mm", 4000);
            verify(!calculator.seenResults.includes("200 cm"));
            calculator.backendDir = Quickshell.env("SPECTRUM_CALCULATOR_TEST_DIR");
        }
        function test_conversion_does_not_steal_focus() {
            field("from").forceActiveFocus();
            tryVerify(() => field("from").activeFocus);
            calculator.toUnit = "mm";
            tryCompare(calculator, "conversionResult", "1000 mm", 3000);
            verify(field("from").activeFocus);
        }
        function test_empty_invalid_and_custom_units_recover_without_stale_copy() {
            field("value").text = "";
            compare(calculator.conversionResult, "");
            verify(!field("copy").enabled);
            calculator.setCategory(calculator.conversionGroups.length - 1);
            calculator.fromUnit = "not_a_unit";
            calculator.toUnit = "m";
            field("value").text = "1";
            tryVerify(() => calculator.conversionError.length > 0, 3000);
            compare(calculator.conversionResult, "");
            verify(!field("copy").enabled);
            calculator.fromUnit = "km";
            tryCompare(calculator, "conversionResult", "1000 m", 3000);
            compare(calculator.conversionError, "");
            calculator.backendDir = Quickshell.env("SPECTRUM_CALCULATOR_FAILED_DIR");
            calculator.convert();
            compare(calculator.conversionResult, "");
            verify(!field("copy").enabled);
            tryVerify(() => calculator.conversionError.length > 0, 3000);
            verify(!field("copy").enabled);
            calculator.backendDir = Quickshell.env("SPECTRUM_CALCULATOR_TEST_DIR");
        }
        function test_arithmetic_answer_history_and_input_survive_conversions() {
            calculator.advanced = false;
            const input = findChild(calculator, "calculator-input");
            input.text = "12 + 30";
            calculator.evaluate();
            tryCompare(calculator, "result", "42", 3000);
            tryCompare(calculator, "busy", false, 3000);
            const historyLength = calculator.history.length;
            input.text = "7 + 8";
            calculator.advanced = true;
            tryCompare(calculator, "conversionResult", "100 cm", 3000);
            compare(calculator.result, "42");
            compare(calculator.history.length, historyLength);
            compare(input.text, "7 + 8");
        }
    }
}
