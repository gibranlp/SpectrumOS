import QtQuick

Rectangle {
    id: surface
    property bool attachTop: false
    property bool attachBottom: false
    property bool attachLeft: false
    property bool attachRight: false
    property int topFrameThickness: 0
    property int leftEdgeInset: 0
    property int topAttachmentHeight: 0
    property int leftAttachmentWidth: 0
    property int leftFrameThickness: geometry.frameThickness
    property int rightFrameThickness: geometry.frameThickness
    readonly property real joinRadius: Math.min(radius, width / 2, height / 2)
    readonly property int attachmentOverlap: geometry.frameThickness
    ShellGeometry { id: geometry }
    property alias keyboardController: keyboardNavigation
    KeyboardNavigation { id: keyboardNavigation }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            keyboardNavigation.move(event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier));
            event.accepted = true;
        } else if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].includes(event.key)) {
            keyboardNavigation.moveDirection(event.key);
            event.accepted = true;
        }
    }

    // El fondo se mete bajo el marco para cubrir el rebote, incluidas las curvas.
    Rectangle {
        x: surface.attachLeft ? -surface.leftAttachmentWidth : -surface.joinRadius
        y: -surface.topAttachmentHeight - surface.attachmentOverlap
        width: surface.width + (surface.attachLeft ? surface.leftAttachmentWidth : surface.joinRadius)
            + (surface.attachRight ? 0 : surface.joinRadius)
        height: surface.attachmentOverlap
        color: surface.color
        visible: surface.attachTop
    }
    Rectangle {
        x: 0
        y: -surface.topAttachmentHeight
        width: surface.width
        height: surface.topAttachmentHeight
        color: surface.color
        visible: surface.attachTop && height > 0
        MouseArea { anchors.fill: parent }
    }
    Rectangle {
        x: surface.attachLeft ? -surface.leftAttachmentWidth : -surface.joinRadius
        y: surface.height
        width: surface.width + (surface.attachLeft ? surface.leftAttachmentWidth : surface.joinRadius)
            + (surface.attachRight ? 0 : surface.joinRadius)
        height: surface.attachmentOverlap
        color: surface.color
        visible: surface.attachBottom
    }
    Rectangle {
        x: -surface.leftAttachmentWidth - surface.attachmentOverlap
        y: 0
        width: surface.attachmentOverlap
        height: surface.height
        color: surface.color
        visible: surface.attachLeft
    }
    // Extiende el fondo hasta el marco sin mover los controles ni tapar los iconos.
    Rectangle {
        x: -surface.leftAttachmentWidth
        width: surface.leftAttachmentWidth
        height: surface.height
        color: surface.color
        visible: surface.attachLeft && width > 0
        MouseArea { anchors.fill: parent }
    }
    Rectangle {
        x: surface.width
        y: 0
        width: surface.attachmentOverlap
        height: surface.height
        color: surface.color
        visible: surface.attachRight
    }

    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: surface.radius
        color: surface.color
        visible: surface.attachTop
    }
    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: surface.radius
        color: surface.color
        visible: surface.attachBottom
    }
    Rectangle {
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        width: surface.radius
        color: surface.color
        visible: surface.attachLeft
    }
    Rectangle {
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: surface.radius
        color: surface.color
        visible: surface.attachRight
    }

    ShellCorner {
        tapered: true
        curveRadius: surface.joinRadius
        visible: surface.attachTop && !surface.attachLeft
        y: -surface.topAttachmentHeight
        x: -width + frameThickness
        frameThickness: surface.topFrameThickness
        mirrorX: true
        surfaceColor: surface.color
    }
    ShellCorner {
        tapered: true
        curveRadius: surface.joinRadius
        visible: surface.attachTop && !surface.attachRight
        y: -surface.topAttachmentHeight
        x: surface.width - frameThickness
        frameThickness: surface.topFrameThickness
        surfaceColor: surface.color
    }
    ShellCorner {
        tapered: true
        curveRadius: surface.joinRadius
        visible: surface.attachBottom && !surface.attachLeft
        x: -width
        y: surface.height - height
        frameThickness: 0
        mirrorX: true
        mirrorY: true
        surfaceColor: surface.color
    }
    ShellCorner {
        tapered: true
        curveRadius: surface.joinRadius
        visible: surface.attachBottom && !surface.attachRight
        x: surface.width
        y: surface.height - height
        frameThickness: 0
        mirrorY: true
        surfaceColor: surface.color
    }
    ShellCorner {
        tapered: true
        curveRadius: surface.joinRadius
        visible: surface.attachLeft && !surface.attachTop
        x: -surface.leftAttachmentWidth - frameThickness + surface.leftEdgeInset
        y: -height + frameThickness
        frameThickness: Math.min(surface.leftFrameThickness, Math.max(0, surface.x - surface.leftAttachmentWidth + surface.leftEdgeInset))
        mirrorY: true
        surfaceColor: surface.color
    }
    ShellCorner {
        tapered: true
        curveRadius: surface.joinRadius
        visible: surface.attachLeft && !surface.attachBottom
        x: -surface.leftAttachmentWidth - frameThickness + surface.leftEdgeInset
        y: surface.height - frameThickness
        frameThickness: Math.min(surface.leftFrameThickness, Math.max(0, surface.x - surface.leftAttachmentWidth + surface.leftEdgeInset))
        surfaceColor: surface.color
    }
    ShellCorner {
        tapered: true
        curveRadius: surface.joinRadius
        visible: surface.attachRight && !surface.attachTop
        x: surface.width - width
        y: -height + frameThickness
        frameThickness: surface.rightFrameThickness
        mirrorX: true
        mirrorY: true
        surfaceColor: surface.color
    }
    ShellCorner {
        tapered: true
        curveRadius: surface.joinRadius
        visible: surface.attachRight && !surface.attachBottom
        x: surface.width - width
        y: surface.height - frameThickness
        frameThickness: surface.rightFrameThickness
        mirrorX: true
        surfaceColor: surface.color
    }
}
