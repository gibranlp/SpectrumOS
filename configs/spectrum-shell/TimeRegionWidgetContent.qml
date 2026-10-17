import QtQuick
import QtQuick.Layouts
import Quickshell.Io

ColumnLayout {
    id: content
    required property var theme
    property bool active: false
    property var settings: ({ available: false, timezones: [], locales: [] })
    property string error: ""
    property string message: ""
    property string picker: ""
    property string selectedZone: ""
    property string selectedLanguage: ""
    property string selectedRegion: ""
    property bool serversEdited: false
    property date now: new Date()
    readonly property bool busy: action.running
    spacing: 9

    function refresh(): void {
        if (!status.running)
            status.running = true;
    }
    function apply(args): void {
        if (busy)
            return;
        error = "";
        message = "";
        action.exec([theme.backend("time-region-adapter"), ...args]);
    }
    function choose(kind): void {
        picker = picker === kind ? "" : kind;
        search.text = "";
    }
    onActiveChanged: {
        if (active) {
            selectedZone = "";
            selectedLanguage = "";
            selectedRegion = "";
            picker = "";
            serversEdited = false;
            now = new Date();
            manual.text = Qt.formatDateTime(now, "yyyy-MM-dd HH:mm:ss");
            refresh();
        }
    }

    Process {
        id: status
        command: [content.theme.backend("time-region-adapter"), "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    content.settings = JSON.parse(text);
                    if (!content.serversEdited)
                        servers.text = content.settings.servers || "";
                } catch (error) {
                    content.error = "Could not read time settings";
                }
            }
        }
    }
    Timer { interval: 10000; running: content.active && !content.busy; repeat: true; onTriggered: content.refresh() }
    Timer { interval: 1000; running: content.active; repeat: true; onTriggered: content.now = new Date() }
    Process {
        id: action
        stdout: StdioCollector { onStreamFinished: content.message = text.trim() }
        stderr: StdioCollector { onStreamFinished: content.error = text.trim() }
        onExited: (code) => {
            if (code !== 0 && !content.error)
                content.error = "Time settings could not be updated";
            if (code === 0) {
                content.selectedZone = "";
                content.selectedLanguage = "";
                content.selectedRegion = "";
                content.serversEdited = false;
            }
            content.refresh();
        }
    }

    component Label: Text {
        Layout.fillWidth: true
        color: content.theme.colors.foreground
        font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize }
        wrapMode: Text.Wrap
    }
    component Button: ShellButton {
        fontFamily: content.theme.fontFamily
        fontSize: content.theme.fontSize - 1
        backgroundColor: content.theme.colors.surface_alt
        foregroundColor: content.theme.colors.foreground
        enabled: content.settings.available && !content.busy
    }
    component Input: Rectangle {
        property alias text: input.text
        property string placeholder: ""
        signal edited()
        Layout.fillWidth: true
        implicitHeight: 36
        radius: 8
        color: content.theme.colors.surface_alt
        TextInput {
            activeFocusOnTab: true
            id: input
            anchors { fill: parent; margins: 9 }
            color: content.theme.colors.foreground
            font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize - 1 }
            clip: true
            selectByMouse: true
            enabled: !content.busy
            onTextEdited: parent.edited()
            Text {
                text: parent.parent.placeholder
                visible: !parent.text.length
                color: content.theme.colors.muted
                font: parent.font
            }
        }
    }

    Label { text: Qt.formatDateTime(content.now, "ddd d MMM yyyy  HH:mm:ss"); font.bold: true }
    Label {
        text: content.settings.available ? (content.settings.timezone || "") + "\n" +
            (content.settings.ntp ? (content.settings.synchronized ? "Automatic time · synchronized" : "Automatic time · waiting for synchronization") : "Manual time") :
            (content.settings.error || "Reading time settings…")
        color: content.theme.colors.accent
    }
    RowLayout {
        Layout.fillWidth: true
        Button {
            Layout.fillWidth: true
            label: content.settings.ntp ? "Turn automatic time off" : "Turn automatic time on"
            enabled: content.settings.available && content.settings.can_ntp && !content.busy
            onClicked: content.apply(["ntp", content.settings.ntp ? "off" : "on"])
        }
        Button { label: "Refresh"; enabled: !content.busy; onClicked: content.refresh() }
    }

    Label { text: "TIME ZONE"; font.bold: true }
    RowLayout {
        Layout.fillWidth: true
        Button { Layout.fillWidth: true; label: content.selectedZone || content.settings.timezone || "Choose time zone"; onClicked: content.choose("timezone") }
        Button { label: "Apply"; enabled: !!content.selectedZone && !content.busy; onClicked: content.apply(["timezone", content.selectedZone]) }
    }
    Label { text: "LANGUAGE & REGION"; font.bold: true }
    Label { text: "Language"; color: content.theme.colors.muted }
    Button { Layout.fillWidth: true; label: content.selectedLanguage || content.settings.language || "Choose language"; onClicked: content.choose("language") }
    Label { text: "Regional formats · dates, numbers and currency"; color: content.theme.colors.muted }
    Button { Layout.fillWidth: true; label: content.selectedRegion || content.settings.region || "Choose region"; onClicked: content.choose("region") }

    ColumnLayout {
        Layout.fillWidth: true
        visible: content.picker.length > 0
        Input { id: search; placeholder: content.picker === "timezone" ? "Search city or time zone…" : "Search locale, e.g. en_US or es_MX…" }
        ListView {
            id: choices
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(160, contentHeight)
            clip: true
            spacing: 4
            model: (content.picker === "timezone" ? content.settings.timezones || [] : content.settings.locales || []).filter(name => name.toLowerCase().includes(search.text.toLowerCase()))
            delegate: Button {
                required property string modelData
                width: choices.width
                label: modelData.replace(/_/g, " ")
                onClicked: {
                    if (content.picker === "timezone") content.selectedZone = modelData;
                    else if (content.picker === "language") content.selectedLanguage = modelData;
                    else content.selectedRegion = modelData;
                    content.picker = "";
                }
            }
            onModelChanged: positionViewAtBeginning()
        }
        Label { visible: choices.count === 0; text: "No matching results"; color: content.theme.colors.muted }
    }
    Button {
        Layout.fillWidth: true
        label: "Apply language and region"
        enabled: !content.busy && (!!content.selectedLanguage || !!content.selectedRegion)
        onClicked: content.apply(["locale", content.selectedLanguage || content.settings.language, content.selectedRegion || content.settings.region])
    }
    Label { text: "Regional changes apply to all applications after signing out."; color: content.theme.colors.muted; font.pixelSize: content.theme.fontSize - 2 }

    Label { text: "NTP SERVERS"; font.bold: true }
    Label {
        text: content.settings.server ? "Connected to " + content.settings.server + (content.settings.server_address ? " · " + content.settings.server_address : "") : "No active server"
        color: content.theme.colors.muted
    }
    Input { id: servers; visible: !!content.settings.server_controls; placeholder: "Default servers (or enter hostnames / IPs)"; onEdited: content.serversEdited = true }
    RowLayout {
        Layout.fillWidth: true
        visible: !!content.settings.server_controls
        Button { Layout.fillWidth: true; label: "Save servers"; onClicked: content.apply(["servers", servers.text]) }
        Button { label: "Use defaults"; onClicked: content.apply(["servers", ""]) }
    }
    Label {
        text: content.settings.server_controls ? "Separate servers with spaces. Saving reconnects automatic time when it is running." : "Custom server settings require systemd-timesyncd."
        color: content.theme.colors.muted
        font.pixelSize: content.theme.fontSize - 2
    }
    Label { visible: !!content.settings.fallback_servers; text: "Fallback: " + (content.settings.fallback_servers || ""); color: content.theme.colors.muted; font.pixelSize: content.theme.fontSize - 2 }

    Label { visible: !content.settings.ntp && content.settings.available; text: "MANUAL DATE & TIME"; font.bold: true }
    Input { id: manual; visible: !content.settings.ntp && content.settings.available; placeholder: "YYYY-MM-DD HH:MM:SS" }
    Button { visible: !content.settings.ntp && content.settings.available; Layout.fillWidth: true; label: "Set date and time"; onClicked: content.apply(["time", manual.text]) }
    Label { text: "Hardware clock: " + (content.settings.local_rtc ? "local time" : "UTC"); color: content.theme.colors.muted; font.pixelSize: content.theme.fontSize - 2 }
    Label { visible: content.busy; text: "Applying settings…"; color: content.theme.colors.accent }
    Label { visible: !!content.message && !content.error; text: content.message; color: content.theme.colors.accent; font.pixelSize: content.theme.fontSize - 1 }
    Label { visible: !!content.error; text: content.error; color: content.theme.colors.error || "#ff8c9a"; font.pixelSize: content.theme.fontSize - 1 }
}
