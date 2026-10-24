import QtQuick

Rectangle {
    id: countdown
    required property var theme
    required property var focusState
    property int fontSize: theme.fontSize
    property bool floating: false
    signal openRequested()
    readonly property bool active: ["starting", "work", "paused"].includes(focusState.phase)
    readonly property int remaining: Math.max(0, Math.floor(Number(focusState.remaining) || 0))
    readonly property string timeText: String(Math.floor(remaining / 60)).padStart(2, "0") + ":" + String(remaining % 60).padStart(2, "0")
    visible: active
    implicitWidth: timerText.implicitWidth + 12
    implicitHeight: floating ? 34 : 28
    radius: 8
    color: floating ? theme.colors.surface : "transparent"
    Accessible.role: Accessible.Button
    Accessible.name: (focusState.phase === "paused" ? "Paused focus " : "Focus ") + timeText + ", open Focus"
    Accessible.onPressAction: openRequested()

    Text {
        id: timerText
        anchors.centerIn: parent
        text: countdown.timeText
        color: countdown.focusState.phase === "paused" ? countdown.theme.colors.muted : countdown.theme.colors.accent
        font { family: countdown.theme.fontFamily; pixelSize: countdown.fontSize; bold: true }
    }
    KeyboardAction {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onActivated: countdown.openRequested()
    }
}
