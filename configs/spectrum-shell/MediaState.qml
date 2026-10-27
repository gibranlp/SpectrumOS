import QtQuick
import Quickshell.Services.Mpris
import "MediaKind.js" as MediaKind

QtObject {
    id: media
    property var players: Mpris.players.values
    property string selectedId: ""
    property string selectedRoster: ""
    property string pendingAction: ""
    signal choiceRequested()
    readonly property var controllablePlayers: players.filter(item => item.canControl)
    readonly property string roster: JSON.stringify(controllablePlayers.map(item => playerId(item)).sort())
    readonly property bool choiceRequired: controllablePlayers.length > 1
        && (selectedRoster !== roster || !controllablePlayers.some(item => playerId(item) === selectedId))
    readonly property var player: controllablePlayers.find(item => playerId(item) === selectedId)
        || controllablePlayers.find(item => item.playbackState === MprisPlaybackState.Playing)
        || controllablePlayers.find(item => item.playbackState === MprisPlaybackState.Paused)
        || controllablePlayers[0] || null
    readonly property var choices: controllablePlayers.map(item => ({
        id: playerId(item), name: item.identity || item.desktopEntry || item.dbusName || "Media player",
        title: item.trackTitle || qsTranslate("Spectrum", "No track loaded"),
        status: MprisPlaybackState.toString(item.playbackState), selected: playerId(item) === selectedId && !choiceRequired
    }))
    readonly property var state: ({
        available: player !== null,
        playing: player ? player.isPlaying : false,
        kind: MediaKind.classify(player),
        title: player ? (player.trackTitle || qsTranslate("Spectrum", "Unknown track")) : qsTranslate("Spectrum", "Nothing playing"),
        artist: player ? (player.trackArtist || "Unknown artist") : "",
        album: player ? player.trackAlbum : "",
        artUrl: player ? (player.trackArtUrl || "") : ""
    })

    function playerId(item): string {
        return item.dbusName || item.desktopEntry || item.identity || "player";
    }

    function selectPlayer(id): void {
        if (!controllablePlayers.some(item => playerId(item) === id)) return;
        selectedId = id;
        selectedRoster = roster;
        const action = pendingAction;
        pendingAction = "";
        if (action) control(action);
    }

    function control(action): void {
        if (!["next", "previous", "toggle", "stop"].includes(action)) return;
        if (choiceRequired) {
            pendingAction = action;
            choiceRequested();
            return;
        }
        pendingAction = "";
        if (!player || !player.canControl) return;
        if (action === "next" && player.canGoNext) player.next();
        else if (action === "previous" && player.canGoPrevious) player.previous();
        else if (action === "toggle" && player.canTogglePlaying) player.togglePlaying();
        else if (action === "stop") player.stop();
    }
}
