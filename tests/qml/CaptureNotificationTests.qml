import QtQuick
import QtTest
import Quickshell
import "../../configs/spectrum-shell" as Shell

Scope {
    id: shell
    property var notificationHistory: []
    property var dismissedIds: []
    ListModel { id: toastModel }
    QtObject {
        id: notificationServer
        property var trackedNotifications: ({ values: [] })
    }
    function notification(id) {
        return { id: id, dismiss: () => { shell.dismissedIds = [...shell.dismissedIds, id]; } };
    }
    // NOTIFICATION_METHODS
    QtObject {
        id: theme
        property string barPosition: "top"
        property string barStyle: "islands"
        property var colors: ({surface: "#222222", surface_alt: "#333333", foreground: "#eeeeee", accent: "#66ccee"})
        property string fontFamily: "sans-serif"
        property int fontSize: 14
        property bool animationsEnabled: false
        property bool widgetBounceEnabled: false
    }
    Shell.ScreenshotPanel {
        id: panel
        theme: theme
        targetScreen: Quickshell.screens[0]
        implicitWidth: 900
        implicitHeight: 600
        expanded: true
        topInset: theme.barPosition === "top" ? 34 : 8
        leftInset: theme.barPosition === "left" ? 52 : 0
    }
    TestCase {
        name: "CaptureNotifications"
        when: true
        onCompletedChanged: if (completed) {
            console.log("Capture and notifications:", qtest_results.passCount, "passed", qtest_results.failCount, "failed");
            Qt.quit();
        }
        function init() {
            toastModel.clear();
            shell.dismissedIds = [];
            shell.notificationHistory = [{ summary: "saved" }];
            notificationServer.trackedNotifications = { values: [shell.notification(1), shell.notification(2), shell.notification(3)] };
        }
        function test_dismiss_targets_latest_visible_toast_even_with_newer_tracked_notification() {
            toastModel.append({ toastId: 10, notificationId: 1 });
            toastModel.append({ toastId: 11, notificationId: 2 });
            shell.dismissLatestNotification();
            compare(toastModel.count, 1);
            compare(toastModel.get(0).notificationId, 1);
            compare(shell.dismissedIds.join(","), "2");
            compare(shell.notificationHistory.length, 1);
        }
        function test_expired_server_notification_still_removes_toast() {
            toastModel.append({ toastId: 10, notificationId: 99 });
            shell.dismissLatestNotification();
            compare(toastModel.count, 0);
            compare(shell.dismissedIds.length, 0);
        }
        function test_no_toast_falls_back_to_latest_tracked() {
            shell.dismissLatestNotification();
            compare(shell.dismissedIds.join(","), "3");
            notificationServer.trackedNotifications = { values: [] };
            shell.dismissLatestNotification();
        }
        function test_clear_removes_toasts_tracked_notifications_and_history() {
            toastModel.append({ toastId: 10, notificationId: 1 });
            shell.clearNotifications();
            compare(toastModel.count, 0);
            compare(shell.dismissedIds.join(","), "1,2,3");
            compare(shell.notificationHistory.length, 0);
        }
        function test_capture_joins_top_left_for_both_positions_and_styles() {
            const card = findChild(panel.contentItem, "captureCard");
            verify(card);
            for (const position of ["top", "left"]) {
                for (const style of ["islands", "full"]) {
                    theme.barPosition = position;
                    theme.barStyle = style;
                    wait(30);
                    compare(card.attachTop, true);
                    compare(card.attachLeft, true);
                    compare(card.attachRight, false);
                    compare(card.x - card.leftAttachmentWidth, position === "left" && style === "full" ? 52 : 8);
                    compare(card.y - card.topAttachmentHeight, position === "top" && style === "full" ? 34 : 8);
                    verify(card.height >= 240);
                    verify(card.x + card.width < panel.width / 2);
                }
            }
        }
    }
}
