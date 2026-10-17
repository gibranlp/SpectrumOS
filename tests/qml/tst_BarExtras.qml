import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

TestCase {
    id: tests
    name: "BarExtras"
    visible: true
    width: 440; height: 600
    when: windowShown
    QtObject {
        id: theme
        property var colors: ({foreground:"#eeeeee",surface_alt:"#333333",accent:"#66ccee",muted:"#aaaaaa"})
        property string fontFamily: "monospace"
        property int fontSize: 12
    }
    Shell.BarExtras { id: extras; width: parent.width; theme: theme; window: null }
    SignalSpy { id: chosen; target: extras; signalName: "chosen" }
    function init() { chosen.clear(); }
    function test_actions_data() {
        return ["spectrumdrop", "appimages", "time", "battery", "displays", "mouse", "typography", "control", "session"].map(action => ({tag:action, action:action}));
    }
    function test_actions(data) {
        const button = findChild(extras, "bar-extra-" + data.action);
        verify(button !== null);
        verify(button.visible && button.enabled);
        verify(button.x >= 0 && button.x + button.width <= extras.width);
        mouseClick(button, button.width / 2, button.height / 2);
        compare(chosen.count, 1);
        compare(chosen.signalArguments[0][0], data.action);
    }
}
