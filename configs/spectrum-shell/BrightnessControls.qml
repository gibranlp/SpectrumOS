pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: content
    required property var theme
    spacing: 5
    Text {
        Layout.fillWidth: true
        visible: !!content.theme.brightnessActionError
        text: qsTranslate("Spectrum", content.theme.brightnessActionError) || ""
        wrapMode: Text.Wrap
        color: content.theme.colors.muted
        font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize - 1 }
    }
    Repeater {
        model: content.theme.brightness.devices || []
        ColumnLayout {
            id: deviceRow
            required property var modelData
            Layout.fillWidth: true
            RowLayout {
                Layout.fillWidth: true
                Text {
                    objectName: "brightness-value-" + deviceRow.modelData.id
                    Layout.fillWidth: true
                    text: qsTranslate("Spectrum", "Brightness · ") + deviceRow.modelData.name + "  ·  " + (deviceRow.modelData.available ? deviceRow.modelData.percent + "%" : qsTranslate("Spectrum", "Unavailable"))
                    elide: Text.ElideRight
                    color: content.theme.colors.foreground
                    font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize }
                }
                Repeater {
                    model: ["down", "up"]
                    ShellButton {
                        required property string modelData
                        objectName: "brightness-" + modelData + "-" + deviceRow.modelData.id
                        label: modelData === "up" ? "+" : "−"
                        enabled: deviceRow.modelData.available && !content.theme.brightnessBusy
                        fontFamily: content.theme.fontFamily
                        fontSize: content.theme.fontSize + 2
                        backgroundColor: content.theme.colors.surface_alt
                        foregroundColor: content.theme.colors.foreground
                        onClicked: content.theme.changeBrightness(modelData, deviceRow.modelData.id)
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: !!deviceRow.modelData.error
                text: qsTranslate("Spectrum", deviceRow.modelData.error) || ""
                wrapMode: Text.Wrap
                color: content.theme.colors.muted
                font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize - 1 }
            }
        }
    }
    Text {
        Layout.fillWidth: true
        visible: !!content.theme.brightness.error
        text: qsTranslate("Spectrum", content.theme.brightness.error) || ""
        wrapMode: Text.Wrap
        color: content.theme.colors.muted
        font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize - 1 }
    }
}
