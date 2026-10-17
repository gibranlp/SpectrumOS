import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

TestCase {
    id: tests
    name: "DisplayScale"
    width: 500; height: 240
    visible: true
    when: windowShown
    QtObject {
        id: theme
        property var colors: ({foreground:"#eeeeee", background:"#111111", surface:"#222222", muted:"#aaaaaa", accent:"#66ccee"})
        property string fontFamily: "sans-serif"
        property int fontSize: 14
        property bool actionBusy: false
        property var commands: []
        function backend(name) { return "/usr/lib/spectrumos/" + name; }
        function runAction(command) { commands = commands.concat([command]); }
    }
    Shell.DisplayScaleControl { id: first; width: 480; theme: theme; monitorName: "DP-1"; currentScale: 1 }
    Shell.DisplayScaleControl { id: second; y: 100; width: 480; theme: theme; monitorName: "HDMI-A-1"; currentScale: 2 }
    function init() { theme.commands = []; theme.actionBusy = false; first.currentScale = 1; first.width = 480; }
    function test_each_preset_targets_its_monitor() {
        for (const scale of [1,1.5,1.75,2]) {
            mouseClick(findChild(first,"display-scale-DP-1-"+scale));
            compare(theme.commands[theme.commands.length-1], ["/usr/lib/spectrumos/control-adapter","display","scale","DP-1",String(scale)]);
        }
        mouseClick(findChild(second,"display-scale-HDMI-A-1-1.5"));
        compare(theme.commands[4], ["/usr/lib/spectrumos/control-adapter","display","scale","HDMI-A-1","1.5"]);
    }
    function test_selection_follows_monitor_readback() {
        const one = findChild(first,"display-scale-DP-1-1");
        const half = findChild(first,"display-scale-DP-1-1.5");
        verify(one.selected); verify(!half.selected);
        mouseClick(half);
        verify(one.selected); verify(!half.selected);
        first.currentScale = 1.5;
        verify(!one.selected); verify(half.selected);
        compare(half.backgroundColor,theme.colors.accent);
        verify(findChild(second,"display-scale-HDMI-A-1-2").selected);
    }
    function test_busy_disables_changes() {
        theme.actionBusy = true;
        const button = findChild(first,"display-scale-DP-1-2");
        verify(!button.enabled); mouseClick(button); compare(theme.commands.length,0);
    }
    function test_adjusted_scale_shows_actual_value() {
        first.currentScale = 1.6666666;
        compare(findChild(first,"display-scale-current-DP-1").text,"Scaling · current 1.67×");
        verify(!findChild(first,"display-scale-DP-1-1.75").selected);
    }
    function test_narrow_width_wraps_without_clipping() {
        first.width = 180;
        wait(30);
        const last = findChild(first,"display-scale-DP-1-2");
        verify(last.y > 0);
        verify(first.height >= last.mapToItem(first,0,last.height).y);
        verify(last.x + last.width <= first.width);
    }
}
