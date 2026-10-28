import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: packages
    required property var theme
    property var installed: []
    property var updates: []
    property string error: ""
    readonly property var rows: installed.slice().sort((a,b) => a.name.localeCompare(b.name)).map(item => {
        const update = updates.find(candidate => candidate.name === item.name && candidate.installed === item.installed);
        return {name:item.name, installed:item.installed, available:update && update.available !== item.installed ? update.available : ""};
    })
    spacing: 4

    Text {
        Layout.fillWidth: true
        text: qsTranslate("Spectrum", "SpectrumOS packages")
        color: packages.theme.colors.foreground
        font { family: packages.theme.fontFamily; pixelSize: packages.theme.fontSize; bold: true }
    }
    Text {
        Layout.fillWidth: true
        visible: packages.error.length > 0 || packages.rows.length === 0
        text: packages.error ? qsTranslate("Spectrum", "Could not read installed package versions.") : qsTranslate("Spectrum", "No SpectrumOS packages found.")
        wrapMode: Text.Wrap
        color: packages.theme.colors.muted
        font { family: packages.theme.fontFamily; pixelSize: packages.theme.fontSize - 1 }
    }
    Repeater {
        objectName: "update-package-rows"
        model: packages.rows
        RowLayout {
            id: row
            required property var modelData
            objectName: "update-package-" + modelData.name
            Layout.fillWidth: true
            spacing: 10
            Text {
                Layout.fillWidth: true
                Layout.preferredWidth: packages.width * 0.5
                text: row.modelData.name
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                color: packages.theme.colors.foreground
                font { family: packages.theme.fontFamily; pixelSize: packages.theme.fontSize - 2 }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: packages.width * 0.5
                spacing: 6
                Text {
                    objectName: "installed-version"
                    Layout.fillWidth: true
                    text: row.modelData.installed
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAnywhere
                    color: packages.theme.colors.muted
                    font { family: packages.theme.fontFamily; pixelSize: packages.theme.fontSize - 2 }
                }
                Text {
                    visible: !!row.modelData.available
                    text: "→"
                    color: packages.theme.colors.accent
                    font { family: packages.theme.fontFamily; pixelSize: packages.theme.fontSize - 2 }
                }
                Text {
                    objectName: "available-version"
                    Layout.fillWidth: true
                    visible: !!row.modelData.available
                    text: row.modelData.available
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAnywhere
                    color: packages.theme.colors.accent
                    font { family: packages.theme.fontFamily; pixelSize: packages.theme.fontSize - 2; bold: true }
                }
            }
        }
    }
}
