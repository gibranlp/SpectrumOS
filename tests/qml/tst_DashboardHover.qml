import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

TestCase {
    id: tests
    name: "DashboardHover"
    width: 600
    height: 180
    visible: true
    when: windowShown
    Shell.DashboardHoverArea {
        id: hotspot
        x: 170
        width: 260
        height: 34
        onOpenRequested: dashboardOpen = true
    }
    Shell.ShellButton {
        id: control
        x: 280
        width: 40
        height: 28
        label: "⏵"
    }
    SignalSpy { id: opened; target: hotspot; signalName: "openRequested" }
    SignalSpy { id: clicked; target: control; signalName: "clicked" }
    function init() {
        mouseMove(tests,20,100);
        hotspot.enabled = true;
        hotspot.dashboardOpen = false;
        hotspot.height = 34;
        opened.clear();clicked.clear();
        wait(20);
    }
    function test_dwell_opens_once_per_entry() {
        mouseMove(hotspot,20,15);
        compare(opened.count,0);
        tryCompare(opened,"count",1,600);
        verify(hotspot.dashboardOpen);
        wait(240);compare(opened.count,1);
        hotspot.dashboardOpen=false;
        wait(240);compare(opened.count,1);
        mouseMove(tests,20,100);mouseMove(hotspot,20,15);
        tryCompare(opened,"count",2,600);
    }
    function test_short_hover_and_exit_cancel_opening() {
        mouseMove(hotspot,20,15);wait(50);
        mouseMove(tests,20,100);wait(240);
        compare(opened.count,0);
    }
    function test_open_or_disabled_target_does_not_trigger() {
        hotspot.dashboardOpen=true;
        mouseMove(hotspot,20,15);wait(240);compare(opened.count,0);
        mouseMove(tests,20,100);
        hotspot.dashboardOpen=false;
        hotspot.enabled=false;
        mouseMove(hotspot,20,15);wait(240);compare(opened.count,0);
    }
    function test_disabling_during_dwell_cancels_opening() {
        mouseMove(hotspot,20,15);wait(50);
        hotspot.enabled=false;wait(240);compare(opened.count,0);
    }
    function test_bar_button_stays_clickable_and_hoverable() {
        mouseMove(control,20,14);
        tryCompare(opened,"count",1,600);
        mouseClick(control,20,14);
        compare(clicked.count,1);
    }
    function test_edge_and_notch_heights_data() {
        return [{tag:"frame-edge",height:8,y:1},{tag:"multimedia-notch",height:34,y:20}];
    }
    function test_edge_and_notch_heights(data) {
        hotspot.height=data.height;
        mouseMove(hotspot,20,data.y);
        tryCompare(opened,"count",1,600);
    }
}
