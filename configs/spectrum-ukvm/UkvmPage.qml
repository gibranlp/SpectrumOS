pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "UkvmModel.js" as Model

Item {
    id: page
    required property var theme
    required property var backend
    readonly property int uiFontSize: Math.min(page.theme.fontSize, Math.max(11, Math.min(16, Math.floor(height / 52))))
    property string selectedId: ""
    property bool showDetails: false
    property bool showHealthDetails: false
    property var peers: []
    property var nodes: []
    readonly property var selected: Model.peerAt(peers, selectedId)
    readonly property var selectedNode: nodes.find(n => !n.local && n.node_id === selectedId) || null
    readonly property var service: backend.status.service || {}
    readonly property var backendProblems: Model.backendProblems(backend.doctor)
    signal closeRequested()

    function syncTopology() {
        const nextPeers = backend.status.peers || [];
        const nextNodes = (backend.status.layout || {}).nodes || [];
        if (!Model.sameData(peers, nextPeers)) peers = nextPeers;
        if (!Model.sameData(nodes, nextNodes)) nodes = nextNodes;
    }
    Component.onCompleted: syncTopology()
    function place(x, y) {
        if (!selected || page.backend.busy) return;
        page.backend.action(selected.position ? ["layout", "move", selected.node_id, String(x), String(y)]
                                          : ["layout", "place", String(x), String(y), selected.node_id]);
    }
    function perform(args) {
        if (page.backend.busy || !page.backend.compatible) return;
        if (args[0] === "peer" && args[1] === "allow" && args[3] === "control-this-node")
            page.backend.authorizeControl(args[2]);
        else page.backend.action(args);
    }
    property int peerPage: 0
    property int discoveryPage: 0
    property int healthPage: 0
    readonly property int peerPageSize: width < 800 ? 2 : 3
    readonly property var listedPeers: peers.slice(peerPage * peerPageSize, (peerPage + 1) * peerPageSize)
    readonly property var discoveredMachines: Model.discoveryMachines(backend.machines, (backend.status.node || {}).node_id)
    onDiscoveredMachinesChanged: discoveryPage = 0
    readonly property var listedMachines: discoveredMachines.slice(discoveryPage * 2, discoveryPage * 2 + 2)
    onPeersChanged: peerPage = Math.min(peerPage, Math.max(0, Math.ceil(peers.length / peerPageSize) - 1))
    Connections {
        target: page.backend
        function onStatusChanged() { page.syncTopology(); }
        function onPairingChanged() { if (page.backend.pairing) { page.showHealthDetails = false; } }
        function onRemoteOpened() { page.closeRequested(); }
        function onMachinesChanged() { page.discoveryPage = 0; }
    }
    onVisibleChanged: { if (!visible) { pickerMode = ""; } }

    component Label: Text {
        color: page.theme.colors.foreground
        font { family: page.theme.fontFamily; pixelSize: page.uiFontSize }
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
    }
    component Action: Button {
        id: actionButton
        property bool prominent: false
        implicitHeight: Math.max(32, page.uiFontSize + 14)
        implicitWidth: Math.min(page.width - 24, Math.max(42, contentItem.implicitWidth + 24))
        enabled: !page.backend.busy && page.backend.compatible
        focusPolicy: Qt.StrongFocus
        Accessible.name: text
        Keys.onReturnPressed: event => { if (enabled && !event.isAutoRepeat) clicked(); }
        Keys.onEnterPressed: event => { if (enabled && !event.isAutoRepeat) clicked(); }
        contentItem: Text {
            text: actionButton.text
            textFormat: Text.PlainText
            font { family: page.theme.fontFamily; pixelSize: page.uiFontSize; bold: true }
            color: actionButton.prominent ? page.theme.colors.background : page.theme.colors.foreground
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            opacity: actionButton.enabled ? 1 : 0.4
        }
        background: Rectangle {
            radius: 8
            color: actionButton.prominent ? page.theme.colors.accent : page.theme.colors.surface_alt
            opacity: actionButton.down ? 0.65 : 1
            border.width: actionButton.activeFocus || actionButton.hovered ? 1 : 0
            border.color: page.theme.colors.accent
        }
    }
    component DirectAction: Row {
        id: control
        property string text
        property string description
        property var args
        property bool prominent: false
        objectName: "action-" + args[0] + (args[1] ? "-" + args[1] : "")
        signal clicked()
        onClicked: page.perform(args)
        Action {
            text: control.text
            prominent: control.prominent
            onClicked: control.clicked()
            ToolTip.text: control.description
            ToolTip.visible: hovered
            ToolTip.delay: 600
        }
    }
    property string pickerPeer: ""
    property string pickerMode: ""
    function openPicker(mode) {
        if (!selected || backend.busy || backend.sending) return;
        pickerPeer = selectedId;
        pickerMode = mode;
        filePicker.open();
    }
    FilePicker {
        id: filePicker
        objectName: "ukvm-file-picker"
        anchors.fill: parent
        z: 10
        visible: page.pickerMode.length > 0
        theme: page.theme
        fontSize: page.uiFontSize
        folderMode: page.pickerMode === "folder"
        peerName: (Model.peerAt(page.peers, page.pickerPeer) || {}).name || "Computer"
        onCancelled: { page.pickerMode = ""; page.forceActiveFocus(); }
        onChosen: paths => {
            page.pickerMode = "";
            page.backend.sendFiles(paths, page.pickerPeer);
            page.forceActiveFocus();
        }
    }
    Rectangle {
        objectName: "control-onboarding"
        anchors.fill: parent
        z: 11
        visible: !!page.backend.controlOffer && !page.backend.pairing
        color: page.theme.colors.surface
        radius: 12
        MouseArea { anchors.fill: parent }
        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(480, parent.width - 32)
            spacing: 16
            Label {
                objectName: "control-onboarding-title"
                Layout.fillWidth: true
                maximumLineCount: 4
                text: "Allow " + ((page.backend.controlOffer || {}).name || "this peer") + " to control this computer"
                font.bold: true
                font.pixelSize: page.uiFontSize + 4
            }
            Label {
                Layout.fillWidth: true
                maximumLineCount: 6
                text: "Pairing established trust. Allowing control lets this computer receive keyboard and mouse input from this peer. Clipboard and file permissions stay unchanged."
            }
            Label {
                Layout.fillWidth: true
                maximumLineCount: 6
                text: "Allow and apply starts UKVM if needed. Approve the desktop's RemoteDesktop dialog yourself; choose Remember if offered for future logins."
                color: page.theme.colors.muted
            }
            RowLayout {
                Action { objectName: "allow-paired-control"; text: "Allow and apply"; prominent: true; onClicked: page.backend.decideControl(true) }
                Action { objectName: "decline-paired-control"; text: "Not now"; onClicked: page.backend.decideControl(false) }
            }
        }
    }
    readonly property var transferRows: ((page.backend.status.files || {}).transfers || [])
    readonly property var currentTransfer: Model.activeTransfer(page.backend.sending, page.backend.transfer, transferRows)
    component Field: TextField {
        id: field
        color: page.theme.colors.foreground
        placeholderTextColor: page.theme.colors.muted
        font { family: page.theme.fontFamily; pixelSize: page.uiFontSize }
        background: Rectangle { radius: 8; color: page.theme.colors.surface_alt; border.width: parent.activeFocus ? 1 : 0; border.color: page.theme.colors.accent }
        selectByMouse: true
    }

    component ClipboardToggle: AbstractButton {
        property string permissionKey: "share_clipboard"
        property string permissionArg: "share-clipboard"
        property string permissionTitle: "Share clipboard"
        property string permissionHelp: "Share plain text, including sensitive copied text. Enable on both computers. Changes apply immediately."
        property string statusKey: "clipboard"
        id: toggle
        objectName: permissionArg + "-toggle"
        readonly property var permission: (page.selected || {}).permissions || {}
        readonly property bool known: typeof permission[permissionKey] === "boolean"
        checked: permission[permissionKey] === true
        checkable: false
        enabled: !!page.selected && known && !page.backend.busy && page.backend.compatible
            && !!page.backend.status[statusKey] && page.backend.status[statusKey].state !== "restart_required"
        implicitHeight: Math.max(36, page.uiFontSize + 16)
        implicitWidth: 220
        focusPolicy: Qt.StrongFocus
        Accessible.role: Accessible.CheckBox
        Accessible.name: permissionTitle
        Accessible.checked: checked
        ToolTip.text: permissionHelp
        ToolTip.visible: hovered
        ToolTip.delay: 600
        onClicked: page.backend.action(["peer", checked ? "deny" : "allow", page.selectedId, permissionArg])
        Keys.onReturnPressed: event => { if (enabled && !event.isAutoRepeat) clicked(); }
        Keys.onEnterPressed: event => { if (enabled && !event.isAutoRepeat) clicked(); }
        background: Rectangle {
            radius: 8
            color: page.theme.colors.surface
            border.width: toggle.activeFocus || toggle.hovered ? 1 : 0
            border.color: page.theme.colors.accent
            opacity: toggle.enabled ? 1 : 0.5
        }
        contentItem: RowLayout {
            spacing: 10
            Rectangle {
                Layout.leftMargin: 10
                implicitWidth: 18; implicitHeight: 18; radius: 4
                color: toggle.checked ? page.theme.colors.accent : "transparent"
                border.width: 1
                border.color: toggle.checked ? page.theme.colors.accent : page.theme.colors.muted
                Text { anchors.centerIn: parent; text: toggle.checked ? "✓" : ""; color: page.theme.colors.background; font.pixelSize: 14 }
            }
            Label {
                objectName: toggle.permissionArg === "share-clipboard" ? "clipboard-permission" : toggle.permissionArg === "receive-files" ? "files-permission" : "screen-permission"
                Layout.fillWidth: true
                text: toggle.permissionTitle
                font.bold: true
                wrapMode: Text.NoWrap
            }
            Label { Layout.rightMargin: 10; text: toggle.known ? (toggle.checked ? "On" : "Off") : "Unknown"; color: page.theme.colors.muted }
        }
    }

    ColumnLayout {
        id: content
        objectName: "ukvm-content"
        anchors.fill: parent
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Label { text: "UNIVERSALKVM"; font.pixelSize: page.uiFontSize + 6; font.bold: true; color: page.theme.colors.accent }
                Label { text: !page.backend.installed ? "Not installed" : !page.backend.compatible ? "Checking CLI compatibility…" : Model.serviceLabel(page.backend.status); color: page.theme.colors.muted }
            }
            Action { text: "Refresh"; enabled: !page.backend.busy; onClicked: { page.backend.error = ""; page.backend.refresh(); } }
            Action { text: "Close"; enabled: true; onClicked: page.closeRequested() }
        }
        RowLayout {
            visible: !!page.currentTransfer
            Layout.fillWidth: true
            Label { Layout.fillWidth: true; elide: Text.ElideRight; maximumLineCount: 1; text: page.currentTransfer ? page.currentTransfer.name + " · " + page.currentTransfer.direction + " · " + page.currentTransfer.peer_name + " · " + page.currentTransfer.state + " · " + page.currentTransfer.bytes + " / " + page.currentTransfer.total_bytes + " bytes" : "" }
            ProgressBar {
                id: fileProgress
                objectName: "file-progress"
                Layout.preferredWidth: 120
                from: 0; to: Math.max(1, (page.currentTransfer || {}).total_bytes || 1); value: (page.currentTransfer || {}).bytes || 0
                background: Rectangle { implicitHeight: 8; radius: 4; color: page.theme.colors.surface_alt }
                contentItem: Item { implicitHeight: 8; Rectangle { width: parent.width * fileProgress.visualPosition; height: parent.height; radius: 4; color: page.theme.colors.accent } }
            }
            Action { text: "Cancel"; visible: !!page.currentTransfer && ["preparing", "connecting", "transferring", "verifying"].indexOf(page.currentTransfer.state) >= 0; onClicked: page.backend.action(["files", "cancel", page.currentTransfer.id]) }
        }
        Flow {
            visible: page.backend.compatible
            Layout.fillWidth: true; spacing: 6
            Action { text: "Install service"; visible: page.service.load_state !== "loaded"; onClicked: page.backend.action(["service", "install"]) }
            Action { text: page.service.unit_file_state === "enabled" ? "Disable login start" : "Enable login start"; onClicked: page.backend.action(["service", page.service.unit_file_state === "enabled" ? "disable" : "enable"]) }
            Action { text: page.service.active_state === "active" ? "Stop" : "Start"; onClicked: page.backend.action(["service", page.service.active_state === "active" ? "stop" : "start"]) }
            DirectAction { text: "Restart"; description: "Active control will close. Portal consent may be requested again."; args: ["service", "restart"] }
            DirectAction { text: page.backend.applyPending ? "Apply •" : "Apply"; prominent: page.backend.applyPending; description: "Apply saved changes and restart UKVM. Active control will close."; args: ["apply"] }
            Action { text: page.showHealthDetails ? "Back" : "Diagnostics"; onClicked: page.showHealthDetails = !page.showHealthDetails }
        }
        Label {
            id: operationMessage
            objectName: "operation-message"
            visible: !!page.backend.error || !!page.backend.notice || !!((page.backend.status.files || {}).error)
            Layout.fillWidth: true
            text: page.backend.error || (page.backend.status.files || {}).error || page.backend.notice
            color: page.backend.error ? page.theme.colors.accent : page.theme.colors.muted
            ToolTip.text: text
            ToolTip.visible: messageHover.hovered
            HoverHandler { id: messageHover }
        }
        Label {
            visible: page.backend.compatible
            Layout.fillWidth: true
            text: "Clipboard: " + Model.clipboardLabel(page.backend.status.clipboard)
                + "   ·   Remote control: " + Model.authorizationLabel(page.backend.status, "remote_desktop", page.backend.doctor)
            objectName: "clipboard-status"
            color: page.theme.colors.muted
        }
        Item {
            id: workspace
            objectName: "ukvm-workspace"
            Layout.fillWidth: true; Layout.fillHeight: true
            Label {
                anchors.centerIn: parent; width: parent.width
                visible: !page.backend.installed
                text: "Install the SpectrumOS ukvm and spectrum-xdg-desktop-portal-hyprland packages, then refresh."
            }
            ColumnLayout {
                anchors.centerIn: parent; width: Math.min(480, parent.width)
                visible: page.backend.compatible && !!page.backend.status.health && !page.backend.status.health.identity_initialized
                Label { text: "SET UP THIS COMPUTER"; font.bold: true; color: page.theme.colors.accent }
                Label { text: "Choose a name to get started." }
                RowLayout {
                    Layout.fillWidth: true
                    Field { id: nodeName; objectName: "setupNodeName"; Layout.fillWidth: true; placeholderText: (page.backend.status.node || {}).name || "Computer name"; maximumLength: 63 }
                    Action { objectName: "initializeNode"; text: "Set up"; prominent: true; onClicked: page.backend.action(["setup", "--local", "--name", nodeName.text.trim() || (page.backend.status.node || {}).name || "My computer"]) }
                }
            }
            RowLayout {
                anchors.fill: parent; spacing: 12
                visible: page.backend.compatible && !page.showHealthDetails && !page.backend.pairing && ((page.backend.status.health || {}).identity_initialized !== false)
                ColumnLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Label { text: "YOUR MACHINES"; font.bold: true; color: page.theme.colors.accent }
                    Label { text: "Select a computer, then + to move it."; Layout.fillWidth: true; color: page.theme.colors.muted }
                    Item {
                        id: topology
                        objectName: "topology"
                        Layout.fillWidth: true; Layout.fillHeight: true
                        readonly property real cellWidth: Math.min(145, (width - 8) / 5)
                        readonly property real cellHeight: Math.min(62, (height - 8) / 5)
                    Repeater {
                        model: Model.slots()
                        delegate: Button {
                            id: machine
                            required property var modelData
                            readonly property var node: Model.nodeAt(page.nodes, modelData.x, modelData.y)
                            readonly property var peer: node && !node.local ? Model.peerAt(page.peers, node.node_id) : null
                            readonly property bool local: modelData.x === 0 && modelData.y === 0
                            readonly property bool selected: !!node && page.selectedId === node.node_id
                            readonly property string machineState: local ? "THIS COMPUTER" : node ? Model.availability(peer).toUpperCase() : ""
                            x: topology.width / 2 + modelData.x * topology.cellWidth - width / 2
                            y: topology.height / 2 + modelData.y * topology.cellHeight - height / 2
                            width: topology.cellWidth - 8; height: topology.cellHeight - 8
                            enabled: !page.backend.busy && (!!node || !!page.selected)
                            focusPolicy: Qt.StrongFocus
                            Keys.onReturnPressed: event => { if (enabled && !event.isAutoRepeat) clicked(); }
                            Keys.onEnterPressed: event => { if (enabled && !event.isAutoRepeat) clicked(); }
                            Accessible.name: (node ? node.name || "Untrusted placement" : "Empty position") + " " + modelData.x + ", " + modelData.y + " " + machineState
                            onClicked: {
                                if (local) page.selectedId = "";
                                else if (node) page.selectedId = node.node_id;
                                else page.place(modelData.x, modelData.y);
                            }
                            background: Rectangle {
                                radius: 8
                                color: machine.local ? page.theme.colors.accent : page.theme.colors.surface_alt
                                border.width: machine.selected || machine.activeFocus ? 2 : 1
                                border.color: machine.selected || machine.activeFocus ? page.theme.colors.accent : page.theme.colors.muted
                                opacity: machine.node || machine.local ? 1 : 0.45
                            }
                            contentItem: Column {
                                anchors.centerIn: parent
                                spacing: 3
                                Label {
                                    width: machine.width - 12
                                    text: machine.local ? ((page.backend.status.node || {}).name || "Local computer") : machine.node ? (machine.node.name || "Missing trust") : "+"
                                    color: machine.local ? page.theme.colors.background : page.theme.colors.foreground
                                    horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; wrapMode: Text.NoWrap; font.bold: true; font.pixelSize: Math.min(page.uiFontSize, Math.max(9, topology.cellHeight * 0.24))
                                }
                                Label { visible: !!machine.machineState; width: machine.width - 12; text: machine.machineState; color: machine.local ? page.theme.colors.background : page.theme.colors.muted; horizontalAlignment: Text.AlignHCenter; font.pixelSize: Math.max(9, page.uiFontSize - 3); wrapMode: Text.NoWrap; elide: Text.ElideRight }
                            }
                        }
                    }

                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Action { text: "‹"; visible: page.peers.length > page.peerPageSize; enabled: page.peerPage > 0; onClicked: page.peerPage-- }
                        Repeater {
                            model: page.listedPeers
                            delegate: Action {
                                required property var modelData
                                objectName: "peer-" + modelData.node_id
                                Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.minimumWidth: 0
                                text: modelData.name; prominent: page.selectedId === modelData.node_id
                                onClicked: page.selectedId = modelData.node_id
                            }
                        }
                        Action { text: "›"; visible: page.peers.length > page.peerPageSize; enabled: (page.peerPage + 1) * page.peerPageSize < page.peers.length; onClicked: page.peerPage++ }
                        Label { visible: !page.peers.length; text: "No paired computers yet."; Layout.fillWidth: true; color: page.theme.colors.muted }
                    }
                    RowLayout {
                        objectName: "files-actions"
                        visible: true
                        Layout.fillWidth: true
                        Label { Layout.fillWidth: true; maximumLineCount: 1; text: page.selected ? "Send to " + page.selected.name : "Select a computer to send files"; color: page.theme.colors.muted }
                        Action { objectName: "send-files"; text: "Send files"; enabled: !!page.selected && ((page.selected || {}).permissions || {}).connect === true && page.backend.compatible && !page.backend.sending && !page.backend.busy && !!page.backend.status.files && page.backend.status.files.state !== "restart_required"; onClicked: page.openPicker("files") }
                        Action { objectName: "send-folder"; text: "Send folder"; enabled: !!page.selected && ((page.selected || {}).permissions || {}).connect === true && page.backend.compatible && !page.backend.sending && !page.backend.busy && !!page.backend.status.files && page.backend.status.files.state !== "restart_required"; onClicked: page.openPicker("folder") }
                    }
                }
                Rectangle {
                    id: peerPanel
                    objectName: "peer-panel"
                    Layout.preferredWidth: Math.min(310, page.width * 0.37)
                    Layout.fillHeight: true
                    radius: 12; color: page.theme.colors.surface_alt
                    ColumnLayout {
                        id: inspector
                        anchors { fill: parent; margins: 12 }
                        spacing: 5
                        Label { Layout.fillWidth: true; text: page.selected ? page.selected.name : "Select a computer"; font.bold: true; color: page.theme.colors.accent }
                        Label { Layout.fillWidth: true; text: page.selected ? Model.availability(page.selected) : "Select a trusted machine to manage permissions and position."; color: page.theme.colors.muted }
                        Action { objectName: "open-remote"; text: "Open remote screen"; visible: !!page.selected && !page.showDetails; Layout.fillWidth: true; enabled: !!page.selected && ((page.selected || {}).permissions || {}).connect === true && page.backend.compatible && !page.backend.busy; onClicked: page.backend.action(["remote", page.selectedId]); ToolTip.text: "View this peer's desktop. The peer must allow screen viewing; click its desktop to control it."; ToolTip.visible: hovered }
                        ClipboardToggle { permissionKey: "view_screen"; permissionArg: "view-screen"; permissionTitle: "Share this screen"; permissionHelp: "Allow this trusted peer to view this computer's screen. Control is separate. Portal consent is still required."; statusKey: "runtime"; visible: !!page.selected && !page.showDetails; Layout.fillWidth: true }
                        ClipboardToggle { permissionKey: "receive_files"; permissionArg: "receive-files"; permissionTitle: "Receive files"; permissionHelp: "Allow this trusted computer to send files here without asking for each transfer. Changes apply immediately."; statusKey: "files"; visible: !!page.selected && !page.showDetails; Layout.fillWidth: true }
                        ClipboardToggle { visible: !!page.selected && !page.showDetails; Layout.fillWidth: true }
                        Label { visible: !!page.selected && !page.showDetails; Layout.fillWidth: true; text: "This peer may control here: " + Model.permissionLabel(((page.selected || {}).permissions || {}).control_this_node) }
                        DirectAction {
                            visible: !!page.selected && !page.showDetails
                            text: (page.selected || {}).permissions && page.selected.permissions.control_this_node ? "Revoke control" : "Allow control"
                            description: "Allow " + ((page.selected || {}).name || "this peer") + " to control this computer and apply. Revoking requires Apply. Portal approval remains separate."
                            args: ["peer", ((page.selected || {}).permissions || {}).control_this_node ? "deny" : "allow", page.selectedId, "control-this-node"]
                        }

                        Flow {
                            visible: !!page.selected
                            Layout.fillWidth: true; spacing: 6
                            DirectAction { text: "Remove position"; visible: !!page.selected && !!page.selected.position && !page.showDetails; description: "Remove this position and retain trust."; args: ["layout", "remove", page.selectedId, "--yes"] }
                            DirectAction { visible: !page.showDetails; text: "Unpair"; description: "Remove local trust and placement. The other computer retains its trust."; args: ["unpair", page.selectedId, "--yes"] }
                            Action { text: page.showDetails ? "Less" : "Details"; onClicked: page.showDetails = !page.showDetails }
                        }
                        Label { visible: page.showDetails && !!page.selected; Layout.fillWidth: true; text: page.selected ? (page.selected.endpoint || "No endpoint hint") + " · " + (page.selected.position ? "(" + page.selected.position.x + ", " + page.selected.position.y + ")" : "unplaced") : "" }
                        Label { visible: page.showDetails && !!page.selected; Layout.fillWidth: true; maximumLineCount: 3; wrapMode: Text.WrapAnywhere; text: "Node ID: " + page.selectedId; font.pixelSize: Math.min(12, page.uiFontSize) }
                        Label { visible: !!page.selectedNode && !page.selected; text: "This placement has no trusted peer."; Layout.fillWidth: true; color: page.theme.colors.accent }
                        DirectAction { visible: !!page.selectedNode && !page.selected; text: "Remove position"; description: "Remove the untrusted position."; args: ["layout", "remove-position", String((page.selectedNode || {}).x), String((page.selectedNode || {}).y), "--yes"] }
                        Item { Layout.fillHeight: true }
                    }
                }
            }
            Rectangle {
                anchors.fill: parent; radius: 12; color: page.theme.colors.surface_alt
                visible: page.showHealthDetails && !page.backend.pairing
                ColumnLayout {
                    anchors { fill: parent; margins: 12 }
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        Action { text: "Overview"; prominent: page.healthPage === 0; onClicked: page.healthPage = 0 }
                        Action { text: "Authorization"; prominent: page.healthPage === 1; onClicked: page.healthPage = 1 }
                        Action { text: "Backend"; prominent: page.healthPage === 2; onClicked: page.healthPage = 2 }
                    }
                    Label { visible: page.healthPage === 0; Layout.fillWidth: true; text: Model.healthLabel(page.backend.status, page.backend.doctor); color: page.theme.colors.accent }
                    Label { visible: page.healthPage === 0; Layout.fillWidth: true; text: (page.backend.applyPending ? "Saved changes require Apply. " : "") + "Enable controls future logins; Start controls this session." }
                    Label { visible: page.healthPage === 0; Layout.fillWidth: true; maximumLineCount: 4; text: "Runtime: " + ((page.backend.status.runtime || {}).error || (page.backend.status.runtime || {}).state || "unknown") + "\nService: " + (page.service.error || page.service.active_state || "unavailable") + "\nClipboard: " + ((page.backend.status.clipboard || {}).error || Model.clipboardLabel(page.backend.status.clipboard)); color: page.theme.colors.muted }
                    Label { visible: page.healthPage === 0; Layout.fillWidth: true; maximumLineCount: 3; wrapMode: Text.WrapAnywhere; text: "Local Node ID: " + ((page.backend.status.node || {}).node_id || "not initialized") }
                    Label { visible: page.healthPage === 1; Layout.fillWidth: true; text: "Screen sharing authorization: " + Model.authorizationLabel(page.backend.status, "screen_cast", page.backend.doctor) }
                    Label { visible: page.healthPage === 1; Layout.fillWidth: true; text: "Remote control authorization: " + Model.authorizationLabel(page.backend.status, "remote_desktop", page.backend.doctor) }
                    Label { visible: page.healthPage === 1; Layout.fillWidth: true; text: "Input capture authorization: " + Model.authorizationLabel(page.backend.status, "input_capture", page.backend.doctor) }
                    DirectAction { visible: page.healthPage === 1 && !!page.backend.status.desktop_authorization; text: "Forget approval"; description: "Stop UKVM and forget desktop authorization. Portal approval will be required again. Peer permissions stay unchanged."; args: ["authorization", "reset", "--yes"] }
                    Label { visible: page.healthPage === 1; Layout.fillWidth: true; text: "Portal consent and peer permissions are independent. Capability checks never approve consent."; color: page.theme.colors.muted }
                    Label { visible: page.healthPage === 2; Layout.fillWidth: true; maximumLineCount: 6; text: page.backendProblems.join("\n") || "Wayland backend ready"; color: page.theme.colors.accent }
                    Label { visible: page.healthPage === 2; Layout.fillWidth: true; maximumLineCount: 3; text: "Update the managed SpectrumOS portal package if missing or incompatible, then log out and back in. Hyprland partial external-edge barriers remain a platform limitation."; color: page.theme.colors.muted }
                    RowLayout {
                        visible: page.healthPage === 2; Layout.fillWidth: true
                        Field { id: endpoint; Layout.fillWidth: true; placeholderText: "Pair directly: host[:port]"; enabled: !page.backend.busy }
                        Action { text: "Pair"; enabled: !page.backend.busy && page.backend.compatible && !!endpoint.text.trim(); onClicked: page.backend.startPair(endpoint.text.trim(), "") }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
            Rectangle {
                anchors.fill: parent; radius: 12; color: page.theme.colors.surface_alt
                visible: page.backend.pairing
                ColumnLayout {
                    anchors { fill: parent; margins: 16 }
                    spacing: 10
                    Label { text: page.backend.pairingPhase; Layout.fillWidth: true; color: page.theme.colors.accent }
                    Label { visible: !!page.backend.offer; text: (page.backend.offer || {}).remote_name || ""; Layout.fillWidth: true; font.bold: true }
                    Label { visible: !!page.backend.offer; text: (page.backend.offer || {}).verification_code || ""; font.pixelSize: page.uiFontSize + 16; color: page.theme.colors.accent; Layout.fillWidth: true }
                    Label { visible: !!page.backend.offer; text: "Only approve if the code matches on BOTH machines. Both users must approve. Trust never grants control or clipboard permission automatically."; maximumLineCount: 3; Layout.fillWidth: true }
                    Flow {
                        Layout.fillWidth: true; spacing: 8
                        Action { objectName: "approvePairing"; text: "Codes match · Trust machine"; prominent: true; enabled: page.backend.pairing && !!page.backend.offer; onClicked: page.backend.approve(true) }
                        Action { objectName: "rejectPairing"; text: "Reject"; enabled: page.backend.pairing && !!page.backend.offer; onClicked: page.backend.approve(false) }
                        Action { text: "Cancel"; enabled: page.backend.pairing; onClicked: page.backend.cancelPair() }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }
        ColumnLayout {
            id: discovery
            objectName: "discovery-panel"
            visible: page.backend.compatible && !page.backend.pairing && !page.showHealthDetails && ((page.backend.status.health || {}).identity_initialized !== false)
            Layout.fillWidth: true; spacing: 4
            RowLayout {
                Layout.fillWidth: true
                Label { text: "NEARBY MACHINES"; font.bold: true; color: page.theme.colors.accent; Layout.fillWidth: true }
                Action { text: page.backend.discovering ? "Discovering…" : "Discover"; onClicked: page.backend.run(["discover"]) }
                Action { text: "Receive pairing"; onClicked: page.backend.startPair("", "") }
                Action { text: "‹"; visible: page.discoveredMachines.length > 2; enabled: page.discoveryPage > 0; onClicked: page.discoveryPage-- }
                Action { text: "›"; visible: page.discoveredMachines.length > 2; enabled: (page.discoveryPage + 1) * 2 < page.discoveredMachines.length; onClicked: page.discoveryPage++ }
            }
            Label { visible: !page.discoveredMachines.length; Layout.fillWidth: true; text: page.backend.discovering ? "Looking for computers…" : "Discover computers, or receive a pairing request."; color: page.theme.colors.muted }
            Repeater {
                model: page.listedMachines
                delegate: RowLayout {
                    id: discoveryMachine
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Label { objectName: "discovery-name-" + discoveryMachine.index; Layout.fillWidth: true; text: discoveryMachine.modelData.name }
                    Action { text: "Pair"; enabled: !page.backend.busy && discoveryMachine.modelData.pairing_available === true && (discoveryMachine.modelData.addresses || []).length > 0; onClicked: page.backend.startPair(discoveryMachine.modelData.addresses[0], discoveryMachine.modelData.advertised_node_id || "") }
                }
            }
        }
        Label { visible: page.backend.compatible && !!page.backend.status.layout && !page.backend.status.layout.valid; text: "Topology needs attention. Select the affected machine to remove its position."; Layout.fillWidth: true; color: page.theme.colors.accent }
        Label { visible: page.backend.recovery.some(r => r.state !== "complete"); text: "Interrupted pairing: inspect ukvm pair status --json for explicit recovery."; Layout.fillWidth: true; color: page.theme.colors.accent }
    }
}
