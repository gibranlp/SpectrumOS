import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell.Io

ColumnLayout {
    id: content
    required property var theme
    property bool active: false
    property var settings: ({ sensitivity: 0, scroll_factor: 1, cursor_size: 24, adaptive_cursor: false, natural_scroll: false })
    property string error: ""
    readonly property bool busy: action.running
    spacing: 10

    function refresh(): void { if (!status.running) status.running = true; }
    function apply(key, value): void {
        if (busy) return;
        error = "";
        action.exec([theme.backend("mouse-adapter"), "--set", key, String(value)]);
    }
    onActiveChanged: if (active) refresh()
    Process {
        id: status
        command: [content.theme.backend("mouse-adapter"), "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { content.settings = JSON.parse(text); }
                catch (error) { content.error = qsTranslate("Spectrum", "Could not read mouse settings"); }
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) content.error = text.trim() }
    }
    Process {
        id: action
        stderr: StdioCollector { onStreamFinished: content.error = text.trim() }
        onExited: (code) => {
            if (code !== 0 && !content.error) content.error = qsTranslate("Spectrum", "Could not apply mouse settings");
            content.refresh();
        }
    }
    Timer { interval: 3000; running: content.active && !content.busy; repeat: true; onTriggered: content.refresh() }

    component Label: Text {
        Layout.fillWidth: true
        color: content.theme.colors.foreground
        wrapMode: Text.Wrap
        font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize }
    }
    component Button: ShellButton {
        enabled: !content.busy
        fontFamily: content.theme.fontFamily
        fontSize: content.theme.fontSize - 1
        backgroundColor: content.theme.colors.surface_alt
        foregroundColor: content.theme.colors.foreground
    }
    component Slider: Controls.Slider {
        Layout.fillWidth: true
        enabled: !content.busy
        focusPolicy: Qt.StrongFocus
        palette.highlight: content.theme.colors.accent
        palette.button: content.theme.colors.surface_alt
        palette.window: content.theme.colors.surface_alt
        property string setting: ""
        onPressedChanged: if (!pressed) content.apply(setting, Math.round(value * 100) / 100)
        onMoved: if (!pressed) content.apply(setting, Math.round(value * 100) / 100)
    }

    Label { text: qsTranslate("Spectrum", "MOVEMENT SPEED"); font.bold: true; color: content.theme.colors.accent }
    Label { text: Math.round((speed.value + 1) * 100) + qsTranslate("Spectrum", "% · 100% is the default"); font.pixelSize: content.theme.fontSize - 1 }
    Slider { id: speed; setting: "sensitivity"; from: -1; to: 1; stepSize: 0.05; value: content.settings.sensitivity }
    RowLayout {
        Layout.fillWidth: true
        Label { text: qsTranslate("Spectrum", "Slower"); color: content.theme.colors.muted; font.pixelSize: content.theme.fontSize - 2 }
        Label { text: qsTranslate("Spectrum", "Faster"); horizontalAlignment: Text.AlignRight; color: content.theme.colors.muted; font.pixelSize: content.theme.fontSize - 2 }
    }
    Label { text: qsTranslate("Spectrum", "SCROLL AMOUNT"); font.bold: true; color: content.theme.colors.accent }
    Label { text: scroll.value.toFixed(2) + qsTranslate("Spectrum", "× per wheel step"); font.pixelSize: content.theme.fontSize - 1 }
    Slider { id: scroll; setting: "scroll_factor"; from: 0.1; to: 10; stepSize: 0.1; value: content.settings.scroll_factor }
    Label {
        text: qsTranslate("Spectrum", "Applications decide the number of lines or pages. This multiplies the wheel distance for external mice.")
        color: content.theme.colors.muted
        font.pixelSize: content.theme.fontSize - 2
    }
    Button {
        Layout.fillWidth: true
        label: qsTranslate("Spectrum", "Natural scrolling · ") + (content.settings.natural_scroll ? qsTranslate("Spectrum", "On") : qsTranslate("Spectrum", "Off"))
        onClicked: content.apply("natural_scroll", content.settings.natural_scroll ? "off" : "on")
    }
    Label { text: qsTranslate("Spectrum", "CURSOR SIZE"); font.bold: true; color: content.theme.colors.accent }
    Flow {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: [16, 24, 32, 48, 64]
            Button {
                required property int modelData
                label: modelData + qsTranslate("Spectrum", " px")
                backgroundColor: content.settings.cursor_size === modelData ? content.theme.colors.accent : content.theme.colors.surface_alt
                foregroundColor: content.settings.cursor_size === modelData ? content.theme.colors.background : content.theme.colors.foreground
                onClicked: content.apply("cursor_size", modelData)
            }
        }
    }
    Label { text: qsTranslate("Spectrum", "CURSOR COLORS"); font.bold: true; color: content.theme.colors.accent }
    Button {
        Layout.fillWidth: true
        label: qsTranslate("Spectrum", "Follow system colors · ") + (content.settings.adaptive_cursor ? qsTranslate("Spectrum", "On") : qsTranslate("Spectrum", "Off"))
        onClicked: content.apply("adaptive_cursor", content.settings.adaptive_cursor ? "off" : "on")
    }
    Label {
        text: qsTranslate("Spectrum", "Uses the system accent with a dark outline. Some applications refresh their cursor after reopening.")
        color: content.theme.colors.muted
        font.pixelSize: content.theme.fontSize - 2
    }
    Button {
        Layout.fillWidth: true
        label: qsTranslate("Spectrum", "Reset movement and scrolling")
        onClicked: { content.error = ""; action.exec([content.theme.backend("mouse-adapter"), "--reset-input"]); }
    }
    Label { visible: content.busy; text: qsTranslate("Spectrum", "Applying mouse settings…"); color: content.theme.colors.accent }
    Label { visible: !!content.error; text: qsTranslate("Spectrum", content.error); color: content.theme.colors.error || content.theme.colors.accent; font.pixelSize: content.theme.fontSize - 1 }
}
