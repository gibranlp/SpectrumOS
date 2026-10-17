import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: content
    required property var theme
    spacing: 9

    Text {
        text: "CONNECTED DISPLAYS"
        color: content.theme.colors.accent
        font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize; bold: true }
    }
    Repeater {
        model: content.theme.displays.monitors || []
        Rectangle {
            id: displayRow
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: displayFields.implicitHeight + 24
            radius: 11
            color: content.theme.colors.surface_alt

            ColumnLayout {
                id: displayFields
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 6
                Text {
                    text: displayRow.modelData.name + (displayRow.modelData.primary ? "  ·  Primary" : "")
                    color: content.theme.colors.foreground
                    font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize; bold: true }
                }
                Text {
                    text: displayRow.modelData.resolution + "  ·  " + displayRow.modelData.refresh + "  ·  " + displayRow.modelData.scale
                    color: content.theme.colors.muted
                    font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize - 1 }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 5
                    Repeater {
                        model: displayRow.modelData.mode_choices || []
                        ShellButton {
                            required property var modelData
                            visible: modelData.value.length > 0
                            label: modelData.label
                            fontFamily: content.theme.fontFamily
                            fontSize: content.theme.fontSize - 2
                            backgroundColor: content.theme.colors.surface
                            foregroundColor: content.theme.colors.foreground
                            onClicked: content.theme.runAction([content.theme.backend("control-adapter"), "display", "mode", displayRow.modelData.name, modelData.value])
                        }
                    }
                }
                DisplayScaleControl {
                    Layout.fillWidth: true
                    theme: content.theme
                    monitorName: displayRow.modelData.name
                    currentScale: parseFloat(displayRow.modelData.scale)
                }
                RowLayout {
                    Layout.fillWidth: true
                    ShellButton {
                        label: "Make primary"
                        enabled: !displayRow.modelData.primary
                        fontFamily: content.theme.fontFamily
                        fontSize: content.theme.fontSize - 2
                        backgroundColor: content.theme.colors.surface
                        foregroundColor: content.theme.colors.foreground
                        onClicked: content.theme.runAction([content.theme.backend("control-adapter"), "display", "primary", displayRow.modelData.name])
                    }
                    ShellButton {
                        label: "Rotate"
                        fontFamily: content.theme.fontFamily
                        fontSize: content.theme.fontSize - 2
                        backgroundColor: content.theme.colors.surface
                        foregroundColor: content.theme.colors.foreground
                        onClicked: content.theme.runAction([content.theme.backend("control-adapter"), "display", "rotate", displayRow.modelData.name, String((displayRow.modelData.transform + 1) % 4)])
                    }
                }
                Text {
                    text: "Workspaces on this display"
                    color: content.theme.colors.muted
                    font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize - 1 }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 5
                    Repeater {
                        model: [1, 2, 3, 4, 5, 6]
                        ShellButton {
                            required property int modelData
                            readonly property bool assigned: content.theme.workspaceAssignments.workspace_monitors && content.theme.workspaceAssignments.workspace_monitors[String(modelData)] === displayRow.modelData.name
                            label: String(modelData)
                            fontFamily: content.theme.fontFamily
                            fontSize: content.theme.fontSize - 1
                            backgroundColor: assigned ? content.theme.colors.accent : content.theme.colors.surface
                            foregroundColor: assigned ? content.theme.colors.background : content.theme.colors.foreground
                            onClicked: content.theme.runAction([content.theme.backend("workspace-layout"), "--workspace", String(modelData), displayRow.modelData.name])
                        }
                    }
                }
            }
        }
    }
    Flow {
        Layout.fillWidth: true
        spacing: 5
        Repeater {
            model: ["left", "right", "up", "down"]
            ShellButton {
                required property string modelData
                label: "Arrange " + modelData
                fontFamily: content.theme.fontFamily
                fontSize: content.theme.fontSize - 1
                backgroundColor: content.theme.colors.surface_alt
                foregroundColor: content.theme.colors.foreground
                onClicked: content.theme.runAction([content.theme.backend("control-adapter"), "display", modelData])
            }
        }
    }
    BrightnessControls {
        Layout.fillWidth: true
        theme: content.theme
    }
    ScreensaverControls {
        Layout.fillWidth: true
        theme: content.theme
    }
}
