import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Item {
    width: 240
    height: 140
    Shell.ShellButton { id: button; x: 40; y: 40; label: "Copy" }
    SignalSpy { id: clicked; target: button; signalName: "clicked" }
    TestCase {
        name: "ShellButton"
        when: windowShown
        function init() {
            button.enabled = true;
            button.animationsEnabled = true;
            clicked.clear();
            wait(220);
        }
        function test_mouse_press_has_visible_feedback_and_one_activation() {
            const resting = button.color.toString();
            mousePress(button, button.width / 2, button.height / 2);
            verify(button.pressed);
            wait(100);
            verify(button.scale < 1);
            verify(button.color.toString() !== resting);
            compare(clicked.count, 0);
            mouseRelease(button, button.width / 2, button.height / 2);
            compare(clicked.count, 1);
            verify(button.pressed);
            tryCompare(button, "pressed", false);
            tryCompare(button, "scale", 1);
        }
        function test_keyboard_press_and_focus_loss_release_feedback() {
            const action = button.children.find(child => child.activeFocusOnTab === true);
            verify(action !== undefined);
            action.forceActiveFocus();
            keyPress(Qt.Key_Space);
            verify(button.pressed);
            compare(clicked.count, 0);
            keyRelease(Qt.Key_Space);
            compare(clicked.count, 1);
            tryCompare(button, "pressed", false);
            keyPress(Qt.Key_Space);
            verify(button.pressed);
            action.focus = false;
            tryCompare(button, "pressed", false);
            keyRelease(Qt.Key_Space);
        }
        function test_disabled_button_does_not_activate() {
            button.enabled = false;
            mouseClick(button);
            verify(!button.pressed);
            compare(clicked.count, 0);
        }
        function test_reduced_motion_keeps_feedback_without_scaling() {
            button.animationsEnabled = false;
            const resting = button.color.toString();
            mousePress(button, button.width / 2, button.height / 2);
            verify(button.pressed);
            compare(button.scale, 1);
            verify(button.color.toString() !== resting);
            mouseRelease(button, button.width / 2, button.height / 2);
            compare(clicked.count, 1);
        }
    }
}
