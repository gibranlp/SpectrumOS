import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Rectangle {
    width: 800; height: 600; color: "#e2e4e8"
    Shell.IgorSleeper { id: cat; x: 270; y: 180; onDismissRequested: active = false }
    Shell.IgorNapStage { id: stage; anchors.fill: parent; onDismissRequested: active = false }
    Shell.IgorRoutine { id: routine; available: true; monitorNames: ["DP-1", "HDMI-A-1"]; greetingDelay: 60000 }
    TestCase {
        name: "IgorSleeper"
        when: windowShown
        function init() {
            mouseMove(cat, -100, -100);
            cat.pawsFirstProbability = 0;
            cat.active = false;
            stage.active = false;
            routine.visitsEnabled = false;
            routine.playing = false;
            routine.blockedMonitors = [];
            routine.suppressed = false;
            routine.napProbability = 0;
            tryCompare(cat, "phase", "hidden", 3000);
        }
        function test_pawsFirstEntrance() {
            cat.pawsFirstProbability = 1;
            cat.active = true;
            tryCompare(cat, "reveal", 1, 1200);
            compare(cat.headReveal, 0);
            tryCompare(cat, "headReveal", 1, 1200);
            tryCompare(cat, "phase", "sleeping", 1600);
        }
        function test_wakeBlinksTwiceThenHeadThenPaws() {
            cat.active = true;
            tryCompare(cat, "phase", "sleeping", 3000);
            cat.active = false;
            tryCompare(cat, "phase", "blinking", 600);
            for (let i = 0; i < 2; i++) {
                tryCompare(cat, "eyelids", 1, 400);
                compare(cat.reveal, 1);
                compare(cat.headReveal, 1);
                tryCompare(cat, "eyelids", 0, 400);
            }
            tryCompare(cat, "phase", "head-leaving", 400);
            compare(cat.reveal, 1);
            tryCompare(cat, "phase", "paws-leaving", 800);
            compare(cat.headReveal, 0);
            compare(cat.reveal, 1);
            tryCompare(cat, "phase", "hidden", 1000);
            compare(cat.reveal, 0);
        }
        function test_disableDuringWakeStopsMotion() {
            cat.active = true;
            tryCompare(cat, "phase", "sleeping", 3000);
            cat.active = false;
            tryCompare(cat, "phase", "blinking", 600);
            cat.animationsEnabled = false;
            compare(cat.phase, "hidden");
            compare(cat.reveal, 0);
            wait(500);
            compare(cat.phase, "hidden");
            cat.animationsEnabled = true;
        }
        function test_edgePerches_data() {
            return [ {tag: "top", edge: "top"}, {tag: "bottom", edge: "bottom"},
                {tag: "left", edge: "left"}, {tag: "right", edge: "right"} ];
        }
        function test_edgePerches(data) {
            stage.edge = data.edge;
            stage.active = true;
            const sleeper = findChild(stage, "igorSleepingFace").parent;
            tryCompare(sleeper, "phase", "sleeping", 3500);
            const perch = findChild(stage, "igorNapPerch");
            if (data.edge === "left") verify(perch.x < 0);
            if (data.edge === "right") verify(perch.x + perch.width > stage.width - stage.leftInset - stage.rightInset);
            if (data.edge === "top") verify(perch.y < 0);
            if (data.edge === "bottom") verify(perch.y + perch.height > stage.height - stage.topInset - stage.bottomInset);
            verify(stage.motionActive);
            stage.grabToImage(result => result.saveToFile("/tmp/igor-nap-" + data.edge + ".png"));
            wait(60);
            stage.active = false;
            tryCompare(stage, "motionActive", false, 3000);
        }
        function test_originalFaceClosesEyesAndDreams() {
            cat.active = true;
            tryCompare(cat, "phase", "settling", 1200);
            cat.grabToImage(result => result.saveToFile("/tmp/igor-standing.png"));
            tryCompare(cat, "phase", "sleeping", 3000);
            compare(cat.eyelids, 1);
            compare(findChild(cat, "igorSleepingFace").blink, 1);
            verify(!findChild(cat, "igorSleepingBody"));
            verify(!findChild(cat, "igorFullTail"));
            tryVerify(() => findChild(cat, "igorSleepZ0").opacity > 0.1, 1000);
            cat.grabToImage(result => result.saveToFile("/tmp/igor-sleeping.png"));
            wait(100);
        }
        function test_stageHoverWakesOnEveryEdge_data() {
            return test_edgePerches_data();
        }
        function test_stageHoverWakesOnEveryEdge(data) {
            stage.edge = data.edge;
            stage.position = 0.7;
            stage.active = true;
            const sleeper = findChild(stage, "igorSleepingFace").parent;
            tryCompare(sleeper, "phase", "sleeping", 3500);
            verify(stage.hoverTarget.width > 0);
            verify(stage.hoverTarget.height > 0);
            const origin = stage.hoverTarget.mapToItem(stage, 0, 0);
            const extent = stage.hoverTarget.mapToItem(stage, stage.hoverTarget.width, stage.hoverTarget.height);
            verify(extent.x > origin.x);
            verify(extent.y > origin.y);
            verify(origin.x >= stage.leftInset);
            verify(origin.y >= stage.topInset);
            verify(extent.x <= stage.width - stage.rightInset);
            verify(extent.y <= stage.height - stage.bottomInset);
            mouseMove(stage.hoverTarget, stage.hoverTarget.width / 2, stage.hoverTarget.height / 2);
            verify(!stage.active);
            compare(sleeper.phase, "leaving");
            compare(stage.hoverTarget.width, 0);
            tryCompare(sleeper, "phase", "hidden", 3000);
        }
        function test_hoverWakesAndLeaves() {
            cat.active = true;
            tryCompare(cat, "phase", "sleeping", 3500);
            mouseMove(cat.hoverTarget, cat.hoverTarget.width / 2, cat.hoverTarget.height / 2);
            verify(!cat.active);
            compare(cat.phase, "leaving");
            tryCompare(cat, "eyelids", 0, 300);
            compare(cat.reveal, 1);
            tryCompare(cat, "phase", "hidden", 3000);
            verify(!cat.motionActive);
            compare(cat.hoverTarget.width, 0);
        }
        function test_dismissDuringArrivalCancelsSleep() {
            cat.active = true;
            wait(100);
            cat.active = false;
            tryCompare(cat, "phase", "hidden", 3000);
            wait(1700);
            compare(cat.phase, "hidden");
        }
        function test_randomMonitorsAndSafePositions() {
            routine.visitsEnabled = true;
            for (let i = 0; i < 12; i++) {
                verify(routine.nap());
                verify(routine.monitorNames.includes(routine.selectedMonitor));
                verify(routine.edges.includes(routine.edge));
                verify(routine.position >= 0.02 && routine.position <= 0.98);
                compare(routine.visitDuration, 0);
                routine.retreat();
            }
        }
        function test_mediaWakesIgorAndPauseEndsMediaVisit() {
            routine.visitsEnabled = true;
            routine.napProbability = 1;
            routine.visitCount = 1;
            routine.minimumStay = 80;
            routine.maximumStay = 80;
            verify(routine.appear(""));
            verify(routine.napping);
            routine.playing = true;
            verify(routine.visiting);
            verify(!routine.napping);
            compare(routine.visitDuration,0);
            verify(!routine.nap());
            routine.playing = false;
            verify(!routine.visiting);
        }
        function test_napHonorsRecordingPanelsAndDisabled() {
            verify(!routine.nap());
            routine.visitsEnabled = true;
            routine.blockedMonitors = routine.monitorNames;
            verify(!routine.nap());
            routine.blockedMonitors = [];
            verify(routine.nap());
            routine.suppressed = true;
            verify(!routine.visiting);
        }
        function test_celebrationReturnsToPerch() {
            routine.visitsEnabled = true;
            verify(routine.nap());
            verify(routine.celebrate());
            verify(!routine.napping);
            verify(routine.celebrationMessage.length > 0);
        }
    }
}
