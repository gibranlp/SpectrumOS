import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Item {
    width: 360
    height: 260
    Shell.ShellSurface {
        id: surface
        anchors.fill: parent
        focus: true
        Flickable {
            id: scroll
            width: 300
            height: 100
            contentHeight: 500
            Column {
                visible: !directionGrid.visible
                width: 280
                Shell.ShellButton { id: first; label: "First"; onClicked: tests.activations++ }
                Shell.ShellButton { label: "Disabled"; enabled: false; onClicked: tests.activations += 100 }
                Shell.ShellButton { label: "Hidden"; visible: false; onClicked: tests.activations += 100 }
                Item { width: 280; height: 260 }
                Shell.ShellButton { id: last; label: "Last"; onClicked: tests.activations++ }
            }
            Item {
                id: directionGrid
                visible: false
                width: 280
                height: 450
                Shell.ShellButton { id: topLeft; x: 0; y: 0; label: "A"; onClicked: tests.activations++ }
                Shell.ShellButton { x: 70; y: 0; label: "Disabled"; enabled: false }
                Shell.ShellButton { x: 90; y: 0; label: "Hidden"; visible: false }
                Shell.ShellButton { id: topRight; x: 180; y: 0; label: "B"; onClicked: tests.activations++ }
                Shell.ShellButton { id: bottomLeft; x: 0; y: 340; label: "C"; onClicked: tests.activations++ }
                Shell.ShellButton { id: bottomRight; x: 180; y: 340; label: "D"; onClicked: tests.activations++ }
            }
        }
    }
    TestCase {
        id: tests
        name: "KeyboardNavigation"
        when: windowShown
        property int activations: 0
        function init() { directionGrid.visible = false; activations = 0; scroll.contentY = 0; surface.forceActiveFocus(); }
        function test_arrowsFollowRowsAndColumnsAndScroll() {
            directionGrid.visible = true;
            keyClick(Qt.Key_Down);
            verify(topLeft.children[1].activeFocus);
            keyClick(Qt.Key_Right);
            verify(topRight.children[1].activeFocus);
            keyClick(Qt.Key_Down);
            verify(bottomRight.children[1].activeFocus);
            verify(scroll.contentY > 200);
            keyClick(Qt.Key_Left);
            verify(bottomLeft.children[1].activeFocus);
            keyClick(Qt.Key_Up);
            verify(topLeft.children[1].activeFocus);
            compare(scroll.contentY, 0);
            compare(activations, 0);
        }
        function test_tabSkipsDisabledAndHiddenAndWraps() {
            keyClick(Qt.Key_Tab);
            verify(first.children[1].activeFocus);
            keyClick(Qt.Key_Tab);
            verify(last.children[1].activeFocus);
            verify(scroll.contentY > 200);
            keyClick(Qt.Key_Tab);
            verify(first.children[1].activeFocus);
            compare(scroll.contentY, 0);
            keyClick(Qt.Key_Tab, Qt.ShiftModifier);
            verify(last.children[1].activeFocus);
        }
        function test_keyboardActivatesOnce() {
            keyClick(Qt.Key_Tab);
            keyClick(Qt.Key_Return);
            compare(activations, 1);
            keyClick(Qt.Key_Enter);
            compare(activations, 2);
            keyClick(Qt.Key_Space);
            compare(activations, 3);
        }
    }
}
