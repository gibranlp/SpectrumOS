import QtQuick

Item {
    id: note
    property bool active: false
    property color noteColor: "#000000"
    property var paletteColors: []
    property var random: Math.random
    property int colorIndex: 0
    readonly property color currentColor: paletteColors.length
        ? paletteColors[colorIndex % paletteColors.length] : noteColor
    property real noteSize: 32
    property real uprightRotation: 0
    property int minimumInterval: 4000
    property int maximumInterval: 9000
    property int flightDuration: 2400
    property real progress: 0
    property real drift: 0
    property string symbol: "♪"
    readonly property bool emitting: flight.running
    visible: active && emitting

    function schedule(): void {
        emission.interval = minimumInterval + Math.round(Math.random() * (maximumInterval - minimumInterval));
        emission.restart();
    }
    function emitNote(): void {
        if (!active)
            return;
        colorIndex = paletteColors.length ? Math.floor(random() * paletteColors.length) : 0;
        progress = 0;
        drift = (Math.random() < 0.5 ? -1 : 1) * noteSize * (0.7 + Math.random());
        symbol = Math.random() < 0.5 ? "♪" : "♫";
        flight.restart();
    }
    onActiveChanged: {
        if (active) {
            schedule();
        } else {
            emission.stop();
            flight.stop();
            progress = 0;
        }
    }
    Component.onCompleted: { if (active) schedule(); }

    Text {
        objectName: "igorMusicNoteGlyph"
        x: note.width / 2 - width / 2 + note.drift * note.progress
        y: -height / 2 - note.noteSize * 3.5 * note.progress
        text: note.symbol
        color: note.currentColor
        font { pixelSize: note.noteSize; bold: true }
        rotation: note.uprightRotation
        opacity: Math.min(1, note.progress * 6) * (1 - note.progress)
        scale: 0.7 + note.progress * 0.4
    }
    NumberAnimation {
        id: flight
        target: note
        property: "progress"
        from: 0
        to: 1
        duration: note.flightDuration
        easing.type: Easing.OutSine
    }
    Timer {
        id: emission
        onTriggered: {
            note.emitNote();
            note.schedule();
        }
    }
}
