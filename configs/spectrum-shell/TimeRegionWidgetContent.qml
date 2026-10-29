import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Spectrum.I18n 1.0

ColumnLayout {
    id: content
    required property var theme
    property bool active: false
    property var settings: ({ available: false, timezones: [], locales: [] })
    property string error: ""
    property string message: ""
    property string picker: ""
    signal pickerOpened(Item selector)
    property string selectedZone: ""
    property string selectedLanguage: ""
    property string selectedRegion: ""
    property bool serversEdited: false
    property date now: new Date()
    readonly property bool busy: action.running
    readonly property string interfaceLanguage: Translator.selectedLanguage
    readonly property var interfaceChoices: ["system", ...Translator.languages.map(row => row.id)]
    spacing: 9

    function interfaceName(value): string {
        if (value === "system")
            return qsTranslate("Spectrum", "Follow system");
        const language = Translator.languages.find(row => row.id === value);
        return language ? language.name : value;
    }
    function setInterfaceLanguage(value): void {
        error = "";
        message = "";
        if (!Translator.selectLanguage(value))
            error = qsTranslate("Spectrum", Translator.error);
        else
            picker = "";
    }

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
                    content.error = qsTranslate("Spectrum", "Could not read time settings");
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
                content.error = qsTranslate("Spectrum", "Time settings could not be updated");
            if (code === 0) {
                Translator.reload();
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

    component Selector: ColumnLayout {
        id: selector
        required property string kind
        objectName: "time-region-picker-" + kind
        Layout.fillWidth: true
        visible: content.picker === kind
        onHeightChanged: if (visible)
            Qt.callLater(() => { if (selector.visible) content.pickerOpened(selector); });
        onVisibleChanged: if (visible) {
            search.text = "";
            Qt.callLater(() => { if (selector.visible) content.pickerOpened(selector); });
        }
        Input { id: search; objectName: selector.visible ? "time-region-search" : ""; placeholder: selector.kind === "interface" ? qsTranslate("Spectrum", "Search interface language…") : selector.kind === "timezone" ? qsTranslate("Spectrum", "Search city or time zone…") : qsTranslate("Spectrum", "Search locale, e.g. en_US or es_MX…") }
        ListView {
            id: choices
            objectName: selector.visible ? "time-region-choices" : ""
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(160, contentHeight)
            clip: true
            spacing: 4
            model: selector.visible ? (selector.kind === "interface" ? content.interfaceChoices : selector.kind === "timezone" ? content.settings.timezones || [] : content.settings.locales || []).filter(name => (selector.kind === "interface" ? content.interfaceName(name) + " " + name : name).toLowerCase().includes(search.text.toLowerCase())) : []
            delegate: Button {
                required property string modelData
                width: choices.width
                label: selector.kind === "interface" ? content.interfaceName(modelData) : modelData.replace(/_/g, " ")
                enabled: !content.busy && (selector.kind === "interface" || content.settings.available)
                onClicked: {
                    if (selector.kind === "interface") {
                        content.setInterfaceLanguage(modelData);
                        return;
                    }
                    if (selector.kind === "timezone") content.selectedZone = modelData;
                    else if (selector.kind === "language") content.selectedLanguage = modelData;
                    else content.selectedRegion = modelData;
                    content.picker = "";
                }
            }
            onModelChanged: positionViewAtBeginning()
        }
        Label { visible: choices.count === 0; text: qsTranslate("Spectrum", "No matching results"); color: content.theme.colors.muted }
    }

    Label { text: content.now.toLocaleString(Qt.locale(Translator.region), "ddd d MMM yyyy  HH:mm:ss"); font.bold: true }
    Label {
        text: content.settings.available ? (content.settings.timezone || "") + "\n" +
            (content.settings.ntp ? (content.settings.synchronized ? qsTranslate("Spectrum", "Automatic time · synchronized") : qsTranslate("Spectrum", "Automatic time · waiting for synchronization")) : qsTranslate("Spectrum", "Manual time")) :
            (content.settings.error || qsTranslate("Spectrum", "Reading time settings…"))
        color: content.theme.colors.accent
    }
    RowLayout {
        Layout.fillWidth: true
        Button {
            Layout.fillWidth: true
            label: content.settings.ntp ? qsTranslate("Spectrum", "Turn automatic time off") : qsTranslate("Spectrum", "Turn automatic time on")
            enabled: content.settings.available && !!content.settings.can_ntp && !content.busy
            onClicked: content.apply(["ntp", content.settings.ntp ? "off" : "on"])
        }
        Button { label: qsTranslate("Spectrum", "Refresh"); enabled: !content.busy; onClicked: content.refresh() }
    }

    Label { text: qsTranslate("Spectrum", "TIME ZONE"); font.bold: true }
    RowLayout {
        Layout.fillWidth: true
        Button { objectName: "timezone-selector"; Layout.fillWidth: true; label: content.selectedZone || content.settings.timezone || qsTranslate("Spectrum", "Choose time zone"); onClicked: content.choose("timezone") }
        Button { label: qsTranslate("Spectrum", "Apply"); enabled: !!content.selectedZone && !content.busy; onClicked: content.apply(["timezone", content.selectedZone]) }
    }
    Selector { kind: "timezone" }
    Label { text: qsTranslate("Spectrum", "LANGUAGE & REGION"); font.bold: true }
    Label { text: qsTranslate("Spectrum", "Spectrum interface language"); font.bold: true }
    Button {
        objectName: "interface-language"
        Layout.fillWidth: true
        label: content.interfaceName(content.interfaceLanguage)
        enabled: !content.busy
        onClicked: content.choose("interface")
    }
    Selector { kind: "interface" }
    Label {
        text: qsTranslate("Spectrum", "Applies immediately to translated Spectrum controls. Untranslated text uses English.")
        color: content.theme.colors.muted
        font.pixelSize: content.theme.fontSize - 2
    }
    Label { text: qsTranslate("Spectrum", "System language"); color: content.theme.colors.muted }
    Button { objectName: "system-language-selector"; Layout.fillWidth: true; label: content.selectedLanguage || content.settings.language || qsTranslate("Spectrum", "Choose language"); onClicked: content.choose("language") }
    Selector { kind: "language" }
    Label { text: qsTranslate("Spectrum", "Regional formats · dates, numbers and currency"); color: content.theme.colors.muted }
    Button { objectName: "region-selector"; Layout.fillWidth: true; label: content.selectedRegion || content.settings.region || qsTranslate("Spectrum", "Choose region"); onClicked: content.choose("region") }

    Selector { kind: "region" }

    Button {
        Layout.fillWidth: true
        label: qsTranslate("Spectrum", "Apply language and region")
        enabled: !content.busy && (!!content.selectedLanguage || !!content.selectedRegion)
        onClicked: content.apply(["locale", content.selectedLanguage || content.settings.language, content.selectedRegion || content.settings.region])
    }
    Label { text: qsTranslate("Spectrum", "System language and regional formats apply to applications after signing out. Spectrum follows the system language when Follow system is selected."); color: content.theme.colors.muted; font.pixelSize: content.theme.fontSize - 2 }

    Label { text: qsTranslate("Spectrum", "NTP SERVERS"); font.bold: true }
    Label {
        text: content.settings.server ? qsTranslate("Spectrum", "Connected to %1").arg(content.settings.server) + (content.settings.server_address ? " · " + content.settings.server_address : "") : qsTranslate("Spectrum", "No active server")
        color: content.theme.colors.muted
    }
    Input { id: servers; objectName: "time-region-servers"; visible: !!content.settings.server_controls; placeholder: qsTranslate("Spectrum", "Default servers (or enter hostnames / IPs)"); onEdited: content.serversEdited = true }
    RowLayout {
        Layout.fillWidth: true
        visible: !!content.settings.server_controls
        Button { Layout.fillWidth: true; label: qsTranslate("Spectrum", "Save servers"); onClicked: content.apply(["servers", servers.text]) }
        Button { label: qsTranslate("Spectrum", "Use defaults"); onClicked: content.apply(["servers", ""]) }
    }
    Label {
        text: content.settings.server_controls ? qsTranslate("Spectrum", "Separate servers with spaces. Saving reconnects automatic time when it is running.") : qsTranslate("Spectrum", "Custom server settings require systemd-timesyncd.")
        color: content.theme.colors.muted
        font.pixelSize: content.theme.fontSize - 2
    }
    Label { visible: !!content.settings.fallback_servers; text: qsTranslate("Spectrum", "Fallback: %1").arg(content.settings.fallback_servers || ""); color: content.theme.colors.muted; font.pixelSize: content.theme.fontSize - 2 }

    Label { visible: !content.settings.ntp && content.settings.available; text: qsTranslate("Spectrum", "MANUAL DATE & TIME"); font.bold: true }
    Input { id: manual; visible: !content.settings.ntp && content.settings.available; placeholder: "YYYY-MM-DD HH:MM:SS" }
    Button { visible: !content.settings.ntp && content.settings.available; Layout.fillWidth: true; label: qsTranslate("Spectrum", "Set date and time"); onClicked: content.apply(["time", manual.text]) }
    Label { text: qsTranslate("Spectrum", "Hardware clock: %1").arg(content.settings.local_rtc ? qsTranslate("Spectrum", "local time") : "UTC"); color: content.theme.colors.muted; font.pixelSize: content.theme.fontSize - 2 }
    Label { visible: content.busy; text: qsTranslate("Spectrum", "Applying settings…"); color: content.theme.colors.accent }
    Label { objectName: "time-region-message"; visible: !!content.message && !content.error; text: qsTranslate("Spectrum", content.message); color: content.theme.colors.accent; font.pixelSize: content.theme.fontSize - 1 }
    Label { visible: !!content.error; text: qsTranslate("Spectrum", content.error); color: content.theme.colors.error || "#ff8c9a"; font.pixelSize: content.theme.fontSize - 1 }
}
