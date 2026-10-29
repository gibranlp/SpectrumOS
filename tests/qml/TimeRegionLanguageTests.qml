import QtQuick
import QtTest
import Quickshell
import Spectrum.I18n 1.0
import "../../configs/spectrum-shell" as Shell

FloatingWindow {
    visible: true
    implicitWidth: 420
    implicitHeight: 1200
    TestCase {
        id: test
        name: "TimeRegionLanguage"
        width: 400
        height: 700
        visible: true
        when: true
        property var theme: ({fontFamily: "monospace", fontSize: 13,
            colors: {foreground: "#eeeeee", muted: "#aaaaaa", surface_alt: "#333333", accent: "#66ccee", error: "#ff8888"},
            backend: name => Quickshell.env("SPECTRUM_TIME_REGION_FIXTURE") + "/" + name})
        onCompletedChanged: if (completed) {
            console.log("Time & Region UI:", qtest_results.passCount, "passed", qtest_results.failCount, "failed");
            Qt.quit();
        }
        Shell.TimeRegionWidgetContent {
            id: editor
            width: test.width
            theme: test.theme
            active: true
        }
        Component {
            id: anotherEditor
            Shell.TimeRegionWidgetContent { theme: test.theme; width: test.width }
        }
        function init() {
            verify(Translator.selectLanguage("en_US"));
            editor.settings = {available: true, language: "en_US.UTF-8", region: "pt_BR.UTF-8", locales: [], timezones: []};
            editor.selectedLanguage = "";
            editor.selectedRegion = "";
            editor.picker = "";
            wait(80);
        }
        function test_language_switch_preserves_drafts_and_system_settings() {
            editor.selectedZone = "America/Cancun";
            editor.selectedLanguage = "es_MX.UTF-8";
            editor.selectedRegion = "en_US.UTF-8";
            editor.serversEdited = true;
            const servers = findChild(editor, "time-region-servers");
            servers.text = "private.example.org";
            editor.setInterfaceLanguage("es_MX");
            tryCompare(Translator, "language", "es_MX");
            wait(80);
            compare(qsTranslate("Spectrum", "System language"), "Idioma del sistema");
            compare(editor.selectedZone, "America/Cancun");
            compare(editor.selectedLanguage, "es_MX.UTF-8");
            compare(editor.selectedRegion, "en_US.UTF-8");
            compare(servers.text, "private.example.org");
            compare(editor.settings.region, "pt_BR.UTF-8");
            verify(!editor.busy);
        }
        function test_shared_and_new_widgets_use_the_same_language() {
            const other = anotherEditor.createObject(test);
            verify(other !== null);
            editor.setInterfaceLanguage("pt_BR");
            tryCompare(other, "interfaceLanguage", "pt_BR");
            wait(80);
            compare(qsTranslate("Spectrum", "System language"), "Idioma do sistema");
            compare(findChild(other, "interface-language").label, "Português (Brasil)");
            other.destroy();
            const reopened = anotherEditor.createObject(test);
            compare(reopened.interfaceLanguage, "pt_BR");
            reopened.destroy();
        }
        function test_follow_system_and_region_remain_independent() {
            editor.setInterfaceLanguage("system");
            tryCompare(Translator, "language", "es_MX");
            compare(Translator.region, "pt_BR");
            wait(80);
            compare(findChild(editor, "interface-language").label, "Seguir el idioma del sistema");
            editor.setInterfaceLanguage("en_US");
            compare(Translator.region, "pt_BR");
        }
        function test_interface_selector_works_without_system_helper() {
            editor.settings = {available: false};
            verify(findChild(editor, "interface-language").enabled);
            editor.setInterfaceLanguage("pt_BR");
            tryCompare(Translator, "language", "pt_BR");
        }
        function test_invalid_selection_preserves_language_and_reports_failure() {
            editor.setInterfaceLanguage("invalid");
            compare(Translator.language, "en_US");
            verify(editor.error.length > 0);
        }
        function test_interface_search_uses_native_names() {
            editor.choose("interface");
            findChild(editor, "time-region-search").text = "Português";
            const choices = findChild(editor, "time-region-choices");
            tryCompare(choices, "count", 1);
            compare(choices.model[0], "pt_BR");
        }
        function test_picker_opens_beside_its_setting_data() {
            return [
                {tag:"timezone", kind:"timezone", button:"timezone-selector"},
                {tag:"interface", kind:"interface", button:"interface-language"},
                {tag:"language", kind:"language", button:"system-language-selector"},
                {tag:"region", kind:"region", button:"region-selector"}
            ];
        }
        function test_picker_opens_beside_its_setting(data) {
            editor.settings = {available:true, timezones:["America/Cancun", "Europe/London"], locales:["en_US.UTF-8", "es_MX.UTF-8"]};
            const button = findChild(editor, data.button);
            button.clicked();
            tryCompare(editor, "picker", data.kind);
            wait(60);
            const selector = findChild(editor, "time-region-picker-" + data.kind);
            verify(selector.visible);
            const buttonBottom = button.mapToItem(editor, 0, button.height).y;
            verify(selector.y >= buttonBottom);
            verify(selector.y - buttonBottom <= editor.spacing + 1, "The list must appear directly below its own setting");
            for (const other of ["timezone", "interface", "language", "region"])
                compare(findChild(editor, "time-region-picker-" + other).visible, other === data.kind);
            findChild(editor, "time-region-search").text = "no matching choice";
            editor.choose(data.kind);
            verify(!selector.visible);
            editor.choose(data.kind);
            compare(findChild(editor, "time-region-search").text, "");
        }
        function test_timezone_selection_keeps_the_apply_step() {
            editor.settings = {available:true, timezones:["America/Cancun"], locales:[]};
            editor.choose("timezone");
            const choices = findChild(editor, "time-region-choices");
            tryCompare(choices, "count", 1);
            wait(60);
            choices.itemAtIndex(0).clicked();
            compare(editor.selectedZone, "America/Cancun");
            compare(editor.picker, "");
            verify(!editor.busy);
        }
        function test_helper_result_uses_the_current_interface_language() {
            editor.setInterfaceLanguage("pt_BR");
            editor.message = "Time settings updated";
            wait(80);
            compare(findChild(editor, "time-region-message").text, "Configurações de hora atualizadas");
            verify(Translator.selectLanguage("es_MX"));
            wait(80);
            compare(findChild(editor, "time-region-message").text, "Se actualizó la configuración de hora");
        }
    }
}
