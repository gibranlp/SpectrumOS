pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: cat
    property bool edgeAttached: true
    property real pawsFirstProbability: 0.35
    property var randomSource: Math.random
    property bool pawsFirst: false
    property real headReveal: 1
    property bool active: false
    property bool animationsEnabled: true
    onAnimationsEnabledChanged: {
        if (!animationsEnabled) {
            entrance.stop();
            departure.stop();
            reveal = 0;
            phase = "hidden";
        }
    }
    property color accent: "#b293e6"
    property string fontFamily: "sans-serif"
    property real reveal: 0
    property real eyelids: 0
    property real dream: 0
    property string phase: "hidden"
    readonly property bool motionActive: active || phase !== "hidden"
    readonly property alias hoverTarget: hoverTarget
    signal dismissRequested()
    implicitWidth: 180
    implicitHeight: implicitWidth * 164 / 400
    visible: motionActive

    onActiveChanged: {
        entrance.stop();
        departure.stop();
        if (!animationsEnabled) {
            reveal = 0;
            phase = "hidden";
        } else if (active) {
            phase = "arriving";
            reveal = 0;
            pawsFirst = randomSource() < pawsFirstProbability;
            headReveal = pawsFirst ? 0 : 1;
            eyelids = 0;
            entrance.start();
        } else if (phase !== "hidden") {
            phase = "leaving";
            departure.start();
        }
    }
    IgorIllustration {
        objectName: "igorSleepingFace"
        anchors.fill: parent
        showPaws: true
        headReveal: cat.headReveal
        outfitVisitActive: cat.active
        blink: cat.eyelids
    }
    Repeater {
        model: 3
        Text {
            required property int index
            objectName: "igorSleepZ" + index
            readonly property real drift: (cat.dream + index / 3) % 1
            x: cat.width * 0.65 + drift * cat.width * 0.16
            y: -10 - drift * 34
            text: index === 2 ? "Z" : "z"
            font { family: cat.fontFamily; pixelSize: 11 + drift * 8; bold: true }
            color: cat.accent
            opacity: cat.phase === "sleeping" ? Math.sin(drift * Math.PI) * 0.7 : 0
        }
    }
    MouseArea {
        id: hoverTarget
        objectName: "igorNapHover"
        x: cat.width * 0.15
        width: cat.active && cat.reveal > 0.98 ? cat.width * 0.7 : 0
        height: cat.active && cat.reveal > 0.98 ? cat.height : 0
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: cat.dismissRequested()
    }
    SequentialAnimation {
        id: entrance
        NumberAnimation { target: cat; property: "reveal"; to: 1; duration: 600; easing.type: Easing.OutCubic }
        PauseAnimation { duration: cat.pawsFirst ? 180 : 0 }
        NumberAnimation { target: cat; property: "headReveal"; to: 1; duration: cat.pawsFirst ? 450 : 0; easing.type: Easing.OutCubic }
        ScriptAction { script: cat.phase = "settling" }
        PauseAnimation { duration: 300 }
        NumberAnimation { target: cat; property: "eyelids"; to: 1; duration: 450; easing.type: Easing.InOutSine }
        ScriptAction { script: cat.phase = "sleeping" }
    }
    SequentialAnimation {
        id: departure
        NumberAnimation { target: cat; property: "eyelids"; to: 0; duration: 180; easing.type: Easing.OutCubic }
        PauseAnimation { duration: 100 }
        ScriptAction { script: cat.phase = "blinking" }
        SequentialAnimation {
            loops: 2
            NumberAnimation { target: cat; property: "eyelids"; to: 1; duration: 100; easing.type: Easing.InOutSine }
            PauseAnimation { duration: 80 }
            NumberAnimation { target: cat; property: "eyelids"; to: 0; duration: 150; easing.type: Easing.InOutSine }
            PauseAnimation { duration: 100 }
        }
        ScriptAction { script: cat.phase = "head-leaving" }
        NumberAnimation { target: cat; property: "headReveal"; to: 0; duration: 420; easing.type: Easing.InCubic }
        ScriptAction { script: cat.phase = "paws-leaving" }
        PauseAnimation { duration: 100 }
        NumberAnimation { target: cat; property: "reveal"; to: 0; duration: 420; easing.type: Easing.InCubic }
        ScriptAction { script: cat.phase = "hidden" }
    }
    NumberAnimation on dream {
        running: cat.animationsEnabled && cat.phase === "sleeping"
        loops: Animation.Infinite
        from: 0; to: 1; duration: 4200
    }
}
