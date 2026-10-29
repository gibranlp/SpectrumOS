import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

TestCase {
    id: tests
    name: "BarExtras"
    visible: true
    width: 440; height: 1400
    when: windowShown
    QtObject {
        id: theme
        property var colors: ({foreground:"#eeeeee",surface_alt:"#333333",accent:"#66ccee",muted:"#aaaaaa"})
        property string fontFamily: "monospace"
        property int fontSize: 12
    }
    Shell.BarExtras { id: extras; width: parent.width; theme: theme; window: null }
    SignalSpy { id: chosen; target: extras; signalName: "chosen" }
    function init() { extras.detailed = false; chosen.clear(); }
    function test_detailed_menu_preserves_secondary_widgets() {
        extras.detailed = true;
        const actions = extras.actions.map(item => item.action);
        for (const action of ["questline", "updates", "time", "screenshot", "recorder", "audio-recorder", "ukvm"])
            verify(actions.includes(action), action + " must remain available in More");
        for (const action of ["favorites", "breaks", "brightness", "weather", "keep-awake", "audio", "battery", "displays", "typography", "network", "bluetooth", "notifications"])
            verify(!actions.includes(action), action + " stays on the bar");
        compare(new Set(actions).size, actions.length);
        waitForRendering(extras);
        const button = findChild(extras, "bar-extra-dashboard");
        mouseClick(button, button.width / 2, button.height / 2);
        compare(chosen.signalArguments[0][0], "dashboard");
    }
    function test_actions_data() {
        return ["spectrumdrop", "appimages", "time", "brightness", "displays", "mouse", "typography", "control", "session"].map(action => ({tag:action, action:action}));
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
