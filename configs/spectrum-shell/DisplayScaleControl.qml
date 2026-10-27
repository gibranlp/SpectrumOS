pragma ComponentBehavior: Bound
import QtQuick

Column {
    id: control
    required property var theme
    required property string monitorName
    required property real currentScale
    spacing: 6

    Text {
        objectName: "display-scale-current-" + control.monitorName
        text: qsTranslate("Spectrum", "Scaling · current ") + Number(control.currentScale.toFixed(2)) + "×"
        color: control.theme.colors.muted
        font { family: control.theme.fontFamily; pixelSize: control.theme.fontSize - 1 }
    }
    Flow {
        width: parent.width
        spacing: 5
        Repeater {
            model: [1, 1.25, 1.5, 1.75, 2]
            ShellButton {
                required property real modelData
                readonly property bool selected: Math.abs(control.currentScale - modelData) < 0.01
                objectName: "display-scale-" + control.monitorName + "-" + modelData
                label: modelData + "×"
                enabled: !control.theme.actionBusy
                fontFamily: control.theme.fontFamily
                fontSize: control.theme.fontSize - 1
                backgroundColor: selected ? control.theme.colors.accent : control.theme.colors.surface
                foregroundColor: selected ? control.theme.colors.background : control.theme.colors.foreground
                Accessible.name: control.monitorName + " scaling " + modelData + "×"
                onClicked: control.theme.runAction([control.theme.backend("control-adapter"), "display", "scale", control.monitorName, String(modelData)])
            }
        }
    }
    Text {
        width: parent.width
        text: qsTranslate("Spectrum", "Some resolutions use the nearest supported scale.")
        wrapMode: Text.Wrap
        color: control.theme.colors.muted
        font { family: control.theme.fontFamily; pixelSize: control.theme.fontSize - 2 }
    }
}
