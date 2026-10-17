import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Item {
    Shell.RecordingDot { id: dot }
    Shell.RecordingStatus { id: status; y: 40 }
    SignalSpy { id: screenSpy; target: status; signalName: "screenRequested" }
    SignalSpy { id: audioSpy; target: status; signalName: "audioRequested" }
    TestCase {
        name: "RecordingDot"
        when: windowShown
        function init() {
            status.screenRecording = false;
            status.audioRecording = false;
            screenSpy.clear();
            audioSpy.clear();
            dot.screenRecording = false;
            dot.audioRecording = false;
        }
        function test_iconsFollowRecorderTypeAndOpenTheCorrectPanel() {
            const camera = findChild(status, "screenRecordingIcon");
            const microphone = findChild(status, "audioRecordingIcon");
            compare(status.visible, false);
            status.audioRecording = true;
            compare(camera.visible, false);
            compare(microphone.visible, true);
            wait(20);
            mouseClick(microphone);
            compare(audioSpy.count, 1);
            compare(screenSpy.count, 0);
            status.screenRecording = true;
            compare(camera.visible, true);
            compare(microphone.visible, true);
            wait(20);
            mouseClick(camera);
            compare(screenSpy.count, 1);
            status.audioRecording = false;
            compare(camera.visible, true);
            compare(microphone.visible, false);
            compare(findChild(status, "recordingStatusDot").active, true);
        }
        function test_eitherRecorderKeepsIndicatorVisible() {
            compare(dot.visible, false);
            dot.screenRecording = true;
            compare(dot.visible, true);
            dot.audioRecording = true;
            dot.screenRecording = false;
            compare(dot.visible, true);
            dot.audioRecording = false;
            compare(dot.visible, false);
        }
        function test_blinksAndRestartsImmediatelyAfterIdle() {
            dot.audioRecording = true;
            compare(dot.opacity, 1);
            compare(String(dot.color), "#ff3b30");
            tryCompare(dot, "opacity", 0, 900);
            tryCompare(dot, "opacity", 1, 900);
            dot.audioRecording = false;
            compare(dot.visible, false);
            wait(550);
            compare(dot.lit, true);
            dot.screenRecording = true;
            compare(dot.opacity, 1);
            tryCompare(dot, "opacity", 0, 900);
        }
    }
}
