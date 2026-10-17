pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls

Rectangle {
    id: action
    required property var theme
    property string icon: ""
    property string label: ""
    property string hint: label
    property bool active: false
    readonly property color accentColor: theme.colors.accent
    signal clicked()
    implicitWidth: 96
    implicitHeight: 82
    radius: 12
    color: !enabled ? Qt.darker(theme.colors.surface_alt, 1.15)
        : keyboard.activeFocus || hover.hovered || active
            ? Qt.tint(theme.colors.surface_alt, Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.18))
            : theme.colors.surface_alt
    border.width: keyboard.activeFocus ? 2 : active ? 1 : 0
    border.color: theme.colors.accent
    opacity: enabled ? 1 : 0.5
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.description: hint
    Accessible.onPressAction: if (enabled) clicked()
    Column {
        anchors.centerIn: parent
        spacing: 5
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: action.icon
            color: action.active ? action.theme.colors.accent : action.theme.colors.foreground
            font.family: action.theme.fontFamily
            font.pixelSize: 32
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: action.label
            color: action.theme.colors.foreground
            font.family: action.theme.fontFamily
            font.pixelSize: action.theme.fontSize
        }
    }
    HoverHandler { id: hover }
    Controls.ToolTip.visible: hover.hovered && action.hint !== action.label
    Controls.ToolTip.text: hint
    Controls.ToolTip.delay: 600
    KeyboardAction {
        id: keyboard
        anchors.fill: parent
        highlightEnabled: false
        enabled: action.enabled
        onActivated: action.clicked()
    }
}
