import QtQuick

Rectangle {
    id: dot
    property bool screenRecording: false
    property bool audioRecording: false
    readonly property bool active: screenRecording || audioRecording
    property bool lit: true
    property bool animationsEnabled: true
    onAnimationsEnabledChanged: lit = true
    implicitWidth: 12
    implicitHeight: 12
    radius: width / 2
    color: "#ff3b30"
    visible: active
    opacity: lit ? 1 : 0
    Accessible.role: Accessible.Indicator
    Accessible.name: screenRecording && audioRecording ? "Screen and audio recording active" : screenRecording ? "Screen recording active" : "Audio recording active"
    onActiveChanged: lit = true

    Timer {
        interval: 500
        running: dot.animationsEnabled && dot.active && dot.visible
        repeat: true
        onTriggered: dot.lit = !dot.lit
    }
}
