import QtQuick

QtObject {
    property var players: []
    property var windows: []
    readonly property bool mediaPlaying: players.some(player => player.isPlaying === true)
    readonly property bool fullscreenActive: windows.some(window => window.fullscreen === true)
    readonly property bool blocked: mediaPlaying || fullscreenActive
}
