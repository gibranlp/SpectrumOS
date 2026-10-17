pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

ColumnLayout {
    id: drop
    required property var theme
    required property var backend
    spacing: 10
    component Label: Text {
        color: drop.theme.colors.foreground
        font.family: drop.theme.fontFamily
        font.pixelSize: drop.theme.fontSize
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
    component Button: ShellButton {
        fontFamily: drop.theme.fontFamily
        fontSize: drop.theme.fontSize
        backgroundColor: drop.theme.colors.surface_alt
        foregroundColor: drop.theme.colors.foreground
        enabled: !drop.backend.busy
    }
    component Action: WidgetAction {
        theme: drop.theme
        Layout.fillWidth: true
        enabled: !drop.backend.busy
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 16
        Label { text: "󰀂"; font.pixelSize: 52; color: drop.backend.state.receiving ? drop.theme.colors.accent : drop.theme.colors.muted }
        ColumnLayout {
            Layout.fillWidth: true
            Label { Layout.fillWidth: true; text: drop.backend.state.receiving ? "Ready to receive" : "Receive files"; font.pixelSize: drop.theme.fontSize + 6; font.bold: true }
            Label {
                Layout.fillWidth: true
                text: drop.backend.state.receiving
                    ? (drop.backend.state.name || "Spectrum") + " · " + Math.ceil(Math.max(0, drop.backend.state.remaining || 0) / 60) + " min left"
                    : "Choose how long to be visible"
                color: drop.theme.colors.muted
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Action { objectName: "drop-receive-5"; icon: "󰇚"; label: "5 min"; hint: "Receive and discover for 5 minutes"; enabled: !drop.backend.busy && drop.backend.state.available !== false && !drop.backend.state.transfer?.active; onClicked: drop.backend.command(["receive", "5"]) }
        Action { icon: "󰇚"; label: "10 min"; hint: "Receive and discover for 10 minutes"; enabled: !drop.backend.busy && drop.backend.state.available !== false && !drop.backend.state.transfer?.active; onClicked: drop.backend.command(["receive", "10"]) }
        Action { icon: "󰇚"; label: "30 min"; hint: "Receive and discover for 30 minutes"; enabled: !drop.backend.busy && drop.backend.state.available !== false && !drop.backend.state.transfer?.active; onClicked: drop.backend.command(["receive", "30"]) }
        Action { objectName: "drop-stop"; icon: "󰓛"; label: "Stop"; hint: "Stop receiving and restore Wi-Fi if needed"; enabled: !drop.backend.busy && (!!drop.backend.state.receiving || !!drop.backend.state.radio_owned) && !drop.backend.state.transfer?.active; onClicked: drop.backend.command(["stop"]) }
    }
    RowLayout {
        Layout.fillWidth: true
        Button { label: "󰉋  Save folder"; enabled: !drop.backend.busy && drop.backend.state.available !== false && !drop.backend.state.transfer?.active; onClicked: drop.backend.command(["folder"]) }
        Label { Layout.fillWidth: true; text: drop.backend.state.dir || "Downloads"; elide: Text.ElideMiddle; maximumLineCount: 1; color: drop.theme.colors.muted }
    }
    Label {
        Layout.fillWidth: true
        visible: !!drop.backend.state.receiving || !!drop.backend.state.radio_owned
        text: drop.backend.state.receiving ? (drop.backend.state.visibility === "contacts" ? "Contacts only" : "Everyone nearby") : "Stopped · Stop restores Wi-Fi"
        color: drop.theme.colors.muted
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: transferBody.implicitHeight + 24
        visible: !!drop.backend.state.transfer?.message
        radius: 12
        color: drop.theme.colors.surface_alt
        RowLayout {
            id: transferBody
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            Label { text: drop.backend.state.transfer?.phase === "failed" ? "󰅚" : drop.backend.state.transfer?.phase === "complete" ? "󰄬" : "󰇠"; font.pixelSize: 32; color: drop.theme.colors.accent }
            Label {
                Layout.fillWidth: true
                objectName: "drop-transfer-status"
                text: drop.backend.state.transfer?.phase === "failed" && !(drop.backend.state.transfer?.message || "").startsWith("Send failed:")
                    ? "Send failed: " + (drop.backend.state.transfer?.message || "") : drop.backend.state.transfer?.message || ""
                color: drop.backend.state.transfer?.phase === "failed" ? drop.theme.colors.accent : drop.theme.colors.foreground
            }
            Controls.BusyIndicator { visible: !!drop.backend.state.transfer?.active; running: visible; implicitWidth: 28; implicitHeight: 28 }
            Button { objectName: "drop-cancel"; visible: !!drop.backend.state.transfer?.active; label: "󰜺  Cancel"; onClicked: drop.backend.command(["cancel"]) }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Label { text: "Nearby"; font.bold: true; font.pixelSize: drop.theme.fontSize + 3; Layout.fillWidth: true }
        Button { objectName: "drop-scan"; label: drop.backend.scanning ? "󰑐  Searching…" : "󰍉  Search"; implicitHeight: 44; enabled: !drop.backend.scanning && !drop.backend.busy && !!drop.backend.state.visible && !drop.backend.state.transfer?.active; onClicked: drop.backend.scan() }
    }
    Item {
        Layout.fillWidth: true
        implicitHeight: 104
        visible: drop.backend.peers.length === 0
        Column {
            anchors.centerIn: parent
            spacing: 10
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: "󰍹"; font.pixelSize: 48; color: drop.theme.colors.muted }
            Label {
                text: drop.backend.scanning ? "Looking for devices…" : drop.backend.state.visible ? "Open AirDrop on your Apple device" : "Start receiving to find devices"
                color: drop.theme.colors.muted
            }
        }
    }
    Controls.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: parent.width
            Repeater {
                model: drop.backend.peers
                delegate: Rectangle {
                    id: device
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 98
                    radius: 10
                    color: drop.theme.colors.surface_alt
                    RowLayout {
                        anchors { fill: parent; margins: 10 }
                        Label { text: "󰍹"; font.pixelSize: 36 }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Label { Layout.fillWidth: true; text: device.modelData.name || "Nearby Apple device"; font.bold: true; elide: Text.ElideRight; maximumLineCount: 1 }
                            Label { text: "Select files to send"; color: drop.theme.colors.muted; font.pixelSize: drop.theme.fontSize - 1 }
                        }
                        Action {
                            Layout.fillWidth: false
                            icon: "󰇠"
                            objectName: "drop-send-" + device.modelData.mac
                            label: "Send"; hint: "Choose files to send to " + (device.modelData.name || device.modelData.mac)
                            enabled: !drop.backend.busy && !!drop.backend.state.visible && !drop.backend.state.transfer?.active
                            onClicked: drop.backend.command(["send", device.modelData.mac])
                        }
                    }
                }
            }
        }
    }
    Label { Layout.fillWidth: true; objectName: "drop-error"; visible: !!drop.backend.error; text: drop.backend.error; color: drop.theme.colors.accent }
}
