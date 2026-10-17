import QtQuick
import QtQuick.Layouts

Rectangle {
    id: column
    property string title: ""
    property string kind: ""
    property var items: []
    property var theme
    signal itemChosen(var item)

    radius: 16
    color: theme.colors.background

    ColumnLayout {
        anchors { fill: parent; margins: 14 }
        spacing: 10

        Text {
            text: column.title
            color: column.theme.colors.foreground
            font { family: column.theme.fontFamily; pixelSize: column.theme.fontSize + 5; bold: true }
        }
        Text {
            visible: column.items.length === 0
            text: "Nothing here yet"
            color: column.theme.colors.muted
            font { family: column.theme.fontFamily; pixelSize: column.theme.fontSize }
        }
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: column.items
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: 74
                radius: 10
                color: column.theme.colors.surface_alt

                Column {
                    anchors { fill: parent; margins: 10 }
                    spacing: 5
                    Text {
                        width: parent.width
                        text: parent.parent.modelData.title
                        elide: Text.ElideRight
                        color: column.theme.colors.foreground
                        font { family: column.theme.fontFamily; pixelSize: column.theme.fontSize + 2; bold: true }
                    }
                    Text {
                        width: parent.width
                        text: column.kind === "Treasury" ? parent.parent.modelData.currency_code + " " + (parent.parent.modelData.amount_minor / 100).toFixed(2) + "  ·  " + parent.parent.modelData.status : (parent.parent.modelData.campaign || "Unfiled") + (parent.parent.modelData.due_date ? "  ·  " + parent.parent.modelData.due_date : "")
                        elide: Text.ElideRight
                        color: column.theme.colors.muted
                        font { family: column.theme.fontFamily; pixelSize: column.theme.fontSize }
                    }
                }
                KeyboardAction {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onActivated: column.itemChosen(parent.modelData)
                }
            }
        }
    }
}
