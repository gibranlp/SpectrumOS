import QtQuick

Item {
    id: cat
    property real headReveal: 1
    property bool showPaws: true
    property bool active: false
    property bool playing: false
    property bool watching: false
    property bool meeting: false
    property string movieMood: "watching"
    property bool waving: false
    property color musicNoteColor: "#000000"
    property var musicNoteColors: []
    property color headphonesColor: "#7acfff"
    property color headphonesHighlight: "#78dba9"
    property string gesture: "curious"
    readonly property bool quiet: gesture === "quiet"
    property real headTilt: 0
    property real headLift: 0
    property real pawTilt: 0
    property real pawLift: 0
    property real rightPawLift: 0
    property real breath: 0
    property real stretch: 0
    property real blink: 0
    property real earTilt: 0
    implicitWidth: 180
    implicitHeight: implicitWidth * 164 / 400

    function settle(): void {
        headTilt = 0;
        headLift = 0;
        pawTilt = 0;
        pawLift = 0;
        rightPawLift = 0;
        breath = 0;
        stretch = 0;
        blink = 0;
        earTilt = 0;
    }
    onActiveChanged: { if (!active) settle(); }
    onPlayingChanged: settle()
    Behavior on headTilt { enabled: !cat.active; NumberAnimation { duration: 300 } }
    Behavior on headLift { enabled: !cat.active; NumberAnimation { duration: 300 } }
    Behavior on pawTilt { enabled: !cat.active; NumberAnimation { duration: 300 } }
    Behavior on pawLift { enabled: !cat.active; NumberAnimation { duration: 300 } }
    Behavior on rightPawLift { enabled: !cat.active; NumberAnimation { duration: 300 } }
    Behavior on stretch { enabled: !cat.active; NumberAnimation { duration: 300 } }
    Behavior on earTilt { enabled: !cat.active; NumberAnimation { duration: 300 } }

    Image {
        anchors.fill: parent
        visible: cat.showPaws
        source: Qt.resolvedUrl("igor/left-paw.svg")
        sourceSize.width: Math.ceil(cat.width * 2)
        transform: [
            Rotation { origin.x: cat.width * 0.145; origin.y: cat.height * 0.9; angle: cat.pawTilt },
            Translate { y: cat.pawLift * cat.width / 180 }
        ]
    }
    Image {
        anchors.fill: parent
        visible: cat.showPaws
        source: Qt.resolvedUrl("igor/right-paw.svg")
        sourceSize.width: Math.ceil(cat.width * 2)
        transform: Translate { y: cat.rightPawLift * cat.width / 180 }
    }
    Item {
        id: head
        objectName: "igorHead"
        visible: cat.headReveal > 0
        anchors.fill: parent
        transform: [
            Scale { origin.x: cat.width / 2; origin.y: cat.height; xScale: 1 + cat.breath * 0.012 - cat.stretch * 0.025; yScale: 1 + cat.breath * 0.022 + cat.stretch * 0.12 },
            Rotation { origin.x: cat.width * 0.5; origin.y: cat.height * 0.95; angle: cat.headTilt },
            Translate { y: cat.headLift * cat.width / 180 + (1 - cat.headReveal) * cat.height },
            Rotation { origin.x: cat.width / 2; origin.y: cat.height; angle: cat.watching && cat.movieMood === "startled" ? -9 : 0
                Behavior on angle { NumberAnimation { duration: 140 } }
            }
        ]

        Image {
            width: head.width
            height: head.height * 264 / 164
            source: Qt.resolvedUrl("igor/chin.svg")
            sourceSize.width: Math.ceil(cat.width * 2)
        }
        Image {
            anchors.fill: parent
            source: Qt.resolvedUrl("igor/head-base.svg")
            sourceSize.width: Math.ceil(cat.width * 2)
        }

        // Las partes superiores se recortan del mismo dibujo para conservar sus detalles.
        Repeater {
            model: 2
            Item {
                required property int index
                readonly property real cutoff: head.height * (index === 0 ? 85 : 100) / 164
                x: index === 0 ? 0 : head.width * 0.65
                width: head.width * (index === 0 ? 0.4 : 0.35)
                height: cutoff
                clip: true
                transform: Rotation {
                    origin.x: parent.index === 0 ? parent.width * 0.875 : parent.width * 0.2
                    origin.y: parent.height
                    angle: parent.index === 0 ? cat.earTilt : -cat.earTilt * 0.7
                }
                Image {
                    x: -parent.x
                    width: head.width
                    height: head.height
                    source: Qt.resolvedUrl("igor/head.svg")
                    sourceSize.width: Math.ceil(cat.width * 2)
                }
            }
        }
        Repeater {
            model: 2
            Item {
                required property int index
                x: index * head.width / 2
                y: head.height * (index === 0 ? 85 : 100) / 164 - 0.5
                width: head.width / 2
                height: head.height - y
                clip: true
                Image {
                    x: -parent.x
                    y: -parent.y
                    width: head.width
                    height: head.height
                    source: Qt.resolvedUrl("igor/head.svg")
                    sourceSize.width: Math.ceil(cat.width * 2)
                }
            }
        }
        Canvas {
            id: headphones
            objectName: "igorHeadphones"
            anchors.fill: parent
            visible: cat.playing || cat.meeting
            onVisibleChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: cat
                function onHeadphonesColorChanged() { headphones.requestPaint(); }
                function onHeadphonesHighlightChanged() { headphones.requestPaint(); }
            }
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.scale(width / 400, height / 164);
                ctx.lineCap = "round";
                ctx.beginPath();
                ctx.moveTo(96, 104);
                ctx.bezierCurveTo(72, 19, 327, 19, 307, 108);
                ctx.strokeStyle = "#0e0f11";
                ctx.lineWidth = 20;
                ctx.stroke();
                ctx.strokeStyle = cat.headphonesColor;
                ctx.lineWidth = 10;
                ctx.stroke();
                for (const x of [80, 293]) {
                    ctx.beginPath();
                    ctx.ellipse(x, 84, 34, 53);
                    ctx.fillStyle = "#0e0f11";
                    ctx.fill();
                    ctx.beginPath();
                    ctx.ellipse(x + 5, 88, 24, 43);
                    ctx.fillStyle = cat.headphonesColor;
                    ctx.fill();
                    ctx.beginPath();
                    ctx.moveTo(x + 17, 98);
                    ctx.lineTo(x + 17, 120);
                    ctx.strokeStyle = cat.headphonesHighlight;
                    ctx.lineWidth = 5;
                    ctx.stroke();
                }
            }
        }
        Canvas {
            id: meetingMic
            objectName: "igorMeetingMicrophone"
            anchors.fill: parent
            visible: cat.meeting
            onVisibleChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: cat
                function onHeadphonesColorChanged() { meetingMic.requestPaint(); }
                function onHeadphonesHighlightChanged() { meetingMic.requestPaint(); }
            }
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.scale(width / 400, height / 164);
                ctx.lineCap = "round";
                ctx.beginPath();
                ctx.moveTo(307, 119);
                ctx.bezierCurveTo(308, 147, 274, 153, 238, 143);
                ctx.strokeStyle = "#0e0f11";
                ctx.lineWidth = 13;
                ctx.stroke();
                ctx.strokeStyle = cat.headphonesColor;
                ctx.lineWidth = 6;
                ctx.stroke();
                ctx.beginPath();
                ctx.ellipse(222, 133, 26, 17);
                ctx.fillStyle = "#0e0f11";
                ctx.fill();
                ctx.beginPath();
                ctx.ellipse(228, 138, 14, 7);
                ctx.fillStyle = cat.headphonesHighlight;
                ctx.fill();
            }
        }
        Canvas {
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections { target: cat; function onBlinkChanged() { eyelids.requestPaint(); } }
            id: eyelids
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                if (cat.blink <= 0) return;
                ctx.scale(width / 400, height / 164);
                for (const eye of [[153, 113, 24, 25], [244, 122, 23, 23]]) {
                    const [x, y, rx, ry] = eye;
                    ctx.save();
                    ctx.beginPath();
                    ctx.ellipse(x - rx, y - ry, rx * 2, ry * 2);
                    ctx.clip();
                    ctx.fillStyle = "#0e0f11";
                    const gap = ry * (1 - cat.blink);
                    ctx.fillRect(x - rx, y - ry, rx * 2, ry - gap);
                    ctx.fillRect(x - rx, y + gap, rx * 2, ry - gap);
                    ctx.restore();
                }
            }
        }
        Image {
            objectName: "igorMovieGlasses"
            anchors.fill: parent
            visible: cat.watching && !cat.playing && !cat.meeting
            source: Qt.resolvedUrl("igor/movie-glasses.svg")
            sourceSize.width: Math.ceil(cat.width * 2)
        }
    }

    IgorMusicNote {
        objectName: "igorMusicNote"
        width: cat.width
        active: cat.active && cat.playing && !cat.quiet
        noteColor: cat.musicNoteColor
        paletteColors: cat.musicNoteColors
        noteSize: cat.width * 0.18
        uprightRotation: -cat.rotation
    }

    SequentialAnimation {
        running: cat.active && !cat.quiet
        loops: Animation.Infinite
        NumberAnimation { target: cat; property: "breath"; to: 1; duration: 1600; easing.type: Easing.InOutSine }
        NumberAnimation { target: cat; property: "breath"; to: 0; duration: 1800; easing.type: Easing.InOutSine }
    }
    SequentialAnimation {
        running: cat.active
        loops: Animation.Infinite
        PauseAnimation { duration: cat.gesture === "sleepy" ? 900 : 2200 }
        NumberAnimation { target: cat; property: "blink"; to: 1; duration: 130; easing.type: Easing.InOutSine }
        PauseAnimation { duration: cat.gesture === "sleepy" ? 380 : 70 }
        NumberAnimation { target: cat; property: "blink"; to: 0; duration: 190; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 190 }
        NumberAnimation { target: cat; property: "blink"; to: 1; duration: 110 }
        NumberAnimation { target: cat; property: "blink"; to: 0; duration: 180 }
        PauseAnimation { duration: 2400 }
    }
    SequentialAnimation {
        running: cat.active && !cat.quiet
        loops: Animation.Infinite
        PauseAnimation { duration: 1500 }
        NumberAnimation { target: cat; property: "earTilt"; to: -4; duration: 170; easing.type: Easing.OutSine }
        NumberAnimation { target: cat; property: "earTilt"; to: 2; duration: 230; easing.type: Easing.InOutSine }
        NumberAnimation { target: cat; property: "earTilt"; to: 0; duration: 260; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 3400 }
    }
    SequentialAnimation {
        running: cat.active && cat.playing && !cat.quiet
        loops: Animation.Infinite
        ParallelAnimation {
            NumberAnimation { target: cat; property: "headTilt"; to: -6; duration: 600; easing.type: Easing.InOutSine }
            NumberAnimation { target: cat; property: "headLift"; to: -4; duration: 600; easing.type: Easing.InOutSine }
            NumberAnimation { target: cat; property: "rightPawLift"; to: -3; duration: 600; easing.type: Easing.InOutSine }
        }
        ParallelAnimation {
            NumberAnimation { target: cat; property: "headTilt"; to: 6; duration: 600; easing.type: Easing.InOutSine }
            NumberAnimation { target: cat; property: "headLift"; to: 0; duration: 600; easing.type: Easing.InOutSine }
            NumberAnimation { target: cat; property: "rightPawLift"; to: 0; duration: 600; easing.type: Easing.InOutSine }
        }
    }
    SequentialAnimation {
        running: cat.active && !cat.playing && !cat.quiet
        loops: Animation.Infinite
        PauseAnimation { duration: 650 }
        NumberAnimation { target: cat; property: "headTilt"; to: -7; duration: 800; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 1300 }
        NumberAnimation { target: cat; property: "headTilt"; to: 6; duration: 1100; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 1100 }
        NumberAnimation { target: cat; property: "headTilt"; to: 0; duration: 850; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 1400 }
    }
    SequentialAnimation {
        running: cat.active && !cat.playing && cat.gesture === "stretch"
        PauseAnimation { duration: 1200 }
        ParallelAnimation {
            NumberAnimation { target: cat; property: "stretch"; to: 1; duration: 1000; easing.type: Easing.InOutSine }
            NumberAnimation { target: cat; property: "headLift"; to: -7; duration: 1000; easing.type: Easing.InOutSine }
            NumberAnimation { target: cat; property: "rightPawLift"; to: -5; duration: 1000; easing.type: Easing.InOutSine }
        }
        PauseAnimation { duration: 700 }
        ParallelAnimation {
            NumberAnimation { target: cat; property: "stretch"; to: 0; duration: 1300; easing.type: Easing.InOutSine }
            NumberAnimation { target: cat; property: "headLift"; to: 0; duration: 1300; easing.type: Easing.InOutSine }
            NumberAnimation { target: cat; property: "rightPawLift"; to: 0; duration: 1300; easing.type: Easing.InOutSine }
        }
    }
    SequentialAnimation {
        running: cat.active && cat.waving && !cat.playing
        PauseAnimation { duration: 650 }
        ParallelAnimation {
            NumberAnimation { target: cat; property: "pawLift"; to: -18; duration: 550; easing.type: Easing.InOutSine }
            NumberAnimation { target: cat; property: "pawTilt"; to: -32; duration: 550; easing.type: Easing.InOutSine }
        }
        NumberAnimation { target: cat; property: "pawTilt"; to: 20; duration: 400; easing.type: Easing.InOutSine }
        NumberAnimation { target: cat; property: "pawTilt"; to: -25; duration: 400; easing.type: Easing.InOutSine }
        NumberAnimation { target: cat; property: "pawTilt"; to: 16; duration: 400; easing.type: Easing.InOutSine }
        NumberAnimation { target: cat; property: "pawTilt"; to: -20; duration: 400; easing.type: Easing.InOutSine }
        ParallelAnimation {
            NumberAnimation { target: cat; property: "pawTilt"; to: 0; duration: 650; easing.type: Easing.InOutSine }
            NumberAnimation { target: cat; property: "pawLift"; to: 0; duration: 650; easing.type: Easing.InOutSine }
        }
    }
}
