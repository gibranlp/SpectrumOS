import QtQuick
import QtQuick.Controls
import QtTest
import "../../configs/spectrum-shell" as Shell

Item {
    width: 440; height: 500
    QtObject {
        id: theme
        property var colors: ({foreground: "#eeeeee", background: "#111111", surface_alt: "#333333", accent: "#66ccee", muted: "#aaaaaa"})
        property string fontFamily: "sans-serif"
        property int fontSize: 14
        property bool actionBusy: false
        property var brightness: ({devices: [], error: ""})
        property bool brightnessBusy: false
        property string brightnessActionError: ""
        property var commands: []
        function changeBrightness(operation, device) { commands = commands.concat([[operation, device]]); }
        function backend(name) { return "/usr/lib/spectrumos/" + name; }
        function runAction(command) { commands = commands.concat([command]); }
    }
    Shell.AudioDeviceControl {
        id: audio
        y: 100; width: 400; theme: theme
        device: ({id: 17, label: "Headset", default: false, volume_percent: 42, volume: "42%", muted: false})
    }
    Shell.ConnectionIpControl {
        id: network
        y: 240; width: 400; theme: theme
        profile: ({uuid: "profile-uuid", name: "Work", type: "wifi", ipv4_enabled: true, ipv6_enabled: true})
    }
    Shell.BrightnessControls { id: brightnessControls; y: 350; width: 400; theme: theme }
    TextField { id: entry; width: 200; Keys.onEscapePressed: event => event.accepted = true }
    Shell.EscapeDismissal { id: dismissal; active: false; onDismissed: tests.dismissals++ }
    TestCase {
        id: tests
        name: "DeviceControls"
        when: windowShown
        property int dismissals: 0
        function init() {
            theme.commands = []; theme.actionBusy = false; theme.brightnessBusy = false;
            theme.brightness = {devices: [{id: "backlight:apple", name: "apple_backlight", available: true, percent: 50, error: ""}], error: ""}; dismissals = 0; dismissal.active = false;
            audio.output = true;
            network.profile = {uuid: "profile-uuid", name: "Work", type: "wifi", ipv4_enabled: true, ipv6_enabled: true};
        }
        function test_brightnessReadbackAndTarget() {
            const label = findChild(brightnessControls, "brightness-value-backlight:apple");
            verify(label.text.endsWith("50%"));
            mouseClick(findChild(brightnessControls, "brightness-up-backlight:apple"));
            compare(theme.commands[0], ["up", "backlight:apple"]);
            verify(label.text.endsWith("50%"));
            theme.brightness = {devices: [{id: "backlight:apple", name: "apple_backlight", available: true, percent: 55, error: ""}], error: ""};
            tryVerify(() => findChild(brightnessControls, "brightness-value-backlight:apple").text.endsWith("55%"));
        }
        function test_brightnessBusyAndUnavailable() {
            theme.brightnessBusy = true;
            verify(!findChild(brightnessControls, "brightness-down-backlight:apple").enabled);
            theme.brightnessBusy = false;
            theme.brightness = {devices: [{id: "ddc:monitor", name: "DP-1", available: false, percent: null, error: "Permission denied"}], error: ""};
            tryVerify(() => !!findChild(brightnessControls, "brightness-up-ddc:monitor"));
            verify(!findChild(brightnessControls, "brightness-up-ddc:monitor").enabled);
            verify(findChild(brightnessControls, "brightness-value-ddc:monitor").text.endsWith("Unavailable"));
        }
        function test_escapeFromTextInput() {
            dismissal.active = true; entry.forceActiveFocus(); keyClick(Qt.Key_Escape);
            compare(dismissals, 1);
        }
        function test_escapeFromSlider() {
            dismissal.active = true; findChild(audio, "device-volume").forceActiveFocus(); keyClick(Qt.Key_Escape);
            compare(dismissals, 1);
        }
        function test_inactiveEscape() {
            entry.forceActiveFocus(); keyClick(Qt.Key_Escape); compare(dismissals, 0);
        }
        function test_deviceVolumeKeepsDefault() {
            const slider = findChild(audio, "device-volume");
            tryCompare(slider, "value", 42);
            slider.forceActiveFocus(); keyClick(Qt.Key_Right);
            compare(theme.commands.length, 1);
            compare(theme.commands[0], [theme.backend("control-adapter"), "audio", "output-volume", "17", "43"]);
        }
        function test_inputMuteTargetsDevice() {
            audio.output = false; mouseClick(findChild(audio, "device-mute"));
            compare(theme.commands[0], [theme.backend("control-adapter"), "audio", "input-mute", "17"]);
        }
        function test_protocolUsesBackendState() {
            const ipv6 = findChild(network, "connection-ipv6");
            mouseClick(ipv6);
            compare(theme.commands[0], [theme.backend("network-adapter"), "ip-family", "profile-uuid", "ipv6", "off"]);
            verify(ipv6.checked);
            network.profile = {uuid: "profile-uuid", name: "Work", type: "wifi", ipv4_enabled: true, ipv6_enabled: false};
            verify(!ipv6.checked);
            verify(!findChild(network, "connection-ipv4").enabled);
        }
        function test_busyPreventsEdits() {
            theme.actionBusy = true;
            verify(!findChild(audio, "device-volume").enabled);
            verify(!findChild(network, "connection-ipv6").enabled);
        }
        function test_unknownProtocolCannotBeChanged() {
            network.profile = {uuid: "profile-uuid", name: "Work", type: "wifi", ipv4_enabled: null, ipv6_enabled: null};
            verify(!findChild(network, "connection-ipv4").enabled);
            verify(!findChild(network, "connection-ipv6").enabled);
        }
    }
}
