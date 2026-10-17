import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: notch
    required property var targetScreen
    required property var theme
    required property var samples
    required property string barPosition
    readonly property bool horizontal: barPosition === "left"

    screen: targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    color: "transparent"
    focusable: false
    mask: Region {}

    ShellSurface {
        id: card
        attachTop: notch.horizontal
        attachLeft: !notch.horizontal
        topFrameThickness: leftFrameThickness
        leftEdgeInset: leftFrameThickness
        width: notch.horizontal ? notch.width * 0.2 : 34
        height: notch.horizontal ? 34 : notch.height * 0.2
        x: notch.horizontal ? (notch.width + 52 - width) / 2 : 0
        y: notch.horizontal ? 0 : (notch.height - height) / 2
        radius: Math.max(0, 34 - leftFrameThickness - joinRadius)
        color: notch.theme.colors.surface

        Canvas {
            anchors.fill: parent
            anchors.leftMargin: notch.horizontal ? 19 : 9
            anchors.rightMargin: notch.horizontal ? 19 : 7
            anchors.topMargin: notch.horizontal ? 9 : 19
            anchors.bottomMargin: notch.horizontal ? 7 : 19
            property var values: notch.samples
            property color first: notch.theme.colors.accent
            property color second: notch.theme.colors.accent_alt || notch.theme.colors.accent
            property color third: notch.theme.colors.accent
            onValuesChanged: if (visible) requestPaint()
            onFirstChanged: requestPaint()
            onSecondChanged: requestPaint()
            onThirdChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const painter = getContext("2d");
                painter.clearRect(0, 0, width, height);
                if (values.length < 2 || width <= 0 || height <= 0)
                    return;
                const length = notch.horizontal ? width : height;
                const center = notch.horizontal ? height / 2 : width / 2;
                const reach = (notch.horizontal ? height : width) * 0.45;
                const gradient = painter.createLinearGradient(0, 0, notch.horizontal ? width : 0, notch.horizontal ? 0 : height);
                gradient.addColorStop(0, first);
                gradient.addColorStop(0.5, second);
                gradient.addColorStop(1, third);
                painter.strokeStyle = gradient;
                painter.lineWidth = 1.6;
                painter.beginPath();
                for (let index = 0; index < values.length; index++) {
                    const position = index * length / (values.length - 1);
                    const amplitude = Math.pow(Math.max(0, Math.min(1, values[index] / 100)), 0.65);
                    const offset = Math.sin(index * 1.35) * amplitude * reach;
                    if (notch.horizontal) {
                        if (index === 0) painter.moveTo(position, center + offset);
                        else painter.lineTo(position, center + offset);
                    } else {
                        if (index === 0) painter.moveTo(center + offset, position);
                        else painter.lineTo(center + offset, position);
                    }
                }
                painter.stroke();
            }
        }
    }
}
