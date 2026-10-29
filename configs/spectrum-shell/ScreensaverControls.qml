pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: controls
    required property var theme
    spacing: 8
    Text {
        text: qsTranslate("Spectrum", "SCREENSAVER")
        color: controls.theme.colors.accent
        font { family: controls.theme.fontFamily; pixelSize: controls.theme.fontSize; bold: true }
    }
    ShellCheckBox {
        objectName: "screensaver-enabled"
        theme: controls.theme
        label: qsTranslate("Spectrum", "Start when idle")
        value: controls.theme.screensaverSettings.enabled
        enabled: !controls.theme.screensaverBusy
        onChangeRequested: value => controls.theme.configureScreensaver("enabled", value ? "on" : "off")
    }
    Text {
        text: qsTranslate("Spectrum", "Wait before starting")
        color: controls.theme.colors.muted
        font { family: controls.theme.fontFamily; pixelSize: controls.theme.fontSize - 1 }
    }
    Flow {
        Layout.fillWidth: true
        spacing: 5
        Repeater {
            model: [60, 120, 180, 300, 480, 600, 900]
            ShellButton {
                required property int modelData
                objectName: "screensaver-timeout-" + modelData
                label: (modelData / 60) + qsTranslate("Spectrum", " min")
                enabled: !controls.theme.screensaverBusy
                fontFamily: controls.theme.fontFamily
                fontSize: controls.theme.fontSize - 1
                backgroundColor: controls.theme.screensaverSettings.timeout === modelData ? controls.theme.colors.accent : controls.theme.colors.surface_alt
                foregroundColor: controls.theme.screensaverSettings.timeout === modelData ? controls.theme.colors.background : controls.theme.colors.foreground
                onClicked: controls.theme.configureScreensaver("timeout", modelData)
            }
        }
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: qsTranslate("Spectrum", "Move the pointer or press a key to return. Uses your current theme. Existing screen lock and display-off timers still apply.")
        color: controls.theme.colors.muted
        font { family: controls.theme.fontFamily; pixelSize: controls.theme.fontSize - 2 }
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        visible: controls.theme.screensaverError.length > 0
        text: controls.theme.screensaverError
        color: controls.theme.colors.error || controls.theme.colors.foreground
        font { family: controls.theme.fontFamily; pixelSize: controls.theme.fontSize - 1 }
    }
}
