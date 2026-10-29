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
            id: volumeIcon
            text: indicator.muted ? "󰖁" : "󰕾"
            horizontalAlignment: Text.AlignHCenter
            width: indicator.compact ? 44 : Math.ceil(iconMetrics.advanceWidth)
            color: indicator.theme.colors.foreground
            font { family: indicator.theme.fontFamily; pixelSize: indicator.compact ? indicator.theme.fontSize + 5 : indicator.theme.fontSize + 1 }
        }
        Text {
            id: volumeLabel
            text: indicator.available ? indicator.percent + "%" : "—"
            width: indicator.compact ? 44 : Math.ceil(labelMetrics.advanceWidth)
            color: indicator.theme.colors.foreground
            font { family: indicator.theme.fontFamily; pixelSize: indicator.theme.fontSize - 1 }
            fontSizeMode: Text.Fit
            minimumPixelSize: 8
            horizontalAlignment: Text.AlignHCenter
        }
    }
    TextMetrics { id: iconMetrics; text: volumeIcon.text; font: volumeIcon.font }
    TextMetrics { id: labelMetrics; text: volumeLabel.text; font: volumeLabel.font }
    KeyboardAction {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onActivated: indicator.clicked()
    }
}
