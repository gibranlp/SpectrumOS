pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell.Io

ColumnLayout {
    id: vpn
    required property var theme
    property bool active: false
    property bool expanded: false
    property var state: ({installed: false, connected: false, status: "Checking Proton VPN…"})
    property string message: ""
    readonly property bool busy: statusProcess.running || actionProcess.running
    function refresh(): void {
        if (active && expanded && !statusProcess.running && !actionProcess.running)
            statusProcess.running = true;
    }
    function perform(operation, value): void {
        if (busy) return;
        message = "";
        const command = [theme.backend("network-adapter"), operation];
        if (value) command.push(value);
        actionProcess.exec(command);
    }
    onActiveChanged: {
        if (!active) expanded = false;
        else refresh();
    }
    onExpandedChanged: refresh()
    Component.onCompleted: refresh()
    Process {
        id: statusProcess
        command: [vpn.theme.backend("network-adapter"), "vpn-status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { vpn.state = JSON.parse(text); }
                catch (e) { vpn.state = {installed: true, connected: false, status: "Could not read Proton VPN status"}; }
            }
        }
    }
    Process {
        id: actionProcess
        stdout: StdioCollector { onStreamFinished: { if (text.trim()) vpn.message = text.trim(); } }
        stderr: StdioCollector { onStreamFinished: { if (text.trim()) vpn.message = text.trim(); } }
        onExited: vpn.refresh()
    }
    Timer { interval: 10000; repeat: true; running: vpn.active && vpn.expanded; onTriggered: vpn.refresh() }
    ShellButton {
        objectName: "proton-vpn-toggle"
        label: "Proton VPN"
        backgroundColor: vpn.expanded ? vpn.theme.colors.accent : vpn.theme.colors.surface_alt
        foregroundColor: vpn.expanded ? vpn.theme.colors.background : vpn.theme.colors.foreground
        onClicked: vpn.expanded = !vpn.expanded
    }
    ColumnLayout {
        objectName: "proton-vpn-details"
        Layout.fillWidth: true
        visible: vpn.expanded
        Text {
            Layout.fillWidth: true
            text: qsTranslate("Spectrum", vpn.state.status)
            wrapMode: Text.WordWrap
            color: vpn.theme.colors.foreground
            font { family: vpn.theme.fontFamily; pixelSize: vpn.theme.fontSize - 1 }
        }
        ColumnLayout {
            visible: vpn.state.installed
            Layout.fillWidth: true
            enabled: !vpn.busy
            Controls.TextField {
                id: country
                objectName: "proton-country"
                Layout.fillWidth: true
                placeholderText: qsTranslate("Spectrum", "Country code (US, MX); empty = fastest")
                maximumLength: 2
                validator: RegularExpressionValidator { regularExpression: /[A-Za-z]{0,2}/ }
                color: vpn.theme.colors.foreground
                font.family: vpn.theme.fontFamily
                background: Rectangle { color: vpn.theme.colors.surface_alt; radius: 6 }
            }
            RowLayout {
                ShellButton {
                    label: qsTranslate("Spectrum", "Sign in")
                    onClicked: vpn.perform("vpn-signin", "")
                }
                ShellButton {
                    enabled: vpn.state.signed_in === true
                    label: vpn.state.connected ? qsTranslate("Spectrum", "Disconnect") : qsTranslate("Spectrum", "Connect")
                    onClicked: vpn.perform(vpn.state.connected ? "vpn-disconnect" : "vpn-connect", country.text.trim())
                }
                ShellButton {
                    enabled: vpn.state.signed_in === true
                    label: qsTranslate("Spectrum", "Sign out")
                    onClicked: vpn.perform("vpn-signout", "")
                }
            }
            Text {
                Layout.fillWidth: true
                text: qsTranslate("Spectrum", "Sign in opens a terminal for your password and two-factor code. Country selection and NetShield depend on your plan.")
                wrapMode: Text.WordWrap
                color: vpn.theme.colors.muted
                font { family: vpn.theme.fontFamily; pixelSize: vpn.theme.fontSize - 2 }
            }
            RowLayout {
                ShellButton { label: qsTranslate("Spectrum", "View settings"); onClicked: vpn.perform("vpn-settings", "") }
                ShellButton { label: qsTranslate("Spectrum", "Kill switch on"); onClicked: vpn.perform("vpn-config", "kill-switch:standard") }
                ShellButton { label: qsTranslate("Spectrum", "Off"); onClicked: vpn.perform("vpn-config", "kill-switch:off") }
            }
            RowLayout {
                ShellButton { label: qsTranslate("Spectrum", "Block ads / malware"); onClicked: vpn.perform("vpn-config", "netshield:malware-ads-trackers") }
                ShellButton { label: qsTranslate("Spectrum", "NetShield off"); onClicked: vpn.perform("vpn-config", "netshield:off") }
            }
        }
        Text {
            Layout.fillWidth: true
            visible: actionProcess.running || vpn.message.length > 0
            text: actionProcess.running ? qsTranslate("Spectrum", "Working…") : vpn.message
            wrapMode: Text.WrapAnywhere
            color: vpn.theme.colors.foreground
            font { family: vpn.theme.fontFamily; pixelSize: vpn.theme.fontSize - 2 }
        }
    }
}
