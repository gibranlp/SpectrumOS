import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

AbstractButton {
    id: box
    required property var theme
    property string label: ""
    property bool value: false
    property bool known: true
    signal changeRequested(bool value)
    checked: value
    checkable: false
    implicitHeight: 32
    implicitWidth: labelText.implicitWidth + 50
    enabled: known && !theme.actionBusy
    focusPolicy: Qt.StrongFocus
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.checked: checked
    onClicked: changeRequested(!value)
    background: Rectangle {
        radius: 8; color: box.theme.colors.surface_alt
        border.width: box.activeFocus || box.hovered ? 1 : 0
        border.color: box.theme.colors.accent
        opacity: box.enabled ? 1 : 0.5
    }
    contentItem: RowLayout {
        spacing: 8
        Rectangle {
            Layout.leftMargin: 10
            implicitWidth: 16; implicitHeight: 16; radius: 4
            color: box.checked ? box.theme.colors.accent : "transparent"
            border.width: 1; border.color: box.theme.colors.accent
            Text { anchors.centerIn: parent; text: box.checked ? "✓" : ""; color: box.theme.colors.background; font.pixelSize: 12 }
        }
        Text {
            id: labelText
            Layout.rightMargin: 10
            text: box.label
            color: box.theme.colors.foreground
            font { family: box.theme.fontFamily; pixelSize: box.theme.fontSize - 1 }
        }
    }
}
