import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: swatch
    property string value: ""
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 14
    property bool selected: false
    property string copiedValue: ""
    signal copied()
    readonly property real luminance: 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
    readonly property color ink: luminance > 0.179 ? "#000000" : "#ffffff"
    implicitWidth: label.implicitWidth + 24
    implicitHeight: 42
    radius: 9
    color: value || "#333333"
    border.width: selected ? 2 : 1
    border.color: Qt.rgba(ink.r, ink.g, ink.b, selected ? 0.8 : 0.2)
    Accessible.role: Accessible.Button
    Accessible.name: "Copy " + value
    Accessible.onPressAction: copyColor()

    function linear(channel): real {
        return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4);
    }

    function copyColor(): void {
        if (!value || copyProcess.running) return;
        copiedValue = value;
        copyProcess.exec(["wl-copy", copiedValue]);
    }

    Process {
        id: copyProcess
        onExited: (code, status) => {
            if (code !== 0) return;
            Quickshell.execDetached(["notify-send", "--app-name", "SpectrumOS Color Picker",
                "--icon", "color-select-symbolic", "--expire-time", "2000", "Color copied", swatch.copiedValue]);
            swatch.copied();
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: swatch.value
        color: swatch.ink
        font { family: swatch.fontFamily; pixelSize: swatch.fontSize; bold: true }
    }
    KeyboardAction {
        anchors.fill: parent
        enabled: swatch.value.length > 0
        focusColor: swatch.ink
        cursorShape: Qt.PointingHandCursor
        onActivated: swatch.copyColor()
    }
}
