pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

Controls.ScrollView {
    id: drop
    required property var theme
    required property var backend
    signal openFolderRequested(string path)
    readonly property bool networkMode: backend.transport === "pc"
    readonly property var receiveState: networkMode ? backend.state.lan || {} : backend.state
    readonly property var incoming: networkMode ? receiveState.incoming || [] : []
    readonly property bool incomingBusy: incoming.some(item => ["pending", "receiving"].includes(item.phase))
    contentHeight: contentBody.implicitHeight
    palette { window: theme.colors.surface; base: theme.colors.background; text: theme.colors.foreground; button: theme.colors.surface_alt; buttonText: theme.colors.foreground; highlight: theme.colors.accent; highlightedText: theme.colors.background }
    contentWidth: availableWidth
    clip: true

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
    component CodeField: Controls.TextField {
        Layout.fillWidth: true
        placeholderText: qsTranslate("Spectrum", "Receiver code")
        maximumLength: 24
        color: drop.theme.colors.foreground
        placeholderTextColor: drop.theme.colors.muted
        selectionColor: drop.theme.colors.accent
        font.family: drop.theme.fontFamily
        font.pixelSize: drop.theme.fontSize
        echoMode: TextInput.Password
        padding: 10
        background: Rectangle { radius: 8; color: drop.theme.colors.background; border.width: parent.activeFocus ? 1 : 0; border.color: drop.theme.colors.accent }
    }

    ColumnLayout {
        id: contentBody
        width: drop.availableWidth
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            Repeater {
                model: [{id:"pc", label:qsTranslate("Spectrum", "Spectrum PCs")}, {id:"airdrop", label:qsTranslate("Spectrum", "Apple AirDrop")}]
                Button {
                    required property var modelData
                    Layout.fillWidth: true
                    label: modelData.label
                    backgroundColor: (drop.networkMode ? "pc" : "airdrop") === modelData.id ? drop.theme.colors.accent : drop.theme.colors.surface_alt
                    foregroundColor: (drop.networkMode ? "pc" : "airdrop") === modelData.id ? drop.theme.colors.background : drop.theme.colors.foreground
                    enabled: !drop.backend.busy && !drop.backend.state.transfer?.active
                    onClicked: drop.backend.selectTransport(modelData.id)
                }
            }
        }
        Rectangle {
            objectName: "drop-selected-files"
            Layout.fillWidth: true
            visible: (drop.backend.state.selection?.count || 0) > 0
            implicitHeight: selectionBody.implicitHeight + 20
            radius: 10
            color: drop.theme.colors.surface_alt
            ColumnLayout {
                id: selectionBody
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                Label { objectName: "drop-selection-summary"; Layout.fillWidth: true; text: (drop.backend.state.selection?.count || 0) + qsTranslate("Spectrum", " files selected in Thunar"); font.bold: true }
                Label { Layout.fillWidth: true; text: (drop.backend.state.selection?.names || []).join("\n"); maximumLineCount: 5; elide: Text.ElideRight; color: drop.theme.colors.muted }
                Button { objectName: "drop-clear-selection"; label: qsTranslate("Spectrum", "Clear selection"); enabled: !drop.backend.busy && !drop.backend.state.transfer?.active; onClicked: drop.backend.command(["clear-selection", drop.backend.transport]) }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Label { text: "󰀂"; font.pixelSize: 44; color: drop.receiveState.receiving ? drop.theme.colors.accent : drop.theme.colors.muted }
            ColumnLayout {
                Layout.fillWidth: true
                Label { Layout.fillWidth: true; text: drop.receiveState.receiving ? qsTranslate("Spectrum", "Ready to receive") : qsTranslate("Spectrum", "Receive files"); font.pixelSize: drop.theme.fontSize + 5; font.bold: true }
                Label {
                    Layout.fillWidth: true
                    text: drop.receiveState.receiving
                        ? (drop.receiveState.name || "Spectrum") + " · " + Math.ceil(Math.max(0, drop.receiveState.remaining || 0) / 60) + qsTranslate("Spectrum", " min left")
                        : drop.networkMode ? qsTranslate("Spectrum", "Ethernet or Wi-Fi · no special radio required") : qsTranslate("Spectrum", "Wi-Fi and Bluetooth · compatible radio required")
                    color: drop.theme.colors.muted
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [5, 10, 30]
                Action {
                    required property int modelData
                    objectName: "drop-receive-" + modelData
                    icon: "󰇚"
                    label: modelData + qsTranslate("Spectrum", " min")
                    hint: qsTranslate("Spectrum", "Receive for ") + modelData + qsTranslate("Spectrum", " minutes")
                    enabled: !drop.backend.busy && (drop.networkMode ? drop.receiveState.available !== false : drop.backend.state.available !== false) && !drop.backend.state.transfer?.active && !drop.incomingBusy
                    onClicked: drop.backend.command([drop.networkMode ? "receive-lan" : "receive", String(modelData)])
                }
            }
            Action {
                objectName: "drop-stop"
                icon: "󰓛"; label: qsTranslate("Spectrum", "Stop"); hint: qsTranslate("Spectrum", "Stop receiving")
                enabled: !drop.backend.busy && (!!drop.receiveState.receiving || (!drop.networkMode && !!drop.backend.state.radio_owned)) && !drop.backend.state.transfer?.active
                onClicked: drop.backend.command([drop.networkMode ? "stop-lan" : "stop"])
            }
        }
        Rectangle {
            Layout.fillWidth: true
            visible: drop.networkMode && !!drop.receiveState.receiving
            implicitHeight: codeBody.implicitHeight + 20
            radius: 10
            color: drop.theme.colors.surface_alt
            ColumnLayout {
                id: codeBody
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                Label { Layout.fillWidth: true; text: qsTranslate("Spectrum", "Use this code on the sending Spectrum PC. Review each incoming request."); color: drop.theme.colors.muted }
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        Layout.fillWidth: true
                        objectName: "drop-receiver-code"
                        text: (drop.receiveState.code || "").match(/.{1,4}/g)?.join("-") || ""
                        font.bold: true
                        font.pixelSize: drop.theme.fontSize + 3
                    }
                    Button { label: qsTranslate("Spectrum", "Copy"); onClicked: drop.backend.command(["copy-lan-code"]) }
                }
                Label {
                    Layout.fillWidth: true
                    text: (drop.receiveState.addresses || []).map(host => (host.includes(":") ? "[" + host + "]" : host) + ":" + (drop.receiveState.port || 8857)).join(" · ")
                    color: drop.theme.colors.muted
                    font.pixelSize: drop.theme.fontSize - 2
                }
            }
        }
        Repeater {
            model: drop.incoming
            Rectangle {
                id: incomingCard
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: incomingBody.implicitHeight + 20
                radius: 10
                color: drop.theme.colors.surface_alt
                ColumnLayout {
                    id: incomingBody
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                    Label { Layout.fillWidth: true; text: incomingCard.modelData.sender + " · " + (incomingCard.modelData.file_count || incomingCard.modelData.files.length) + qsTranslate("Spectrum", " files"); font.bold: true }
                    Label { Layout.fillWidth: true; text: incomingCard.modelData.files.slice(0, 3).map(item => item.name).join("\n"); maximumLineCount: 3; elide: Text.ElideRight; color: drop.theme.colors.muted }
                    RowLayout {
                        visible: incomingCard.modelData.phase === "pending"
                        Button { objectName: "drop-accept-" + incomingCard.modelData.id; label: qsTranslate("Spectrum", "Accept"); onClicked: drop.backend.command(["accept-lan", incomingCard.modelData.id]) }
                        Button { objectName: "drop-decline-" + incomingCard.modelData.id; label: qsTranslate("Spectrum", "Decline"); onClicked: drop.backend.command(["decline-lan", incomingCard.modelData.id]) }
                    }
                    Controls.ProgressBar { Layout.fillWidth: true; visible: incomingCard.modelData.phase === "receiving"; from: 0; to: Math.max(1, incomingCard.modelData.total); value: incomingCard.modelData.bytes }
                    Button { visible: incomingCard.modelData.phase === "receiving"; label: qsTranslate("Spectrum", "Cancel"); onClicked: drop.backend.command(["cancel-incoming-lan", incomingCard.modelData.id]) }
                    Button { visible: incomingCard.modelData.phase === "complete"; label: qsTranslate("Spectrum", "Open folder"); onClicked: drop.openFolderRequested(incomingCard.modelData.folder) }
                    Label { Layout.fillWidth: true; visible: incomingCard.modelData.phase !== "pending"; text: qsTranslate("Spectrum", incomingCard.modelData.error) || (incomingCard.modelData.phase === "complete" ? qsTranslate("Spectrum", "Received and verified · ") + incomingCard.modelData.folder : qsTranslate("Spectrum", "Receiving…")); color: drop.theme.colors.muted }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Button { label: qsTranslate("Spectrum", "󰉋  Save folder"); enabled: !drop.backend.busy && !drop.backend.state.transfer?.active && !drop.incomingBusy; onClicked: drop.backend.command(["folder"]) }
            Label { Layout.fillWidth: true; text: drop.receiveState.dir || qsTranslate("Spectrum", "Downloads"); elide: Text.ElideMiddle; maximumLineCount: 1; color: drop.theme.colors.muted }
        }
        Label {
            Layout.fillWidth: true
            visible: !drop.networkMode && (!!drop.receiveState.receiving || !!drop.backend.state.radio_owned)
            text: drop.receiveState.receiving ? (drop.receiveState.visibility === "contacts" ? qsTranslate("Spectrum", "Contacts only") : qsTranslate("Spectrum", "Everyone nearby")) : qsTranslate("Spectrum", "Stopped · Stop restores Wi-Fi")
            color: drop.theme.colors.muted
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: transferBody.implicitHeight + 24
            visible: !!drop.backend.state.transfer?.message
            radius: 12
            color: drop.theme.colors.surface_alt
            ColumnLayout {
                id: transferBody
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: drop.backend.state.transfer?.phase === "failed" ? "󰅚" : drop.backend.state.transfer?.phase === "complete" ? "󰄬" : "󰇠"; font.pixelSize: 28; color: drop.theme.colors.accent }
                    Label {
                        Layout.fillWidth: true
                        objectName: "drop-transfer-status"
                        text: drop.backend.state.transfer?.phase === "failed" && !(drop.backend.state.transfer?.message || "").startsWith(qsTranslate("Spectrum", "Send failed:"))
                            ? qsTranslate("Spectrum", "Send failed: ") + (drop.backend.state.transfer?.message || "") : drop.backend.state.transfer?.message || ""
                    }
                    Controls.BusyIndicator { visible: !!drop.backend.state.transfer?.active; running: visible; implicitWidth: 28; implicitHeight: 28 }
                    Button { objectName: "drop-cancel"; visible: !!drop.backend.state.transfer?.active; label: qsTranslate("Spectrum", "Cancel"); onClicked: drop.backend.command(["cancel"]) }
                }
                Controls.ProgressBar { Layout.fillWidth: true; visible: !!drop.backend.state.transfer?.active && drop.backend.state.transfer?.percent !== undefined; from: 0; to: 100; value: drop.backend.state.transfer?.percent || 0 }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Label { text: qsTranslate("Spectrum", "Nearby"); font.bold: true; font.pixelSize: drop.theme.fontSize + 3; Layout.fillWidth: true }
            Button { objectName: "drop-scan"; label: drop.backend.scanning ? qsTranslate("Spectrum", "󰑐  Searching…") : qsTranslate("Spectrum", "󰍉  Search"); implicitHeight: 44; enabled: !drop.backend.scanning && !drop.backend.busy && (drop.networkMode || !!drop.backend.state.visible) && !drop.backend.state.transfer?.active; onClicked: drop.backend.scan() }
        }
        Label {
            Layout.fillWidth: true
            visible: drop.backend.peers.length === 0
            text: drop.backend.scanning ? qsTranslate("Spectrum", "Looking for devices…") : drop.networkMode ? qsTranslate("Spectrum", "Enable receiving on the other Spectrum PC, then Search. You can also connect by IP address below.") : drop.backend.state.visible ? qsTranslate("Spectrum", "Open AirDrop on your Apple device") : qsTranslate("Spectrum", "Start receiving to find devices")
            color: drop.theme.colors.muted
        }
        Repeater {
            model: drop.backend.peers
            Rectangle {
                id: device
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: deviceBody.implicitHeight + 20
                radius: 10
                color: drop.theme.colors.surface_alt
                ColumnLayout {
                    id: deviceBody
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "󰍹"; font.pixelSize: 32 }
                        Label { Layout.fillWidth: true; text: device.modelData.name || (drop.networkMode ? qsTranslate("Spectrum", "Spectrum PC") : qsTranslate("Spectrum", "Nearby Apple device")); font.bold: true; elide: Text.ElideRight; maximumLineCount: 1 }
                        Action {
                            Layout.fillWidth: false
                            icon: "󰇠"; objectName: "drop-send-" + device.modelData.mac
                            label: qsTranslate("Spectrum", "Send"); hint: qsTranslate("Spectrum", "Choose files to send")
                            enabled: !drop.backend.busy && (drop.networkMode || !!drop.backend.state.visible) && !drop.backend.state.transfer?.active && (!drop.networkMode || receiverCode.text.replace(/[ -]/g, "").length === 16)
                            onClicked: {
                                drop.backend.command([drop.networkMode ? "send-lan" : "send", device.modelData.mac], drop.networkMode ? {code: receiverCode.text} : {});
                                receiverCode.clear();
                            }
                        }
                    }
                    CodeField { id: receiverCode; objectName: "drop-code-" + device.modelData.mac; visible: drop.networkMode }
                }
            }
        }
        Label { Layout.fillWidth: true; visible: drop.networkMode; text: qsTranslate("Spectrum", "Connect by IP"); font.bold: true }
        RowLayout {
            visible: drop.networkMode
            Layout.fillWidth: true
            Controls.TextField {
                id: manualAddress
                objectName: "drop-manual-address"
                Layout.fillWidth: true
                placeholderText: qsTranslate("Spectrum", "Receiver IP address")
                color: drop.theme.colors.foreground
                placeholderTextColor: drop.theme.colors.muted
                font.family: drop.theme.fontFamily
                font.pixelSize: drop.theme.fontSize
                background: Rectangle { radius: 8; color: drop.theme.colors.surface_alt }
                padding: 10
            }
            CodeField { id: manualCode; objectName: "drop-manual-code"; Layout.preferredWidth: 180 }
            Button {
                objectName: "drop-manual-send"
                label: qsTranslate("Spectrum", "Send")
                enabled: !drop.backend.busy && !drop.backend.state.transfer?.active && manualAddress.text.trim().length > 0 && manualCode.text.replace(/[ -]/g, "").length === 16
                onClicked: { drop.backend.command(["send-lan", "manual"], {address: manualAddress.text.trim(), code: manualCode.text}); manualCode.clear(); }
            }
        }
        Label { Layout.fillWidth: true; visible: drop.networkMode && !!drop.receiveState.error; text: qsTranslate("Spectrum", drop.receiveState.error) || ""; color: drop.theme.colors.muted }
        Label { Layout.fillWidth: true; objectName: "drop-error"; visible: !!drop.backend.error; text: qsTranslate("Spectrum", drop.backend.error); color: drop.theme.colors.accent }
    }
}
