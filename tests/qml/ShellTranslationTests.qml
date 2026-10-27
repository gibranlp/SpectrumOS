import QtQuick
import QtTest
import Quickshell
import Spectrum.I18n 1.0
import "../../configs/spectrum-shell" as Shell

Scope {
    TestCase {
        id: test
        name: "ShellTranslations"
        when: true
        width: 420
        height: 800
        property var theme: ({fontFamily: "monospace", fontSize: 13, idle: {active: false},
            colors: {background: "#111111", surface: "#222222", surface_alt: "#333333", foreground: "#eeeeee", muted: "#aaaaaa", accent: "#66ccee"}})
        onCompletedChanged: if (completed) {
            console.log("Shell translations:", qtest_results.passCount, "passed", qtest_results.failCount, "failed");
            Qt.quit();
        }
        Shell.WidgetIcons { id: icons; theme: test.theme; width: 400; height: 40 }
        Shell.BarExtras { id: extras; theme: test.theme; window: null; width: 400 }
        Shell.FocusChoice { id: priority; theme: test.theme; translateModel: true; model: ["Low", "Medium", "High"]; currentIndex: 1 }
        Shell.FocusChoice { id: personal; theme: test.theme; model: ["Home", "High"]; currentIndex: 1 }
        Shell.Calculator { id: calculator; theme: test.theme; backendDir: "/nonexistent"; width: 400 }
        Component { id: lateIcons; Shell.WidgetIcons { theme: test.theme; width: 400; height: 40 } }
        function init() { verify(Translator.selectLanguage("en_US")); wait(60); }
        function cleanup() { verify(Translator.selectLanguage("en_US")); wait(60); }
        function iconLabel(action) { return icons.widgets.find(item => item.action === action).label; }
        function test_live_labels_and_actions_in_both_orientations() {
            const identifiers = JSON.stringify(icons.widgets.map(item => item.action));
            for (const vertical of [false, true]) {
                icons.vertical = vertical;
                verify(Translator.selectLanguage("es_MX"));
                wait(80);
                compare(iconLabel("wallpapers"), "Fondos de pantalla");
                compare(iconLabel("focus"), "Temporizador de enfoque");
                compare(extras.actions.find(item => item.action === "control").label, "Centro de control");
                verify(Translator.selectLanguage("pt_BR"));
                wait(80);
                compare(iconLabel("wallpapers"), "Papéis de parede");
                compare(iconLabel("focus"), "Temporizador de foco");
                compare(JSON.stringify(icons.widgets.map(item => item.action)), identifiers);
            }
        }
        function test_model_values_and_personal_names_do_not_change() {
            verify(Translator.selectLanguage("es_MX"));
            wait(80);
            compare(priority.displayText, "Media");
            compare(priority.currentText, "Medium");
            compare(personal.displayText, "High");
            verify(Translator.selectLanguage("pt_BR"));
            wait(80);
            compare(priority.displayText, "Média");
            compare(priority.currentIndex, 1);
        }
        function test_calculator_state_and_input_survive_translation() {
            calculator.result = "12081.1796";
            calculator.history = [{result: "12081.1796", unit: ""}];
            const input = findChild(calculator, "calculator-input");
            input.text = "10414.81*1.16";
            verify(Translator.selectLanguage("es_MX"));
            wait(80);
            compare(input.text, "10414.81*1.16");
            compare(calculator.result, "12081.1796");
            compare(calculator.history.length, 1);
        }
        function test_later_widgets_and_context_specific_translations() {
            verify(Translator.selectLanguage("es_MX"));
            wait(80);
            const later = lateIcons.createObject(test);
            compare(later.widgets.find(item => item.action === "favorites").label, "Favoritos");
            compare(qsTranslate("Spectrum", "Clear"), "Limpiar");
            compare(qsTranslate("Weather", "Clear"), "Despejado");
            later.destroy();
        }
        function test_plural_forms_include_portuguese_zero() {
            verify(Translator.selectLanguage("pt_BR"));
            wait(80);
            compare(qsTranslate("Spectrum", "Sharing text · %n computer", "", 0), "Compartilhando texto · 0 computador");
            compare(qsTranslate("Spectrum", "Sharing text · %n computer", "", 2), "Compartilhando texto · 2 computadores");
        }
    }
}
