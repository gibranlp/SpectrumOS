import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Item {
    width: 600
    height: 100
    Shell.ScrollingTitle {
        id: title
        width: 220
        height: 28
        centered: true
        autoScroll: true
        bold: true
    }
    TestCase {
        name: "MediaTitle"
        when: windowShown
        function init() { title.title = "Artist - Song"; }
        function test_shortTrackRemainsCentered() {
            wait(120);
            compare(title.scrollOffset, 0);
            const label = title.children[0].children[0];
            compare(label.horizontalAlignment, Text.AlignHCenter);
            compare(label.width, title.width);
        }
        function test_longTrackScrollsWithoutHoverAndResetsOnChange() {
            title.title = "Artist with a long name - A song title that exceeds the available space";
            tryVerify(() => title.scrollOffset > 0, 500);
            title.title = "New artist - New song";
            compare(title.scrollOffset, 0);
            wait(120);
            compare(title.scrollOffset, 0);
        }
    }
}
