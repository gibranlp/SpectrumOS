import QtQuick
import QtQuick.Layouts

Rectangle {
    id: column
    required property var theme
    property string title: ""
    property var items: []
    property string selectedId: ""
    property bool selectionEnabled: true
    signal itemChosen(string id)
    radius: 16
    color: theme.colors.background

    ColumnLayout {
        anchors { fill: parent; margins: 12 }
        spacing: 10
        Text {
            Layout.fillWidth: true
            text: column.title
            color: column.theme.colors.foreground
            font { family: column.theme.fontFamily; pixelSize: column.theme.fontSize + 2; bold: true }
        }
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 7
            model: column.items
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: Math.max(64, content.implicitHeight + 20)
                radius: 10
                color: column.selectedId === modelData.id
                    ? Qt.tint(column.theme.colors.surface_alt, Qt.rgba(column.theme.colors.accent.r, column.theme.colors.accent.g, column.theme.colors.accent.b, 0.35))
                    : column.theme.colors.surface_alt
                ColumnLayout {
                    id: content
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                    spacing: 5
                    Text {
                        Layout.fillWidth: true
                        text: modelData.title
                        wrapMode: Text.Wrap
                        color: column.theme.colors.foreground
                        font { family: column.theme.fontFamily; pixelSize: column.theme.fontSize + 1; bold: column.selectedId === modelData.id }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: !!modelData.subtitle
                        text: modelData.subtitle || ""
                        wrapMode: Text.Wrap
                        color: column.theme.colors.muted
                        font { family: column.theme.fontFamily; pixelSize: column.theme.fontSize - 1 }
                    }
                }
                KeyboardAction {
                    anchors.fill: parent
                    enabled: column.selectionEnabled
                    cursorShape: Qt.PointingHandCursor
                    onActivated: column.itemChosen(parent.modelData.id)
                }
            }
        }
    }
}
