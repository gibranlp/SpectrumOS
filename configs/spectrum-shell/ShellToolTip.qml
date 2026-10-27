import QtQuick
import QtQuick.Controls as Controls

Controls.ToolTip {
    id: tip
    required property var theme
    delay: 400
    leftPadding: 8
    rightPadding: 8
    topPadding: 5
    bottomPadding: 5
    width: Math.min(360, implicitWidth)
    font { family: theme.fontFamily; pixelSize: Math.max(8, theme.fontSize - 1) }
    contentItem: Text {
        text: tip.text
        textFormat: Text.PlainText
        font: tip.font
        color: tip.theme.colors.foreground
        wrapMode: Text.Wrap
    }
    background: Rectangle {
        color: tip.theme.colors.surface_alt
        radius: 7
        border.width: 1
        border.color: tip.theme.colors.muted
    }
}
