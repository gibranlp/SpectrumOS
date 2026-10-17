import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Item {
    id: scene
    width: 800
    height: 600
    Shell.IgorRoutine { id: routine }
    Shell.IgorIllustration { id: cat; width: 180; height: 73.8 }

    QtObject {
        id: buttonTheme
        property bool igorEnabled: false
        property var colors: ({ accent: "#efaac3", surface_alt: "#343638" })
        function toggleIgor(): void { igorEnabled = !igorEnabled; }
    }
    Shell.IgorButton { id: button; x: 500; theme: buttonTheme }

    TestCase {
        name: "Igor"
        when: windowShown

        function init() {
            routine.visitsEnabled = false;
            routine.celebrationsAllowed = true;
            routine.celebrationDuration = 6500;
            routine.random = Math.random;
            routine.monitorNames = [];
            routine.blockedMonitors = [];
            routine.selectedMonitor = "";
            routine.available = true;
            routine.suppressed = false;
            routine.playing = false;
            routine.mediaKind = "music";
            routine.quietVisitProbability = 0;
            routine.napProbability = 0;
            routine.greetingDelay = 1000;
            routine.minimumPause = 2000;
            routine.maximumPause = 2000;
            routine.minimumStay = 1000;
            routine.maximumStay = 1000;
            cat.active = false;
            cat.playing = false;
            cat.waving = false;
            cat.gesture = "curious";
            wait(320);
        }

        function test_media_kind_controls_accessories() {
            routine.playing = true;
            routine.mediaKind = "music";
            verify(routine.musicPlaying);
            verify(!routine.watching);
            routine.mediaKind = "video";
            verify(!routine.musicPlaying);
            verify(routine.watching);
            routine.mediaKind = "unknown";
            verify(!routine.musicPlaying);
            verify(!routine.watching);
            routine.playing = false;
            routine.mediaKind = "video";
            verify(!routine.watching);
        }
        function test_celebrationEmergesWithQuestlineOpen() {
            routine.monitorNames = ["DP-1", "HDMI-A-1"];
            routine.blockedMonitors = routine.monitorNames;
            routine.suppressed = true;
            routine.visitsEnabled = true;
            verify(routine.celebrate());
            verify(routine.visiting);
            verify(routine.monitorNames.includes(routine.selectedMonitor));
            verify(routine.celebrationMessage.length > 0);
            compare(routine.edge, "bottom");
        }
        function test_celebrationKeepsExistingMusicPerchAndVariesPhrases() {
            routine.monitorNames = ["DP-1", "HDMI-A-1"];
            routine.visitsEnabled = true;
            routine.playing = true;
            verify(routine.appear("right", "HDMI-A-1"));
            const position = routine.position;
            verify(routine.celebrate());
            const first = routine.celebrationMessage;
            verify(routine.celebrate());
            verify(routine.celebrationMessage !== first);
            compare(routine.selectedMonitor, "HDMI-A-1");
            compare(routine.edge, "right");
            compare(routine.position, position);
            verify(!routine.waving);
        }
        function test_celebrationHonorsDisabledAndRecording() {
            verify(!routine.celebrate());
            routine.visitsEnabled = true;
            routine.celebrationsAllowed = false;
            verify(!routine.celebrate());
            routine.celebrationsAllowed = true;
            verify(routine.celebrate());
            routine.celebrationsAllowed = false;
            verify(!routine.visiting);
            compare(routine.celebrationMessage, "");
        }
        function test_celebrationExpiresAndRestoresPanelSuppression() {
            routine.monitorNames = ["DP-1"];
            routine.blockedMonitors = ["DP-1"];
            routine.suppressed = true;
            routine.visitsEnabled = true;
            routine.celebrationDuration = 60;
            verify(routine.celebrate());
            tryCompare(routine, "celebrationMessage", "", 300);
            verify(!routine.visiting);
            verify(!routine.manualGreeting);
            verify(!routine.appear("bottom"));
        }
        function test_musicStopKeepsCelebrationUntilItsTimeout() {
            routine.visitsEnabled = true;
            routine.playing = true;
            routine.celebrationDuration = 300;
            verify(routine.celebrate());
            routine.playing = false;
            verify(routine.visiting);
            verify(routine.celebrationMessage.length > 0);
            routine.retreat();
            compare(routine.celebrationMessage, "");
        }
        function test_headphonesFollowMusicAndPalette() {
            const headphones = findChild(cat, "igorHeadphones");
            verify(!headphones.visible);
            cat.playing = true;
            verify(headphones.visible);
            cat.headphonesColor = "#ff0000";
            wait(30);
            const red = grabImage(cat);
            cat.headphonesColor = "#00ff00";
            wait(30);
            const green = grabImage(cat);
            const x = Math.round(cat.width * 90 / 400);
            const y = Math.round(cat.height * 110 / 164);
            verify(red.red(x, y) > red.green(x, y));
            verify(green.green(x, y) > green.red(x, y));
            cat.playing = false;
            verify(!headphones.visible);
        }
        function test_activationGreetsImmediatelyEvenWithPanelOpen() {
            routine.visitsEnabled = true;
            routine.suppressed = true;
            verify(!routine.visiting);
            verify(routine.greet());
            verify(routine.visiting);
            routine.retreat();
            verify(!routine.eligible);
            verify(!routine.appear("bottom"));
        }
        function test_quietCornerVisitStaysWithinOneMinute() {
            routine.visitsEnabled = true;
            routine.visitCount = 1;
            routine.quietVisitProbability = 1;
            routine.minimumQuietStay = 35000;
            routine.maximumQuietStay = 60000;
            verify(routine.appear(""));
            compare(routine.gesture, "quiet");
            verify(routine.position <= 0.08 || routine.position >= 0.92);
            verify(routine.visitDuration >= 35000 && routine.visitDuration <= 60000);
            verify(!routine.waving);
        }
        function test_quietPoseOnlyBlinks() {
            cat.gesture = "quiet";
            cat.playing = true;
            cat.active = true;
            wait(1750);
            compare(cat.headTilt, 0);
            compare(cat.earTilt, 0);
            compare(cat.breath, 0);
            compare(cat.pawLift, 0);
            tryVerify(() => cat.blink > 0.8, 1200);
        }
        function test_edges_data() {
            return [ { tag: "top", edge: "top" }, { tag: "bottom", edge: "bottom" },
                     { tag: "left", edge: "left" }, { tag: "right", edge: "right" } ];
        }
        function test_edges(data) {
            routine.visitsEnabled = true;
            verify(routine.appear(data.edge));
            compare(routine.edge, data.edge);
            verify(routine.position >= 0.28 && routine.position <= 0.72);
            verify(routine.visiting);
            verify(routine.waving);
            routine.retreat();
            verify(!routine.visiting);
        }
        function test_buttonRemainsClickableAfterHover() {
            buttonTheme.igorEnabled = false;
            mouseMove(button, button.width / 2, button.height / 2);
            wait(750);
            mouseClick(button, button.width / 2, button.height / 2);
            verify(buttonTheme.igorEnabled);
            mouseClick(button, button.width / 2, button.height / 2);
            verify(!buttonTheme.igorEnabled);
        }
        function test_buttonToggles() {
            buttonTheme.igorEnabled = false;
            mouseClick(button, button.width / 2, button.height / 2);
            verify(buttonTheme.igorEnabled);
            mouseClick(button, button.width / 2, button.height / 2);
            verify(!buttonTheme.igorEnabled);
        }
        function test_disableRetreats() {
            routine.visitsEnabled = true;
            routine.appear("bottom");
            routine.visitsEnabled = false;
            verify(!routine.visiting);
            verify(!routine.appear("top"));
            verify(!routine.greeted);
        }
        function test_randomVisitsReachEveryMonitor() {
            routine.monitorNames = ["DP-1", "HDMI-A-1", "DP-2"];
            routine.visitsEnabled = true;
            const originalRandom = routine.random;
            try {
                for (let i = 0; i < 3; i++) {
                    routine.random = () => (i + 0.5) / 3;
                    verify(routine.appear("bottom"));
                    compare(routine.selectedMonitor, routine.monitorNames[i]);
                    routine.retreat();
                }
            } finally { routine.random = originalRandom; }
        }
        function test_blockedAndDisconnectedMonitors() {
            routine.monitorNames = ["DP-1", "HDMI-A-1"];
            routine.blockedMonitors = ["DP-1"];
            routine.visitsEnabled = true;
            verify(routine.appear("bottom"));
            compare(routine.selectedMonitor, "HDMI-A-1");
            routine.monitorNames = ["DP-1"];
            verify(!routine.visiting);
            verify(!routine.appear("bottom"));
            routine.blockedMonitors = [];
            verify(routine.appear("bottom"));
            compare(routine.selectedMonitor, "DP-1");
        }
        function test_panelOnVisitedMonitorRetreatsAndAllowsAnotherMonitor() {
            routine.monitorNames = ["DP-1", "HDMI-A-1"];
            routine.visitsEnabled = true;
            verify(routine.appear("bottom", "DP-1"));
            routine.blockedMonitors = ["DP-1"];
            verify(!routine.visiting);
            verify(routine.appear("bottom"));
            compare(routine.selectedMonitor, "HDMI-A-1");
        }
        function test_noScreensPreventVisits() {
            routine.visitsEnabled = true;
            routine.available = false;
            verify(!routine.appear("left"));
            routine.available = true;
            verify(routine.appear("left"));
            routine.available = false;
            verify(!routine.visiting);
        }
        function test_panelsSuppressVisits() {
            routine.visitsEnabled = true;
            routine.appear("right");
            routine.suppressed = true;
            verify(!routine.visiting);
            verify(!routine.appear("bottom"));
        }
        function test_visitAutomaticallyRetreats() {
            routine.greetingDelay = 40;
            routine.minimumStay = 80;
            routine.maximumStay = 80;
            routine.visitsEnabled = true;
            tryCompare(routine, "visiting", true, 500);
            tryCompare(routine, "visiting", false, 500);
        }
        function test_musicArrivesAndStaysBeyondOrdinaryVisit() {
            routine.minimumStay = 40;
            routine.maximumStay = 40;
            routine.visitsEnabled = true;
            routine.playing = true;
            tryCompare(routine, "visiting", true, 400);
            wait(200);
            verify(routine.visiting);
            verify(!routine.waving);
            routine.playing = false;
            verify(!routine.visiting);
        }
        function test_musicAlreadyPlayingWhenVisitsBecomeEligible() {
            routine.playing = true;
            routine.available = false;
            routine.visitsEnabled = true;
            wait(120);
            verify(!routine.visiting);
            routine.available = true;
            tryCompare(routine, "visiting", true, 400);
            routine.suppressed = true;
            verify(!routine.visiting);
            routine.suppressed = false;
            tryCompare(routine, "visiting", true, 400);
        }
        function test_musicReplacesQuietPoseAndCancelsDeparture() {
            routine.minimumQuietStay = 80;
            routine.maximumQuietStay = 80;
            routine.visitsEnabled = true;
            routine.visitCount = 1;
            routine.quietVisitProbability = 1;
            verify(routine.appear(""));
            compare(routine.gesture, "quiet");
            routine.playing = true;
            compare(routine.gesture, "curious");
            wait(200);
            verify(routine.visiting);
            routine.retreat();
            tryCompare(routine, "visiting", true, 400);
            verify(routine.gesture !== "quiet");
        }
        function test_mediaStaysVisibleWithoutRelocating_data() {
            return ["music", "video", "unknown"].map(kind => ({tag:kind,kind:kind}));
        }
        function test_mediaStaysVisibleWithoutRelocating(data) {
            routine.minimumStay = 50;
            routine.maximumStay = 50;
            routine.mediaKind = data.kind;
            routine.visitsEnabled = true;
            routine.playing = true;
            tryCompare(routine,"visiting",true,300);
            const previousEdge = routine.edge;
            const previousPosition = routine.position;
            const previousCount = routine.visitCount;
            wait(250);
            verify(routine.visiting);
            compare(routine.edge,previousEdge);
            compare(routine.position,previousPosition);
            compare(routine.visitCount,previousCount);
            compare(routine.visitDuration,0);
            verify(!routine.napping);
            compare(routine.musicPlaying,data.kind === "music");
            compare(routine.watching,data.kind === "video");
            routine.playing = false;
            verify(!routine.visiting);
        }
        function test_switchingMediaOnlyChangesAccessories() {
            routine.visitsEnabled = true;
            routine.playing = true;
            tryCompare(routine,"visiting",true,300);
            const edge = routine.edge;
            const position = routine.position;
            for (const kind of ["video","music","unknown","music"]) {
                routine.mediaKind = kind;
                compare(routine.musicPlaying,kind === "music");
                compare(routine.watching,kind === "video");
                verify(routine.visiting);
                compare(routine.edge,edge);
                compare(routine.position,position);
                compare(routine.visitDuration,0);
            }
        }
        function test_celebrationDoesNotScheduleMediaDeparture() {
            routine.visitsEnabled = true;
            routine.playing = true;
            routine.celebrationDuration = 40;
            tryCompare(routine,"visiting",true,300);
            verify(routine.celebrate());
            tryCompare(routine,"celebrationMessage","",300);
            wait(1100);
            verify(routine.visiting);
            compare(routine.visitDuration,0);
        }
        function test_musicIsGentleAndStops() {
            cat.active = true;
            cat.playing = true;
            wait(350);
            verify(Math.abs(cat.headTilt) > 0);
            verify(Math.abs(cat.headTilt) <= 6);
            verify(cat.headLift >= -4 && cat.headLift <= 0);
            cat.active = false;
            tryCompare(cat, "headTilt", 0, 600);
            tryCompare(cat, "headLift", 0, 600);
        }
        function test_blinkBreathingAndEarTwitch() {
            cat.active = true;
            wait(1750);
            verify(cat.breath > 0);
            verify(Math.abs(cat.earTilt) > 0);
            tryVerify(() => cat.blink > 0.8, 1200);
            cat.active = false;
            compare(cat.blink, 0);
            tryCompare(cat, "earTilt", 0, 600);
        }
        function test_stretchAndRecovery() {
            cat.gesture = "stretch";
            cat.active = true;
            wait(2400);
            verify(cat.stretch > 0.9);
            verify(cat.headLift < -6);
            wait(2000);
            compare(cat.stretch, 0);
            compare(cat.rightPawLift, 0);
        }
        function test_visitGesturesVary() {
            routine.visitsEnabled = true;
            const seen = [];
            for (let i = 0; i < 4; ++i) {
                routine.appear("bottom");
                seen.push(routine.gesture);
                routine.retreat();
            }
            compare(new Set(seen).size, 4);
        }
        function test_waveReturnsToRest() {
            cat.active = true;
            cat.waving = true;
            wait(1300);
            verify(cat.pawLift < 0);
            verify(Math.abs(cat.pawTilt) <= 32);
            wait(2400);
            compare(cat.pawLift, 0);
            compare(cat.pawTilt, 0);
        }
    }
}
