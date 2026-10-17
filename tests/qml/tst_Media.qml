import QtQuick
import QtQuick.Window
import QtTest
import Quickshell.Services.Mpris
import "../../configs/spectrum-shell" as Shell

Item {
    id: scene
    QtObject {
        id: player
        property string dbusName: "org.mpris.MediaPlayer2.test"
        property string identity: "First player"
        property int uniqueId: 1
        property int playbackState: MprisPlaybackState.Paused
        property bool isPlaying: playbackState === MprisPlaybackState.Playing
        property string trackTitle: "Test track"
        property string trackArtist: "Test artist"
        property string trackAlbum: "Test album"
        property string trackArtUrl: ""
        property var metadata: ({})
        property bool canControl: true
        property bool canGoNext: true
        property bool canGoPrevious: true
        property bool canTogglePlaying: true
        property string action: ""
        property bool changeTrackOnNext: false
        function next(): void {
            action = "next";
            if (changeTrackOnNext) {
                uniqueId += 1;
                trackTitle = "Track " + uniqueId;
            }
        }
        function previous(): void { action = "previous"; }
        function togglePlaying(): void { action = "toggle"; }
        function stop(): void { action = "stop"; }
    }
    QtObject {
        id: other
        property string dbusName: "org.mpris.MediaPlayer2.other"
        property string identity: "Second player"
        property int uniqueId: 2
        property int playbackState: MprisPlaybackState.Stopped
        property bool isPlaying: playbackState === MprisPlaybackState.Playing
        property string trackTitle: "Other track"
        property string trackArtist: "Other artist"
        property string trackAlbum: ""
        property string trackArtUrl: ""
        property bool canControl: true
        property bool canGoNext: true
        property bool canGoPrevious: true
        property bool canTogglePlaying: true
        property string action: ""
        function next(): void { action = "next"; }
        function previous(): void { action = "previous"; }
        function togglePlaying(): void { action = "toggle"; }
        function stop(): void { action = "stop"; }
    }
    Shell.MediaState { id: media; players: [player] }
    SignalSpy { id: chooser; target: media; signalName: "choiceRequested" }
    TestCase {
        name: "Media"
        when: windowShown || (scene.Window.window !== null && scene.Window.window.visible)
        onCompletedChanged: if (completed) console.log("Media checks:", qtest_results.passCount, "passed,", qtest_results.failCount, "failed")
        function init() {
            media.players = [player];
            media.selectedId = "";
            media.selectedRoster = "";
            media.pendingAction = "";
            player.playbackState = MprisPlaybackState.Paused;
            player.canControl = true;
            player.canGoNext = true;
            player.canGoPrevious = true;
            player.canTogglePlaying = true;
            player.action = "";
            player.uniqueId = 1;
            player.trackTitle = "Test track";
            player.changeTrackOnNext = false;
            player.trackArtUrl = "";
            player.metadata = {};
            other.canControl = true;
            other.playbackState = MprisPlaybackState.Stopped;
            other.uniqueId = 2;
            other.action = "";
            chooser.clear();
        }
        function test_noPlayer() {
            media.players = [];
            compare(media.state.available, false);
            compare(media.state.playing, false);
            compare(media.state.artUrl, "");
        }
        function test_mediaKindFollowsMetadataWithoutPlaybackRestart() {
            player.playbackState = MprisPlaybackState.Playing;
            player.metadata = {"xesam:url":"https://music.youtube.com/watch?v=1"};
            compare(media.state.kind,"music");
            player.metadata = {"xesam:url":"https://www.youtube.com/watch?v=2"};
            compare(media.state.kind,"video");
            compare(media.state.playing,true);
            player.metadata = {};
            compare(media.state.kind,"unknown");
            media.players = [];
            compare(media.state.kind,"unknown");
        }
        function test_artworkFollowsMetadataAndPlayerRemoval() {
            player.trackArtUrl = "file:///tmp/album-one.png";
            compare(media.state.artUrl, player.trackArtUrl);
            player.trackArtUrl = "https://example.com/album-two.png";
            compare(media.state.artUrl, player.trackArtUrl);
            player.trackArtUrl = "";
            compare(media.state.artUrl, "");
            player.trackArtUrl = "file:///tmp/album-one.png";
            media.players = [];
            compare(media.state.artUrl, "");
        }
        function test_metadataAndPlaybackChangeWithoutPolling() {
            compare(media.state.title, "Test track");
            compare(media.state.artist, "Test artist");
            compare(media.state.playing, false);
            player.playbackState = MprisPlaybackState.Playing;
            compare(media.state.playing, true);
            player.playbackState = MprisPlaybackState.Stopped;
            compare(media.state.available, true);
            compare(media.state.playing, false);
        }
        function test_controlsRespectCapabilities() {
            media.control("toggle"); compare(player.action, "toggle");
            media.control("previous"); compare(player.action, "previous");
            player.canGoNext = false;
            media.control("next"); compare(player.action, "previous");
            player.canControl = false;
            media.control("toggle"); compare(player.action, "previous");
        }
        function test_multiplePlayersPromptAndReplayOnlyOnChosenPlayer() {
            media.players = [player, other];
            media.control("toggle");
            compare(chooser.count, 1);
            compare(player.action, "");
            compare(other.action, "");
            compare(media.pendingAction, "toggle");
            media.selectPlayer(media.playerId(other));
            compare(other.action, "toggle");
            compare(player.action, "");
            compare(media.pendingAction, "");
            compare(media.choiceRequired, false);
            media.control("next");
            compare(other.action, "next");
            compare(chooser.count, 1);
        }
        function test_selectionSurvivesPlaybackAndRosterOrderChanges() {
            media.players = [player, other];
            media.selectPlayer(media.playerId(other));
            player.playbackState = MprisPlaybackState.Playing;
            compare(media.state.title, "Other track");
            media.players = [other, player];
            compare(media.choiceRequired, false);
            media.control("stop");
            compare(other.action, "stop");
            compare(player.action, "");
        }
        function test_newPlayerRequiresFreshChoice() {
            media.selectPlayer(media.playerId(player));
            media.players = [player, other];
            compare(media.choiceRequired, true);
            media.selectPlayer(media.playerId(player));
            compare(media.choiceRequired, false);
            other.uniqueId = 3;
            compare(media.choiceRequired, false);
        }
        function test_oneSelectionSurvivesQueuedAndRepeatedTrackChanges() {
            player.changeTrackOnNext = true;
            media.players = [player, other];
            media.control("next");
            compare(chooser.count, 1);
            media.selectPlayer(media.playerId(player));
            compare(player.uniqueId, 2);
            compare(media.choiceRequired, false);
            compare(media.choices.find(item => item.id === media.selectedId).selected, true);
            for (let index = 0; index < 5; index++) {
                media.control("next");
                compare(media.choiceRequired, false);
                compare(media.state.title, player.trackTitle);
            }
            compare(player.uniqueId, 7);
            compare(chooser.count, 1);
            compare(other.action, "");
        }
        function test_otherPlayerTrackChangesKeepSelectedPlayer() {
            media.players = [player, other];
            media.selectPlayer(media.playerId(player));
            other.uniqueId += 1;
            compare(media.choiceRequired, false);
            media.control("toggle");
            compare(player.action, "toggle");
            compare(other.action, "");
            compare(chooser.count, 0);
        }
        function test_disconnectedPlayerFallsBackAndPendingDoesNotReplayTwice() {
            media.players = [player, other];
            media.control("next");
            media.players = [player];
            media.control("toggle");
            compare(player.action, "toggle");
            compare(media.pendingAction, "");
            player.action = "";
            media.selectPlayer(media.playerId(player));
            compare(player.action, "");
        }
        function test_dismissedOrInvalidChoiceDoesNotControlAnything() {
            media.players = [player, other];
            media.control("toggle");
            media.selectPlayer("missing");
            compare(media.pendingAction, "toggle");
            media.pendingAction = "";
            media.selectPlayer(media.playerId(other));
            compare(other.action, "");
            compare(player.action, "");
        }
        function test_uncontrollablePlayerDoesNotCausePrompt() {
            other.canControl = false;
            media.players = [player, other];
            media.control("toggle");
            compare(player.action, "toggle");
            compare(chooser.count, 0);
        }
    }
}
