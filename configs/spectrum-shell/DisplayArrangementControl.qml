import QtQuick

Flow {
    id: arrangement
    required property var theme
    spacing: 5
    Repeater {
        model: ["left", "right", "up", "down"]
        ShellButton {
            required property string modelData
            readonly property bool selected: arrangement.theme.displays.arrangement === modelData
            objectName: "display-arrange-" + modelData
            enabled: !arrangement.theme.actionBusy && (arrangement.theme.displays.monitors || []).length > 1
            label: qsTranslate("Spectrum", "Arrange ") + modelData
            fontFamily: arrangement.theme.fontFamily
            fontSize: arrangement.theme.fontSize - 1
            backgroundColor: selected ? arrangement.theme.colors.accent : arrangement.theme.colors.surface_alt
            foregroundColor: selected ? arrangement.theme.colors.background : arrangement.theme.colors.foreground
            onClicked: arrangement.theme.runAction([arrangement.theme.backend("control-adapter"), "display", modelData])
        }
    }
}
