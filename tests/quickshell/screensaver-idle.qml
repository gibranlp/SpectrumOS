import QtQuick
import Quickshell
import "." as Shell

ShellRoot {
    id: test
    property int stage: 0
    property var previousMonitor: null
    Shell.ScreensaverIdleMonitor { id: monitor }
    function check(condition, message): void {
        if (!condition) {
            console.error(message);
            Qt.exit(1);
        }
    }
    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: {
            if (test.stage === 0) {
                monitor.monitoring = true;
            } else if (test.stage === 1) {
                test.check(monitor.item && monitor.item.timeout === 180, "Initial timeout was not armed");
                test.previousMonitor = monitor.item;
                monitor.timeout = 1;
            } else if (test.stage === 2) {
                test.check(monitor.item && monitor.item !== test.previousMonitor, "Timeout change reused the native monitor");
                test.check(monitor.item.timeout === 1, "Saved timeout was not armed");
            } else if (test.stage === 10) {
                test.check(monitor.isIdle, "Fresh monitor did not propagate the compositor idle event");
                monitor.monitoring = false;
                test.check(!monitor.item && !monitor.isIdle, "Blocked monitor retained idle state");
                monitor.timeout = 2;
            } else if (test.stage === 11) {
                test.check(!monitor.item, "Disabled timeout change armed a monitor");
                monitor.monitoring = true;
            } else if (test.stage === 12) {
                test.check(monitor.item && monitor.item.timeout === 2, "Unblocking did not create a new monitor");
                test.check(!monitor.isIdle, "Unblocking did not restart the idle wait");
            } else if (test.stage === 24) {
                test.check(monitor.isIdle, "Reenabled monitor did not propagate idle");
                console.log("PASS: timeout replacement, idle propagation, blocking, and rearming");
                Qt.quit();
            }
            test.stage += 1;
        }
    }
}
