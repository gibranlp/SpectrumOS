import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

TestCase {
    id: tests
    name: "AppImages"
    width: 560; height: 650
    visible: true
    when: windowShown
    QtObject {
        id: theme
        property var colors: ({foreground: "#eeeeee", surface_alt: "#333333", muted: "#aaaaaa", accent: "#66ccee"})
        property string fontFamily: "sans-serif"
        property int fontSize: 14
        function backend(name) { return "/usr/lib/spectrumos/" + name; }
    }
    QtObject {
        id: manager
        property var applications: []
        property bool busy: false
        property string error: ""
        property string message: ""
        property var commands: []
        function run(args) { commands = commands.concat([args]); }
    }
    Shell.AppImageWidgetContent { id: content; width: 530; theme: theme; manager: manager }
    function init() {
        content.active = false;
        manager.busy = false;
        manager.error = ""; manager.message = ""; manager.commands = [];
        manager.applications = [];
        wait(10);
    }
    function test_emptyAndRefresh() {
        verify(findChild(content, "appimage-empty").visible);
        content.active = true;
        compare(manager.commands[0], ["status"]);
    }
    function test_addAndFolder() {
        mouseClick(findChild(content, "appimage-add"));
        compare(manager.commands[0], ["choose-add"]);
        mouseClick(findChild(content, "appimage-folder"));
        compare(manager.commands[1], ["folder"]);
    }
    function test_applicationActions() {
        manager.applications = [{id: "fixture", name: "Fixture App", icon: "application-x-executable", size: 2000000}];
        wait(10);
        verify(!findChild(content, "appimage-empty").visible);
        mouseClick(findChild(content, "appimage-launch-fixture"));
        mouseClick(findChild(content, "appimage-replace-fixture"));
        mouseClick(findChild(content, "appimage-remove-fixture"));
        compare(manager.commands, [["launch", "fixture"], ["choose-replace", "fixture"], ["remove", "fixture"]]);
    }
    function test_busyPreventsDuplicateOperations() {
        manager.busy = true;
        verify(!findChild(content, "appimage-add").enabled);
        verify(!findChild(content, "appimage-folder").enabled);
        verify(content.busy);
    }
    function test_feedback() {
        manager.error = "Choose a modern AppImage.";
        compare(findChild(content, "appimage-feedback").text, manager.error);
        manager.error = "";
        manager.message = "AppImage added to the launcher.";
        compare(findChild(content, "appimage-feedback").text, manager.message);
    }
}
