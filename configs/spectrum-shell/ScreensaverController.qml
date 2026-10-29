pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

Item {
    id: saver
    required property var theme
    property var settings: ({enabled: false, timeout: 180})
    property string error: ""
    readonly property var diagnostics: ({
        idle: idleMonitor.isIdle, monitorEnabled: idleMonitor.monitoring, armed: lifecycle.armed,
        sessionAllowed: lifecycle.sessionAllowed, pendingStart: pendingStart,
        gaming: theme.gamingActive, recording: theme.recording.active,
        audioRecording: theme.audioRecording.active, keepAwake: theme.idle.active
    })
    readonly property bool busy: settingsAction.running
    readonly property bool active: lifecycle.active
    readonly property bool mediaPlaying: activity.mediaPlaying
    readonly property bool fullscreenActive: activity.fullscreenActive
    readonly property bool mediaBlocked: activity.blocked
    readonly property bool blocked: theme.gamingActive || theme.recording.active || theme.audioRecording.active || mediaBlocked
    property bool pendingStart: false
    property bool pendingPreview: false
    readonly property string effect: "matrix"

    ScreensaverActivity {
        id: activity
        players: Mpris.players.values
        windows: ToplevelManager.toplevels.values
    }
    ScreensaverState {
        id: lifecycle
        enabled: saver.settings.enabled
        blocked: saver.blocked
        idle: idleMonitor.isIdle
    }
    ScreensaverIdleMonitor {
        id: idleMonitor
        monitoring: saver.settings.enabled && !saver.blocked
        timeout: saver.settings.timeout
        onIsIdleChanged: {
            if (isIdle && saver.settings.enabled && !saver.blocked) saver.requestStart(false);
            else if (!isIdle && !lifecycle.previewing) saver.pendingStart = false;
        }
    }
    onBlockedChanged: {
        if (blocked) { pendingStart = false; lifecycle.dismiss(); }
        else if (error === "Pause playback and leave fullscreen before previewing.") error = "";
    }

    function configure(key, value): void {
        if (settingsAction.running) return;
        settingsAction.exec([theme.backend("screensaver-adapter"), "set", key, String(value)]);
    }
    function requestStart(preview): void {
        if (blocked || pendingStart || lifecycle.active) return;
        pendingStart = true;
        pendingPreview = preview;
        error = "";
        if (!sessionProcess.running) sessionProcess.running = true;
    }
    function finishStart(): void {
        if (!pendingStart || !lifecycle.sessionAllowed) return;
        pendingStart = false;
        if (lifecycle.start(pendingPreview) && pendingPreview) previewDeadline.restart();
    }
    function preview(effectName): bool {
        if (blocked) {
            error = mediaBlocked ? "Pause playback and leave fullscreen before previewing."
                : "Finish recording or disable Gaming before previewing.";
            return false;
        }
        requestStart(true);
        return true;
    }
    function dismiss(): void {
        pendingStart = false;
        previewDeadline.stop();
        lifecycle.dismiss();
    }
    function acceptSettings(text): void {
        try {
            const value = JSON.parse(text);
            if (value.error) { error = value.error; return; }
            dismiss();
            settings = value;
            error = "";
        } catch (exception) { error = qsTranslate("Spectrum", "Could not read screensaver settings."); }
    }
    FileView {
        path: saver.theme.configHome + "/spectrumos/screensaver.json"
        watchChanges: true
        printErrors: false
        onFileChanged: { reload(); if (!settingsProcess.running) settingsProcess.running = true; }
    }
    Process {
        id: settingsProcess
        command: [saver.theme.backend("screensaver-adapter"), "--json"]
        running: true
        stdout: StdioCollector { onStreamFinished: saver.acceptSettings(text) }
        onExited: exitCode => { if (exitCode !== 0 && !saver.error) saver.error = qsTranslate("Spectrum", "Could not load screensaver settings."); }
    }
    Process {
        id: settingsAction
        stdout: StdioCollector { onStreamFinished: saver.acceptSettings(text) }
        onExited: exitCode => { if (exitCode !== 0 && !saver.error) saver.error = qsTranslate("Spectrum", "Could not save screensaver settings."); }
    }
    Process {
        id: sessionProcess
        command: [saver.theme.backend("screensaver-adapter"), "session"]
        onExited: exitCode => { if (exitCode !== 0) { lifecycle.sessionAllowed = false; saver.dismiss(); saver.error = qsTranslate("Spectrum", "Could not check the session idle state."); } }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const value = JSON.parse(text);
                    lifecycle.sessionAllowed = value.allowed === true;
                    if (!lifecycle.sessionAllowed) {
                        saver.dismiss();
                        if (value.error) saver.error = value.error;
                    } else saver.finishStart();
                } catch (exception) { lifecycle.sessionAllowed = false; saver.dismiss(); }
            }
        }
    }
    Timer {
        interval: 2000
        repeat: true
        running: lifecycle.active
        onTriggered: if (!sessionProcess.running) sessionProcess.running = true
    }
    Timer { id: previewDeadline; interval: 20000; onTriggered: saver.dismiss() }

    Variants {
        model: Quickshell.screens.filter(screen => screen.name && screen.name !== "FALLBACK" && screen.width > 0 && screen.height > 0)
        PanelWindow {
            id: window
            required property var modelData
            screen: modelData
            visible: lifecycle.active
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: saver.theme.colors.background
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "spectrum-screensaver"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            FocusScope {
                id: input
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => { event.accepted = true; saver.dismiss(); }
                ScreensaverScene {
                    anchors.fill: parent
                    colors: saver.theme.colors
                    running: lifecycle.active
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.AllButtons
                    cursorShape: Qt.BlankCursor
                    property real lastX: -1
                    property real lastY: -1
                    onEntered: { lastX = mouseX; lastY = mouseY; }
                    onPositionChanged: mouse => {
                        if (lastX >= 0 && (Math.abs(mouse.x - lastX) > 3 || Math.abs(mouse.y - lastY) > 3)) saver.dismiss();
                        if (lastX < 0) { lastX = mouse.x; lastY = mouse.y; }
                    }
                    onClicked: saver.dismiss()
                    onWheel: wheel => { wheel.accepted = true; saver.dismiss(); }
                }
            }
        }
    }
}
