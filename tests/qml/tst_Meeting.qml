import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell
import "../../configs/spectrum-shell/MeetingDetection.js" as Detection

Item {
    id: scene
    width: 640; height: 420
    Shell.IgorRoutine { id: routine }
    Shell.IgorStage { id: stage; anchors.fill: parent; catSize: 260; animationDuration: 0; pawsFirstProbability: 0 }
    TestCase {
        name: "IgorMeeting"
        when: windowShown
        function init() {
            routine.playing = false;
            routine.meeting = false;
            routine.mediaKind = "music";
            stage.playing = false;
            stage.watching = false;
            stage.meeting = false;
            stage.visiting = false;
        }
        function test_apps_data() {
            return ["Google Chrome", "Brave", "Zen Browser", "zen-browser", "zen", "Firefox", "Microsoft Teams", "teams-for-linux", "zoom", "vesktop"].map(app => ({tag:app,app:app}));
        }
        function test_apps(data) {
            verify(Detection.isCallingApp({"application.name":data.app}));
            verify(Detection.isCallingApp({"application.process.binary":data.app}));
        }
        function test_unrelated_apps() {
            verify(!Detection.isCallingApp({"application.name":"STASH Music Player"}));
            verify(!Detection.isCallingApp({"application.name":"citizen"}));
            verify(!Detection.isCallingApp({"application.name":"audio-recorder"}));
            verify(!Detection.isCallingApp(null));
        }
        function test_only_active_microphone_capture() {
            const link = {state:7, source:{audio:{},isStream:false,isSink:false},
                target:{audio:{},isStream:true,isSink:false,ready:true,properties:{"application.name":"Zen Browser"}}};
            verify(Detection.isActiveMicrophoneLink(link,7));
            link.state = 6;
            verify(!Detection.isActiveMicrophoneLink(link,7));
            link.state = 7;
            link.source.isSink = true;
            verify(!Detection.isActiveMicrophoneLink(link,7));
            link.source.isSink = false;
            link.source.isStream = true;
            verify(!Detection.isActiveMicrophoneLink(link,7));
            link.source.isStream = false;
            link.target.isSink = true;
            verify(!Detection.isActiveMicrophoneLink(link,7));
            link.target.isSink = false;
            link.target.isStream = false;
            verify(!Detection.isActiveMicrophoneLink(link,7));
            link.target.isStream = true;
            link.target.ready = false;
            verify(!Detection.isActiveMicrophoneLink(link,7));
            link.target.ready = true;
            link.target.properties = {"application.name":"audio-recorder"};
            verify(!Detection.isActiveMicrophoneLink(link,7));
            verify(!Detection.isActiveMicrophoneLink(null,7));
        }
        function test_meeting_wakes_sleeping_igor() {
            routine.visitsEnabled = true;
            routine.available = true;
            routine.suppressed = false;
            verify(routine.nap());
            verify(routine.napping);
            routine.meeting = true;
            routine.playing = true;
            verify(!routine.napping);
            verify(routine.visiting);
            verify(!routine.musicPlaying);
            verify(!routine.watching);
            routine.visitsEnabled = false;
        }
        function test_meeting_overrides_media() {
            routine.playing = true;
            routine.meeting = true;
            for (const kind of ["music", "video", "unknown"]) {
                routine.mediaKind = kind;
                verify(!routine.musicPlaying);
                verify(!routine.watching);
            }
            routine.meeting = false;
            routine.mediaKind = "music";
            verify(routine.musicPlaying);
            routine.mediaKind = "video";
            verify(routine.watching);
        }
        function test_headset_has_mic_without_music_notes_or_glasses() {
            stage.visiting = true;
            stage.meeting = true;
            tryCompare(findChild(stage,"igorRevealMotion"),"progress",1);
            verify(findChild(stage,"igorHeadphones").visible);
            verify(findChild(stage,"igorMeetingMicrophone").visible);
            verify(!findChild(stage,"igorMusicNote").active);
            verify(!findChild(stage,"igorMovieGlasses").visible);
            stage.meeting = false;
            stage.playing = true;
            verify(findChild(stage,"igorHeadphones").visible);
            verify(!findChild(stage,"igorMeetingMicrophone").visible);
        }
    }
}
