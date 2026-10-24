import QtQuick
import QtTest
import Quickshell
import "../../configs/spectrum-shell" as Shell

Scope {
    QtObject {
        id: theme
        property var colors: ({surface: "#222222", surface_alt: "#333333", background: "#111111", foreground: "#eeeeee", muted: "#aaaaaa", accent: "#66ccee"})
        property string fontFamily: "sans-serif"
        property int fontSize: 14
        property bool animationsEnabled: false
        property bool widgetBounceEnabled: false
        property bool gamingActive: false
    }
    Shell.Launcher { id: launcher; theme: theme }
    TestCase {
        name: "LauncherCatalog"
        when: true
        onCompletedChanged: if (completed) {
            console.log("Launcher catalog:", qtest_results.passCount, "passed", qtest_results.failCount, "failed");
            Qt.quit();
        }
        function test_launch_command_preserves_arguments_and_captures_before_delay() {
            const command = Shell.ApplicationLaunch.dispatchCommand(["uwsm", "app", "--", "a'b $HOME `id` ]=] é.desktop"], 380);
            verify(command.startsWith("hl.dsp.exec_cmd([==[sleep 0.380; exec "));
            verify(command.includes("'a'\\''b $HOME `id` ]=] é.desktop'"));
            verify(command.endsWith("]==])"));
        }
        function test_removal_updates_open_launcher_and_unchanged_catalog_is_stable() {
            compare(launcher.applicationEntries.length, 0);
            launcher.expanded = true;
            tryVerify(() => launcher.applicationEntries.some(entry => entry.id === "spectrum-launcher-fixture"), 4000);
            const previous = launcher.applicationEntries;
            wait(2300);
            verify(launcher.applicationEntries === previous);
            Quickshell.execDetached(["/usr/bin/rm", "--", Quickshell.env("SPECTRUM_LAUNCHER_TEST_ENTRY")]);
            tryVerify(() => !launcher.applicationEntries.some(entry => entry.id === "spectrum-launcher-fixture"), 4000);
            launcher.expanded = false;
        }
    }
}
