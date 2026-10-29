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
    property double startupUntil: 0
    property double breakUntil: 0
    property string pendingNotification: ""
    readonly property bool paused: inhibited || (settings.pause_focus && focusActive)
    readonly property bool snoozed: Date.now() < snoozedUntil && snoozedUntil > previousTick
    readonly property bool idle: idleMonitor.isIdle
    readonly property bool busy: configProcess.running
    readonly property string status: !ready ? qsTranslate("Spectrum", "Loading…") : !settings.enabled ? qsTranslate("Spectrum", "Reminders are off") : startupUntil > 0 ? qsTranslate("Spectrum", "Starting in a moment…") : breakUntil > 0 ? qsTranslate("Spectrum", "Break · ") + Math.ceil(Math.max(0, breakUntil - previousTick) / 60000) + qsTranslate("Spectrum", " min remaining") : idle ? qsTranslate("Spectrum", "Taking a break") : paused ? qsTranslate("Spectrum", "Paused for your current activity") : snoozed ? qsTranslate("Spectrum", "Snoozed for 10 minutes") : qsTranslate("Spectrum", "Counting active desk time")

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

    Component.onCompleted: configProcess.exec([backendDir + "/spectrum-breaks", "status"])
    IdleMonitor {
        id: idleMonitor
        enabled: state.ready && state.settings.enabled
        timeout: 120
        respectInhibitors: false
        onIsIdleChanged: { if (isIdle && !state.breakUntil && !state.startupUntil) state.reset(); state.previousTick = Date.now(); }
    }
    Process {
        id: configProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    if (!result.ok) { state.error = result.error || "Could not save reminders."; return; }
                    const firstLoad = !state.ready;
                    const wasEnabled = state.settings.enabled;
                    state.settings = result.settings;
                    state.ready = true;
                    state.reset();
                    if (!state.settings.enabled) {
                        state.startupUntil = 0;
                        state.breakUntil = 0;
                        state.pendingNotification = "";
                    } else if (firstLoad || !wasEnabled) {
                        state.startupUntil = Date.now() + (firstLoad ? 90000 : 0);
                        state.pendingNotification = "started";
                    }
                } catch (error) { state.error = qsTranslate("Spectrum", "Could not read break reminder settings."); }
            }
        }
    }
    Process { id: notificationProcess }
    function notify(kind): void {
        notificationProcess.exec([backendDir + "/spectrum-breaks", "notify", kind]);
    }
    function tick(now): void {
        const elapsed = Math.max(0, (now - previousTick) / 1000);
        previousTick = now;
        if (!ready || !settings.enabled) return;
        if (paused || notificationProcess.running || now < snoozedUntil) return;
        if (startupUntil > 0 || pendingNotification) {
            if (now < startupUntil) return;
            startupUntil = 0;
            notify(pendingNotification || "started");
            pendingNotification = "";
            return;
        }
        if (breakUntil > 0) {
            if (now < breakUntil) return;
            breakUntil = 0;
            notify("resumed");
            return;
        }
        // Un salto largo del reloj indica suspensión; no se acumula como trabajo.
        if (elapsed > 45) { reset(); return; }
        if (idle) return;
        eyeElapsed += Math.round(elapsed);
        movementElapsed += Math.round(elapsed);
        if (movementElapsed >= settings.movement_minutes * 60 || eyeElapsed >= settings.eye_minutes * 60) {
            const movementDue = movementElapsed >= settings.movement_minutes * 60;
            notify(movementDue ? "movement" : "eyes");
            breakUntil = now + 180000;
            eyeElapsed = 0;
            if (movementDue) movementElapsed = 0;
        }
    }
    Timer {
        interval: 1000
        running: state.ready && state.settings.enabled
        repeat: true
        onTriggered: state.tick(Date.now())
    }
}
