import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Spectrum.I18n 1.0

ShellRoot {
    id: shell
    readonly property var languageController: Translator
    property var colors: ({ background: "#111827", surface: "#1e293b", foreground: "#f8fafc", muted: "#a6b0c0", accent: "#70a0d0" })
    property var network: ({ available: false, wifi_enabled: false, status: "Checking network…", networks: [] })
    property string pendingPassword: ""
    property string actionError: ""
    property string clockText: Qt.formatDateTime(new Date(), "ddd d MMM  HH:mm")

    FileView {
        path: "/usr/share/spectrumos/installer/palette.json"
        onTextChanged: {
            try {
                const palette = JSON.parse(text());
                if (palette.roles)
                    shell.colors = palette.roles;
            } catch (error) {
                console.warn("Live shell palette:", error);
            }
        }
    }

    Process {
        id: networkProcess
        command: ["/usr/local/lib/spectrumos/network-adapter", "--json"]
        stdout: StdioCollector { onStreamFinished: {
            try { shell.network = JSON.parse(text); }
            catch (error) { shell.actionError = "Could not read network status"; }
        } }
    }

    Process {
        id: actionProcess
        stdinEnabled: true
        onStarted: {
            if (shell.pendingPassword) {
                write(shell.pendingPassword + "\n");
                shell.pendingPassword = "";
            }
        }
        stderr: StdioCollector { onStreamFinished: {
            if (text.trim())
                shell.actionError = text.trim().split("\n")[0];
        } }
        onExited: (exitCode) => {
            shell.pendingPassword = "";
            if (exitCode !== 0 && !shell.actionError)
                shell.actionError = "Network action failed";
            if (!networkProcess.running)
                networkProcess.running = true;
        }
    }

    function networkAction(args, password): void {
        if (actionProcess.running)
            return;
        actionError = "";
        pendingPassword = password || "";
        actionProcess.exec(["/usr/local/lib/spectrumos/network-adapter", ...args]);
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            shell.clockText = Qt.formatDateTime(new Date(), "ddd d MMM  HH:mm");
            if (!networkProcess.running && !actionProcess.running)
                networkProcess.running = true;
        }
    }

    IpcHandler {
        target: "spectrum-live"
        function toggleNetwork(): void {
            if (bars.instances.length)
                bars.instances[0].networkOpen = !bars.instances[0].networkOpen;
        }
    }

    Variants {
        id: bars
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData
            property bool networkOpen: false
            property string selectedSsid: ""
            property bool passwordOpen: false
            anchors { top: true; left: true; right: true }
            implicitHeight: 40
            color: shell.colors.surface
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "spectrum-live-bar"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: installLabel.implicitWidth + 22
                    Layout.preferredHeight: 30
                    radius: 9
                    color: shell.colors.accent
                    Text {
                        id: installLabel
                        anchors.centerIn: parent
                        text: qsTranslate("Spectrum", "Install SpectrumOS")
                        color: shell.colors.background
                        font { pixelSize: 13; bold: true }
                    }
                    MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["/usr/local/bin/spectrum-installer"]) }
                }

                Text {
                    text: qsTranslate("Spectrum", "Rescue system")
                    color: shell.colors.foreground
                    font.pixelSize: 13
                    MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["uwsm", "app", "--", "foot", "--title=Rescue system", "-e", "/usr/local/bin/spectrum-rescue-shell"]) }
                }

                Item { Layout.fillWidth: true }
                Text { text: shell.clockText; color: shell.colors.foreground; font.pixelSize: 13 }
                Item { Layout.fillWidth: true }

                Text {
                    text: qsTranslate("Spectrum", shell.network.status || "Network unavailable")
                    color: shell.colors.foreground
                    font.pixelSize: 13
                    MouseArea { anchors.fill: parent; onClicked: bar.networkOpen = !bar.networkOpen }
                }

                Repeater {
                    model: SystemTray.items
                    Item {
                        required property var modelData
                        Layout.preferredWidth: 23
                        Layout.preferredHeight: 28
                        Image { anchors.centerIn: parent; width: 18; height: 18; source: modelData.icon; fillMode: Image.PreserveAspectFit }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton || modelData.onlyMenu)
                                    modelData.display(bar, parent.x, parent.y + parent.height);
                                else
                                    modelData.activate();
                            }
                        }
                    }
                }
            }

            PanelWindow {
                id: networkWindow
                screen: bar.screen
                visible: bar.networkOpen
                focusable: true
                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "spectrum-live-network"
                color: "transparent"

                MouseArea { anchors.fill: parent; onClicked: bar.networkOpen = false }

                Rectangle {
                    width: Math.min(390, networkWindow.width - 24)
                    height: Math.min(540, networkWindow.height - 72)
                    x: networkWindow.width - width - 12
                    y: 46
                    radius: 15
                    color: shell.colors.surface
                    border { color: shell.colors.accent; width: 1 }
                    MouseArea { anchors.fill: parent; onClicked: {} }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTranslate("Spectrum", "Network"); color: shell.colors.foreground; font { pixelSize: 18; bold: true } }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: shell.network.wifi_enabled ? qsTranslate("Spectrum", "Wi-Fi on") : qsTranslate("Spectrum", "Wi-Fi off")
                                color: shell.colors.accent
                                MouseArea { anchors.fill: parent; onClicked: shell.networkAction(["toggle"]) }
                            }
                        }
                        Text { text: shell.network.status || qsTranslate("Spectrum", "Unavailable"); color: shell.colors.muted; font.pixelSize: 12 }
                        Text {
                            visible: shell.actionError.length > 0
                            text: shell.actionError
                            color: "#ff8d8d"
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                            font.pixelSize: 12
                        }
                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 4
                            model: shell.network.networks || []
                            delegate: Rectangle {
                                required property var modelData
                                width: ListView.view.width
                                height: 45
                                radius: 8
                                color: modelData.active ? shell.colors.accent : shell.colors.background
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    Text {
                                        text: modelData.ssid
                                        color: modelData.active ? shell.colors.background : shell.colors.foreground
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: modelData.active ? qsTranslate("Spectrum", "Connected") : modelData.security + " · " + modelData.signal + "%"
                                        color: modelData.active ? shell.colors.background : shell.colors.muted
                                        font.pixelSize: 11
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        if (modelData.active)
                                            return;
                                        if (modelData.saved)
                                            shell.networkAction(["connect", modelData.uuid]);
                                        else if (modelData.security === "Open")
                                            shell.networkAction(["connect-open", modelData.ssid]);
                                        else {
                                            bar.selectedSsid = modelData.ssid;
                                            bar.passwordOpen = true;
                                            passwordInput.text = "";
                                            passwordInput.forceActiveFocus();
                                        }
                                    }
                                }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: bar.passwordOpen ? 74 : 0
                            visible: bar.passwordOpen
                            radius: 8
                            color: shell.colors.background
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                Text { text: qsTranslate("Spectrum", "Password for ") + bar.selectedSsid; color: shell.colors.foreground; font.pixelSize: 12 }
                                TextInput {
                                    id: passwordInput
                                    Layout.fillWidth: true
                                    color: shell.colors.foreground
                                    echoMode: TextInput.Password
                                    font.pixelSize: 14
                                    onAccepted: {
                                        if (text.length) {
                                            shell.networkAction(["connect-secured", bar.selectedSsid], text);
                                            text = "";
                                            bar.passwordOpen = false;
                                        }
                                    }
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: qsTranslate("Spectrum", "Rescan"); color: shell.colors.accent; MouseArea { anchors.fill: parent; onClicked: shell.networkAction(["rescan"]) } }
                            Item { Layout.fillWidth: true }
                            Text { text: qsTranslate("Spectrum", "Connection editor"); color: shell.colors.accent; MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(["nm-connection-editor"]) } }
                        }
                    }
                }
            }
        }
    }
}
