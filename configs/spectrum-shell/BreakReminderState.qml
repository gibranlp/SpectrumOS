import QtQuick
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: state
    required property string backendDir
    property bool inhibited: false
    property bool focusActive: false
    property var settings: ({enabled:false, eye_minutes:20, movement_minutes:50, pause_focus:true})
    property bool ready: false
    property string error: ""
    property int eyeElapsed: 0
    property int movementElapsed: 0
    property double snoozedUntil: 0
    property double previousTick: Date.now()
    readonly property bool paused: inhibited || (settings.pause_focus && focusActive)
    readonly property bool snoozed: Date.now() < snoozedUntil && snoozedUntil > previousTick
    readonly property bool idle: idleMonitor.isIdle
    readonly property bool busy: configProcess.running
    readonly property string status: !ready ? qsTranslate("Spectrum", "Loading…") : !settings.enabled ? qsTranslate("Spectrum", "Reminders are off") : idle ? qsTranslate("Spectrum", "Taking a break") : paused ? qsTranslate("Spectrum", "Paused for your current activity") : snoozed ? qsTranslate("Spectrum", "Snoozed for 10 minutes") : qsTranslate("Spectrum", "Counting active desk time")

    function configure(change): void {
        if (configProcess.running) return;
        error = "";
        configProcess.exec([backendDir + "/spectrum-breaks", "configure", JSON.stringify(change)]);
    }
    function reset(): void { eyeElapsed = 0; movementElapsed = 0; snoozedUntil = 0; previousTick = Date.now(); }
    function snooze(): void { snoozedUntil = Date.now() + 600000; previousTick = Date.now(); }
    function minutesLeft(elapsed, interval): string {
        const seconds = Math.max(0, interval * 60 - elapsed);
        return Math.ceil(seconds / 60) + " min";
    }
    onPausedChanged: previousTick = Date.now()
    onSettingsChanged: reset()
    Component.onCompleted: configProcess.exec([backendDir + "/spectrum-breaks", "status"])
    IdleMonitor {
        id: idleMonitor
        enabled: state.ready && state.settings.enabled
        timeout: 120
        respectInhibitors: false
        onIsIdleChanged: { if (isIdle) state.reset(); state.previousTick = Date.now(); }
    }
    Process {
        id: configProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    if (!result.ok) { state.error = result.error || "Could not save reminders."; return; }
                    state.settings = result.settings;
                    state.ready = true;
                } catch (error) { state.error = qsTranslate("Spectrum", "Could not read break reminder settings."); }
            }
        }
    }
    Process { id: notificationProcess }
    Timer {
        interval: 10000
        running: state.ready && state.settings.enabled
        repeat: true
        onTriggered: {
            const now = Date.now();
            const elapsed = Math.max(0, (now - state.previousTick) / 1000);
            state.previousTick = now;
            // Un salto largo del reloj indica suspensión; no se acumula como trabajo.
            if (elapsed > 45) { state.reset(); return; }
            if (state.paused || state.idle || now < state.snoozedUntil) return;
            state.eyeElapsed += Math.round(elapsed);
            state.movementElapsed += Math.round(elapsed);
            if (notificationProcess.running) return;
            if (state.movementElapsed >= state.settings.movement_minutes * 60) {
                notificationProcess.exec([state.backendDir + "/spectrum-breaks", "notify", "movement"]);
                state.movementElapsed = 0;
                state.eyeElapsed = 0;
            } else if (state.eyeElapsed >= state.settings.eye_minutes * 60) {
                notificationProcess.exec([state.backendDir + "/spectrum-breaks", "notify", "eyes"]);
                state.eyeElapsed = 0;
            }
        }
    }
}
