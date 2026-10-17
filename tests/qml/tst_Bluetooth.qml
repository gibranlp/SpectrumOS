import QtQuick
import QtQuick.Window
import QtTest
import Quickshell.Bluetooth
import "../../configs/spectrum-shell" as Shell

Item {
    id: scene
    width: 600
    height: 850
    QtObject {
        id: theme
        property var colors: ({ accent: "#eaaac3", background: "#151515", surface_alt: "#343638", foreground: "#ffffff", muted: "#aaaaaa" })
        property string fontFamily: "sans-serif"
        property int fontSize: 16
        property var command: []
        function runAction(args): void { command = args; }
    }
    QtObject {
        id: device
        property string name: "Test headphones"
        property string address: "00:11:22:33:44:55"
        property bool paired: true
        property bool connected: false
        property bool pairing: false
        property bool trusted: false
        property bool batteryAvailable: true
        property real battery: 0.6
        property int state: BluetoothDeviceState.Disconnected
        property string action: ""
        function connect(): void { action = "connect"; }
        function disconnect(): void { action = "disconnect"; }
        function pair(): void { action = "pair"; }
        function cancelPair(): void { action = "cancelPair"; }
        function forget(): void { action = "forget"; }
    }
    QtObject {
        id: adapter
        property string name: "Test adapter"
        property bool enabled: true
        property int state: BluetoothAdapterState.Enabled
        property bool discovering: false
        property var devices: [device]
    }
    Shell.BluetoothWidgetContent { id: content; width: 396; theme: theme; adapter: adapter }
    TestCase {
        name: "Bluetooth"
        onCompletedChanged: {
            if (completed) console.log("Bluetooth interaction checks:", qtest_results.passCount, "passed,", qtest_results.failCount, "failed");
        }
        when: windowShown || (scene.Window.window !== null && scene.Window.window.visible)
        function init() {
            content.adapter = adapter;
            content.active = true;
            content.forgetTarget = null;
            adapter.enabled = true;
            adapter.state = BluetoothAdapterState.Enabled;
            adapter.discovering = false;
            device.paired = true;
            device.connected = false;
            device.pairing = false;
            device.trusted = false;
            device.state = BluetoothDeviceState.Disconnected;
            device.action = "";
            theme.command = [];
            wait(20);
        }
        function click(name) {
            const button = findChild(content, name);
            verify(button !== null);
            verify(button.enabled);
            mouseClick(button, button.width / 2, button.height / 2);
        }
        function test_powerAndScan() {
            click("bluetoothScan");
            verify(adapter.discovering);
            click("bluetoothPower");
            verify(!adapter.enabled);
            verify(!adapter.discovering);
            verify(!findChild(content, "bluetoothScan").enabled);
            compare(findChild(content, "bluetoothPower").label, "Turn on");
            click("bluetoothPower");
            verify(adapter.enabled);
        }
        function test_missingOrBlockedAdapter() {
            content.adapter = null;
            verify(!findChild(content, "bluetoothPower").enabled);
            verify(!findChild(content, "bluetoothScan").enabled);
            content.adapter = adapter;
            adapter.state = BluetoothAdapterState.Blocked;
            verify(!findChild(content, "bluetoothPower").enabled);
        }
        function test_deviceLifecycle() {
            click("bluetoothConnect"); compare(device.action, "connect");
            device.connected = true;
            click("bluetoothConnect"); compare(device.action, "disconnect");
            device.connected = false; device.paired = false;
            click("bluetoothConnect"); compare(device.action, "pair");
            device.pairing = true;
            click("bluetoothConnect"); compare(device.action, "cancelPair");
        }
        function test_trustAndConfirmedForget() {
            click("bluetoothTrust"); verify(device.trusted);
            click("bluetoothTrust"); verify(!device.trusted);
            click("bluetoothForget");
            compare(content.forgetTarget, device);
            compare(device.action, "");
            wait(20);
            click("bluetoothConfirmForget");
            compare(device.action, "forget");
            compare(content.forgetTarget, null);
        }
        function test_closingStopsDiscovery() {
            adapter.discovering = true;
            content.active = false;
            verify(!adapter.discovering);
        }
        function test_settingsLaunchesBlueman() {
            click("bluetoothSettings");
            compare(theme.command.join(" "), "uwsm app -- blueman-manager");
        }
    }
}
