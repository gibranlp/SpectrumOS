import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

ColumnLayout {
    id: content
    signal settingsRequested()
    required property var theme
    property bool active: false
    property var adapter: Bluetooth.defaultAdapter
    property var forgetTarget: null
    readonly property bool powered: adapter !== null && adapter.enabled
    readonly property bool changingPower: adapter !== null && (adapter.state === BluetoothAdapterState.Enabling || adapter.state === BluetoothAdapterState.Disabling)
    spacing: 9

    onActiveChanged: {
        forgetTarget = null;
        if (!active && adapter && adapter.discovering)
            adapter.discovering = false;
    }

    Text {
        Layout.fillWidth: true
        text: !content.adapter ? "No Bluetooth adapter detected." : content.adapter.state === BluetoothAdapterState.Blocked ? "Bluetooth is blocked. Check your hardware switch or airplane mode." : content.changingPower ? "Changing Bluetooth power…" : content.powered ? "Bluetooth is on · " + content.adapter.name : "Bluetooth is off. Turn it on to connect or find devices."
        wrapMode: Text.WordWrap
        color: content.theme.colors.muted
        font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize - 1 }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        ShellButton {
            objectName: "bluetoothPower"
            Layout.fillWidth: true
            label: content.powered ? "Turn off" : "Turn on"
            enabled: content.adapter !== null && !content.changingPower && content.adapter.state !== BluetoothAdapterState.Blocked
            fontFamily: content.theme.fontFamily
            fontSize: content.theme.fontSize - 1
            backgroundColor: content.powered ? content.theme.colors.accent : content.theme.colors.surface_alt
            foregroundColor: content.powered ? content.theme.colors.background : content.theme.colors.foreground
            onClicked: {
                if (content.adapter.discovering) content.adapter.discovering = false;
                content.adapter.enabled = !content.adapter.enabled;
            }
        }
        ShellButton {
            objectName: "bluetoothScan"
            Layout.fillWidth: true
            label: content.adapter && content.adapter.discovering ? "Stop scan" : "Find devices"
            enabled: content.powered && !content.changingPower
            fontFamily: content.theme.fontFamily
            fontSize: content.theme.fontSize - 1
            backgroundColor: content.theme.colors.surface_alt
            foregroundColor: content.theme.colors.foreground
            onClicked: content.adapter.discovering = !content.adapter.discovering
        }
    }
    Text {
        Layout.fillWidth: true
        visible: content.powered
        text: content.adapter && content.adapter.discovering ? "Searching for nearby devices… Put your device in pairing mode." : "Choose Find devices to search for a new device."
        wrapMode: Text.WordWrap
        color: content.theme.colors.muted
        font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize - 1 }
    }
    Repeater {
        model: content.adapter ? content.adapter.devices : []
        ColumnLayout {
            id: deviceRow
            required property var modelData
            readonly property bool busy: modelData.pairing || modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
            Layout.fillWidth: true
            spacing: 5
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: content.theme.colors.surface_alt }
            Text {
                Layout.fillWidth: true
                text: deviceRow.modelData.name || deviceRow.modelData.address
                elide: Text.ElideRight
                color: content.theme.colors.foreground
                font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize; bold: true }
            }
            Text {
                Layout.fillWidth: true
                text: deviceRow.modelData.pairing ? "Pairing…" : (deviceRow.modelData.state === BluetoothDeviceState.Connecting ? "Connecting…" : deviceRow.modelData.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…" : deviceRow.modelData.connected ? "Connected" : deviceRow.modelData.paired ? "Paired" : "Available") + (deviceRow.modelData.trusted ? " · Trusted" : "") + (deviceRow.modelData.batteryAvailable ? " · " + Math.round(deviceRow.modelData.battery * 100) + "% battery" : "")
                color: content.theme.colors.muted
                font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize - 2 }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                ShellButton {
                    objectName: "bluetoothConnect"
                    Layout.fillWidth: true
                    label: deviceRow.modelData.pairing ? "Cancel pairing" : deviceRow.modelData.connected ? "Disconnect" : deviceRow.modelData.paired ? "Connect" : "Pair"
                    enabled: content.powered && (!deviceRow.busy || deviceRow.modelData.pairing)
                    fontFamily: content.theme.fontFamily
                    fontSize: content.theme.fontSize - 2
                    backgroundColor: deviceRow.modelData.connected ? content.theme.colors.accent : content.theme.colors.surface_alt
                    foregroundColor: deviceRow.modelData.connected ? content.theme.colors.background : content.theme.colors.foreground
                    onClicked: {
                        if (deviceRow.modelData.pairing) deviceRow.modelData.cancelPair();
                        else if (deviceRow.modelData.connected) deviceRow.modelData.disconnect();
                        else if (deviceRow.modelData.paired) deviceRow.modelData.connect();
                        else deviceRow.modelData.pair();
                    }
                }
                ShellButton {
                    objectName: "bluetoothTrust"
                    visible: deviceRow.modelData.paired
                    label: deviceRow.modelData.trusted ? "Untrust" : "Trust"
                    enabled: content.powered && !deviceRow.busy
                    fontFamily: content.theme.fontFamily
                    fontSize: content.theme.fontSize - 2
                    backgroundColor: content.theme.colors.surface_alt
                    foregroundColor: content.theme.colors.foreground
                    onClicked: deviceRow.modelData.trusted = !deviceRow.modelData.trusted
                }
                ShellButton {
                    objectName: "bluetoothForget"
                    visible: deviceRow.modelData.paired
                    label: "Forget"
                    enabled: content.powered && !deviceRow.busy
                    fontFamily: content.theme.fontFamily
                    fontSize: content.theme.fontSize - 2
                    backgroundColor: content.theme.colors.surface_alt
                    foregroundColor: content.theme.colors.foreground
                    onClicked: content.forgetTarget = deviceRow.modelData
                }
            }
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: content.forgetTarget !== null
        Text {
            Layout.fillWidth: true
            text: content.forgetTarget ? "Forget " + (content.forgetTarget.name || content.forgetTarget.address) + "? You will need to pair it again." : ""
            wrapMode: Text.WordWrap
            color: content.theme.colors.foreground
            font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize - 1 }
        }
        RowLayout {
            ShellButton {
                objectName: "bluetoothConfirmForget"
                label: "Forget device"
                enabled: content.powered && content.forgetTarget !== null
                fontFamily: content.theme.fontFamily
                fontSize: content.theme.fontSize - 1
                backgroundColor: content.theme.colors.accent
                foregroundColor: content.theme.colors.background
                onClicked: {
                    const device = content.forgetTarget;
                    content.forgetTarget = null;
                    if (device) device.forget();
                }
            }
            ShellButton {
                label: "Cancel"
                fontFamily: content.theme.fontFamily
                fontSize: content.theme.fontSize - 1
                backgroundColor: content.theme.colors.surface_alt
                foregroundColor: content.theme.colors.foreground
                onClicked: content.forgetTarget = null
            }
        }
    }
    ShellButton {
        objectName: "bluetoothSettings"
        Layout.fillWidth: true
        label: "Pairing & device settings"
        fontFamily: content.theme.fontFamily
        fontSize: content.theme.fontSize - 1
        backgroundColor: content.theme.colors.surface_alt
        foregroundColor: content.theme.colors.foreground
        onClicked: {
            content.settingsRequested();
            content.theme.runAction(["uwsm", "app", "--", "blueman-manager"]);
        }
    }
    Text {
        Layout.fillWidth: true
        text: "Use device settings for PIN codes, pairing confirmations, or connection troubleshooting."
        wrapMode: Text.WordWrap
        color: content.theme.colors.muted
        font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize - 2 }
    }
}
