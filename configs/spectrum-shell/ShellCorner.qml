import QtQuick

Canvas {
    id: corner
    required property color surfaceColor
    ShellGeometry { id: geometry }
    property int frameThickness: geometry.frameThickness
    property int curveRadius: geometry.curveRadius
    property bool mirrorX: false
    property bool mirrorY: false

    width: frameThickness + curveRadius
    height: frameThickness + curveRadius

    onSurfaceColorChanged: requestPaint()
    onFrameThicknessChanged: requestPaint()
    onCurveRadiusChanged: requestPaint()
    onMirrorXChanged: requestPaint()
    onMirrorYChanged: requestPaint()

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const painter = getContext("2d");
        painter.clearRect(0, 0, width, height);
        painter.save();
        painter.translate(mirrorX ? width : 0, mirrorY ? height : 0);
        painter.scale(mirrorX ? -1 : 1, mirrorY ? -1 : 1);
        painter.fillStyle = surfaceColor;
        painter.beginPath();
        painter.moveTo(0, 0);
        painter.lineTo(width, 0);
        painter.lineTo(width, frameThickness);
        painter.arc(width, height, curveRadius, -Math.PI / 2, -Math.PI, true);
        painter.lineTo(0, height);
        painter.closePath();
        painter.fill();
        painter.restore();
    }
}
