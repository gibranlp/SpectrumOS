import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

ColumnLayout {
    id: control
    required property var theme
    required property var device
    property bool output: true
    property var audioNode: (theme.audioNodes || []).find(node => node.name === device.name && !node.isStream && node.isSink === output && node.audio) || null
    readonly property bool volumeAvailable: !!(audioNode && audioNode.ready && audioNode.audio)
    property int previewPercent: -1
    readonly property bool dragging: slider.pressed
    spacing: 3
    ShellButton {
        Layout.fillWidth: true
        label: (control.device[qsTranslate("Spectrum", "default")] ? "✓ " : "") + control.device.label
        fontFamily: control.theme.fontFamily
        fontSize: control.theme.fontSize - 1
        enabled: !control.theme.actionBusy
        backgroundColor: control.device["default"] ? control.theme.colors.accent : control.theme.colors.surface_alt
        foregroundColor: control.device["default"] ? control.theme.colors.background : control.theme.colors.foreground
        onClicked: control.theme.runAction([control.theme.backend("control-adapter"), "audio", control.output ? "output" : "input", String(control.device.id)])
    }
    RowLayout {
        Layout.fillWidth: true
        ShellButton {
            objectName: "device-mute"
            label: control.device.muted ? "󰖁" : "󰕾"
            fontFamily: control.theme.fontFamily
            fontSize: control.theme.fontSize
            enabled: !control.theme.actionBusy
            backgroundColor: control.theme.colors.surface_alt
            foregroundColor: control.theme.colors.foreground
            onClicked: control.theme.runAction([control.theme.backend("control-adapter"), "audio", control.output ? "output-mute" : "input-mute", String(control.device.id)])
        }
        Controls.Slider {
            id: slider
            objectName: "device-volume"
            Layout.fillWidth: true
            implicitHeight: 30
            from: 0; to: 100; stepSize: 1
            enabled: !control.theme.actionBusy && typeof control.device.volume_percent === "number"
            Accessible.name: control.device.label + " volume"
            Binding { target: slider; property: "value"; value: control.volumeAvailable ? Math.round(control.audioNode.audio.volume * 100) : control.previewPercent >= 0 ? control.previewPercent : control.device.volume_percent || 0; when: !slider.pressed && !control.theme.actionBusy && !control.theme.audioVolumeBusy; restoreMode: Binding.RestoreNone }
            onMoved: {
                control.previewPercent = Math.round(value);
                control.theme.setAudioVolume(control.output ? "sink" : "source", control.device.name, control.previewPercent);
            }
            background: Rectangle {
                x: slider.leftPadding; y: slider.topPadding + slider.availableHeight / 2 - 3
                width: slider.availableWidth; height: 6; radius: 3
                color: control.theme.colors.surface_alt
                Rectangle { width: parent.width * slider.visualPosition; height: parent.height; radius: 3; color: control.theme.colors.accent }
            }
            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: 14; height: 14; radius: 7
                color: slider.activeFocus ? control.theme.colors.foreground : control.theme.colors.accent
            }
        }
        Text {
            objectName: "device-volume-label"
            text: typeof control.device.volume_percent === "number" ? Math.round(slider.value) + "%" : "—"
            color: control.theme.colors.muted
            font { family: control.theme.fontFamily; pixelSize: control.theme.fontSize - 1 }
        }
    }
}
