import QtQuick

Item {
    id: indicator
    required property var theme
    property real percent: 0
    property bool charging: false
    property bool pluggedIn: false
    property bool compact: false
    readonly property int level: Math.round(Math.max(0, Math.min(100, percent)))
    readonly property string stateLabel: charging ? qsTranslate("Spectrum", "Charging")
        : pluggedIn ? (level >= 99 ? qsTranslate("Spectrum", "Fully charged") : "🔌") : qsTranslate("Spectrum", "On battery")
    readonly property color levelColor: charging ? theme.colors.accent
        : level <= 20 ? (theme.colors.error || "#ff8c9a") : theme.colors.foreground
    implicitWidth: compact ? 44 : content.width
    implicitHeight: Math.max(24, content.height)
    Accessible.name: stateLabel + " · " + level + "%"

    Grid {
        id: content
        anchors.centerIn: parent
        columns: indicator.compact ? 1 : 3
        spacing: indicator.compact ? 2 : 5
        Text {
            objectName: "battery-power-status"
            visible: !indicator.compact && (indicator.charging || indicator.pluggedIn)
            text: indicator.charging ? "⚡" : "🔌"
            color: indicator.levelColor
            font { family: indicator.theme.fontFamily; pixelSize: indicator.theme.fontSize - 1 }
        }
        Item {
            width: indicator.compact ? 44 : 26
            height: 16
            Rectangle {
                id: body
                objectName: "battery-body"
                anchors.centerIn: parent
                width: 22
                height: 12
                radius: 2
                color: "transparent"
                border { width: 1; color: indicator.levelColor }
                Rectangle {
                    objectName: "battery-level-fill"
                    x: 2
                    y: 2
                    width: (body.width - 4) * indicator.level / 100
                    height: body.height - 4
                    radius: 1
                    color: indicator.levelColor
                }
                Rectangle {
                    x: parent.width
                    y: 4
                    width: 2
                    height: 4
                    radius: 1
                    color: indicator.levelColor
                }
            }
        }
        Text {
            id: percentage
            objectName: "battery-percentage"
            text: (indicator.compact ? (indicator.charging ? "⚡ " : indicator.pluggedIn ? "🔌 " : "") : "") + indicator.level + "%"
            width: indicator.compact ? 44 : Math.ceil(labelMetrics.advanceWidth)
            horizontalAlignment: Text.AlignHCenter
            color: indicator.levelColor
            font { family: indicator.theme.fontFamily; pixelSize: indicator.theme.fontSize - 1 }
            fontSizeMode: Text.Fit
            minimumPixelSize: 8
        }
    }
    TextMetrics { id: labelMetrics; text: percentage.text; font: percentage.font }
}
