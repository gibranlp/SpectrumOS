//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Notifications
import Quickshell.Wayland

ShellRoot {
    id: shell

    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")
    readonly property string palettePath: Quickshell.env("SPECTRUM_SHELL_PALETTE") || (cacheHome + "/spectrumos/theme/current/palette.json")
    readonly property string fontPath: cacheHome + "/spectrumos/theme/current/kitty.conf"
    readonly property string backendDir: Quickshell.env("SPECTRUM_SHELL_BACKEND_DIR") || "/usr/lib/spectrumos"
    property var colors: ({ background: "#15131a", surface: "#232029", surface_alt: "#2e2c34", foreground: "#eff3fa", muted: "#a6afbe", accent: "#b293e6" })
    property var brightness: ({ devices: [], error: "Checking display brightness…" })
    readonly property bool brightnessBusy: brightnessActionProcess.running
    property bool brightnessRefreshPending: false
    property int brightnessRevision: 0
    property string brightnessActionError: ""
    property var overview: ({ hostname: "SpectrumOS", load: "…", memory: "…", disk: "…", audio: "…", uptime: "…", brightness: { available: false, percent: 0 }, font_size: "13px", font_family: "jetbrains-mono", font_families: [] })
    property var network: ({ available: false, wifi_enabled: false, connection_type: "none", status: "Checking network…", ethernet: { connected: false }, wifi: { connected: false } })
    property var audioDevices: ({ available: false, sinks: [], sources: [] })
    readonly property bool volumeAvailable: !!(Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.ready && Pipewire.defaultAudioSink.audio)
    readonly property int volumePercent: volumeAvailable ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) : 0
    readonly property bool volumeMuted: volumeAvailable && Pipewire.defaultAudioSink.audio.muted
    PwObjectTracker { objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : [] }
    readonly property var media: mediaState.state
    readonly property var mediaPlayers: mediaState.choices
    readonly property bool mediaChoiceRequired: mediaState.choiceRequired
    readonly property string mediaPendingAction: mediaState.pendingAction
    MediaState { id: mediaState; onChoiceRequested: shell.openOnFocused("showMediaChooser") }

    function selectMediaPlayer(id): void { mediaState.selectPlayer(id); }
    function dismissMediaChoice(): void { mediaState.pendingAction = ""; }
    property var themeState: ({ wallpapers: [], palette: {}, gowall: {} })
    property var displays: ({ monitors: [] })
    property var workspaceAssignments: ({ workspace_monitors: {} })
    property var weather: ({ temperature: "—", icon: "", location: "" })
    property var recording: ({ active: false })
    property var audioRecording: ({ active: false })
    property var performance: ({ available: false, mode: "balanced" })
    property var idle: ({ active: false })
    property bool performancePending: false
    property bool idlePending: false
    readonly property var screensaverSettings: screensaver.settings
    readonly property bool screensaverBusy: screensaver.busy
    readonly property string screensaverError: screensaver.error
    readonly property bool screensaverMediaBlocked: screensaver.mediaBlocked
    ScreensaverController { id: screensaver; theme: shell }
    function configureScreensaver(key, value): void { screensaver.configure(key, value); }
    function previewScreensaver(): void { screensaver.preview(""); }
    property var keyboardLayout: ({ id: "", label: "" })
    property var workspaceIcons: ({ current: "pacman", states: { active: "󰮯", occupied: "󰊠", empty: "•" }, glyphs: [], sets: [] })
    property string actionError: ""
    readonly property bool actionBusy: actionProcess.running
    property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontSize: Math.max(8, Math.min(24, parseInt(overview.font_size) || 13))
    property string pendingPassword: ""
    property alias toastNotifications: toastModel
    ListModel { id: toastModel }

    function removeToast(toastId): void {
        for (let index = 0; index < toastModel.count; index++) {
            if (toastModel.get(index).toastId === toastId) {
                toastModel.remove(index);
                return;
            }
        }
    }
    property int nextToastId: 0
    property var notificationHistory: []
    property bool doNotDisturb: false
    property bool igorEnabled: false
    property bool desktopLogoEnabled: true
    property string desktopLogoCorner: "bottom-right"
    property bool igorGreetingPending: false
    QuestlineWorkspace { id: sharedQuestlineWorkspace; backendDir: shell.backendDir }
    property bool igorMeetingPreview: false
    Timer {
        id: igorMeetingPreviewTimer
        interval: 20000
        onTriggered: shell.igorMeetingPreview = false
    }
    MeetingState { id: meetingState }
    IgorRoutine {
        id: igorRoutine
        visitsEnabled: shell.igorEnabled && !shell.gamingActive && !screensaver.active
        available: monitorNames.length > 0
        monitorNames: bars.instances.map(bar => bar.screen.name)
        blockedMonitors: bars.instances.filter(bar => bar.igorSuppressed).map(bar => bar.screen.name)
        suppressed: monitorNames.length === blockedMonitors.length
        playing: shell.igorMeetingPreview || meetingState.active || shell.media.playing === true
        meeting: shell.igorMeetingPreview || meetingState.active
        mediaKind: shell.media.kind || "unknown"
        celebrationsAllowed: !shell.gamingActive && !shell.recording.active && !shell.audioRecording.active && !screensaver.active
    }
    property bool widgetBounceEnabled: true
    property string barPosition: "left"
    property string barStyle: "full"
    property bool gamingActive: false
    property var gamingStatus: ({ active: false, error: "" })
    readonly property bool animationsEnabled: !gamingActive
    property string barProfile: "standard"
    property var barProfiles: ({})
    readonly property bool barVisible: !shell.gamingActive && barProfile !== "minimal"
    readonly property int barLeftInset: barVisible && barPosition === "left" ? 52 : 0
    readonly property int panelLeftInset: shell.gamingActive ? 0 : barVisible ? barLeftInset : 8
    readonly property int panelTopInset: shell.gamingActive ? 0 : barVisible && barPosition === "top" ? 34 : 8
    property string activeWindowTitle: ""
    property string activeWindowIdentity: ""
    property string currentDateTime: Qt.formatDateTime(new Date(), "ddd d MMM  HH:mm")
    property var focusState: ({ phase: "idle", remaining: 1500, task: "", tasks: [] })
    property var waveSamples: []
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property bool statisticsVisible: bars.instances.some(bar => bar.barProfile === "detailed" || bar.dashboardOpen || bar.controlCenterOpen)
    readonly property bool controlsVisible: bars.instances.some(bar => bar.controlCenterOpen)
    readonly property bool waveformVisible: bars.instances.some(bar =>
        (!shell.gamingActive && bar.widgetOpen && bar.widgetPage === "audio") || (shell.media.playing && bar.barProfile === "multimedia"))

    NotificationServer {
        id: notificationServer
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: notification => {
            notification.tracked = true;
            if (notification.appName !== "Spectrum Volume")
                shell.notificationHistory = [{
                    notification: notification,
                    appName: notification.appName,
                    summary: notification.summary,
                    body: notification.body,
                    actions: []
                }, ...shell.notificationHistory].slice(0, 50);
            if (notification.appName !== "Spectrum Volume")
                shell.toastNotifications.append({
                    toastId: ++shell.nextToastId,
                    notificationId: notification.id,
                    expiresAt: Date.now() + 5000,
                    appName: notification.appName,
                    iconSource: shell.notificationIcon(notification),
                    summary: notification.summary,
                    body: notification.body
                });
            while (shell.toastNotifications.count > 10)
                shell.toastNotifications.remove(0);
        }
    }

    function backend(name): string { return backendDir + "/" + name; }
    function notificationIcon(notification): string {
        const entry = DesktopEntries.byId(notification.desktopEntry || "")
            || DesktopEntries.heuristicLookup(notification.appName || "")
            || DesktopEntries.applications.values.find(application =>
                application.name.toLowerCase() === (notification.appName || "").toLowerCase());
        const icon = notification.appIcon || (entry ? entry.icon : "") || notification.image;
        if (!icon)
            return "";
        if (icon.startsWith("/"))
            return "file://" + icon;
        return icon.includes("://") ? icon : Quickshell.iconPath(icon, true);
    }
    function workspaceGlyph(number, state): string {
        return workspaceIcons.states && workspaceIcons.states[state]
            ? workspaceIcons.states[state] : workspaceIcons.glyphs[number - 1] || String(number);
    }

    function workspacesForMonitor(monitorName): var {
        if (!monitorName)
            return [];
        const assignments = workspaceAssignments.workspace_monitors || {};
        const configured = Object.keys(assignments);
        if (configured.length)
            return configured.filter(number => assignments[number] === monitorName).map(Number).sort((a, b) => a - b);
        return Hyprland.workspaces.values
            .filter(workspace => workspace.id > 0 && workspace.monitor && workspace.monitor.name === monitorName)
            .map(workspace => workspace.id)
            .sort((a, b) => a - b);
    }

    function workspaceOccupied(number): bool {
        for (const workspace of Hyprland.workspaces.values) {
            if (workspace.id === number)
                return workspace.toplevels.values.length > 0;
        }
        return false;
    }

    function refreshControls(): void {
        if (!overviewProcess.running)
            overviewProcess.running = true;
        if (!networkProcess.running)
            networkProcess.running = true;
        if (!audioProcess.running)
            audioProcess.running = true;
        if (!themeProcess.running)
            themeProcess.running = true;
        if (!displayProcess.running)
            displayProcess.running = true;
        if (!workspaceAssignmentsProcess.running)
            workspaceAssignmentsProcess.running = true;
        if (!workspaceIconsProcess.running)
            workspaceIconsProcess.running = true;
        if (!keyboardLayoutProcess.running)
            keyboardLayoutProcess.running = true;
    }

    function openOnFocused(name): void {
        for (const instance of bars.instances) {
            if (instance.monitor && instance.monitor.focused) {
                instance[name]();
                return;
            }
        }
        if (bars.instances.length)
            bars.instances[0][name]();
    }

    function openWidgetOnFocused(page): void {
        for (const instance of bars.instances) {
            if (instance.monitor && instance.monitor.focused) {
                instance.toggleBarWidget(page);
                return;
            }
        }
        if (bars.instances.length)
            bars.instances[0].toggleBarWidget(page);
    }

    function refreshBrightness(): void {
        if (brightnessProcess.running || brightnessActionProcess.running)
            brightnessRefreshPending = true;
        else {
            brightnessRefreshPending = false;
            brightnessProcess.running = true;
        }
    }

    function changeBrightness(operation, device): void {
        if (brightnessBusy || !["up", "down"].includes(operation)) return;
        actionError = "";
        brightnessActionError = "";
        brightnessRevision++;
        brightness = Object.assign({}, brightness, { error: "" });
        brightnessActionProcess.exec([backend("brightness-adapter"), operation, "--device", device, "--json"]);
    }

    function runAction(command): void {
        if (!actionProcess.running) {
            actionError = "";
            actionProcess.exec(command);
        }
    }

    function cyclePerformanceMode(): void {
        const modes = performance.modes || ["power-saver", "balanced", "performance"];
        if (modes.length)
            setPerformanceMode(modes[(modes.indexOf(performance.mode) + 1) % modes.length]);
    }

    function setPerformanceMode(mode): void {
        if (!performance.available || performancePending || performance.mode === mode)
            return;
        performancePending = true;
        actionError = "";
        performance = Object.assign({}, performance, { mode: mode });
        performanceActionProcess.exec([backend("performance-mode"), "--set", mode]);
    }

    function toggleKeepAwake(): void {
        if (idlePending)
            return;
        idlePending = true;
        actionError = "";
        idle = { active: !idle.active };
        idleActionProcess.exec([backend("idle-adapter"), idle.active ? "on" : "off"]);
    }

    function controlMedia(action): void {
        mediaState.control(action);
    }

    function connectSecuredWifi(ssid, password): void {
        if (wifiProcess.running || !password)
            return;
        actionError = "";
        pendingPassword = password;
        wifiProcess.exec([backend("network-adapter"), "connect-secured", ssid]);
    }

    function toggleIgor(): void {
        if (!layoutActionProcess.running) {
            igorGreetingPending = !igorEnabled;
            layoutActionProcess.exec([backend("spectrum-shell-layout"), "set-mascot", igorEnabled ? "off" : "on"]);
        }
    }

    function toggleDesktopLogo(): void {
        if (!layoutActionProcess.running)
            layoutActionProcess.exec([backend("spectrum-shell-layout"), "set-logo", desktopLogoEnabled ? "off" : "on"]);
    }

    function setDesktopLogoCorner(corner): void {
        if (["top-left", "top-right", "bottom-left", "bottom-right"].includes(corner) && !layoutActionProcess.running)
            layoutActionProcess.exec([backend("spectrum-shell-layout"), "set-logo-corner", corner]);
    }

    function setWidgetBounce(enabled): void {
        if (!layoutActionProcess.running)
            layoutActionProcess.exec([backend("spectrum-shell-layout"), "set-bounce", enabled ? "on" : "off"]);
    }

    function setBarStyle(style): void {
        if (["full", "islands"].includes(style) && !layoutActionProcess.running)
            layoutActionProcess.exec([backend("spectrum-shell-layout"), "set-style", style]);
    }

    function setBarPosition(position): void {
        if ((position === "top" || position === "left") && !layoutActionProcess.running)
            layoutActionProcess.exec([backend("spectrum-shell-layout"), "set", position]);
    }

    function leaveGaming(): void {
        if (!layoutActionProcess.running)
            layoutActionProcess.exec([backend("spectrum-shell-layout"), "set-gaming", "off"]);
    }

    function setBarProfile(profile, monitorName): void {
        if (!["standard", "minimal", "detailed", "multimedia", "gaming"].includes(profile) || layoutActionProcess.running)
            return;
        if (profile === "gaming") {
            layoutActionProcess.exec([backend("spectrum-shell-layout"), "set-profile", profile]);
            return;
        }
        if (!monitorName) {
            const focused = bars.instances.find(instance => instance.monitor && instance.monitor.focused);
            const target = focused || bars.instances[0];
            monitorName = target ? target.screen.name : "";
        }
        if (monitorName)
            layoutActionProcess.exec([backend("spectrum-shell-layout"), "set-profile", profile, monitorName]);
    }

    function applyPalette(contents): bool {
        try {
            const parsed = JSON.parse(contents);
            if (!parsed.roles)
                return false;
            shell.colors = parsed.roles;
            return true;
        } catch (error) {
            console.warn("SpectrumShell palette:", error);
            return false;
        }
    }

    FileView {
        id: paletteFile
        path: shell.palettePath
        watchChanges: true
        onFileChanged: reload()
        onTextChanged: shell.applyPalette(text())
    }

    FileView {
        id: fontFile
        path: shell.fontPath
        watchChanges: true
        onFileChanged: reload()
        onTextChanged: {
            const match = text().match(/^font_family\s+(.+)$/m);
            if (match)
                shell.fontFamily = match[1].trim();
        }
    }

    Process {
        command: ["systemctl", "--user", "start", "spectrum-hotkey.service"]
        running: true
    }

    Process {
        id: brightnessProcess
        property int revision: 0
        onStarted: revision = shell.brightnessRevision
        command: [shell.backend("brightness-adapter"), "status", "--json"]
        stdout: StdioCollector { onStreamFinished: {
            if (!shell.brightnessBusy && brightnessProcess.revision === shell.brightnessRevision) {
                try { shell.brightness = JSON.parse(text); }
                catch (error) { shell.brightness = Object.assign({}, shell.brightness, {error: "Could not read display brightness."}); }
            }
        } }
        onExited: exitCode => {
            if (exitCode !== 0)
                shell.brightness = Object.assign({}, shell.brightness, {error: "Could not read display brightness."});
            if (shell.brightnessRefreshPending) brightnessRefresh.restart();
        }
    }

    Process {
        id: brightnessActionProcess
        stdout: StdioCollector { onStreamFinished: {
            try {
                const result = JSON.parse(text);
                if (result.ok && result.device) {
                    shell.brightness = Object.assign({}, shell.brightness, {
                        devices: (shell.brightness.devices || []).map(device => device.id === result.device.id ? result.device : device), error: ""
                    });
                } else {
                    shell.brightnessActionError = result.error || "Could not change brightness.";
                }
            } catch (error) {
                shell.brightnessActionError = "Could not change brightness.";
            }
        } }
        onExited: exitCode => {
            if (exitCode !== 0 && !shell.brightnessActionError)
                shell.brightnessActionError = "Could not change brightness.";
            if (shell.brightnessRefreshPending) brightnessRefresh.restart();
        }
    }

    Timer {
        id: brightnessRefresh
        interval: 100
        onTriggered: shell.refreshBrightness()
    }

    Timer {
        interval: 3000
        running: shell.controlsVisible || bars.instances.some(bar => bar.widgetOpen && bar.widgetPage === "displays")
        triggeredOnStart: true
        repeat: true
        onTriggered: { if (!shell.brightnessBusy) shell.refreshBrightness(); }
    }

    Process {
        id: overviewProcess
        command: [shell.backend("system-adapter"), "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    shell.overview = JSON.parse(text);
                    if (shell.overview.font_family_rendered)
                        shell.fontFamily = shell.overview.font_family_rendered;
                } catch (error) {
                    console.warn("SpectrumShell overview:", error);
                }
            }
        }
    }

    Process {
        id: networkProcess
        command: [shell.backend("network-adapter"), "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    shell.network = JSON.parse(text);
                } catch (error) {
                    console.warn("SpectrumShell network:", error);
                }
            }
        }
    }

    Process {
        id: audioProcess
        command: [shell.backend("control-adapter"), "--audio-json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    shell.audioDevices = JSON.parse(text);
                } catch (error) {
                    console.warn("SpectrumShell audio devices:", error);
                }
            }
        }
    }

    Process {
        id: themeProcess
        command: [shell.backend("theme-adapter"), "--json"]
        stdout: StdioCollector { onStreamFinished: {
            try { shell.themeState = JSON.parse(text); } catch (error) { console.warn("SpectrumShell theme:", error); }
        } }
    }

    Process {
        id: displayProcess
        command: [shell.backend("control-adapter"), "--display-json"]
        stdout: StdioCollector { onStreamFinished: {
            try { shell.displays = JSON.parse(text); } catch (error) { console.warn("SpectrumShell displays:", error); }
        } }
    }

    Process {
        id: workspaceAssignmentsProcess
        command: [shell.backend("workspace-layout"), "--json"]
        stdout: StdioCollector { onStreamFinished: {
            try { shell.workspaceAssignments = JSON.parse(text); }
            catch (error) { console.warn("SpectrumShell workspace assignments:", error); }
        } }
    }

    Process {
        id: workspaceIconsProcess
        command: [shell.backend("waybar-workspace-icons"), "--json"]
        stdout: StdioCollector { onStreamFinished: {
            try { shell.workspaceIcons = JSON.parse(text); } catch (error) { console.warn("SpectrumShell workspace icons:", error); }
        } }
    }

    Process {
        id: gamingProcess
        command: [shell.backend("spectrum-gaming-session")]
        running: true
        onExited: gamingRestart.restart()
        stdout: SplitParser {
            onRead: data => {
                try { shell.gamingStatus = JSON.parse(data); }
                catch (error) { console.warn("SpectrumShell gaming:", error); }
            }
        }
    }

    Timer {
        id: gamingRestart
        interval: 1000
        onTriggered: if (!gamingProcess.running) gamingProcess.running = true
    }

    FileView {
        path: shell.configHome + "/spectrumos/shell.json"
        watchChanges: true
        onFileChanged: { reload(); if (!layoutProcess.running) layoutProcess.running = true; }
    }

    Process {
        id: layoutProcess
        command: [shell.backend("spectrum-shell-layout"), "--json"]
        running: true
        stdout: StdioCollector { onStreamFinished: {
            try {
                const state = JSON.parse(text);
                shell.gamingActive = state.gaming_enabled === true;
                shell.barStyle = state.bar_style || "full";
                shell.barPosition = state.bar_position === "top" ? "top" : "left";
                shell.barProfile = state.bar_profile || "standard";
                shell.barProfiles = state.bar_profiles || {};
                shell.igorEnabled = state.igor_enabled !== false;
                shell.widgetBounceEnabled = state.widget_bounce_enabled !== false;
                shell.desktopLogoEnabled = state.desktop_logo_enabled !== false;
                shell.desktopLogoCorner = state.desktop_logo_corner || "bottom-right";
                if (shell.igorGreetingPending) {
                    shell.igorGreetingPending = false;
                    if (shell.igorEnabled)
                        Qt.callLater(() => igorRoutine.greet());
                }
            }
            catch (error) { console.warn("SpectrumShell layout:", error); }
        } }
    }

    Process {
        id: activeWindowProcess
        command: ["hyprctl", "activewindow", "-j"]
        running: true
        stdout: StdioCollector { onStreamFinished: {
            try {
                const window = JSON.parse(text);
                shell.activeWindowTitle = window.title || "";
                shell.activeWindowIdentity = window.address || "";
            }
            catch (error) {
                shell.activeWindowTitle = "";
                shell.activeWindowIdentity = "";
            }
        } }
    }

    Timer {
        id: activeWindowRefresh
        interval: 40
        onTriggered: { if (!activeWindowProcess.running) activeWindowProcess.running = true; }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["activewindow", "activewindowv2", "windowtitle", "windowtitlev2"].includes(event.name))
                activeWindowRefresh.restart();
            if (["monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "configreloaded"].includes(event.name))
                workspaceAssignmentsRefresh.restart();
        }
    }

    Timer {
        id: workspaceAssignmentsRefresh
        interval: 1500
        onTriggered: {
            if (workspaceAssignmentsProcess.running)
                restart();
            else
                workspaceAssignmentsProcess.running = true;
        }
    }

    Process {
        id: focusProcess
        command: [shell.backend("spectrum-focus"), "state"]
        stdout: StdioCollector { onStreamFinished: {
            try { shell.focusState = JSON.parse(text); focusFile.reload(); }
            catch (error) { console.warn("SpectrumShell focus timer:", error); }
        } }
    }

    Process {
        id: cavaProcess
        property string lastFrame: ""
        command: [shell.backend("waybar-cava"), "--wave"]
        running: shell.waveformVisible
        onRunningChanged: {
            if (!running) {
                lastFrame = "";
                shell.waveSamples = [];
            }
        }
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const frame = data.trim();
                if (frame === cavaProcess.lastFrame)
                    return;
                cavaProcess.lastFrame = frame;
                const samples = frame.split(/\s+/).map(Number);
                if (samples.length === 40 && samples.every(Number.isFinite))
                    shell.waveSamples = samples;
            }
        }
    }

    Timer {
        interval: 15000
        repeat: true
        running: ["starting", "work", "paused"].includes(shell.focusState.phase)
        onTriggered: { if (!focusProcess.running) focusProcess.running = true; }
    }

    Process {
        id: layoutActionProcess
        onExited: {
            if (!layoutProcess.running)
                layoutProcess.running = true;
        }
    }

    Process {
        id: weatherProcess
        command: [shell.backend("weather-adapter"), "--json"]
        stdout: StdioCollector { onStreamFinished: {
            try { shell.weather = JSON.parse(text); } catch (error) { console.warn("SpectrumShell weather:", error); }
        } }
    }

    Process {
        id: audioRecorderProcess
        command: [shell.backend("audio-recorder"), "--status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { shell.audioRecording = JSON.parse(text); audioRecorderFile.reload(); }
                catch (error) { console.warn("SpectrumShell audio recorder:", error); }
            }
        }
    }

    Process {
        id: recorderProcess
        command: [shell.backend("recorder-menu"), "--json"]
        stdout: StdioCollector { onStreamFinished: {
            try { shell.recording = JSON.parse(text); recorderFile.reload(); } catch (error) { console.warn("SpectrumShell recorder:", error); }
        } }
    }

    Process {
        id: performanceProcess
        command: [shell.backend("performance-mode"), "--json"]
        stdout: StdioCollector { onStreamFinished: {
            if (!shell.performancePending) {
                try { shell.performance = JSON.parse(text); } catch (error) { console.warn("SpectrumShell performance:", error); }
            }
        } }
    }

    Process {
        id: performanceActionProcess
        onExited: exitCode => {
            shell.performancePending = false;
            if (exitCode !== 0)
                shell.actionError = "Could not change performance mode";
            performanceRefresh.restart();
        }
    }

    Timer {
        id: performanceRefresh
        interval: 100
        onTriggered: {
            if (performanceProcess.running)
                restart();
            else
                performanceProcess.running = true;
        }
    }

    Process {
        id: idleProcess
        command: [shell.backend("idle-adapter"), "--json"]
        stdout: StdioCollector { onStreamFinished: {
            if (!shell.idlePending) {
                try { shell.idle = JSON.parse(text); } catch (error) { console.warn("SpectrumShell idle:", error); }
            }
        } }
    }

    Process {
        id: idleActionProcess
        onExited: exitCode => {
            shell.idlePending = false;
            if (exitCode !== 0)
                shell.actionError = "Could not change keep-awake state";
            idleRefresh.restart();
        }
    }

    Timer {
        id: idleRefresh
        interval: 100
        onTriggered: {
            if (idleProcess.running)
                restart();
            else
                idleProcess.running = true;
        }
    }

    Process {
        id: keyboardLayoutProcess
        command: [shell.backend("keyboard-layout"), "--json"]
        stdout: StdioCollector { onStreamFinished: {
            try { shell.keyboardLayout = JSON.parse(text); } catch (error) { console.warn("SpectrumShell keyboard layout:", error); }
        } }
    }

    Process {
        id: wifiProcess
        stdinEnabled: true
        onStarted: {
            write(shell.pendingPassword + "\n");
            shell.pendingPassword = "";
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    shell.actionError = text.trim().split("\n")[0];
            }
        }
        onExited: (exitCode) => {
            shell.pendingPassword = "";
            if (exitCode !== 0 && !shell.actionError)
                shell.actionError = "Wi-Fi connection failed";
            shell.refreshControls();
            if (!weatherProcess.running)
                weatherProcess.running = true;
        }
    }

    Process {
        id: actionProcess
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    shell.actionError = text.trim().split("\n")[0];
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0 && !shell.actionError)
                shell.actionError = "Action failed";
            overviewProcess.running = true;
            shell.refreshControls();
            if (!performanceProcess.running)
                performanceProcess.running = true;
            if (!keyboardLayoutProcess.running)
                keyboardLayoutProcess.running = true;
            if (!weatherProcess.running)
                weatherProcess.running = true;
        }
    }

    Component.onCompleted: {
        for (const process of [overviewProcess, networkProcess, recorderProcess, audioRecorderProcess, performanceProcess,
                               idleProcess, keyboardLayoutProcess, workspaceIconsProcess, focusProcess])
            process.running = true;
    }

    FileView {
        id: focusFile
        printErrors: false
        path: shell.stateHome + "/spectrumos/focus/state.json"
        watchChanges: true
        onFileChanged: reload()
        onTextChanged: {
            try { shell.focusState = JSON.parse(text()); } catch (error) {}
        }
    }

    FileView {
        printErrors: false
        path: shell.stateHome + "/spectrumos/waybar/workspace_icons"
        watchChanges: true
        onFileChanged: { reload(); if (!workspaceIconsProcess.running) workspaceIconsProcess.running = true; }
    }

    FileView {
        printErrors: false
        path: shell.configHome + "/spectrumos/keyboard-layout"
        watchChanges: true
        onFileChanged: { reload(); if (!keyboardLayoutProcess.running) keyboardLayoutProcess.running = true; }
    }

    FileView {
        id: audioRecorderFile
        printErrors: false
        path: shell.stateHome + "/spectrumos/audio-recorder/status.json"
        watchChanges: true
        onFileChanged: { reload(); if (!audioRecorderProcess.running) audioRecorderProcess.running = true; }
    }

    Timer {
        interval: 2000
        running: shell.audioRecording.active
        repeat: true
        onTriggered: if (!audioRecorderProcess.running) audioRecorderProcess.running = true
    }

    FileView {
        id: recorderFile
        printErrors: false
        path: shell.stateHome + "/spectrumos/recorder/pid"
        watchChanges: true
        onFileChanged: { reload(); if (!recorderProcess.running) recorderProcess.running = true; }
    }

    Process {
        id: networkMonitor
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser { onRead: networkRefresh.restart() }
    }

    Timer {
        id: networkRefresh
        interval: 300
        onTriggered: {
            if (networkProcess.running) restart();
            else networkProcess.running = true;
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            shell.currentDateTime = Qt.formatDateTime(new Date(), "ddd d MMM  HH:mm");
            paletteFile.reload();
            fontFile.reload();
            for (const process of [overviewProcess, networkProcess, recorderProcess, audioRecorderProcess, performanceProcess,
                                   idleProcess, keyboardLayoutProcess, workspaceIconsProcess, focusProcess])
                if (!process.running) process.running = true;
            if (!networkMonitor.running) networkMonitor.running = true;
        }
    }

    Timer {
        interval: 5000
        running: shell.controlsVisible
        repeat: true
        onTriggered: { if (!overviewProcess.running) overviewProcess.running = true; }
    }

    Process {
        id: telemetryProcess
        command: [shell.backend("system-adapter"), "--telemetry-json"]
        stdout: StdioCollector { onStreamFinished: {
            try { shell.overview = Object.assign({}, shell.overview, JSON.parse(text)); }
            catch (error) { console.warn("SpectrumShell telemetry:", error); }
        } }
    }

    Timer {
        interval: 15000
        running: shell.statisticsVisible && !shell.controlsVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!telemetryProcess.running) telemetryProcess.running = true; }
    }

    Timer {
        interval: 5000
        running: shell.recording.active
        repeat: true
        onTriggered: { if (!recorderProcess.running) recorderProcess.running = true; }
    }

    Timer {
        interval: 300000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!weatherProcess.running) weatherProcess.running = true; }
    }

    Timer {
        interval: 5000
        running: bars.instances.some(bar => bar.widgetOpen && bar.widgetPage === "wifi")
        repeat: true
        onTriggered: { if (!networkProcess.running) networkProcess.running = true; }
    }

    IpcHandler {
        target: "spectrum-shell"
        function refreshTheme(palette: string): bool {
            const applied = shell.applyPalette(palette);
            if (applied)
                fontFile.reload();
            return applied;
        }

        function openPicker(directory: string): void {
            for (const instance of bars.instances) {
                if (instance.monitor && instance.monitor.focused) {
                    pickerPanel.targetScreen = instance.screen;
                    break;
                }
            }
            pickerPanel.open(directory);
        }

        function toggleIgor(): void { shell.toggleIgor(); }
        function igorStatus(): string {
            return JSON.stringify({meeting: meetingState.active, playing: igorRoutine.playing,
                mediaKind: igorRoutine.mediaKind, headphones: igorRoutine.musicPlaying, glasses: igorRoutine.watching});
        }
        function previewIgor(edge: string): bool {
            return igorRoutine.appear(edge);
        }
        function previewIgorMeeting(): bool {
            shell.igorMeetingPreview = true;
            if (!igorRoutine.appear("bottom")) {
                shell.igorMeetingPreview = false;
                return false;
            }
            igorMeetingPreviewTimer.restart();
            return true;
        }
        function previewIgorNap(): bool { return igorRoutine.nap(); }
        function previewIgorCelebration(): bool { return igorRoutine.celebrate(); }
        function dismissIgor(): void {
            igorRoutine.retreat();
        }

        function focusBar(): void { shell.openOnFocused("focusBar"); }
        function toggleOverview(): void { shell.openWidgetOnFocused("wifi"); }
        function toggleAudio(): void { shell.openWidgetOnFocused("audio"); }
        function mediaKey(action: string): void { shell.controlMedia(action); }
        function toggleWifi(): void { shell.openWidgetOnFocused("wifi"); }
        function toggleBluetooth(): void { shell.openWidgetOnFocused("bluetooth"); }
        function toggleTypography(): void { shell.openWidgetOnFocused("typography"); }
        function toggleAppImages(): void { shell.openWidgetOnFocused("appimages"); }
        function toggleMouse(): void { shell.openWidgetOnFocused("mouse"); }
        function toggleDisplays(): void { shell.openWidgetOnFocused("displays"); }
        function previewScreensaver(effect: string): bool { return screensaver.preview(effect); }
        function dismissScreensaver(): void { screensaver.dismiss(); }
        function screensaverState(): string {
            return JSON.stringify({active: screensaver.active, blocked: screensaver.blocked,
                mediaPlaying: screensaver.mediaPlaying, fullscreenActive: screensaver.fullscreenActive,
                settings: screensaver.settings, effect: screensaver.effect, error: screensaver.error});
        }
        function toggleWeather(): void { shell.openWidgetOnFocused("weather"); }
        function toggleTimeRegion(): void { shell.openWidgetOnFocused("time"); }
        function toggleBattery(): void { shell.openWidgetOnFocused("battery"); }

        function toggleLauncher(): void {
            for (const instance of bars.instances) {
                if (instance.monitor && instance.monitor.focused) {
                    instance.toggleLauncher();
                    return;
                }
            }
            if (bars.instances.length)
                bars.instances[0].toggleLauncher();
        }

        function toggleControlCenter(): void { shell.openOnFocused("toggleControlCenter"); }
        function openControlPage(page: string): void {
            for (const instance of bars.instances) {
                if (instance.monitor && instance.monitor.focused) {
                    instance.openControlPage(page);
                    return;
                }
            }
            if (bars.instances.length)
                bars.instances[0].openControlPage(page);
        }
        function toggleWallpapers(): void { shell.openOnFocused("toggleWallpapers"); }
        function toggleNotifications(): void { shell.openOnFocused("toggleNotifications"); }
        function toggleSession(): void { shell.openOnFocused("toggleSession"); }
        function toggleDashboard(): void { shell.openOnFocused("toggleDashboard"); }
        function toggleScreenshot(): void { shell.openOnFocused("toggleScreenshot"); }
        function toggleAudioRecorder(): void { shell.openOnFocused("toggleAudioRecorder"); }
        function toggleRecorder(): void { shell.openOnFocused("toggleRecorder"); }
        function toggleFileSearch(): void { shell.openOnFocused("toggleFileSearch"); }
        function toggleCalculator(): void { shell.openOnFocused("toggleCalculator"); }
        function togglePassword(): void { shell.openOnFocused("togglePassword"); }
        function toggleSpectrumDrop(): void { shell.openOnFocused("toggleSpectrumDrop"); }
        function toggleBarExtras(): void { shell.openOnFocused("toggleBarExtras"); }
        function toggleHotKey(): void { shell.openOnFocused("toggleHotKey"); }
        function toggleShortcuts(): void { shell.openOnFocused("toggleShortcuts"); }
        function toggleUpdates(): void { shell.openOnFocused("toggleUpdates"); }
        function toggleFocusTimer(): void { shell.openOnFocused("toggleFocusTimer"); }
        function toggleEmoji(): void { shell.openOnFocused("toggleEmoji"); }
        function toggleCalendar(): void { shell.openOnFocused("toggleCalendar"); }
        function toggleQuestline(): void { shell.openOnFocused("toggleQuestline"); }
        function openQuestlineNewTask(): void { shell.openOnFocused("openQuestlineNewTask"); }
        function openQuestlineNewScroll(): void { shell.openOnFocused("openQuestlineNewScroll"); }
        function toggleColorPicker(): void { shell.openOnFocused("toggleColorPicker"); }
        function toggleColorHistory(): void { shell.openOnFocused("toggleColorHistory"); }
        function dismissLatestNotification(): void {
            const items = Array.from(notificationServer.trackedNotifications.values);
            if (toastModel.count) {
                const index = toastModel.count - 1;
                const notificationId = toastModel.get(index).notificationId;
                toastModel.remove(index);
                const notification = items.find(item => item.id === notificationId);
                if (notification)
                    notification.dismiss();
                return;
            }
            if (items.length)
                items[items.length - 1].dismiss();
        }
        function clearNotifications(): void {
            toastModel.clear();
            for (const item of Array.from(notificationServer.trackedNotifications.values))
                item.dismiss();
            shell.notificationHistory = [];
        }
        function setBarTop(): void { shell.setBarPosition("top"); }
        function toggleDesktopLogo(): void { shell.toggleDesktopLogo(); }
        function setDesktopLogoCorner(corner: string): void { shell.setDesktopLogoCorner(corner); }
        function setBarLeft(): void { shell.setBarPosition("left"); }
        function leaveGaming(): void { shell.leaveGaming(); }
        function gamingState(): string {
            return JSON.stringify({
                enabled: shell.gamingActive,
                backend: shell.gamingStatus,
                animationsEnabled: shell.animationsEnabled,
                monitors: bars.instances.map(bar => ({ name: bar.screen.name, profile: bar.barProfile,
                    barVisible: bar.barVisible, leftInset: bar.panelLeftInset, topInset: bar.panelTopInset }))
            });
        }
        function barState(): string {
            return JSON.stringify({ style: shell.barStyle, position: shell.barPosition,
                monitors: bars.instances.map(bar => bar.styleState()) });
        }
        function setBarStyle(style: string): void { shell.setBarStyle(style); }
        function setBarProfile(profile: string): void { shell.setBarProfile(profile); }
        function setWidgetBounce(mode: string): void {
            if (mode === "on" || mode === "off")
                shell.setWidgetBounce(mode === "on");
        }
        function setMonitorBarProfile(monitor: string, profile: string): void { shell.setBarProfile(profile, monitor); }
    }

    PickerPanel {
        id: pickerPanel
        theme: shell
        backendDir: shell.backendDir
    }

    Variants {
        id: bars
        model: Quickshell.screens.filter(screen => screen.name && screen.name !== "FALLBACK" && screen.width > 0 && screen.height > 0)

        PanelWindow {
            WlrLayershell.layer: WlrLayer.Overlay
            id: bar
            required property var modelData
            screen: modelData
            implicitHeight: islandStats.visible ? Math.max(34, Math.ceil(islandStats.implicitHeight) + 8) : 34
            exclusionMode: ExclusionMode.Ignore
            color: shell.barStyle === "islands" ? "transparent" : shell.colors.surface
            mask: BarInputRegion { backdrop: topIslands; islands: shell.barStyle === "islands" }
            anchors { top: true; left: true; right: true }
            visible: bar.barVisible && shell.barPosition === "top"

            property bool keyboardActive: false
            focusable: keyboardActive
            readonly property string barProfile: shell.gamingActive ? "gaming" : shell.barProfiles[bar.modelData.name] || shell.barProfile
            readonly property bool barVisible: !shell.gamingActive && barProfile !== "minimal"
            readonly property int barLeftInset: barVisible && shell.barPosition === "left" ? 52 : 0
            readonly property int panelLeftInset: shell.gamingActive ? 0 : barVisible ? barLeftInset : 8
            readonly property int panelTopInset: shell.gamingActive ? 0 : barVisible && shell.barPosition === "top" ? bar.implicitHeight : 8
            readonly property var monitor: Hyprland.monitorFor(screen)
            readonly property bool widgetOpen: barWidget.expanded
            readonly property string widgetPage: barWidget.page
            readonly property bool dashboardOpen: dashboard.expanded
            readonly property bool controlCenterOpen: controlCenter.expanded
            ShellFrame {
                id: shellFrame
                barHeight: bar.implicitHeight
                barProfile: bar.barProfile
                targetScreen: bar.screen
                theme: shell
                barPosition: shell.barPosition
            }

            PanelWindow {
                id: recordingCorner
                screen: bar.screen
                anchors { top: true; right: true }
                implicitWidth: recordingStatus.implicitWidth + 28
                implicitHeight: 34
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "spectrum-recording-indicator"
                color: "transparent"
                focusable: false
                mask: Region { item: recordingStatus }
                visible: !shell.gamingActive && (shell.recording.active || shell.audioRecording.active)

                RecordingStatus {
                    id: recordingStatus
                    anchors.centerIn: parent
                    fontFamily: shell.fontFamily
                    fontSize: shell.fontSize
                    screenRecording: shell.recording.active
                    animationsEnabled: shell.animationsEnabled
                    audioRecording: shell.audioRecording.active
                    onScreenRequested: bar.toggleRecorder()
                    onAudioRequested: bar.toggleAudioRecorder()
                }
            }

            readonly property bool igorSuppressed: shell.gamingActive || shell.recording.active || shell.audioRecording.active || audioRecorderPanel.expanded || barWidget.expanded || controlCenter.expanded || appLauncher.expanded || dashboard.expanded || screenshotPanel.expanded || recorderPanel.expanded || updatePanel.expanded || utilityPanel.expanded || notificationCenter.expanded || sessionRail.expanded || wallpaperBrowser.expanded || pickerPanel.visible || notificationToast.visible

            DesktopBranding {
                targetScreen: bar.screen
                visible: shell.desktopLogoEnabled && !shell.gamingActive
                corner: shell.desktopLogoCorner
                leftInset: bar.barLeftInset
                topInset: bar.barVisible && shell.barPosition === "top" ? bar.implicitHeight : 0
            }

            IgorVisitor {
                id: igorVisitor
                targetScreen: bar.screen
                theme: shell
                panelLeftInset: shell.barStyle === "islands" ? 8 : bar.panelLeftInset
                panelTopInset: shell.barStyle === "islands" ? 8 : bar.panelTopInset
                routine: igorRoutine
            }

            function styleState(): var {
                return { name: bar.modelData.name, profile: bar.barProfile, visible: bar.barVisible,
                    height: bar.implicitHeight,
                    details: islandStats.visible ? { width: islandStats.width, naturalWidth: islandStats.naturalWidth,
                        availableWidth: islandStats.availableWidth, lines: islandStats.lineCount } : null,
                    segments: shell.barStyle === "islands" && barVisible
                        ? shell.barPosition === "top" ? topIslands.segments : verticalBar.islandSegments : [] };
            }

            function focusBar(): void {
                if (!bar.barVisible) { toggleDashboard(); return; }
                const opening = !keyboardActive;
                closeSidePanels();
                appLauncher.expanded = false;
                wallpaperBrowser.expanded = false;
                keyboardActive = opening;
                if (opening) Qt.callLater(() => {
                    if (shell.barPosition === "top") {
                        barContent.forceActiveFocus();
                        barNavigation.move(true);
                    } else verticalBar.focusFirst();
                });
            }

            function closeSidePanels(): void {
                keyboardActive = false;
                barWidget.expanded = false;
                controlCenter.expanded = false;
                notificationCenter.expanded = false;
                sessionRail.expanded = false;
                dashboard.expanded = false;
                screenshotPanel.expanded = false;
                recorderPanel.expanded = false;
                audioRecorderPanel.expanded = false;
                updatePanel.expanded = false;
                utilityPanel.expanded = false;
            }

            function showMediaChooser(): void {
                if (barWidget.expanded && barWidget.page === "audio") return;
                appLauncher.expanded = false;
                closeSidePanels();
                barWidget.open("audio");
            }

            function toggleBarWidget(page): void {
                const opening = !barWidget.expanded || barWidget.page !== page;
                if (opening) {
                    appLauncher.expanded = false;
                    closeSidePanels();
                    barWidget.open(page);
                    if (page === "weather" && !weatherProcess.running)
                        weatherProcess.running = true;
                } else
                    barWidget.expanded = false;
            }

            function toggleLauncher(): void {
                if (!appLauncher.expanded)
                    closeSidePanels();
                utilityPanel.expanded = false;
                appLauncher.toggle();
            }

            function openUtility(page): void {
                const opening = !utilityPanel.expanded || utilityPanel.page !== page;
                if (opening) {
                    closeSidePanels();
                    appLauncher.expanded = false;
                    wallpaperBrowser.expanded = false;
                    utilityPanel.open(page);
                } else {
                    utilityPanel.expanded = false;
                }
            }

            function toggleFileSearch(): void { openUtility("search"); }
            function toggleCalculator(): void { openUtility("calculator"); }
            function togglePassword(): void { openUtility("password"); }
            function toggleSpectrumDrop(): void { openUtility("spectrumdrop"); }
            function toggleBarExtras(): void { toggleBarWidget("extras"); }
            function toggleHotKey(): void { openUtility("hotkey"); }
            function toggleShortcuts(): void { openUtility("shortcuts"); }
            function toggleUpdates(): void {
                const opening = !updatePanel.expanded;
                if (opening) {
                    closeSidePanels();
                    appLauncher.expanded = false;
                    updatePanel.refresh();
                }
                updatePanel.expanded = opening;
            }
            function toggleFocusTimer(): void { openUtility("focus"); }
            function toggleEmoji(): void { openUtility("emoji"); }
            function toggleCalendar(): void { openUtility("calendar"); }
            function toggleQuestline(): void { openUtility("questline"); }
            function openQuestlineNewScroll(): void {
                closeSidePanels();
                appLauncher.expanded = false;
                wallpaperBrowser.expanded = false;
                utilityPanel.openQuestlineNewScroll();
            }
            function openQuestlineNewTask(): void {
                closeSidePanels();
                appLauncher.expanded = false;
                wallpaperBrowser.expanded = false;
                utilityPanel.openQuestlineNewTask();
            }
            function toggleColorPicker(): void {
                closeSidePanels();
                appLauncher.expanded = false;
                wallpaperBrowser.expanded = false;
                utilityPanel.beginColorPick();
            }
            function toggleColorHistory(): void { openUtility("color"); }

            function toggleDashboard(): void {
                const opening = !dashboard.expanded;
                if (opening) {
                    closeSidePanels();
                    appLauncher.expanded = false;
                    wallpaperBrowser.expanded = false;
                    shell.refreshControls();
                }
                dashboard.expanded = opening;
            }

            function toggleScreenshot(): void {
                const opening = !screenshotPanel.expanded;
                if (opening) {
                    closeSidePanels();
                    appLauncher.expanded = false;
                    wallpaperBrowser.expanded = false;
                }
                screenshotPanel.expanded = opening;
            }

            function toggleAudioRecorder(): void {
                const opening = !audioRecorderPanel.expanded;
                if (opening) {
                    closeSidePanels();
                    appLauncher.expanded = false;
                    wallpaperBrowser.expanded = false;
                }
                audioRecorderPanel.expanded = opening;
                if (opening && !audioRecorderProcess.running)
                    audioRecorderProcess.running = true;
            }

            function toggleRecorder(): void {
                const opening = !recorderPanel.expanded;
                if (opening) {
                    closeSidePanels();
                    appLauncher.expanded = false;
                    wallpaperBrowser.expanded = false;
                }
                recorderPanel.expanded = opening;
                if (opening && !recorderProcess.running)
                    recorderProcess.running = true;
            }

            function toggleControlCenter(): void {
                const opening = !controlCenter.expanded;
                if (opening) {
                    closeSidePanels();
                    appLauncher.expanded = false;
                    wallpaperBrowser.expanded = false;
                    shell.refreshControls();
                }
                controlCenter.expanded = opening;
            }

            function openControlPage(page): void {
                if (!controlCenter.expanded)
                    toggleControlCenter();
            }

            function toggleWallpapers(): void {
                if (wallpaperBrowser.expanded) {
                    wallpaperBrowser.expanded = false;
                    return;
                }
                closeSidePanels();
                appLauncher.expanded = false;
                shell.refreshControls();
                wallpaperBrowser.open();
            }

            function toggleNotifications(): void {
                const opening = !notificationCenter.expanded;
                if (opening)
                    closeSidePanels();
                notificationCenter.expanded = opening;
            }

            function toggleSession(): void {
                const opening = !sessionRail.expanded;
                if (opening)
                    closeSidePanels();
                sessionRail.expanded = opening;
            }

            VerticalBar {
                id: verticalBar
                keyboardActive: bar.keyboardActive && shell.barPosition === "left"
                onKeyboardDismissed: bar.keyboardActive = false
                barProfile: bar.barProfile
                targetScreen: bar.screen
                theme: shell
                monitor: bar.monitor
                network: shell.network
                overview: shell.overview
                weather: shell.weather
                recording: shell.recording
                media: shell.media
                activeWindowTitle: shell.activeWindowTitle
                activeWindowIdentity: shell.activeWindowIdentity
                active: bar.barVisible && shell.barPosition === "left"
                onLauncherRequested: bar.toggleLauncher()
                onDashboardRequested: bar.toggleDashboard()
                onTimeRegionRequested: bar.toggleBarWidget("time")
                onControlCenterRequested: bar.toggleControlCenter()
                onNotificationsRequested: bar.toggleNotifications()
                onAudioRequested: bar.toggleBarWidget("audio")
                onWifiRequested: bar.toggleBarWidget("wifi")
                onBluetoothRequested: bar.toggleBarWidget("bluetooth")
                onWeatherRequested: bar.toggleBarWidget("weather")
                onDisplaysRequested: bar.toggleBarWidget("displays")
                onMouseRequested: bar.toggleBarWidget("mouse")
                onTypographyRequested: bar.toggleBarWidget("typography")
                onBatteryRequested: bar.toggleBarWidget("battery")
                onPerformanceRequested: bar.toggleBarWidget("battery")
                onExtrasRequested: bar.toggleBarWidget("extras")
                onSpectrumDropRequested: bar.toggleSpectrumDrop()
                onIdleRequested: shell.toggleKeepAwake()
                onSessionRequested: bar.toggleSession()
                onMediaRequested: action => shell.controlMedia(action)
            }

            MediaNotch {
                targetScreen: bar.screen
                theme: shell
                samples: shell.waveSamples
                barPosition: shell.barPosition
                visible: bar.barProfile === "multimedia"
            }

            Dashboard {
                id: dashboard
                targetScreen: bar.screen
                theme: shell
                weather: shell.weather
                media: shell.media
                topInset: bar.panelTopInset
                leftInset: bar.barLeftInset
                onActionRequested: action => {
                    switch (action) {
                    case "time": bar.toggleBarWidget("time"); break;
                    case "weather": bar.toggleBarWidget("weather"); break;
                    case "questline": bar.toggleQuestline(); break;
                    case "mediaPrevious": shell.controlMedia("previous"); break;
                    case "mediaToggle": shell.controlMedia("toggle"); break;
                    case "mediaNext": shell.controlMedia("next"); break;
                    }
                }
            }

            ScreenshotPanel {
                id: screenshotPanel
                targetScreen: bar.screen
                theme: shell
                topInset: bar.panelTopInset
                leftInset: bar.panelLeftInset
                onCaptureRequested: mode => Quickshell.execDetached([shell.backend("panel"), "--screenshot-" + mode])
            }

            UpdatePanel {
                id: updatePanel
                targetScreen: bar.screen
                theme: shell
                backendDir: shell.backendDir
                topInset: bar.panelTopInset
                leftInset: bar.panelLeftInset
            }

            AudioRecorderPanel {
                id: audioRecorderPanel
                targetScreen: bar.screen
                theme: shell
                backendDir: shell.backendDir
                topInset: bar.panelTopInset
                leftInset: bar.panelLeftInset
                onRecordingRefreshRequested: if (!audioRecorderProcess.running) audioRecorderProcess.running = true
            }

            RecorderPanel {
                id: recorderPanel
                targetScreen: bar.screen
                theme: shell
                backendDir: shell.backendDir
                recording: shell.recording
                topInset: bar.panelTopInset
                leftInset: bar.panelLeftInset
                onRecordingRefreshRequested: {
                    if (!recorderProcess.running)
                        recorderProcess.running = true;
                }
            }

            PanelWindow {
                id: dashboardHover
                visible: !shell.gamingActive
                readonly property bool coversNotch: shell.barPosition === "left" && bar.barProfile === "multimedia"
                screen: bar.screen
                anchors { top: true; left: true; right: true }
                implicitHeight: coversNotch ? 34 : 6
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                color: "transparent"
                focusable: false
                mask: Region { item: hoverArea }

                Timer {
                    id: hoverTimer
                    interval: 180
                    onTriggered: {
                        if (hoverArea.containsMouse && !dashboard.expanded)
                            bar.toggleDashboard();
                    }
                }

                MouseArea {
                    id: hoverArea
                    x: (dashboardHover.width + bar.barLeftInset - width) / 2
                    width: dashboardHover.coversNotch ? dashboardHover.width * 0.2 : 260
                    height: parent.height
                    hoverEnabled: true
                    onEntered: hoverTimer.restart()
                    onExited: hoverTimer.stop()
                }
            }

            SessionRail {
                id: sessionRail
                targetScreen: bar.screen
                theme: shell
                onActionRequested: action => {
                    if (action === "lock")
                        shell.runAction([shell.backend("session-menu"), "lock"]);
                    else
                        shell.runAction([shell.backend("session-menu"), "run", action]);
                }
            }

            Launcher {
                id: appLauncher
                screen: bar.screen
                theme: shell
                leftInset: bar.barLeftInset
            }

            UtilityPanel {
                onSpectrumDropReturnRequested: {
                    if (!barWidget.expanded && !controlCenter.expanded && !notificationCenter.expanded
                        && !appLauncher.expanded && !sessionRail.expanded && !wallpaperBrowser.expanded
                        && !dashboard.expanded && !screenshotPanel.expanded && !recorderPanel.expanded
                        && !audioRecorderPanel.expanded && !updatePanel.expanded)
                        utilityPanel.expanded = true;
                }
                onQuestlineCompleted: igorRoutine.celebrate()
                panelLeftInset: bar.panelLeftInset
                id: utilityPanel
                questlineWorkspace: sharedQuestlineWorkspace
                screen: bar.screen
                theme: shell
                backendDir: shell.backendDir
                focusState: shell.focusState
                leftInset: bar.barLeftInset
                topInset: bar.panelTopInset
                onFocusAction: action => shell.runAction([shell.backend("spectrum-focus"), action])
                onFocusStart: request => shell.runAction([shell.backend("spectrum-focus"), "start", JSON.stringify(request)])
            }

            ControlCenter {
                barProfile: bar.barProfile
                topInset: bar.panelTopInset
                sideInset: bar.panelLeftInset
                id: controlCenter
                screen: bar.screen
                theme: shell
                barPosition: shell.barPosition
                themeState: shell.themeState
                onWidgetBounceSelected: enabled => shell.setWidgetBounce(enabled)
                onBarPositionSelected: position => {
                    shell.setBarPosition(position);
                    controlCenter.expanded = false;
                }
                onBarProfileSelected: profile => {
                    shell.setBarProfile(profile, bar.screen.name);
                    controlCenter.expanded = false;
                }
                onCloseRequested: controlCenter.expanded = false
                onActionRequested: command => {
                    if (command[0] === shell.backend("session-menu")) {
                        controlCenter.expanded = false;
                        bar.toggleSession();
                        return;
                    }
                    shell.runAction(command);
                    if (command[0] === shell.backend("display-menu") || command[0] === shell.backend("bluetooth-menu"))
                        controlCenter.expanded = false;
                }
            }

            WallpaperBrowser {
                leftInset: bar.barLeftInset
                id: wallpaperBrowser
                screen: bar.screen
                theme: shell
                catalog: shell.themeState
                barPosition: shell.barPosition
                Timer {
                    interval: 3000
                    running: wallpaperBrowser.expanded
                    repeat: true
                    onTriggered: {
                        if (!themeProcess.running)
                            themeProcess.running = true;
                    }
                }
                onCloseRequested: wallpaperBrowser.expanded = false
                onApplyWallpaper: token => {
                    shell.runAction([shell.backend("theme-adapter"), "apply", token, shell.themeState.palette.mode || "spectrum", shell.themeState.palette.variant || "dark"]);
                    wallpaperBrowser.expanded = false;
                }
                onRandomWallpaper: {
                    shell.runAction([shell.backend("theme-adapter"), "random"]);
                    wallpaperBrowser.expanded = false;
                }
            }

            NotificationCenter {
                id: notificationCenter
                screen: bar.screen
                theme: shell
                topInset: bar.panelTopInset
                notificationModel: notificationServer.trackedNotifications
                history: shell.notificationHistory
                doNotDisturb: shell.doNotDisturb
                onCloseRequested: notificationCenter.expanded = false
                onClearHistory: shell.notificationHistory = []
                onDismissHistory: item => {
                    shell.notificationHistory = shell.notificationHistory.filter(entry =>
                        entry !== item && entry.notification !== item);
                }
                onToggleDoNotDisturb: shell.doNotDisturb = !shell.doNotDisturb
            }

            PanelWindow {
                id: notificationToast
                screen: bar.screen
                anchors { top: true; bottom: true; right: true }
                margins.top: bar.panelTopInset
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "spectrum-widget-toasts"
                focusable: false
                implicitWidth: Math.min(Math.max(260, shell.fontSize * 20) + 8, bar.screen.width - 20)
                mask: Region { item: toastStack }
                visible: shell.toastNotifications.count > 0 && bar.monitor && bar.monitor.focused && !shell.doNotDisturb && !shell.gamingActive && !barWidget.expanded
                color: "transparent"
                Column {
                    id: toastStack
                    anchors { left: parent.left; leftMargin: 8; right: parent.right; top: parent.top; topMargin: 2 * shellFrame.curveRadius }
                    spacing: 2 * shellFrame.curveRadius + 8
                    Repeater {
                        model: shell.toastNotifications
                        NotificationToast {
                            id: toastCard
                            required property var model
                            theme: shell
                            notification: model
                            presented: notificationToast.visible
                            width: toastStack.width
                            onActivated: bar.toggleNotifications()
                            onDismissed: shell.removeToast(model.toastId)
                            Timer {
                                interval: Math.max(1, toastCard.model.expiresAt - Date.now())
                                running: toastCard.revealed
                                onTriggered: toastCard.revealed = false
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: barContent
                anchors.fill: parent
                color: shell.barStyle === "islands" ? "transparent" : shell.colors.surface
                KeyboardNavigation { id: barNavigation }
                Keys.onEscapePressed: bar.keyboardActive = false
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        barNavigation.move(event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier));
                        event.accepted = true;
                    } else if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].includes(event.key)) {
                        barNavigation.moveDirection(event.key);
                        event.accepted = true;
                    }
                }

                BarIslands {
                    id: topIslands
                    anchors.fill: parent
                    visible: shell.barStyle === "islands"
                    surfaceColor: shell.colors.surface
                    groups: [
                        { start: topRow.x + launcherButton.x, length: workspaceButtons.x + workspaceButtons.width - launcherButton.x },
                        { start: topRow.x + windowTitle.x, length: windowTitle.width, visible: windowTitle.visible && windowTitle.title.length > 0 },
                        { start: clockText.x, length: clockText.width, visible: clockText.visible },
                        { start: detailedStats.x, length: detailedStats.width, visible: detailedStats.visible },
                        { start: topRow.x + islandStats.x, length: islandStats.width, visible: islandStats.visible },
                        { start: mediaControls.x, length: mediaControls.width, visible: mediaControls.visible },
                        { start: topRow.x + minimalStatusGroup.x, length: trayGroup.x + trayGroup.width - minimalStatusGroup.x }
                    ]
                }

                RowLayout {
                    id: topRow
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: recordingCorner.visible ? recordingCorner.implicitWidth : 14
                    spacing: 16

                    Rectangle {
                        id: launcherButton
                        implicitWidth: 36
                        implicitHeight: 30
                        radius: 9
                        color: shell.colors.accent
                        Text {
                            anchors.centerIn: parent
                            text: ""
                            font { family: shell.fontFamily; pixelSize: shell.fontSize + 5; bold: true }
                            color: shell.colors.background
                        }
                        KeyboardAction {
                            anchors.fill: parent
                            onActivated: bar.toggleLauncher()
                        }
                    }

                    IgorButton { id: topIgorButton; theme: shell }

                    Row {
                        id: workspaceButtons
                        spacing: 5
                        Repeater {
                            model: shell.workspacesForMonitor(bar.screen ? bar.screen.name : "")
                            Rectangle {
                                required property int modelData
                                readonly property bool active: bar.monitor && bar.monitor.activeWorkspace && bar.monitor.activeWorkspace.id === modelData
                                readonly property bool occupied: shell.workspaceOccupied(modelData)
                                width: active ? 30 : 25
                                height: 28
                                radius: 8
                                color: active ? shell.colors.accent : occupied ? shell.colors.surface_alt : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: shell.workspaceGlyph(parent.modelData, parent.active ? "active" : parent.occupied ? "occupied" : "empty")
                                    color: parent.active ? shell.colors.background : parent.occupied ? shell.colors.foreground : shell.colors.muted
                                    font { family: shell.fontFamily; pixelSize: shell.fontSize; bold: parent.active }
                                }
                                KeyboardAction {
                                    anchors.fill: parent
                                    onActivated: Hyprland.dispatch("hl.dsp.focus({ workspace = " + parent.modelData + " })")
                                }
                            }
                        }
                    }

                    ScrollingTitle {
                        id: windowTitle
                        visible: bar.barProfile === "standard" || bar.barProfile === "detailed"
                        Layout.preferredWidth: Math.min(shell.barStyle === "islands" ? windowTitle.measuredTextWidth : 420, 420, bar.screen.width * 0.25,
                            islandStats.visible ? Math.max(0, islandStats.availableWidth - islandStats.naturalWidth) : 420)
                        Layout.minimumWidth: 0
                        Layout.maximumWidth: islandStats.visible ? Layout.preferredWidth : 420
                        title: shell.activeWindowTitle
                        windowIdentity: shell.activeWindowIdentity
                        fontFamily: shell.fontFamily
                        fontPixelSize: shell.fontSize
                        textColor: shell.colors.muted
                    }

                    Item { Layout.fillWidth: true }

                    DetailedBarStats {
                        id: islandStats
                        visible: shell.barStyle === "islands" && bar.barProfile === "detailed"
                        availableWidth: Math.max(1, topRow.width - launcherButton.implicitWidth
                            - topIgorButton.implicitWidth - workspaceButtons.width
                            - minimalStatusGroup.implicitWidth - trayGroup.width - 8 * topRow.spacing)
                        Layout.preferredWidth: Math.min(naturalWidth, availableWidth)
                        Layout.minimumWidth: Layout.preferredWidth
                        Layout.maximumWidth: Layout.preferredWidth
                        text: detailedStats.text
                        color: shell.colors.foreground
                        font: detailedStats.font
                    }

                    Item { Layout.fillWidth: true; visible: islandStats.visible }

                    RowLayout {
                        id: minimalStatusGroup
                        spacing: 8
                        HoverHandler { id: minimalStatusHover }

                    Text {
                        text: shell.performance.available ? (shell.performance.mode === "performance" ? "󰓅" : shell.performance.mode === "power-saver" ? "󰌪" : "") : ""
                        visible: bar.barProfile !== "standard" && shell.performance.available && (bar.barProfile !== "minimal" || minimalStatusHover.hovered)
                        color: shell.performance.mode === "performance" ? shell.colors.accent : shell.colors.foreground
                        font { family: shell.fontFamily; pixelSize: shell.fontSize + 1 }
                        KeyboardAction { anchors.fill: parent; onActivated: bar.toggleBarWidget("battery") }
                    }

                    Text {
                        text: shell.idle.active ? "󰅶" : "󰾪"
                        visible: bar.barProfile !== "minimal" || minimalStatusHover.hovered
                        color: shell.idle.active ? shell.colors.accent : shell.colors.foreground
                        font { family: shell.fontFamily; pixelSize: shell.fontSize + 1 }
                        KeyboardAction { anchors.fill: parent; onActivated: shell.toggleKeepAwake() }
                    }

                    Text {
                        visible: bar.barProfile !== "standard" && (bar.barProfile !== "minimal" || minimalStatusHover.hovered)
                        text: "󰥔"
                        color: shell.colors.foreground
                        font { family: shell.fontFamily; pixelSize: shell.fontSize + 1 }
                        KeyboardAction { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onActivated: bar.toggleBarWidget("time") }
                    }

                    Text {
                        visible: bar.barProfile !== "minimal" || minimalStatusHover.hovered
                        text: (shell.weather.icon || "󰖕") + ((bar.barProfile === "standard" || bar.barProfile === "detailed") && shell.weather.temperature !== "—" ? " " + shell.weather.temperature : "")
                        color: shell.colors.foreground
                        font { family: shell.fontFamily; pixelSize: shell.fontSize + 1 }
                        KeyboardAction { anchors.fill: parent; onActivated: bar.toggleBarWidget("weather") }
                    }

                    Text {
                        visible: bar.barProfile !== "minimal" || minimalStatusHover.hovered
                        text: shell.network.connection_type === "ethernet" ? "󰈀" : shell.network.connection_type === "wifi" ? "󰖩" : "󰖪"
                        color: shell.colors.foreground
                        font { family: shell.fontFamily; pixelSize: shell.fontSize + 1 }
                        KeyboardAction { anchors.fill: parent; onActivated: bar.toggleBarWidget("wifi") }
                    }

                    Text {
                        visible: bar.barProfile !== "minimal" || minimalStatusHover.hovered
                        text: "󰂯"
                        color: shell.colors.foreground
                        font { family: shell.fontFamily; pixelSize: shell.fontSize + 1 }
                        KeyboardAction { anchors.fill: parent; onActivated: bar.toggleBarWidget("bluetooth") }
                    }

                    Text {
                        visible: bar.barProfile !== "standard" && (bar.barProfile !== "minimal" || minimalStatusHover.hovered)
                        text: "󰍹"
                        color: shell.colors.foreground
                        font { family: shell.fontFamily; pixelSize: shell.fontSize + 1 }
                        KeyboardAction { anchors.fill: parent; onActivated: bar.toggleBarWidget("displays") }
                    }

                    Text {
                        visible: bar.barProfile !== "standard" && (bar.barProfile !== "minimal" || minimalStatusHover.hovered)
                        text: "󰍽"
                        color: barWidget.expanded && barWidget.page === "mouse" ? shell.colors.accent : shell.colors.foreground
                        font { family: shell.fontFamily; pixelSize: shell.fontSize + 1 }
                        KeyboardAction { anchors.fill: parent; onActivated: bar.toggleBarWidget("mouse") }
                    }

                    Text {
                        visible: bar.barProfile !== "standard" && (bar.barProfile !== "minimal" || minimalStatusHover.hovered)
                        text: "Aa"
                        color: barWidget.expanded && barWidget.page === "typography" ? shell.colors.accent : shell.colors.foreground
                        font { family: shell.fontFamily; pixelSize: shell.fontSize; bold: true }
                        KeyboardAction { anchors.fill: parent; onActivated: bar.toggleBarWidget("typography") }
                    }

                    VolumeIndicator {
                        visible: bar.barProfile !== "minimal"
                        percent: shell.volumePercent
                        muted: shell.volumeMuted
                        available: shell.volumeAvailable
                        theme: shell
                        onClicked: bar.toggleBarWidget("audio")
                    }

                    Text {
                        visible: bar.barProfile !== "standard" && UPower.displayDevice.ready && UPower.displayDevice.isLaptopBattery && (bar.barProfile !== "minimal" || minimalStatusHover.hovered)
                        text: "󰁹 " + Math.round(UPower.displayDevice.percentage * 100) + "%"
                        color: shell.colors.foreground
                        font { family: shell.fontFamily; pixelSize: shell.fontSize - 1 }
                        KeyboardAction { anchors.fill: parent; onActivated: bar.toggleBarWidget("battery") }
                    }

                    Text {
                        visible: bar.barProfile !== "minimal" || minimalStatusHover.hovered
                        text: "󰂚"
                        color: shell.colors.foreground
                        font { family: shell.fontFamily; pixelSize: shell.fontSize + 2 }
                        KeyboardAction { anchors.fill: parent; onActivated: bar.toggleNotifications() }
                    }

                        Text {
                            visible: bar.barProfile === "standard"
                            text: "󰇘"
                            color: shell.colors.foreground
                            font { family: shell.fontFamily; pixelSize: shell.fontSize + 3 }
                            Accessible.name: "More bar controls"
                            KeyboardAction { anchors.fill: parent; onActivated: bar.toggleBarWidget("extras") }
                        }
                        Text {
                            visible: bar.barProfile !== "standard" && bar.barProfile !== "minimal"
                            text: "󰒡"
                            color: shell.colors.foreground
                            font { family: shell.fontFamily; pixelSize: shell.fontSize + 1 }
                            Accessible.name: "SpectrumDrop"
                            KeyboardAction { anchors.fill: parent; onActivated: bar.toggleSpectrumDrop() }
                        }
                        Text {
                            visible: bar.barProfile === "minimal" && !minimalStatusHover.hovered
                            text: "󰕮"
                            color: shell.colors.foreground
                            font { family: shell.fontFamily; pixelSize: shell.fontSize + 2 }
                        }
                    }

                    Row {
                        id: trayGroup
                        spacing: 8
                        Repeater {
                            model: bar.barProfile === "standard" ? [] : SystemTray.items
                            Item {
                                required property var modelData
                                width: 22
                                height: 28
                                Image {
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    source: modelData.icon
                                    fillMode: Image.PreserveAspectFit
                                }
                                KeyboardAction {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onActivated: button => {
                                        const position = bar.itemPosition(parent);
                                        if (button === Qt.RightButton || modelData.onlyMenu)
                                            modelData.display(bar, position.x, position.y + parent.height);
                                        else
                                            modelData.activate();
                                    }
                                }
                            }
                        }
                    }

                }

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    width: Math.min(240, implicitWidth)
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    visible: bar.barProfile !== "multimedia" && bar.barProfile !== "detailed"
                    text: shell.currentDateTime
                    color: shell.colors.foreground
                    font { family: shell.fontFamily; pixelSize: shell.fontSize - 1; bold: true }
                    KeyboardAction { anchors.fill: parent; onActivated: bar.toggleDashboard() }
                }

                TextMetrics { id: statsMetrics; text: detailedStats.text; font: detailedStats.font }

                Text {
                    id: detailedStats
                    anchors.centerIn: parent
                    width: Math.min(shell.barStyle === "islands" ? statsMetrics.width : 600, parent.width - 40, 600)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    visible: bar.barProfile === "detailed" && shell.barStyle !== "islands"
                    text: "CPU " + shell.overview.load + "   RAM " + shell.overview.memory + (shell.overview.gpu ? "   GPU " + shell.overview.gpu : "") + (shell.overview.temperature ? "   " + shell.overview.temperature : "")
                    color: shell.colors.foreground
                    font { family: shell.fontFamily; pixelSize: shell.fontSize - 1; bold: true }
                }

                Row {
                    id: mediaControls
                    readonly property real availableWidth: Math.max(0, 2 * Math.min(
                        parent.width / 2 - workspaceButtons.x - workspaceButtons.width - 38,
                        minimalStatusGroup.x - parent.width / 2 - 30))
                    anchors.centerIn: parent
                    visible: bar.barProfile === "multimedia" && availableWidth >= 180
                    spacing: 5
                    ShellButton {
                        label: "⏮"
                        width: 34
                        height: 28
                        enabled: shell.media.available
                        fontFamily: shell.fontFamily
                        fontSize: shell.fontSize - 1
                        backgroundColor: shell.colors.surface_alt
                        foregroundColor: shell.colors.foreground
                        onClicked: shell.controlMedia("previous")
                    }
                    ShellButton {
                        label: shell.media.playing ? "⏸" : "⏵"
                        width: 34
                        height: 28
                        enabled: shell.media.available
                        fontFamily: shell.fontFamily
                        fontSize: shell.fontSize - 1
                        backgroundColor: shell.colors.surface_alt
                        foregroundColor: shell.colors.foreground
                        onClicked: shell.controlMedia("toggle")
                    }
                    MediaArtwork {
                        width: 28
                        height: 28
                        artUrl: shell.media.artUrl
                        backgroundColor: shell.colors.surface_alt
                        foregroundColor: shell.colors.accent
                        KeyboardAction { anchors.fill: parent; onActivated: bar.toggleDashboard() }
                    }
                    ScrollingTitle {
                        id: mediaTitle
                        width: Math.min(shell.barStyle === "islands" ? mediaTitle.measuredTextWidth : 420, 420, mediaControls.availableWidth - 150)
                        height: 28
                        title: shell.media.available ? [shell.media.artist, shell.media.title].filter(Boolean).join(" - ") : "No media"
                        autoScroll: true
                        centered: false
                        bold: true
                        fontFamily: shell.fontFamily
                        fontPixelSize: shell.fontSize
                        textColor: shell.colors.foreground
                        KeyboardAction { anchors.fill: parent; onActivated: bar.toggleDashboard() }
                    }
                    ShellButton {
                        label: "⏭"
                        width: 34
                        height: 28
                        enabled: shell.media.available
                        fontFamily: shell.fontFamily
                        fontSize: shell.fontSize - 1
                        backgroundColor: shell.colors.surface_alt
                        foregroundColor: shell.colors.foreground
                        onClicked: shell.controlMedia("next")
                    }
                }

            }

            BarWidget {
                panelLeftInset: bar.panelLeftInset
                panelTopInset: bar.panelTopInset
                id: barWidget
                targetScreen: bar.screen
                theme: shell
                barPosition: shell.barPosition
                onExtraRequested: action => {
                    if (action === "spectrumdrop") bar.toggleSpectrumDrop();
                    else if (action === "control") bar.toggleControlCenter();
                    else if (action === "session") bar.toggleSession();
                    else bar.toggleBarWidget(action);
                }
            }
        }
    }
}
