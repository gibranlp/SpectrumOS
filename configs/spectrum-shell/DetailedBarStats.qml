import QtQuick

Text {
    id: stats
    property real availableWidth: 600
    readonly property real naturalWidth: Math.ceil(metrics.advanceWidth)
    width: Math.min(naturalWidth, Math.max(1, availableWidth))
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    TextMetrics { id: metrics; text: stats.text; font: stats.font }
}
