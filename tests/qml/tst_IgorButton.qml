import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Item {
    width: 200
    height: 100
    QtObject {
        id: theme
        property bool igorEnabled: false
        property var colors: ({accent:"#66ccee",surface_alt:"#333333"})
        property int wardrobeRequests: 0
        function openIgorWardrobe() { wardrobeRequests++; }
        function toggleIgor() { igorEnabled = !igorEnabled; }
    }
    Shell.IgorButton { id: button; theme: theme }
    TestCase {
        name: "IgorButton"
        when: windowShown
        function test_secondary_click_opens_wardrobe_without_toggling_visits() {
            theme.igorEnabled = false;
            theme.wardrobeRequests = 0;
            mouseClick(button,button.width/2,button.height/2,Qt.RightButton);
            compare(theme.wardrobeRequests,1);
            verify(!theme.igorEnabled);
        }
        function test_click_and_hover_keep_saved_toggle_behavior() {
            theme.igorEnabled = false;
            mouseMove(button,button.width/2,button.height/2);
            mouseClick(button);
            verify(theme.igorEnabled);
            mouseClick(button);
            verify(!theme.igorEnabled);
        }
    }
}
