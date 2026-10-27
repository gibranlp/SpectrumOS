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
import "NotificationStyle.js" as NotificationStyle
import Quickshell.Wayland
import Spectrum.I18n 1.0

ShellRoot {
    id: shell
    readonly property var languageController: Translator

    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")
    readonly property string palettePath: Quickshell.env("SPECTRUM_SHELL_PALETTE") || (cacheHome + "/spectrumos/theme/current/palette.json")
    readonly property string fontPath: cacheHome + "/spectrumos/theme/current/kitty.conf"
    readonly property bool leanMode: Quickshell.env("SPECTRUM_LEAN_MODE") === "1"
    readonly property string backendDir: Quickshell.env("SPECTRUM_SHELL_BACKEND_DIR") || "/usr/lib/spectrumos"
    property var colors: ({ background: "#15131a", surface: "#232029", surface_alt: "#2e2c34", foreground: "#eff3fa", muted: "#a6afbe", accent: "#b293e6" })
    property var brightness: ({ devices: [], error: qsTranslate("Spectrum", "Checking display brightness…") })
    readonly property bool brightnessBusy: brightnessActionProcess.running
    property bool brightnessRefreshPending: false
    property int brightnessRevision: 0
    property string brightnessActionError: ""
    property var overview: ({ hostname: "SpectrumOS", load: "…", memory: "…", disk: "…", audio: "…", uptime: "…", brightness: { available: false, percent: 0 }, font_size: "13px", font_family: "jetbrains-mono", font_families: [] })
    property var network: ({ available: false, wifi_enabled: false, connection_type: "none", status: "Checking network…", ethernet: { connected: false }, wifi: { connected: false } })
    property var audioDevices: ({ available: false, sinks: [], sources: [] })
    readonly property var audioNodes: Pipewire.nodes.values.filter(node => node.audio && !node.isStream)
    readonly property var volumeNode: Pipewire.defaultAudioSink
    readonly property bool volumeAvailable: !!(Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.ready && Pipewire.defaultAudioSink.audio)
    readonly property int volumePercent: volumeAvailable ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) : 0
    readonly property bool volumeMuted: volumeAvailable && Pipewire.defaultAudioSink.audio.muted
    property bool volumeIndicatorArmed: false
    onVolumeNodeChanged: Qt.callLater(() => { volumeIndicatorArmed = false; volumeIndicatorUpdate.stop(); volumeIndicatorWarmup.restart(); })
    onVolumeAvailableChanged: Qt.callLater(() => { volumeIndicatorArmed = false; volumeIndicatorWarmup.restart(); })
    onVolumePercentChanged: if (volumeIndicatorArmed && volumeAvailable && !volumeIndicatorUpdate.running) volumeIndicatorUpdate.start()
    onVolumeMutedChanged: if (volumeIndicatorArmed && volumeAvailable && !volumeIndicatorUpdate.running) volumeIndicatorUpdate.start()
    Timer {
        id: volumeIndicatorWarmup
        interval: 300
        running: true
        onTriggered: shell.volumeIndicatorArmed = shell.volumeAvailable
    }
    Timer {
        id: volumeIndicatorUpdate
        interval: 35
        onTriggered: if (shell.volumeIndicatorArmed && shell.volumeAvailable) shell.showLevelIndicator("volume", shell.volumePercent, "", "")
    }
    function showLevelIndicator(kind, percent, label, monitor): void {
        const target = bars.instances.find(bar => bar.modelData.name === monitor) || focusedBar();
        if (!target) return;
        for (const bar of bars.instances) if (bar !== target) bar.dismissLevelIndicator();
        target.showLevelIndicator(kind, percent, label);
    }

    PwObjectTracker { objects: shell.audioNodes }
    readonly property var media: mediaState.state
    property bool trackIndicatorReady: false
    property bool trackIndicatorPrimed: false
    property string lastIndicatorTrack: ""
    readonly property string indicatorTrackKey: {
        const player = mediaState.player;
        if (!player || !player.trackTitle) return "";
        const metadata = player.metadata || {};
        return JSON.stringify([mediaState.playerId(player), player.uniqueId,
            String(metadata["mpris:trackid"] || ""), String(metadata["xesam:url"] || ""),
            player.trackTitle]);
    }
    onIndicatorTrackKeyChanged: Qt.callLater(() => trackIndicatorUpdate.restart())
    Timer {
        interval: 800
        running: true
        onTriggered: { shell.lastIndicatorTrack = shell.indicatorTrackKey; shell.trackIndicatorPrimed = !!shell.indicatorTrackKey; shell.trackIndicatorReady = true; }
    }
    Timer {
        id: trackIndicatorUpdate
        interval: 200
        onTriggered: {
            const key = shell.indicatorTrackKey;
            const changed = key !== shell.lastIndicatorTrack;
            shell.lastIndicatorTrack = key;
            if (key && !shell.trackIndicatorPrimed) { shell.trackIndicatorPrimed = true; return; }
            if (!shell.trackIndicatorReady || !changed) return;
            if (!key) {
                for (const bar of bars.instances) bar.dismissTrackIndicator();
                return;
            }
            const target = shell.focusedBar();
            if (!target) return;
            for (const bar of bars.instances) if (bar !== target) bar.dismissLevelIndicator();
            target.showTrackIndicator();
        }
    }

    readonly property var mediaPlayers: mediaState.choices
    readonly property bool mediaChoiceRequired: mediaState.choiceRequired
    readonly property string mediaPendingAction: mediaState.pendingAction
    AudioVolumeManager { id: audioVolume; onFailed: message => shell.actionError = message }
    readonly property bool audioVolumeBusy: audioVolume.busy
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
    FavoritesManager { id: sharedFavorites; theme: shell }
    AppStoreManager { id: sharedAppStore; theme: shell; viewing: bars.instances.some(bar => bar.appStoreOpen) }
    QuestlineWorkspace { id: sharedQuestlineWorkspace; backendDir: shell.backendDir }
    property bool igorMeetingPreview: false
    Timer {
        id: igorMeetingPreviewTimer
        interval: 20000
        onTriggered: shell.igorMeetingPreview = false
    }
    MeetingState { id: meetingState }
    BreakReminderState {
        id: breakReminders
        backendDir: shell.backendDir
        inhibited: shell.gamingActive || meetingState.active || shell.recording.active || shell.audioRecording.active || shell.doNotDisturb || screensaver.active || shell.idle.active
        focusActive: ["starting", "work", "paused"].includes(shell.focusState.phase)
    }

    IgorRoutine {
        id: igorRoutine
        visitsEnabled: shell.igorEnabled && !shell.gamingActive && !screensaver.active
        available: monitorNames.length > 0
        monitorNames: bars.instances.map(bar => bar.modelData.name)
        blockedMonitors: bars.instances.filter(bar => bar.igorSuppressed).map(bar => bar.modelData.name)
        suppressed: monitorNames.length === blockedMonitors.length
        playing: shell.igorMeetingPreview || meetingState.active || shell.media.playing === true
        meeting: shell.igorMeetingPreview || meetingState.active
        mediaKind: shell.media.kind || "unknown"
        celebrationsAllowed: !shell.gamingActive && !shell.recording.active && !shell.audioRecording.active && !screensaver.active
    }
    property bool widgetBounceEnabled: true
    property string barPosition: "left"
    property string barStyle: "full"
    StableUpdateMonitor { id: stableUpdateMonitor; backendDir: shell.backendDir }
    readonly property var stableUpdates: stableUpdateMonitor.status
    readonly property bool checkingStableUpdates: stableUpdateMonitor.checking
    function checkStableUpdates(): void { stableUpdateMonitor.refresh(); }
    property bool gamingRequested: false
    readonly property bool gamingActive: gamingRequested || gamingStatus.automatic === true
    property var gamingStatus: ({ active: false, error: "" })
    readonly property bool animationsEnabled: !gamingActive && !leanMode
    property string barProfile: "standard"
    property var barProfiles: ({})
    readonly property bool barVisible: !shell.gamingActive && barProfile !== "minimal" && barProfile !== "gaming"
    readonly property int barLeftInset: barVisible && barPosition === "left" ? 52 : 0
    readonly property int panelLeftInset: shell.gamingActive ? 0 : barVisible ? barLeftInset : 8
    readonly property int panelTopInset: shell.gamingActive ? 0 : barVisible && barPosition === "top" ? 34 : 8
    property var titleWindows: []
    property bool activeWindowRefreshPending: false
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
        onNotification:notification=>shell.acceptNotification(notification)
    }
    QuestlineNotificationActions {
        id:questlineNotificationActions
        backendDir:shell.backendDir
        onFinished:(job,result)=> {
            shell.setNotificationBusy(job.notificationId,false);
            if (job.action!=="drink_water") return;
            if (result.error) {
                for(let i=0;i<toastModel.count;i++) if(toastModel.get(i).notificationId===job.notificationId) toastModel.setProperty(i,"body",toastModel.get(i).body+"\n"+result.error);
                return;
            }
            const item=Array.from(notificationServer.trackedNotifications.values).find(item=>item.id===job.notificationId);
            if(item)item.dismiss();
        }
    }
    function setNotificationBusy(id,busy): void {
        for(let i=0;i<toastModel.count;i++) if(toastModel.get(i).notificationId===id) toastModel.setProperty(i,"actionBusy",busy);
    }
    function removeNotificationToasts(id): void {
        for(let i=toastModel.count-1;i>=0;i--) if(toastModel.get(i).notificationId===id) toastModel.remove(i);
    }
    function invokeNotificationAction(id,identifier): void {
        const item=Array.from(notificationServer.trackedNotifications.values).find(item=>item.id===id);
        if(!item)return;
        if(identifier==="spectrum-open-updates" && NotificationStyle.isStableUpdate(item)) {
            openOnFocused("openUpdates");
            item.dismiss();
        } else if(identifier==="questline-drink" && NotificationStyle.kind(item)==="hydration") {
            setNotificationBusy(id,true);
            questlineNotificationActions.enqueue("drink_water",id,NotificationStyle.token(item));
        } else {
            const action=Array.from(item.actions || []).find(action=>action.identifier===identifier);
            if(action)action.invoke();
        }
    }
    function acceptNotification(notification): void {
        notification.tracked=true;
        if(notification.appName==="Spectrum Volume")return;
        const kind=NotificationStyle.kind(notification);
        const token=NotificationStyle.token(notification);
        const id=notification.id;
        if(kind.startsWith("hydration")) {
            for(const old of Array.from(notificationServer.trackedNotifications.values)) {
                if(old.id!==id && NotificationStyle.kind(old)==="hydration") old.expire();
            }
        }
        removeNotificationToasts(id);
        const actions=JSON.stringify(NotificationStyle.actions(notification));
        shell.notificationHistory=[{notification:notification,notificationId:id,appName:notification.appName,summary:notification.summary,body:notification.body,questlineKind:kind,reminderToken:token,actions:[]},...shell.notificationHistory.filter(item=>item.notificationId!==id)].slice(0,50);
        const persistent=NotificationStyle.palette(notification,shell.colors).persistent || notification.expireTimeout===0;
        const timeout=notification.expireTimeout>0 ? notification.expireTimeout : 5000;
        toastModel.append({toastId:++shell.nextToastId,notificationId:id,expiresAt:persistent?0:Date.now()+timeout,appName:notification.appName,iconSource:shell.notificationIcon(notification),summary:notification.summary,body:notification.body,questlineKind:kind,reminderToken:token,actionsJson:actions,actionBusy:false});
        notification.closed.connect(reason=> {
            shell.removeNotificationToasts(id);
            if(kind==="hydration" && reason!==NotificationCloseReason.Expired) questlineNotificationActions.enqueue("dismiss_hydration_reminder",id,token);
        });
        while(toastModel.count>10) {
            let removable=-1;
            for(let i=0;i<toastModel.count;i++)if(toastModel.get(i).expiresAt>0){removable=i;break;}
            if(removable<0)break;
            toastModel.remove(removable);
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

    function refreshControls(page): void {
        const groups = {
            audio: [audioProcess], wifi: [networkProcess], displays: [displayProcess],
            typography: [overviewProcess, keyboardLayoutProcess], battery: [overviewProcess],
            wallpapers: [themeProcess], dashboard: [], bluetooth: [], mouse: [], time: [],
            appimages: [], extras: [], weather: []
        };
        const processes = groups[page] || [overviewProcess, networkProcess, audioProcess, themeProcess,
            displayProcess, workspaceAssignmentsProcess, workspaceIconsProcess, keyboardLayoutProcess];
        for (const process of processes)
            if (!process.running) process.running = true;
    }

    // El historial de foco se filtra por monitor y espacio antes de elegir el título de cada barra.
    function windowForMonitor(monitor) {
        if (!monitor || !monitor.activeWorkspace) return null;
        const special = monitor.lastIpcObject.specialWorkspace || {};
        const workspace = special.id ? special.id : monitor.activeWorkspace.id;
        const candidates = titleWindows.filter(window => window.monitor === monitor.id
            && window.mapped !== false && !window.hidden && window.workspace
            && (window.workspace.id === workspace || (!special.id && window.pinned)));
        candidates.sort((a, b) => {
            const first = a.focusHistoryID >= 0 ? a.focusHistoryID : Number.MAX_SAFE_INTEGER;
            const second = b.focusHistoryID >= 0 ? b.focusHistoryID : Number.MAX_SAFE_INTEGER;
            return first - second || String(a.address).localeCompare(String(b.address));
        });
        return candidates[0] || null;
    }

    function focusedBar() {
        const focused = Hyprland.focusedMonitor;
        return bars.instances.find(instance => focused && instance.modelData.name === focused.name)
            || bars.instances.find(instance => instance.monitor && instance.monitor.focused)
            || bars.instances[0] || null;
    }

    function openOnFocused(name): void {
        const target = focusedBar();
        if (target) target[name]();
    }

    function openWidgetOnFocused(page): void {
        const target = focusedBar();
        if (target) target.toggleBarWidget(page);
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
        if (command[0] === "uwsm" && command[1] === "app") {
            ApplicationLaunch.start(command);
            return;
        }
        if (!actionProcess.running) {
            actionError = "";
            actionProcess.exec(command);
        }
    }

    function setAudioVolume(kind, target, percent): void { actionError = ""; audioVolume.setVolume(kind, target, percent); }

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
            const target = focusedBar();
            monitorName = target ? target.modelData.name : "";
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
                catch (error) { shell.brightness = Object.assign({}, shell.brightness, {error: qsTranslate("Spectrum", "Could not read display brightness.")}); }
            }
        } }
        onExited: exitCode => {
            if (exitCode !== 0)
                shell.brightness = Object.assign({}, shell.brightness, {error: qsTranslate("Spectrum", "Could not read display brightness.")});
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
                shell.gamingRequested = state.gaming_enabled === true;
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
        command: ["hyprctl", "clients", "-j"]
        running: true
        stdout: StdioCollector { onStreamFinished: {
            try {
                const windows = JSON.parse(text);
                if (Array.isArray(windows))
                    shell.titleWindows = windows;
            }
            catch (error) { console.warn("SpectrumShell window snapshot:", error); }
        } }
        onExited: {
            if (shell.activeWindowRefreshPending) {
                shell.activeWindowRefreshPending = false;
                activeWindowRefresh.restart();
            }
        }
    }

    Timer {
        id: activeWindowRefresh
        interval: 40
        onTriggered: {
            if (activeWindowProcess.running) shell.activeWindowRefreshPending = true;
            else activeWindowProcess.running = true;
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["activewindow", "activewindowv2", "windowtitle", "windowtitlev2", "openwindow", "closewindow",
                 "movewindow", "movewindowv2", "workspace", "workspacev2", "focusedmon", "focusedmonv2",
                 "moveworkspace", "moveworkspacev2", "activespecial", "activespecialv2", "pin",
                 "monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "configreloaded"].includes(event.name))
                activeWindowRefresh.restart();
            if (["activespecial", "activespecialv2"].includes(event.name))
                Hyprland.refreshMonitors();
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
        preload: true
        printErrors: false
        path: shell.stateHome + "/spectrumos/focus/state.json"
        watchChanges: true
        onFileChanged: reload()
        onTextChanged: {
            try { shell.focusState = JSON.parse(text()); } catch (error) {}
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: focusFile.reload()
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
        function showBrightnessIndicator(percent: int, monitor: string, internal: bool): void {
            const target = internal ? bars.instances.find(bar => /^(eDP-|LVDS-|DSI-)/.test(bar.modelData.name)) : null;
            shell.showLevelIndicator("brightness", percent, internal ? "" : monitor, target ? target.modelData.name : monitor);
        }
        function levelIndicatorState(): string {
            return JSON.stringify(bars.instances.map(bar => bar.levelIndicatorState()));
        }

        function refreshTheme(palette: string): bool {
            const applied = shell.applyPalette(palette);
            if (applied)
                fontFile.reload();
            return applied;
        }

        function openPicker(directory: string): void {
            const target = shell.focusedBar();
            if (target) pickerPanel.targetScreen = target.modelData;
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
        function toggleAppStore(): void { shell.openOnFocused("toggleAppStore"); }
        function appStoreStatus(): string { return JSON.stringify({page:sharedAppStore.page,results:sharedAppStore.results.length,error:sharedAppStore.error,jobs:sharedAppStore.jobs.map(job=>({id:job.id,active:job.active,phase:job.phase})),panels:bars.instances.map(bar=>({monitor:bar.modelData.name,expanded:bar.appStoreOpen}))}); }
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

        function toggleLauncher(): void { shell.openOnFocused("toggleLauncher"); }

        function toggleFavorites(): void { shell.openOnFocused("toggleFavorites"); }
        function favoritesStatus(): string { return JSON.stringify({ready:sharedFavorites.ready,busy:sharedFavorites.busy,favorites:sharedFavorites.favorites.length,categories:sharedFavorites.categories.length,defaultBrowser:sharedFavorites.defaultBrowser,panels:bars.instances.map(bar=>({monitor:bar.modelData.name,expanded:bar.favoritesOpen}))}); }
        function toggleControlCenter(): void { shell.openOnFocused("toggleControlCenter"); }
        function openControlPage(page: string): void {
            const target = shell.focusedBar();
            if (target) target.openControlPage(page);
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
        function openSpectrumDropFiles(): void { shell.openOnFocused("openSpectrumDropFiles"); }
        function toggleBarExtras(): void { shell.openOnFocused("toggleBarExtras"); }
        function toggleHotKey(): void { shell.openOnFocused("toggleHotKey"); }
        function toggleShortcuts(): void { shell.openOnFocused("toggleShortcuts"); }
        function toggleUpdates(): void { shell.openOnFocused("toggleUpdates"); }
        function toggleFocusTimer(): void { shell.openOnFocused("toggleFocusTimer"); }
        function toggleBreakReminders(): void { shell.openOnFocused("toggleBreakReminders"); }
        function toggleLocalServices(): void { shell.openOnFocused("toggleLocalServices"); }
        function toggleDefaultApps(): void { shell.openOnFocused("toggleDefaultApps"); }
        function focusTimerState(): string {
            return JSON.stringify({phase: shell.focusState.phase, remaining: shell.focusState.remaining,
                monitors: bars.instances.map(bar => bar.focusTimerState())});
        }
        function toggleEmoji(): void { shell.openOnFocused("toggleEmoji"); }
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
        function stableUpdateState(): string { return JSON.stringify({checking: shell.checkingStableUpdates, status: shell.stableUpdates}); }
        function checkStableUpdates(): void { shell.checkStableUpdates(); }
        function updatesState(): string { return JSON.stringify(bars.instances.map(bar => ({monitor: bar.modelData.name, expanded: bar.updatesOpen}))); }
        function gamingState(): string {
            return JSON.stringify({
                enabled: shell.gamingActive,
                backend: shell.gamingStatus,
                animationsEnabled: shell.animationsEnabled,
                monitors: bars.instances.map(bar => ({ name: bar.modelData.name, profile: bar.barProfile,
                    barVisible: bar.barVisible, leftInset: bar.panelLeftInset, topInset: bar.panelTopInset }))
            });
        }
        function barState(): string {
            return JSON.stringify({ style: shell.barStyle, position: shell.barPosition,
                monitors: bars.instances.map(bar => bar.styleState()) });
        }
        function windowTitleState(): string {
            return JSON.stringify(bars.instances.map(bar => ({monitor: bar.modelData.name,
                workspace: bar.monitor && bar.monitor.activeWorkspace ? bar.monitor.activeWorkspace.id : null,
                windowMonitor: bar.titleWindow ? bar.titleWindow.monitor : null,
                windowWorkspace: bar.titleWindow && bar.titleWindow.workspace ? bar.titleWindow.workspace.id : null,
                pinned: bar.titleWindow ? bar.titleWindow.pinned === true : false,
                title: bar.activeWindowTitle, address: bar.activeWindowIdentity})));
        }
        function widgetMonitorState(): string {
            const target = shell.focusedBar();
            return JSON.stringify({focused: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "",
                target: target ? target.modelData.name : "", monitors: bars.instances.map(bar => bar.widgetMonitorState())});
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
            WlrLayershell.namespace: "spectrum-bar"
            id: bar
            required property var modelData
            screen: modelData
            implicitHeight: islandStats.visible ? Math.max(34, Math.ceil(islandStats.implicitHeight) + 8) : 34
            exclusionMode: ExclusionMode.Ignore
            color: shell.barStyle === "islands" ? "transparent" : shell.colors.surface
            mask: BarInputRegion { backdrop: topIslands; islands: shell.barStyle === "islands"; hoverTarget: dashboardBarHover }
            anchors { top: true; left: true; right: true }
            visible: bar.barVisible && shell.barPosition === "top"

            property bool keyboardActive: false
            focusable: keyboardActive
            readonly property string barProfile: shell.gamingActive ? "gaming" : shell.barProfiles[bar.modelData.name] || shell.barProfile
            readonly property bool barVisible: !shell.gamingActive && barProfile !== "minimal" && barProfile !== "gaming"
            readonly property int barLeftInset: barVisible && shell.barPosition === "left" ? 52 : 0
            readonly property int panelLeftInset: shell.gamingActive ? 0 : barVisible ? barLeftInset : 8
            readonly property int panelTopInset: shell.gamingActive ? 0 : barVisible && shell.barPosition === "top" ? bar.implicitHeight : 8
            readonly property var monitor: Hyprland.monitors.values.find(item => item.name === bar.modelData.name) || null
            readonly property var titleWindow: shell.windowForMonitor(monitor)
            readonly property string activeWindowTitle: titleWindow ? titleWindow.title || "" : ""
            readonly property string activeWindowIdentity: titleWindow ? titleWindow.address || "" : ""
            readonly property bool widgetOpen: barWidget.expanded
            readonly property string widgetPage: barWidget.page
            readonly property bool dashboardOpen: dashboard.expanded
            readonly property bool favoritesOpen: favoritesPanel.expanded
            readonly property bool appStoreOpen: appStorePanel.expanded
            readonly property bool controlCenterOpen: controlCenter.expanded
            ShellFrame {
                id: shellFrame
                barHeight: bar.implicitHeight
                barProfile: bar.barProfile
                targetScreen: bar.modelData
                theme: shell
                barPosition: shell.barPosition
            }

            PanelWindow {
                id: focusCorner
                screen: bar.modelData
                anchors { top: true; right: true }
                implicitWidth: shellFrame.curveRadius + cornerContents.implicitWidth + shellFrame.thickness
                implicitHeight: shellFrame.thickness + 34 + shellFrame.curveRadius
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "spectrum-focus-countdown"
                color: "transparent"
                focusable: false
                visible: !shell.gamingActive && bar.barProfile !== "gaming"
                    && (bar.barProfile === "minimal" || shell.barPosition === "left")
                    && (cornerFocus.active || shell.recording.active || shell.audioRecording.active)
                mask: Region { item: cornerContents }
                ShellSurface {
                    x: shellFrame.curveRadius
                    y: shellFrame.thickness
                    width: cornerContents.implicitWidth
                    height: 34
                    radius: shellFrame.curveRadius
                    color: shell.colors.surface
                    attachTop: true
                    attachRight: true
                    topFrameThickness: 0
                    rightFrameThickness: 0
                    Row {
                        id: cornerContents
                        anchors.centerIn: parent
                        height: 34
                        spacing: 8
                        FocusCountdown {
                            id: cornerFocus
                            implicitHeight: 34
                            theme: shell
                            focusState: shell.focusState
                            onOpenRequested: bar.openFocusTimer()
                        }
                        RecordingStatus {
                            id: cornerRecordingStatus
                            width: implicitWidth + 12
                            fontFamily: shell.fontFamily
                            fontSize: shell.fontSize
                            screenRecording: shell.recording.active
                            audioRecording: shell.audioRecording.active
                            animationsEnabled: shell.animationsEnabled
                            onScreenRequested: bar.toggleRecorder()
                            onAudioRequested: bar.toggleAudioRecorder()
                        }
                    }
                }
            }

            readonly property bool updatesOpen: updatePanel.expanded
            readonly property bool igorSuppressed: shell.gamingActive || shell.recording.active || shell.audioRecording.active || audioRecorderPanel.expanded || barWidget.expanded || controlCenter.expanded || favoritesPanel.expanded || appStorePanel.expanded || appLauncher.expanded || dashboard.expanded || screenshotPanel.expanded || recorderPanel.expanded || updatePanel.expanded || utilityPanel.expanded || notificationCenter.expanded || sessionRail.expanded || wallpaperBrowser.expanded || pickerPanel.visible || notificationToast.visible

            DesktopBranding {
                targetScreen: bar.modelData
                visible: shell.desktopLogoEnabled && !shell.gamingActive
                corner: shell.desktopLogoCorner
                leftInset: bar.barLeftInset
                topInset: bar.barVisible && shell.barPosition === "top" ? bar.implicitHeight : 0
            }

            IgorVisitor {
                id: igorVisitor
                targetScreen: bar.modelData
                theme: shell
                panelLeftInset: shell.barStyle === "islands" ? 8 : bar.panelLeftInset
                panelTopInset: shell.barStyle === "islands" ? 8 : bar.panelTopInset
                routine: igorRoutine
            }

            function widgetMonitorState(): var {
                return {name: modelData.name, barScreen: screen ? screen.name : "", monitor: monitor ? monitor.name : "",
                    profile: barProfile, controlScreen: controlCenter.screen ? controlCenter.screen.name : "",
                    controlOpen: controlCenter.expanded, utilityScreen: utilityPanel.screen ? utilityPanel.screen.name : "",
                    utilityOpen: utilityPanel.expanded};
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
                favoritesPanel.expanded = false;
                appStorePanel.expanded = false;
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
                if (page === "questline") Quickshell.execDetached(["systemctl", "--user", "--no-block", "start", "spectrum-questline-notifications.service", "spectrum-questline-sync.service"]);
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

            function openWidgetIcon(action): void {
                const methods = {dashboard:"toggleDashboard", favorites:"toggleFavorites", "app-store":"toggleAppStore",
                    spectrumdrop:"toggleSpectrumDrop", wallpapers:"toggleWallpapers", notifications:"toggleNotifications",
                    screenshot:"toggleScreenshot", recorder:"toggleRecorder", "audio-recorder":"toggleAudioRecorder",
                    control:"toggleControlCenter", session:"toggleSession", updates:"toggleUpdates", color:"toggleColorPicker",
                    "color-history":"toggleColorHistory"};
                if (methods[action]) bar[methods[action]]();
                else if (action === "keep-awake") shell.toggleKeepAwake();
                else if (action === "ukvm") Quickshell.execDetached(["/usr/bin/spectrum-ukvm"]);
                else if (["questline", "focus", "breaks", "services", "default-apps", "search", "calculator", "password", "emoji", "hotkey", "shortcuts"].includes(action)) bar.openUtility(action);
                else if (["appimages", "audio", "network", "bluetooth", "displays", "mouse", "typography", "weather", "time", "battery"].includes(action)) bar.toggleBarWidget(action === "network" ? "wifi" : action);
            }

            function toggleFileSearch(): void { openUtility("search"); }
            function toggleCalculator(): void { openUtility("calculator"); }
            function togglePassword(): void { openUtility("password"); }
            function toggleSpectrumDrop(): void { openUtility("spectrumdrop"); }
            function openSpectrumDropFiles(): void {
                closeSidePanels();
                appLauncher.expanded = false;
                wallpaperBrowser.expanded = false;
                utilityPanel.open("spectrumdrop");
            }
            function toggleBarExtras(): void { toggleBarWidget("extras"); }
            function toggleHotKey(): void { openUtility("hotkey"); }
            function toggleShortcuts(): void { openUtility("shortcuts"); }
            function openUpdates(): void {
                closeSidePanels();
                appLauncher.expanded = false;
                updatePanel.refresh();
                updatePanel.expanded = true;
            }
            function toggleUpdates(): void {
                if (updatePanel.expanded) updatePanel.expanded = false;
                else openUpdates();
            }
            function showLevelIndicator(kind, percent, label): void { levelIndicator.show(kind, percent, label); }
            function dismissLevelIndicator(): void { levelIndicator.dismiss(); }
            function showTrackIndicator(): void { levelIndicator.showTrack(); }
            function dismissTrackIndicator(): void { levelIndicator.dismissTrack(); }
            function levelIndicatorState(): var { return levelIndicator.state(); }
            function toggleFocusTimer(): void { openUtility("focus"); }
            function toggleBreakReminders(): void { openUtility("breaks"); }
            function toggleLocalServices(): void { openUtility("services"); }
            function toggleDefaultApps(): void { openUtility("default-apps"); }
            function focusTimerState(): var {
                return {monitor: modelData.name, profile: barProfile, position: shell.barPosition,
                    top: {visible: bar.visible && topFocusCountdown.visible, width: topFocusCountdown.width, height: topFocusCountdown.height},
                    left: {visible: false, width: 0, height: 0},
                    topRecording: {visible: bar.visible && topRecordingStatus.visible,
                        x: topRow.x + trayGroup.x + topRecordingStatus.x,
                        y: topRow.y + trayGroup.y + topRecordingStatus.y,
                        width: topRecordingStatus.width, height: topRecordingStatus.height},
                    corner: {visible: focusCorner.visible, width: focusCorner.width, height: focusCorner.height,
                        focus: cornerFocus.active, screenRecording: cornerRecordingStatus.screenRecording,
                        audioRecording: cornerRecordingStatus.audioRecording}};
            }

            function openFocusTimer(): void {
                if (!utilityPanel.expanded || utilityPanel.page !== "focus") openUtility("focus");
            }
            function toggleEmoji(): void { openUtility("emoji"); }
            function toggleQuestline(): void { openUtility("questline"); }
            function openQuestlineNewScroll(): void {
                Quickshell.execDetached(["systemctl", "--user", "--no-block", "start", "spectrum-questline-notifications.service", "spectrum-questline-sync.service"]);
                closeSidePanels();
                appLauncher.expanded = false;
                wallpaperBrowser.expanded = false;
                utilityPanel.openQuestlineNewScroll();
            }
            function openQuestlineNewTask(): void {
                Quickshell.execDetached(["systemctl", "--user", "--no-block", "start", "spectrum-questline-notifications.service", "spectrum-questline-sync.service"]);
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

            function openDashboard(): void {
                if (dashboard.expanded) return;
                closeSidePanels();
                appLauncher.expanded = false;
                wallpaperBrowser.expanded = false;
                shell.refreshControls("dashboard");
                dashboard.expanded = true;
            }

            function toggleDashboard(): void {
                if (dashboard.expanded) dashboard.expanded = false;
                else openDashboard();
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

            function toggleAppStore(): void {
                const opening = !appStorePanel.expanded;
                if (opening) { closeSidePanels(); appLauncher.expanded = false; wallpaperBrowser.expanded = false; }
                appStorePanel.expanded = opening;
            }

            function toggleFavorites(): void {
                const opening = !favoritesPanel.expanded;
                if (opening) {
                    closeSidePanels(); appLauncher.expanded = false; wallpaperBrowser.expanded = false;
                    Quickshell.execDetached(["systemctl", "--user", "--no-block", "start", "spectrum-questline-sync.service"]);
                }
                favoritesPanel.expanded = opening;
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
                shell.refreshControls("wallpapers");
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
                targetScreen: bar.modelData
                theme: shell
                monitor: bar.monitor
                network: shell.network
                overview: shell.overview
                weather: shell.weather
                recording: shell.recording
                media: shell.media
                activeWindowTitle: bar.activeWindowTitle
                activeWindowIdentity: bar.activeWindowIdentity
                active: bar.barVisible && shell.barPosition === "left"
                onWidgetRequested: action => bar.openWidgetIcon(action)
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
                targetScreen: bar.modelData
                theme: shell
                samples: shell.waveSamples
                barPosition: shell.barPosition
                visible: bar.barProfile === "multimedia"
            }

            Dashboard {
                id: dashboard
                questline: utilityPanel.questline
                questlineLoaded: utilityPanel.questlineLoaded
                onRefreshDueDates: utilityPanel.refreshQuestline()
                onDueItemRequested: (taskId, stepId) => {
                    bar.closeSidePanels();
                    appLauncher.expanded = false;
                    wallpaperBrowser.expanded = false;
                    utilityPanel.openQuestlineDueItem(taskId, stepId);
                }
                targetScreen: bar.modelData
                theme: shell
                weather: shell.weather
                media: shell.media
                topInset: bar.panelTopInset
                leftInset: bar.barLeftInset
                onActionRequested: action => {
                    switch (action) {
                    case "time": bar.toggleBarWidget("time"); break;
                    case "weather": bar.toggleBarWidget("weather"); break;
                    case "mediaPrevious": shell.controlMedia("previous"); break;
                    case "mediaToggle": shell.controlMedia("toggle"); break;
                    case "mediaNext": shell.controlMedia("next"); break;
                    }
                }
            }

            ScreenshotPanel {
                id: screenshotPanel
                targetScreen: bar.modelData
                theme: shell
                topInset: bar.panelTopInset
                leftInset: bar.panelLeftInset
                onCaptureRequested: mode => Quickshell.execDetached([shell.backend("panel"), "--screenshot-" + mode])
            }

            UpdatePanel {
                id: updatePanel
                targetScreen: bar.modelData
                theme: shell
                backendDir: shell.backendDir
                topInset: bar.panelTopInset
                leftInset: bar.panelLeftInset
            }

            AudioRecorderPanel {
                id: audioRecorderPanel
                targetScreen: bar.modelData
                theme: shell
                backendDir: shell.backendDir
                topInset: bar.panelTopInset
                leftInset: bar.panelLeftInset
                onRecordingRefreshRequested: if (!audioRecorderProcess.running) audioRecorderProcess.running = true
            }

            RecorderPanel {
                id: recorderPanel
                targetScreen: bar.modelData
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


            SessionRail {
                id: sessionRail
                targetScreen: bar.modelData
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
                screen: bar.modelData
                theme: shell
                leftInset: bar.barLeftInset
            }

            UtilityPanel {
                onSpectrumDropReturnRequested: {
                    if (!barWidget.expanded && !controlCenter.expanded && !favoritesPanel.expanded && !notificationCenter.expanded
                        && !appLauncher.expanded && !sessionRail.expanded && !wallpaperBrowser.expanded
                        && !dashboard.expanded && !screenshotPanel.expanded && !recorderPanel.expanded
                        && !audioRecorderPanel.expanded && !updatePanel.expanded && !appStorePanel.expanded)
                        utilityPanel.expanded = true;
                }
                onQuestlineCompleted: igorRoutine.celebrate()
                panelLeftInset: bar.panelLeftInset
                id: utilityPanel
                questlineWorkspace: sharedQuestlineWorkspace
                screen: bar.modelData
                theme: shell
                backendDir: shell.backendDir
                focusState: shell.focusState
                breakState: breakReminders
                leftInset: bar.barLeftInset
                topInset: bar.panelTopInset
                onFocusAction: action => shell.runAction([shell.backend("spectrum-focus"), action])
                onFocusStart: request => shell.runAction([shell.backend("spectrum-focus"), "start", JSON.stringify(request)])
            }

            AppStorePanel {
                id: appStorePanel
                screen: bar.modelData
                theme: shell
                manager: sharedAppStore
                topInset: bar.panelTopInset
                sideInset: bar.panelLeftInset
                onCloseRequested: expanded = false
            }

            FavoritesPanel {
                id: favoritesPanel
                screen: bar.modelData
                theme: shell
                manager: sharedFavorites
                topInset: bar.panelTopInset
                sideInset: bar.panelLeftInset
                onCloseRequested: expanded = false
            }

            ControlCenter {
                barProfile: bar.barProfile
                topInset: bar.panelTopInset
                sideInset: bar.panelLeftInset
                id: controlCenter
                screen: bar.modelData
                theme: shell
                barPosition: shell.barPosition
                themeState: shell.themeState
                onWidgetBounceSelected: enabled => shell.setWidgetBounce(enabled)
                onBarPositionSelected: position => {
                    shell.setBarPosition(position);
                    controlCenter.expanded = false;
                }
                onBarProfileSelected: profile => {
                    shell.setBarProfile(profile, bar.modelData.name);
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
                screen: bar.modelData
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
                screen: bar.modelData
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
                onQuestlineDrinkRequested:item=>shell.invokeNotificationAction(item.id,"questline-drink")
                onUpdatesRequested:item=>shell.invokeNotificationAction(item.id,"spectrum-open-updates")
                onToggleDoNotDisturb: shell.doNotDisturb = !shell.doNotDisturb
            }

            PanelWindow {
                id: notificationToast
                screen: bar.modelData
                anchors { top: true; bottom: true; right: true }
                margins.top: bar.panelTopInset
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "spectrum-widget-toasts"
                focusable: false
                implicitWidth: Math.min(Math.max(260, shell.fontSize * 20) + 8, bar.modelData.width - 20)
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
                            onActionInvoked:identifier=>shell.invokeNotificationAction(model.notificationId,identifier)
                            Timer {
                                interval: Math.max(1, toastCard.model.expiresAt - Date.now())
                                running: toastCard.revealed && toastCard.model.expiresAt>0
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

                DashboardHoverTarget {
                    id: dashboardBarHover
                    anchors { top: parent.top; bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                    width: Math.min(260, parent.width)
                    targetScreen: bar.modelData
                    barPosition: shell.barPosition
                    barProfile: bar.barProfile
                    barVisible: bar.barVisible
                    leftInset: bar.barLeftInset
                    dashboardOpen: dashboard.expanded
                    onOpenRequested: bar.openDashboard()
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
                    anchors.rightMargin: 14
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
                            model: shell.workspacesForMonitor(bar.modelData ? bar.modelData.name : "")
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
                                    text: shell.workspaceGlyph(parent.modelData, parent.active ? qsTranslate("Spectrum", "active") : parent.occupied ? qsTranslate("Spectrum", "occupied") : qsTranslate("Spectrum", "empty"))
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
                        animationsEnabled: shell.animationsEnabled && bar.visible
                        id: windowTitle
                        visible: (bar.barProfile === "standard" || bar.barProfile === "detailed") && bar.activeWindowTitle.length > 0
                        Layout.preferredWidth: Math.min(shell.barStyle === "islands" ? windowTitle.measuredTextWidth : 420, 420, bar.modelData.width * 0.25,
                            islandStats.visible ? Math.min(180, Math.max(0, islandStats.availableWidth - 240)) : 420)
                        Layout.minimumWidth: 0
                        Layout.maximumWidth: islandStats.visible ? Layout.preferredWidth : 420
                        title: bar.activeWindowTitle
                        windowIdentity: bar.activeWindowIdentity
                        fontFamily: shell.fontFamily
                        fontPixelSize: shell.fontSize
                        textColor: shell.colors.muted
                    }

                    Item { Layout.fillWidth: true }

                    DetailedBarStats {
                        id: islandStats
                        visible: bar.barProfile === "detailed"
                        availableWidth: Math.max(1, topRow.width - launcherButton.implicitWidth
                            - topIgorButton.implicitWidth - workspaceButtons.width
                            - minimalStatusGroup.implicitWidth - trayGroup.width - 8 * topRow.spacing)
                        Layout.preferredWidth: Math.min(naturalWidth, Math.max(1, availableWidth - (windowTitle.visible ? windowTitle.Layout.preferredWidth : 0)))
                        maximumLineCount: 2
                        elide: Text.ElideRight
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
                        FocusCountdown {
                            id: topFocusCountdown
                            theme: shell
                            focusState: shell.focusState
                            onOpenRequested: bar.openFocusTimer()
                        }

                        WidgetIcons {
                            visible: bar.barProfile === "detailed"
                            theme: shell
                            Layout.preferredWidth: Math.min(naturalWidth, Math.max(140, topRow.width
                                - launcherButton.implicitWidth - topIgorButton.implicitWidth - workspaceButtons.width
                                - trayGroup.width - topFocusCountdown.width - 340 - 8 * topRow.spacing))
                            Layout.minimumWidth: Layout.preferredWidth
                            Layout.maximumWidth: Layout.preferredWidth
                            onChosen: action => bar.openWidgetIcon(action)
                        }
                        RowLayout {
                            visible: bar.barProfile !== "detailed"
                            spacing: 8
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
                                text: qsTranslate("Spectrum", "Aa")
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
                                    visible: ["standard", "multimedia"].includes(bar.barProfile)
                                    text: "󰇘"
                                    color: shell.colors.foreground
                                    font { family: shell.fontFamily; pixelSize: shell.fontSize + 3 }
                                    Accessible.name: qsTranslate("Spectrum", "More bar controls")
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
                        RecordingStatus {
                            id: topRecordingStatus
                            fontFamily: shell.fontFamily
                            fontSize: shell.fontSize
                            screenRecording: shell.recording.active
                            audioRecording: shell.audioRecording.active
                            animationsEnabled: shell.animationsEnabled && bar.visible
                            onScreenRequested: bar.toggleRecorder()
                            onAudioRequested: bar.toggleAudioRecorder()
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
                    width: Math.max(0, Math.min(600, 2 * Math.min(parent.width / 2 - (windowTitle.visible ? windowTitle.x + windowTitle.width : workspaceButtons.x + workspaceButtons.width) - 20,
                        minimalStatusGroup.x - parent.width / 2 - 20)))
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    visible: false
                    text: qsTranslate("Spectrum", "CPU ") + shell.overview.load + qsTranslate("Spectrum", "   RAM ") + shell.overview.memory + (shell.overview.gpu ? qsTranslate("Spectrum", "   GPU ") + shell.overview.gpu : "") + (shell.overview.temperature ? "   " + shell.overview.temperature : "")
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
                        animationsEnabled: shell.animationsEnabled && bar.visible
                        id: mediaTitle
                        width: Math.max(0, Math.min(shell.barStyle === "islands" ? mediaTitle.measuredTextWidth : 420, 420, mediaControls.availableWidth - 150))
                        height: 28
                        title: shell.media.available ? [shell.media.artist, shell.media.title].filter(Boolean).join(" - ") : qsTranslate("Spectrum", "No media")
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

            LevelIndicator {
                id: levelIndicator
                targetScreen: bar.modelData
                theme: shell
                barPosition: shell.barPosition
                panelLeftInset: bar.panelLeftInset
                panelTopInset: bar.panelTopInset
                blocked: barWidget.expanded && ["audio", "displays"].includes(barWidget.page)
            }

            BarWidget {
                panelLeftInset: bar.panelLeftInset
                panelTopInset: bar.panelTopInset
                id: barWidget
                targetScreen: bar.modelData
                theme: shell
                barPosition: shell.barPosition
                onExtraRequested: action => {
                    if (action === "spectrumdrop") bar.toggleSpectrumDrop();
                    else if (action === "favorites") bar.toggleFavorites();
                    else if (action === "app-store") bar.toggleAppStore();
                    else if (action === "control") bar.toggleControlCenter();
                    else if (action === "breaks") bar.toggleBreakReminders();
                    else if (action === "services") bar.toggleLocalServices();
                    else if (action === "default-apps") bar.toggleDefaultApps();
                    else if (action === "session") bar.toggleSession();
                    else bar.toggleBarWidget(action);
                }
            }
        }
    }
}
