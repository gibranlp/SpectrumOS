import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "." as Ukvm

Scope {
    id: scene
    readonly property string fixture: Quickshell.env("SPECTRUM_UKVM_THEME_FIXTURE")
    Process { id: writer }
    Ukvm.UkvmTheme {
        id: theme
        palettePath: scene.fixture + "/current/palette.json"
        fontPath: scene.fixture + "/current/kitty.conf"
    }
    FloatingWindow {
        visible: true
        implicitWidth: 400
        implicitHeight: 200
        Rectangle { anchors.fill: parent; color: theme.colors.surface }
        TestCase {
            name: "UkvmTheme"
            when: true
            onCompletedChanged: if (completed) {
                console.log("UKVM theme checks:", qtest_results.passCount, "passed,", qtest_results.failCount, "failed");
                Qt.quit();
            }
            function activateGeneration(name) {
                writer.exec(["python3", scene.fixture + "/switch.py", name]);
                tryCompare(writer, "running", false);
            }
            function init() {
                theme.active = false;
                activateGeneration("first");
                theme.reload();
                tryVerify(() => theme.colors.surface === "#112233");
                tryCompare(theme, "fontFamily", "monospace");
                tryCompare(theme, "fontSize", 12);
            }
            function test_visible_widget_follows_repeated_generation_switches() {
                theme.active = true;
                for (const generation of ["second", "first", "second"]) {
                    activateGeneration(generation);
                    const second = generation === "second";
                    tryVerify(() => theme.colors.surface === (second ? "#554433" : "#112233"), 3500);
                    tryCompare(theme, "fontFamily", second ? "serif" : "monospace");
                    tryCompare(theme, "fontSize", second ? 20 : 12);
                }
            }
            function test_reopening_refreshes_hidden_widget() {
                activateGeneration("second");
                theme.active = true;
                tryVerify(() => theme.colors.surface === "#554433", 500);
                tryCompare(theme, "fontSize", 20);
            }
            function test_invalid_palette_preserves_previous_colors() {
                theme.active = true;
                activateGeneration("invalid");
                wait(1300);
                compare(theme.colors.surface, "#112233");
                activateGeneration("second");
                tryVerify(() => theme.colors.surface === "#554433", 3500);
            }
        }
    }
}
