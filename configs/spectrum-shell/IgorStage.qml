import QtQuick

Item {
    id: stage
    property int leftInset: 8
    property int topInset: 8
    property int rightInset: 8
    property int bottomInset: 8
    property int cornerClearance: 22
    property int shellOverlap: 3
    property real catSize: 180
    property string edge: "bottom"
    property real position: 0.5
    property real pawsFirstProbability: 0.35
    property var randomSource: Math.random
    property real headReveal: 1
    onVisitingChanged: {
        headEntrance.stop();
        if (visiting && animationsEnabled && randomSource() < pawsFirstProbability) {
            headReveal = 0;
            headEntrance.start();
        } else {
            headReveal = 1;
        }
    }
    onAnimationsEnabledChanged: {
        if (!animationsEnabled) {
            headEntrance.stop();
            headReveal = 1;
        }
    }
    SequentialAnimation {
        id: headEntrance
        PauseAnimation { duration: stage.animationDuration + 180 }
        NumberAnimation { target: stage; property: "headReveal"; to: 1; duration: 450; easing.type: Easing.OutCubic }
    }
    property bool visiting: false
    property bool playing: false
    property bool watching: false
    property bool meeting: false
    property real movieReveal: 1
    property string movieMood: "watching"
    property int minimumMovieReactionDelay: 22000
    property int maximumMovieReactionDelay: 50000
    readonly property bool movieActive: visiting && watching && !playing && animationsEnabled && !celebrationMessage
    onMovieActiveChanged: {
        movieReaction.stop();
        movieReveal = 1;
        movieMood = "watching";
        if (movieActive) scheduleMovieReaction();
        else movieReactionTimer.stop();
    }
    function scheduleMovieReaction(): void {
        movieReactionTimer.interval = minimumMovieReactionDelay
            + Math.round(randomSource() * (maximumMovieReactionDelay - minimumMovieReactionDelay));
        movieReactionTimer.restart();
    }
    function startle(): bool {
        if (!movieActive || motion.progress < 0.98 || headReveal < 1 || movieReaction.running)
            return false;
        movieReactionTimer.stop();
        movieReaction.start();
        return true;
    }
    Timer {
        id: movieReactionTimer
        onTriggered: { if (!stage.startle() && stage.movieActive) stage.scheduleMovieReaction(); }
    }
    SequentialAnimation {
        id: movieReaction
        PropertyAction { target: stage; property: "movieMood"; value: "startled" }
        PauseAnimation { duration: 240 }
        NumberAnimation { target: stage; property: "movieReveal"; to: 0; duration: 180; easing.type: Easing.InQuad }
        PauseAnimation { duration: 850 }
        PropertyAction { target: stage; property: "movieMood"; value: "peeking" }
        NumberAnimation { target: stage; property: "movieReveal"; to: 0.8; duration: 450; easing.type: Easing.OutCubic }
        PauseAnimation { duration: 650 }
        NumberAnimation { target: stage; property: "movieReveal"; to: 1; duration: 550; easing.type: Easing.OutCubic }
        PropertyAction { target: stage; property: "movieMood"; value: "watching" }
        onFinished: if (stage.movieActive) stage.scheduleMovieReaction()
    }
    property bool waving: false
    property color musicNoteColor: "#000000"
    property var musicNoteColors: []
    property color headphonesColor: "#7acfff"
    property color headphonesHighlight: "#78dba9"
    property string celebrationMessage: ""
    property color bubbleColor: "#12262d"
    property color bubbleTextColor: "#eeeeee"
    property string fontFamily: "sans-serif"
    property int fontSize: 13
    property string gesture: "curious"
    property int animationDuration: 600
    property bool animationsEnabled: true
    readonly property bool motionActive: motion.active
    readonly property bool side: edge === "left" || edge === "right"
    readonly property real catDepth: catSize * 164 / 400

    Item {
        id: reveal
        x: stage.leftInset
        y: stage.topInset
        width: Math.max(0, stage.width - stage.leftInset - stage.rightInset)
        height: Math.max(0, stage.height - stage.topInset - stage.bottomInset)
        // El recorte conserva a Igor detrás del marco incluso si su ventana está en Overlay.
        clip: true

        Item {
            id: perch
            objectName: "igorPerch"
            readonly property real horizontalMargin: Math.min(stage.cornerClearance, Math.max(0, (reveal.width - width) / 2))
            readonly property real verticalMargin: Math.min(stage.cornerClearance, Math.max(0, (reveal.height - height) / 2))
            width: stage.side ? stage.catDepth : stage.catSize
            height: stage.side ? stage.catSize : stage.catDepth
            x: stage.edge === "left" ? -stage.shellOverlap
                : stage.edge === "right" ? reveal.width - width + stage.shellOverlap
                : horizontalMargin + Math.max(0, reveal.width - width - 2 * horizontalMargin) * stage.position
            y: stage.edge === "top" ? -stage.shellOverlap
                : stage.edge === "bottom" ? reveal.height - height + stage.shellOverlap
                : verticalMargin + Math.max(0, reveal.height - height - 2 * verticalMargin) * stage.position
            transform: [ShellMotion {
                id: motion
                objectName: "igorRevealMotion"
                surface: perch
                animationsEnabled: stage.animationsEnabled
                bounceEnabled: false
                expanded: stage.visiting
                edge: stage.edge
                viewportWidth: reveal.width
                viewportHeight: reveal.height
                duration: stage.animationDuration
            }, Translate {
                objectName: "igorMovieRetreat"
                readonly property real offset: (1 - stage.movieReveal) * (stage.catDepth + stage.shellOverlap + 8)
                x: stage.edge === "left" ? -offset : stage.edge === "right" ? offset : 0
                y: stage.edge === "top" ? -offset : stage.edge === "bottom" ? offset : 0
            }]

            IgorIllustration {
                anchors.centerIn: parent
                width: stage.catSize
                height: stage.catDepth
                rotation: stage.edge === "top" ? 180 : stage.edge === "left" ? 90 : stage.edge === "right" ? -90 : 0
                headReveal: stage.headReveal
                active: stage.visiting && motion.progress > 0.98 && stage.headReveal === 1
                playing: stage.playing
                watching: stage.watching
                meeting: stage.meeting
                movieMood: stage.movieMood
                musicNoteColor: stage.musicNoteColor
                musicNoteColors: stage.musicNoteColors
                headphonesColor: stage.headphonesColor
                headphonesHighlight: stage.headphonesHighlight
                waving: stage.waving
                gesture: stage.gesture
            }
        }
        Rectangle {
            id: bubble
            objectName: "igorSpeechBubble"
            visible: stage.visiting && stage.celebrationMessage !== "" && motion.progress > 0.98 && stage.headReveal === 1
            width: Math.min(reveal.width, Math.max(stage.catSize, speech.implicitWidth + 28))
            height: speech.implicitHeight + 20
            radius: 12
            color: stage.bubbleColor
            border.color: stage.headphonesColor
            border.width: 1
            readonly property real desiredX: stage.edge === "left" ? perch.x + perch.width + 12
                : stage.edge === "right" ? perch.x - width - 12 : perch.x + (perch.width - width) / 2
            readonly property real desiredY: stage.edge === "top" ? perch.y + perch.height + 12
                : stage.edge === "bottom" ? perch.y - height - 12 : perch.y + (perch.height - height) / 2
            x: Math.max(0, Math.min(reveal.width - width, desiredX))
            y: Math.max(0, Math.min(reveal.height - height, desiredY))
            Text {
                id: speech
                anchors.centerIn: parent
                width: Math.min(implicitWidth, Math.max(0, reveal.width - 28))
                text: stage.celebrationMessage
                color: stage.bubbleTextColor
                font { family: stage.fontFamily; pixelSize: stage.fontSize; bold: true }
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
