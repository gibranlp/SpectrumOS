import QtQuick
import QtTest
import Spectrum.Igor 1.0 as Igor

Item {
    width: 800
    height: 600
    Igor.IgorIllustration { id: illustration }
    Igor.IgorRoutine { id: routine; available: true; monitorNames: ["DP-1"] }
    Igor.IgorStage { id: stage; width: 800; height: 600; animationsEnabled: false }
    Igor.IgorNapStage { id: nap; width: 800; height: 600; animationsEnabled: false }
    TestCase {
        name: "IgorRuntimeContract"
        when: windowShown
        function cleanup() { routine.visitsEnabled = false; routine.retreat(); }
        function test_supported_api_and_free_baseline() {
            compare(Igor.RuntimeInfo.apiVersion, 1);
            compare(Igor.RuntimeInfo.version, "0.3.2");
            compare(Igor.RuntimeInfo.freeOutfitIds, ["day-of-the-dead", "christmas", "christmas-lights", "winter"]);
            verify(String(Igor.RuntimeInfo.faceAsset).endsWith("/igor/face.svg"));
        }
        function test_manual_visit_works_without_accounts_or_network() {
            routine.visitsEnabled = true;
            verify(routine.greet());
            verify(routine.visiting);
            compare(routine.selectedMonitor, "DP-1");
            routine.retreat();
            verify(!routine.visiting);
        }
        function test_media_and_meeting_inputs() {
            routine.playing = true;
            routine.mediaKind = "music";
            verify(routine.musicPlaying);
            routine.meeting = true;
            verify(!routine.musicPlaying);
            routine.meeting = false;
            routine.mediaKind = "video";
            verify(routine.watching);
            routine.playing = false;
        }
        function test_shared_shell_motion_can_be_injected() {
            verify(stage.motionSurface !== null);
            verify(stage.motionViewportWidth > 0);
            stage.motionProgress = 0.5;
            compare(stage.motionProgress, 0.5);
        }
        function test_free_assets_load() {
            const outfit = findChild(illustration, "igorSeasonalOutfit");
            findChild(illustration, "igorOutfitClock").running = false;
            outfit.currentDate = new Date(2026, 10, 1);
            compare(outfit.outfitId, "day-of-the-dead");
            tryCompare(outfit, "status", Image.Ready);
        }
    }
}
