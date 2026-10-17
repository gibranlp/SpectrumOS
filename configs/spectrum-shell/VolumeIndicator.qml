import QtQuick

Item {
    id: indicator
    required property var theme
    property int percent: 0
    property bool muted: false
    property bool available: false
    property bool compact: false
    signal clicked()

    implicitWidth: compact ? 44 : content.width
    implicitHeight: Math.max(24, content.height)

    Grid {
        id: content
        anchors.centerIn: parent
        columns: indicator.compact ? 1 : 2
        spacing: indicator.compact ? 2 : 4
        Text {
            text: indicator.muted ? "󰖁" : "󰕾"
            horizontalAlignment: Text.AlignHCenter
            width: indicator.compact ? 44 : implicitWidth
            color: indicator.theme.colors.foreground
            font { family: indicator.theme.fontFamily; pixelSize: indicator.compact ? indicator.theme.fontSize + 5 : indicator.theme.fontSize + 1 }
        }
        Text {
            text: indicator.available ? indicator.percent + "%" : "—"
            width: indicator.compact ? 44 : implicitWidth
            color: indicator.theme.colors.foreground
            font { family: indicator.theme.fontFamily; pixelSize: indicator.theme.fontSize - 1 }
            fontSizeMode: Text.Fit
            minimumPixelSize: 8
            horizontalAlignment: Text.AlignHCenter
        }
    }
    KeyboardAction {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onActivated: indicator.clicked()
    }
}
