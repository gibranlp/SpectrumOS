import QtQuick
import QtTest
import Quickshell
import "../../configs/spectrum-shell" as Shell

Scope {
    QtObject {
        id: player
        property bool positionSupported: true
        property bool lengthSupported: true
        property real position: 25
        property real length: 200
    }
    QtObject {
        id: theme
        property int panelLeftInset: 52
        property int panelTopInset: 40
        property bool animationsEnabled: false
        property bool widgetBounceEnabled: false
        property string barStyle: "full"
        property bool gamingActive: false
        property int fontSize: 13
        property string fontFamily: "monospace"
        property int volumePercent: 45
        property bool volumeMuted: false
        property var media: ({available:false,playing:false,title:"Track",artist:"Artist",artUrl:""})
        property var mediaPlayer: player
        property var colors: ({surface:"#232029",surface_alt:"#2e2c34",foreground:"#eff3fa",muted:"#a6afbe",accent:"#b293e6"})
    }
    Shell.LevelIndicator {
        id: indicator
        targetScreen: Quickshell.screens[0]
        theme: theme
    }
    TestCase {
        name: "LevelIndicator"
        when: true
        onCompletedChanged: if (completed) {console.log("Level indicator:",qtest_results.passCount,"passed",qtest_results.failCount,"failed");Qt.quit();}
        function cleanup() { if (qtest_results.failed) console.warn("Failed indicator test:", qtest_results.functionName); }
        function init() {
            indicator.dismiss();
            indicator.blocked=false;
            indicator.barPosition="top";
            theme.animationsEnabled=false;
            theme.media={available:false,playing:false,title:"Track",artist:"Artist",artUrl:""};
            theme.volumeMuted=false;
            player.positionSupported=true;player.lengthSupported=true;player.position=25;player.length=200;
            wait(20);
        }
        function playing() {theme.media={available:true,playing:true,title:"Track",artist:"Artist",artUrl:""};}
        function test_volume_without_playback_stays_compact() {
            indicator.show("volume",45,"");wait(20);
            verify(indicator.expanded);verify(indicator.levelVisible);verify(!indicator.trackVisible);
            compare(indicator.state().width,340);
            theme.media={available:true,playing:false,title:"Paused",artist:"Artist"};
            indicator.show("volume",45,"");verify(!indicator.trackVisible);
        }
        function test_volume_while_playing_shows_both_with_progress() {
            playing();indicator.show("volume",45,"");wait(30);
            verify(indicator.trackVisible);verify(indicator.levelVisible);verify(!indicator.trackPending);
            compare(indicator.state().width,400);compare(indicator.trackProgress,0.125);
            compare(findChild(indicator,"track-elapsed").text,"0:25");
            compare(findChild(indicator,"track-remaining").text,"−2:55");
            const preview=Quickshell.env("SPECTRUM_INDICATOR_PREVIEW");
            if (preview) grabImage(indicator.contentItem).save(preview);
        }
        function test_track_then_volume_keeps_song_and_reveals_level() {
            try {
            playing();indicator.showTrack();wait(30);
            const height=indicator.state().height;
            verify(!indicator.levelVisible);
            theme.animationsEnabled=true;
            indicator.show("volume",45,"");
            verify(indicator.trackVisible);verify(indicator.levelVisible);
            wait(80);verify(indicator.levelReveal>0 && indicator.levelReveal<1);
            tryCompare(indicator,"levelReveal",1,600);
            verify(indicator.state().height>height);
            tryCompare(indicator,"levelVisible",false,2200);
            verify(indicator.trackVisible);
            tryCompare(indicator,"levelReveal",0,600);
            tryCompare(indicator,"trackVisible",false,2500);
            } catch(error) {console.warn("test_track_then_volume_keeps_song_and_reveals_level",error.message,String(error.stack));throw error;}
        }
        function test_song_change_during_volume_keeps_both() {
            indicator.show("volume",45,"");
            playing();indicator.showTrack();
            verify(indicator.trackVisible);verify(indicator.levelVisible);
            theme.media={available:true,playing:true,title:"Next song",artist:"Another artist"};
            indicator.showTrack();
            compare(indicator.track.title,"Next song");verify(indicator.levelVisible);verify(!indicator.trackPending);
        }
        function test_timeline_handles_seek_unknown_length_and_unavailable_position() {
            playing();indicator.showTrack();
            player.position=150;compare(indicator.positionSeconds,150);compare(indicator.trackProgress,0.75);
            player.position=250;compare(indicator.positionSeconds,200);compare(indicator.trackProgress,1);
            player.lengthSupported=false;compare(indicator.durationSeconds,0);compare(indicator.trackProgress,0);
            compare(findChild(indicator,"track-remaining").text,"--:--");
            player.positionSupported=false;compare(indicator.positionSeconds,0);
            compare(findChild(indicator,"track-elapsed").text,"--:--");
            compare(indicator.formatTime(3670),"1:01:10");
        }
        function test_closing_keeps_content_until_shell_motion_finishes() {
            try {
            theme.animationsEnabled=true;
            playing();indicator.showTrack();wait(450);
            const height=indicator.state().height;
            indicator.dismiss();wait(30);
            verify(!indicator.expanded);verify(indicator.trackPresented);
            compare(indicator.state().height,height);
            tryCompare(indicator,"trackPresented",false,700);
            } catch(error) {console.warn("test_closing_keeps_content_until_shell_motion_finishes",error.message,String(error.stack));throw error;}
        }
        function test_player_disappears_and_blocked_widgets_close() {
            playing();indicator.show("volume",45,"");
            theme.media={available:false,playing:false};
            verify(!indicator.trackVisible);verify(indicator.levelVisible);
            indicator.blocked=true;verify(!indicator.expanded);
            indicator.show("volume",45,"");indicator.showTrack();verify(!indicator.expanded);
        }
        function test_left_bar_and_muted_volume() {
            indicator.barPosition="left";playing();theme.volumeMuted=true;
            indicator.show("volume",45,"");wait(30);
            verify(indicator.trackVisible);verify(indicator.levelVisible);verify(indicator.muted);
            compare(indicator.state().x,theme.panelLeftInset);compare(indicator.state().position,"left");
            verify(indicator.state().y>=0);
        }
        function test_brightness_keeps_standalone_behavior_and_pending_track() {
            playing();indicator.showTrack();indicator.show("brightness",60,"Monitor");
            verify(!indicator.trackVisible);verify(indicator.levelVisible);compare(indicator.percent,60);
            verify(indicator.trackPending);
            tryCompare(indicator,"levelVisible",false,2200);verify(indicator.trackVisible);
        }
    }
}
