import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

TestCase {
    id: tests
    name: "NotificationToastSizing"
    width: 420; height: 700
    visible: true
    when: windowShown
    QtObject {
        id: theme
        property var colors: ({surface:"#222222",surface_alt:"#333333",foreground:"#eeeeee",muted:"#aaaaaa",accent:"#66ccee"})
        property string fontFamily: "sans-serif"
        property int fontSize: 14
        property bool animationsEnabled: false
        property bool widgetBounceEnabled: false
    }
    Shell.NotificationToast {
        id: toast
        width: 350
        theme: theme
        presented: true
        notification: ({appName:"Example",summary:"Update",body:"Short message",actionsJson:"[]"})
    }
    SignalSpy { id: dismissed; target: toast; signalName: "dismissed" }
    function init() { theme.animationsEnabled=false; toast.revealed=true; toast.exitProgress=0; dismissed.clear(); }
    function test_exit_slides_right_before_dismissal() {
        theme.animationsEnabled=true;
        wait(450);
        toast.revealed=false;
        wait(100);
        verify(toast.exitProgress>0 && toast.exitProgress<1);
        verify(toast.transform[0].x>0);
        compare(dismissed.count,0);
        tryCompare(dismissed,"count",1,500);
        compare(toast.exitProgress,1);
    }
    function test_height_grows_with_content() {
        toast.maximumHeight=520;
        toast.notification={appName:"Example",summary:"Update",body:"Short message",actionsJson:"[]"};
        waitForRendering(toast);
        const shortHeight=toast.height;
        toast.notification={appName:"Example",summary:"Update",body:"Details about the operation and its result. ".repeat(15),actionsJson:"[]"};
        waitForRendering(toast);
        verify(toast.height>shortHeight+50);
        verify(toast.height<=520);
    }
    function test_long_content_is_scrollable_without_truncation() {
        toast.maximumHeight=220;
        toast.notification={appName:"Example",summary:"Update",body:"A long message containing all the details. ".repeat(100),actionsJson:"[]"};
        waitForRendering(toast);
        compare(toast.height,220);
        const viewport=toast.children.find(item=>item.contentHeight!==undefined && item.flickableDirection!==undefined);
        verify(viewport!==undefined);
        verify(viewport.contentHeight>viewport.height);
        viewport.contentY=viewport.contentHeight-viewport.height;
        verify(viewport.contentY>0);
    }
}
