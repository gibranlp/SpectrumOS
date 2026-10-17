import QtQuick

Item {
    id: stage
    property bool active: false
    property bool animationsEnabled: true
    property string edge: "bottom"
    property real position: 0.5
    property real catSize: 180
    property int leftInset: 8
    property int topInset: 8
    property int rightInset: 8
    property int bottomInset: 8
    property int cornerClearance: 26
    property color accent: "#b293e6"
    property string fontFamily: "sans-serif"
    readonly property bool side: edge === "left" || edge === "right"
    readonly property bool motionActive: cat.motionActive
    readonly property alias hoverTarget: hoverTarget
    readonly property rect hoverBounds: {
        const shiftX = edge === "left" ? -(1 - cat.reveal) * perch.width
            : edge === "right" ? (1 - cat.reveal) * perch.width : 0;
        const shiftY = edge === "top" ? -(1 - cat.reveal) * perch.height
            : edge === "bottom" ? (1 - cat.reveal) * perch.height : 0;
        const rawX = reveal.x + perch.x + shiftX + (side ? 0 : perch.width * 0.15);
        const rawY = reveal.y + perch.y + shiftY + (side ? perch.height * 0.15 : 0);
        const x = Math.max(reveal.x, rawX);
        const y = Math.max(reveal.y, rawY);
        return Qt.rect(x, y,
            Math.max(0, Math.min(reveal.x + reveal.width, rawX + perch.width * (side ? 1 : 0.7)) - x),
            Math.max(0, Math.min(reveal.y + reveal.height, rawY + perch.height * (side ? 0.7 : 1)) - y));
    }
    signal dismissRequested()
    Item {
        id: reveal
        x: stage.leftInset; y: stage.topInset
        width: Math.max(0, stage.width - stage.leftInset - stage.rightInset)
        height: Math.max(0, stage.height - stage.topInset - stage.bottomInset)
        clip: true
        Item {
            id: perch
            objectName: "igorNapPerch"
            readonly property real horizontalMargin: Math.min(stage.cornerClearance, Math.max(0, (reveal.width - width) / 2))
            readonly property real verticalMargin: Math.min(stage.cornerClearance, Math.max(0, (reveal.height - height) / 2))
            width: stage.side ? stage.catSize * 164 / 400 : stage.catSize
            height: stage.side ? stage.catSize : stage.catSize * 164 / 400
            x: stage.edge === "left" ? -3
                : stage.edge === "right" ? reveal.width - width + 3
                : horizontalMargin + Math.max(0, reveal.width - width - 2 * horizontalMargin) * stage.position
            y: stage.edge === "top" ? -3
                : stage.edge === "bottom" ? reveal.height - height + 3
                : verticalMargin + Math.max(0, reveal.height - height - 2 * verticalMargin) * stage.position
            transform: Translate {
                x: stage.edge === "left" ? -(1 - cat.reveal) * perch.width : stage.edge === "right" ? (1 - cat.reveal) * perch.width : 0
                y: stage.edge === "top" ? -(1 - cat.reveal) * perch.height : stage.edge === "bottom" ? (1 - cat.reveal) * perch.height : 0
            }
            IgorSleeper {
                id: cat
                anchors.centerIn: parent
                width: stage.catSize; height: width * 164 / 400
                rotation: stage.edge === "top" ? 180 : stage.edge === "left" ? 90 : stage.edge === "right" ? -90 : 0
                edgeAttached: true
                animationsEnabled: stage.animationsEnabled
                active: stage.active
                accent: stage.accent
                fontFamily: stage.fontFamily
                onDismissRequested: stage.dismissRequested()
            }
        }
    }
    // El área sin rotación mantiene válido el recorte de entrada de la ventana.
    MouseArea {
        id: hoverTarget
        objectName: "igorNapStageHover"
        x: stage.hoverBounds.x
        y: stage.hoverBounds.y
        width: stage.active && cat.reveal > 0.98 ? stage.hoverBounds.width : 0
        height: stage.active && cat.reveal > 0.98 ? stage.hoverBounds.height : 0
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: stage.dismissRequested()
    }
}
