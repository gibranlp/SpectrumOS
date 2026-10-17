import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

TestCase {
    name: "WidgetAction"
    visible: true
    width: 200; height: 140
    when: windowShown
    QtObject {
        id: theme
        property var colors: ({foreground:"#eeeeee",surface_alt:"#333333",accent:"#66ccee"})
        property string fontFamily: "monospace"
        property int fontSize: 12
    }
    Shell.WidgetAction { id: tile; theme: theme; icon: "▶"; label: "Start" }
    SignalSpy { id: clicked; target: tile; signalName: "clicked" }
    function init() { clicked.clear(); tile.enabled=true; tile.active=false; }
    function test_disabled_does_not_activate() {
        tile.enabled=false;
        mouseClick(tile,tile.width/2,tile.height/2);
        compare(clicked.count,0);
    }
    function test_keyboard_and_theme() {
        const action=tile.children.find(child => child.highlightEnabled !== undefined);
        verify(action !== undefined);
        action.forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(clicked.count,1);
        tile.active=true;
        verify(tile.color.valid);
        compare(tile.Accessible.name,"Start");
    }
}
