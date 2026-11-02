import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Item {
    width: 800
    height: 600
    Shell.IgorBridge {
        id: bridge
        runtimeSource: "../../tests/fixtures/igor-runtime/Compatible.qml"
        available: true
        monitorNames: ["DP-1", "HDMI-A-1"]
    }
    TestCase {
        name: "IgorBridge"
        when: windowShown
        function init() {
            bridge.runtimeSource = "../../tests/fixtures/igor-runtime/Compatible.qml";
            tryCompare(bridge, "runtimeReady", true);
            bridge.visitsEnabled = true;
            bridge.playing = false;
            bridge.meeting = false;
            bridge.blockedMonitors = [];
        }
        function cleanup() { bridge.visitsEnabled = false; bridge.retreat(); }
        function test_free_runtime_receives_host_state() {
            bridge.playing = true;
            bridge.mediaKind = "music";
            verify(bridge.musicPlaying);
            bridge.meeting = true;
            verify(!bridge.musicPlaying);
            bridge.meeting = false;
            bridge.mediaKind = "video";
            verify(bridge.watching);
            verify(bridge.appear("right", "HDMI-A-1"));
            compare(bridge.selectedMonitor, "HDMI-A-1");
            compare(bridge.edge, "right");
        }
        function test_missing_runtime_is_a_safe_disabled_companion() {
            bridge.runtimeSource = "../../tests/fixtures/igor-runtime/Absent.qml";
            tryCompare(bridge, "runtimeReady", false);
            verify(!bridge.greet());
            verify(!bridge.appear("bottom"));
            verify(!bridge.celebrate());
            verify(!bridge.nap());
            verify(!bridge.visiting);
            bridge.retreat();
            compare(bridge.celebrationMessage, "");
        }
        function test_incompatible_runtime_is_not_activated() {
            bridge.runtimeSource = "../../tests/fixtures/igor-runtime/Incompatible.qml";
            tryCompare(bridge, "runtimeReady", false);
            verify(!bridge.greet());
            verify(!bridge.visiting);
        }
    }
}
