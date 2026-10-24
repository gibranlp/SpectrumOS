import QtQuick
import QtTest
import Quickshell
import Quickshell.Wayland
import "../../configs/spectrum-shell" as Shell

Scope {
    QtObject { id: window }
    Shell.ShellFocus { id: controller; window: window; enabled: false; active: false }
    TestCase {
        name: "ShellFocus"
        when: true
        onCompletedChanged: if (completed) {
            console.log("Shell focus:", qtest_results.passCount, "passed", qtest_results.failCount, "failed");
            Qt.quit();
        }
        function init() { controller.enabled = false; controller.active = false; }
        function test_open_releases_game_lock_then_allows_bar_input() {
            compare(controller.mode, WlrKeyboardFocus.None);
            controller.enabled = true;
            compare(controller.mode, WlrKeyboardFocus.Exclusive);
            controller.active = true;
            tryCompare(controller, "mode", WlrKeyboardFocus.OnDemand);
            controller.active = false;
            wait(10);
            compare(controller.mode, WlrKeyboardFocus.OnDemand);
        }
        function test_closing_before_activation_cancels_acquisition() {
            controller.enabled = true;
            controller.enabled = false;
            controller.active = true;
            wait(10);
            compare(controller.mode, WlrKeyboardFocus.None);
            verify(!controller.acquiring);
        }
        function test_portal_handoff_and_reopen() {
            controller.enabled = true;
            controller.active = true;
            tryCompare(controller, "mode", WlrKeyboardFocus.OnDemand);
            controller.enabled = false;
            controller.active = false;
            compare(controller.mode, WlrKeyboardFocus.None);
            controller.enabled = true;
            compare(controller.mode, WlrKeyboardFocus.Exclusive);
        }
        function test_already_active_does_not_grab() {
            controller.active = true;
            controller.enabled = true;
            compare(controller.mode, WlrKeyboardFocus.OnDemand);
        }
        function test_close_cancels_pending_release() {
            controller.enabled = true;
            controller.active = true;
            controller.enabled = false;
            wait(10);
            compare(controller.mode, WlrKeyboardFocus.None);
        }
    }
}
