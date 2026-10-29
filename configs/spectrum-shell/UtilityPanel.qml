pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: panel
    required property var theme
    property int panelLeftInset: theme.panelLeftInset
    required property string backendDir
    signal spectrumDropReturnRequested()
    property string page: "search"
    property bool expanded: false
    property int leftInset: 0
    property int topInset: 8
    readonly property bool cornerPanel: page === "spectrumdrop" || page === "breaks"
    readonly property bool cornerTop: cornerPanel && theme.barPosition === "top"
    readonly property bool sidePanel: page === "shortcuts"
    readonly property bool topPanel: page === "questline" || page === "focus" || page === "services" || page === "default-apps"
    property var questline: ({ available: false, installed: false })
    required property var questlineWorkspace
    property bool questlineRestoring: false
    property bool questlineRestorePending: false
    property string questlineDraftKey: ""
    readonly property var questlineView: questlineContent.item
    property bool questlineLoaded: false
    property var questlineDueTarget: null
    property bool questlineDueReady: false
    property bool questlinePendingNewTask: false
    property bool questlinePendingNewScroll: false
    property bool questlineQuickScrollPicker: false
    property string questlineTab: "Overview"
    property var questlineSelected: null
    property var questlineStepParent: null
    property var questlineStepSelected: null
    property var questlineDeleteTarget: null
    property string questlinePendingId: ""
    property bool questlineEditing: false
    property string questlineError: ""
    property string questlineMessage: ""
    property int questlineCampaignIndex: 0
    property string questlineEditCampaignId: ""
    property string questlineCampaignId: ""
    property string questlineSidequestFrequency: "Daily"
    property int questlineSidequestReward: 20
    property string questlineTaskPriority: "Medium"
    property string questlineTaskRecurrence: "None"
    readonly property var questlineTaskPriorities: ["Low", "Medium", "High"]
    readonly property var questlineTaskRecurrences: ["None", "Daily", "Weekly", "Monthly", "Yearly"]
    readonly property var questlineSidequestFrequencies: ["Daily", "2x Daily", "3x Daily", "5x Daily", "Weekdays", "Weekly", "Monthly"]
    property string questlineTreasuryCampaignId: ""
    property bool questlineCalendarOpen: false
    property date questlineCalendarMonth: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    property string questlineScrollProjectId: ""
    QuestlineTasks {
        id: questlineTasks
        campaigns: panel.questline.campaigns || []
        tasks: panel.questline.tasks || []
        campaignId: panel.questlineCampaignId
    }

    QuestlineTreasury {
        id: questlineTreasury
        campaigns: panel.questline.campaigns || []
        entries: panel.questline.entries || []
        accounts: panel.questline.accounts || []
        campaignId: panel.questlineTreasuryCampaignId
    }

    Component.onCompleted: {
        colorHistoryProcess.exec([backendDir + "/spectrum-shell-tools", "colors"]);
        questlineCampaignProcess.exec([backendDir + "/spectrum-shell-tools", "questline-campaign"]);
    }
    property var emojis: []
    property int emojiSelectedIndex: 0
    property string submittedEmojiQuery: ""
    property string password: ""
    property string colorValue: ""
    property var savedColors: []
    property string pendingColor: ""
    property bool colorPickActive: false
    property bool colorPickedThisRun: false
    property int colorPickCount: 0
    property int passwordLength: 20
    property bool useLetters: true
    property bool useNumbers: true
    property bool useSymbols: true
    property string requestedPasswordOptions: ""
    property int requestedPasswordLength: 20
    required property var breakState
    required property var focusState
    signal focusAction(string action)
    signal focusStart(var request)
    property string pendingFocusPage: ""
    property string previousFocusSession: ""

    function startFocus(request): void {
        if (["starting", "work", "paused"].includes(focusState.phase)) return;
        pendingFocusPage = page;
        previousFocusSession = focusState.session_id || "";
        focusStart(request);
    }

    onFocusStateChanged: {
        if (!pendingFocusPage) return;
        if (focusState.phase === "work" && (focusState.session_id || "") !== previousFocusSession) {
            if (expanded && page === pendingFocusPage) expanded = false;
            pendingFocusPage = "";
        } else if (["error", "completed", "cancelled"].includes(focusState.phase)) {
            pendingFocusPage = "";
        }
    }
    property var pendingShortcut: []

    function activateShortcut(index): void {
        if (shortcutDelay.running || index < 0 || index >= shortcuts.length)
            return;
        pendingShortcut = shortcuts[index].command;
        expanded = false;
        ApplicationLaunch.start(pendingShortcut, 380);
        shortcutDelay.restart();
    }

    Timer {
        id: shortcutDelay
        // Espera a que el panel suelte el foco antes de ejecutar la acción.
        interval: 380
        onTriggered: {
            panel.pendingShortcut = [];
        }
    }
    readonly property var shortcuts: [
        { combo: "Super + Shift + U", action: qsTranslate("Spectrum", "App Store"), command: [backendDir + "/spectrum-shell-open", "app-store"] },
        { combo: "Super + Shift + E", action: qsTranslate("Spectrum", "AppImage Manager"), command: [backendDir + "/spectrum-shell-open", "appimages"] },
        { combo: "Super + D", action: qsTranslate("Spectrum", "Applications"), command: [backendDir + "/spectrum-shell-launcher"] },
        { combo: "Shift + Print", action: qsTranslate("Spectrum", "Area screenshot"), command: [backendDir + "/panel", "--screenshot-area"] },
        { combo: "Super + A", action: qsTranslate("Spectrum", "Audio"), command: [backendDir + "/spectrum-shell-open", "audio"] },
        { combo: "Super + Shift + A", action: qsTranslate("Spectrum", "Audio recorder"), command: [backendDir + "/spectrum-shell-open", "audio-recorder"] },
        { combo: "Super + Shift + L", action: qsTranslate("Spectrum", "Bluetooth"), command: [backendDir + "/spectrum-shell-open", "bluetooth"] },
        { combo: "Super + Shift + B", action: qsTranslate("Spectrum", "Break reminders"), command: [backendDir + "/spectrum-shell-open", "breaks"] },
        { combo: "Super + C", action: qsTranslate("Spectrum", "Calculator"), command: [backendDir + "/spectrum-shell-open", "calculator"] },
        { combo: "Super + J", action: qsTranslate("Spectrum", "Change window arrangement"), command: ["hyprctl", "eval", "require(\"window-actions\").arrange()"] },
        { combo: "Ctrl + Shift + Space", action: qsTranslate("Spectrum", "Clear notifications"), command: [backendDir + "/spectrum-shell-open", "clear-notifications"] },
        { combo: "Super + P", action: qsTranslate("Spectrum", "Control Center"), command: [backendDir + "/spectrum-shell-open", "control"] },
        { combo: "Super + Shift + H", action: qsTranslate("Spectrum", "Dashboard"), command: [backendDir + "/spectrum-shell-open", "dashboard"] },
        { combo: "Super + Shift + G", action: qsTranslate("Spectrum", "Default applications"), command: [backendDir + "/spectrum-shell-open", "default-apps"] },
        { combo: "Ctrl + Space", action: qsTranslate("Spectrum", "Dismiss latest notification"), command: [backendDir + "/spectrum-shell-open", "dismiss-notification"] },
        { combo: "Super + Shift + O", action: qsTranslate("Spectrum", "Displays"), command: [backendDir + "/spectrum-shell-open", "displays"] },
        { combo: "Super + V", action: qsTranslate("Spectrum", "Emoji picker"), command: [backendDir + "/spectrum-shell-open", "emoji"] },
        { combo: "Super + Shift + V", action: qsTranslate("Spectrum", "Favorites"), command: [backendDir + "/spectrum-shell-open", "favorites"] },
        { combo: "Super + E", action: qsTranslate("Spectrum", "Files"), command: ["uwsm", "app", "--", "thunar"] },
        { combo: "Super + S", action: qsTranslate("Spectrum", "Find files"), command: [backendDir + "/spectrum-shell-open", "search"] },
        { combo: "Super + F10", action: qsTranslate("Spectrum", "Focus shell bar"), command: [backendDir + "/spectrum-shell-open", "bar"] },
        { combo: "Super + Shift + F", action: qsTranslate("Spectrum", "Focus timer"), command: [backendDir + "/spectrum-shell-open", "focus"] },
        { combo: "Super + Down", action: qsTranslate("Spectrum", "Focus window down"), command: ["hyprctl", "eval", "require(\"window-actions\").focus(\"down\")"] },
        { combo: "Super + Left", action: qsTranslate("Spectrum", "Focus window left"), command: ["hyprctl", "eval", "require(\"window-actions\").focus(\"left\")"] },
        { combo: "Super + Right", action: qsTranslate("Spectrum", "Focus window right"), command: ["hyprctl", "eval", "require(\"window-actions\").focus(\"right\")"] },
        { combo: "Super + Up", action: qsTranslate("Spectrum", "Focus window up"), command: ["hyprctl", "eval", "require(\"window-actions\").focus(\"up\")"] },
        { combo: "Super + H", action: qsTranslate("Spectrum", "HotKey"), command: [backendDir + "/spectrum-shell-open", "hotkey"] },
        { combo: "Super + K", action: qsTranslate("Spectrum", "Keyboard shortcuts"), command: [backendDir + "/spectrum-shell-open", "shortcuts"] },
        { combo: "Super + Shift + C", action: qsTranslate("Spectrum", "Local services"), command: [backendDir + "/spectrum-shell-open", "services"] },
        { combo: "Super + L", action: qsTranslate("Spectrum", "Lock computer"), command: [backendDir + "/session-menu", "lock"] },
        { combo: "Super + Print", action: qsTranslate("Spectrum", "Monitor screenshot"), command: [backendDir + "/panel", "--screenshot-monitor"] },
        { combo: "Super + Shift + X", action: qsTranslate("Spectrum", "More widgets"), command: [backendDir + "/spectrum-shell-open", "more"] },
        { combo: "Super + Shift + M", action: qsTranslate("Spectrum", "Mouse Settings"), command: [backendDir + "/spectrum-shell-open", "mouse"] },
        { combo: "Super + Shift + Down", action: qsTranslate("Spectrum", "Move window down"), command: ["hyprctl", "eval", "require(\"window-actions\").move(\"down\")"] },
        { combo: "Super + Shift + Left", action: qsTranslate("Spectrum", "Move window left"), command: ["hyprctl", "eval", "require(\"window-actions\").move(\"left\")"] },
        { combo: "Super + Shift + Right", action: qsTranslate("Spectrum", "Move window right"), command: ["hyprctl", "eval", "require(\"window-actions\").move(\"right\")"] },
        { combo: "Super + Shift + 1", action: qsTranslate("Spectrum", "Move window to workspace 1"), command: ["hyprctl", "eval", "local origin = hl.get_active_workspace(); hl.dispatch(hl.dsp.window.move({ workspace = 1 })); if origin then hl.dispatch(hl.dsp.focus({ workspace = origin.id })) end"] },
        { combo: "Super + Shift + 2", action: qsTranslate("Spectrum", "Move window to workspace 2"), command: ["hyprctl", "eval", "local origin = hl.get_active_workspace(); hl.dispatch(hl.dsp.window.move({ workspace = 2 })); if origin then hl.dispatch(hl.dsp.focus({ workspace = origin.id })) end"] },
        { combo: "Super + Shift + 3", action: qsTranslate("Spectrum", "Move window to workspace 3"), command: ["hyprctl", "eval", "local origin = hl.get_active_workspace(); hl.dispatch(hl.dsp.window.move({ workspace = 3 })); if origin then hl.dispatch(hl.dsp.focus({ workspace = origin.id })) end"] },
        { combo: "Super + Shift + 4", action: qsTranslate("Spectrum", "Move window to workspace 4"), command: ["hyprctl", "eval", "local origin = hl.get_active_workspace(); hl.dispatch(hl.dsp.window.move({ workspace = 4 })); if origin then hl.dispatch(hl.dsp.focus({ workspace = origin.id })) end"] },
        { combo: "Super + Shift + 5", action: qsTranslate("Spectrum", "Move window to workspace 5"), command: ["hyprctl", "eval", "local origin = hl.get_active_workspace(); hl.dispatch(hl.dsp.window.move({ workspace = 5 })); if origin then hl.dispatch(hl.dsp.focus({ workspace = origin.id })) end"] },
        { combo: "Super + Shift + 6", action: qsTranslate("Spectrum", "Move window to workspace 6"), command: ["hyprctl", "eval", "local origin = hl.get_active_workspace(); hl.dispatch(hl.dsp.window.move({ workspace = 6 })); if origin then hl.dispatch(hl.dsp.focus({ workspace = origin.id })) end"] },
        { combo: "Super + Shift + Up", action: qsTranslate("Spectrum", "Move window up"), command: ["hyprctl", "eval", "require(\"window-actions\").move(\"up\")"] },
        { combo: "Super + B", action: qsTranslate("Spectrum", "Network"), command: [backendDir + "/spectrum-shell-open", "network"] },
        { combo: "Super + T", action: qsTranslate("Spectrum", "New Questline task"), command: [backendDir + "/spectrum-shell-open", "new-task"] },
        { combo: "Super + Tab", action: qsTranslate("Spectrum", "Next window"), command: ["hyprctl", "eval", "require(\"window-actions\").cycle(true)"] },
        { combo: "Super + N", action: qsTranslate("Spectrum", "Notification history"), command: [backendDir + "/spectrum-shell-open", "notifications"] },
        { combo: "Super + G", action: qsTranslate("Spectrum", "Password generator"), command: [backendDir + "/spectrum-shell-open", "password"] },
        { combo: "Super + I", action: qsTranslate("Spectrum", "Pick colors until Escape"), command: [backendDir + "/spectrum-shell-open", "color"] },
        { combo: "Super + Shift + Space", action: qsTranslate("Spectrum", "Pin floating window across workspaces"), command: [backendDir + "/window-pin-toggle"] },
        { combo: "Super + Shift + P", action: qsTranslate("Spectrum", "Power profiles"), command: [backendDir + "/spectrum-shell-open", "power"] },
        { combo: "Super + Shift + Tab", action: qsTranslate("Spectrum", "Previous window"), command: ["hyprctl", "eval", "require(\"window-actions\").cycle(false)"] },
        { combo: "Super + Shift + Q", action: qsTranslate("Spectrum", "Questline"), command: [backendDir + "/spectrum-shell-open", "questline"] },
        { combo: "Super + Shift + N", action: qsTranslate("Spectrum", "Quick note in Questline"), command: [backendDir + "/spectrum-shell-open", "new-scroll"] },
        { combo: "Super + Shift + Gown", action: qsTranslate("Spectrum", "Resize window down"), command: ["hyprctl", "dispatch", "hl.dsp.window.resize({ x = 0, y = 20, relative = true })"] },
        { combo: "Super + Ctrl + Left", action: qsTranslate("Spectrum", "Resize window left"), command: ["hyprctl", "dispatch", "hl.dsp.window.resize({ x = -20, y = 0, relative = true })"] },
        { combo: "Super + Ctrl + Right", action: qsTranslate("Spectrum", "Resize window right"), command: ["hyprctl", "dispatch", "hl.dsp.window.resize({ x = 20, y = 0, relative = true })"] },
        { combo: "Super + Ctrl + Up", action: qsTranslate("Spectrum", "Resize window up"), command: ["hyprctl", "dispatch", "hl.dsp.window.resize({ x = 0, y = -20, relative = true })"] },
        { combo: "Super + Shift + I", action: qsTranslate("Spectrum", "Saved colors"), command: [backendDir + "/spectrum-shell-open", "color-history"] },
        { combo: "Super + Shift + S", action: qsTranslate("Spectrum", "Screen recorder"), command: [backendDir + "/spectrum-shell-open", "recorder"] },
        { combo: "Print", action: qsTranslate("Spectrum", "Screenshot menu"), command: [backendDir + "/panel", "--capture"] },
        { combo: "Super + X", action: qsTranslate("Spectrum", "Session controls"), command: [backendDir + "/spectrum-shell-open", "session"] },
        { combo: "Super + Shift + D", action: qsTranslate("Spectrum", "SpectrumDrop"), command: [backendDir + "/spectrum-shell-open", "spectrumdrop"] },
        { combo: "Super + Shift + R", action: qsTranslate("Spectrum", "Spectrumize me"), command: [backendDir + "/theme-adapter", "random"] },
        { combo: "Super + U", action: qsTranslate("Spectrum", "SpectrumOS updates"), command: [backendDir + "/spectrum-shell-open", "updates"] },
        { combo: "Super + 1", action: qsTranslate("Spectrum", "Switch to workspace 1"), command: ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = 1 })"] },
        { combo: "Super + 2", action: qsTranslate("Spectrum", "Switch to workspace 2"), command: ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = 2 })"] },
        { combo: "Super + 3", action: qsTranslate("Spectrum", "Switch to workspace 3"), command: ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = 3 })"] },
        { combo: "Super + 4", action: qsTranslate("Spectrum", "Switch to workspace 4"), command: ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = 4 })"] },
        { combo: "Super + 5", action: qsTranslate("Spectrum", "Switch to workspace 5"), command: ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = 5 })"] },
        { combo: "Super + 6", action: qsTranslate("Spectrum", "Switch to workspace 6"), command: ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = 6 })"] },
        { combo: "Super + Return", action: qsTranslate("Spectrum", "Terminal"), command: ["uwsm", "app", "--", "kitty"] },
        { combo: "Super + Shift + T", action: qsTranslate("Spectrum", "Time and region"), command: [backendDir + "/spectrum-shell-open", "time"] },
        { combo: "Super + Space", action: qsTranslate("Spectrum", "Toggle floating window"), command: ["hyprctl", "dispatch", "hl.dsp.window.float({ action = \"toggle\" })"] },
        { combo: "Super + F", action: qsTranslate("Spectrum", "Toggle fullscreen"), command: ["hyprctl", "dispatch", "hl.dsp.window.fullscreen()"] },
        { combo: "Super + Shift + Y", action: qsTranslate("Spectrum", "Typography"), command: [backendDir + "/spectrum-shell-open", "typography"] },
        { combo: "Super + Shift + K", action: qsTranslate("Spectrum", "UniversalKVM"), command: ["/usr/bin/spectrum-ukvm"] },
        { combo: "Super + W", action: qsTranslate("Spectrum", "Wallpapers"), command: [backendDir + "/spectrum-shell-open", "wallpapers"] },
        { combo: "Super + Shift + W", action: qsTranslate("Spectrum", "Weather"), command: [backendDir + "/spectrum-shell-open", "weather"] },
        { combo: "Super + Shift + Print", action: qsTranslate("Spectrum", "Window screenshot"), command: [backendDir + "/panel", "--screenshot-window"] }
    ].sort((a, b) => a.action.localeCompare(b.action))

    visible: motion.active
    color: "transparent"
    WlrLayershell.keyboardFocus: panelFocus.mode
    ShellFocus { id: panelFocus; window: panel; enabled: expanded }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "spectrum-widget-utilitypanel"
    anchors { top: true; bottom: true; left: true; right: true }

    function open(name): void {
        if (page === "questline") { rememberQuestline(); questlineWorkspace.flush(); }
        if (name === "questline") questlineContent.ensureLoaded();
        page = name;
        expanded = true;
        query.text = "";
        emojis = [];
        emojiSelectedIndex = 0;
        if (name === "shortcuts") {
            shortcutList.currentIndex = 0;
            shortcutList.positionViewAtBeginning();
            Qt.callLater(() => shortcutList.forceActiveFocus());
        }
        if (name === "hotkey") hotkeys.command(["status"]);
        if (name === "spectrumdrop") spectrumDrop.command(["status"]);
        if (name === "password")
            generatePassword();
        questlineDueTarget = null;
        if (name === "questline") {
            questlinePendingNewTask = false;
            questlinePendingNewScroll = false;
            questlineRestorePending = true;
            if (questlineWorkspace.ready && questlineLoaded) {
                restoreQuestline(questlineWorkspace.activeTab);
                questlineRestorePending = false;
            }
            refreshQuestline();
        }
        else if (name === "calculator")
            { calculatorContent.ensureLoaded(); calculatorContent.item.activate(); }
        else if (name === "search") {
            fileSearchContent.ensureLoaded();
            fileSearchContent.item.activate();
        }
        else if (name === "emoji")
            Qt.callLater(() => query.forceActiveFocus());
        if (name === "emoji")
            emojiDelay.restart();
    }

    function openSpectrumDropSelection(): void {
        spectrumDrop.selectTransport("pc");
        open("spectrumdrop");
        dropContent.ensureLoaded();
        Qt.callLater(() => { if (dropContent.item) dropContent.item.revealSelection(); });
        spectrumDrop.scan();
    }

    function openQuestlineDueItem(taskId, stepId): void {
        open("questline");
        questlineRestorePending = false;
        questlineDueReady = false;
        questlineDueTarget = {taskId: taskId, stepId: stepId};
    }
    function continueQuestlineDueItem(): void {
        if (!questlineDueTarget || !questlineDueReady || !questlineWorkspace.ready) return;
        const target = questlineDueTarget;
        questlineDueTarget = null;
        const task = (questline.tasks || []).find(item => item.id === target.taskId);
        const step = target.stepId ? (questline.steps || []).find(item => item.id === target.stepId && item.parent_task_id === target.taskId && !item.completed) : null;
        if (!questline.available || !task || (target.stepId && !step)) {
            questlineError = qsTranslate("Spectrum", "This due item is no longer available. Refresh the dashboard calendar.");
            return;
        }
        rememberQuestline();
        questlineWorkspace.flush();
        questlineRestoring = true;
        questlineTab = "Tasks";
        syncQuestlineCampaign(task.project_id || "");
        questlineSelected = task;
        questlineStepParent = null;
        questlineStepSelected = null;
        questlineEditing = false;
        questlineDraftKey = "";
        questlineQuickScrollPicker = false;
        questlineDeleteTarget = null;
        questlinePendingId = "";
        questlineError = "";
        questlineMessage = "";
        questlineRestoring = false;
        rememberQuestline();
        if (step) {
            const draft = questlineWorkspace.drafts["Steps:" + step.id];
            if (draft && draft.view) restoreQuestline("Tasks", draft.view);
            else beginQuestlineStepEdit(step);
        } else {
            Qt.callLater(() => { questlineView.questlineDetailFlick.contentY = 0; questlineView.questlineItemList.positionViewAtIndex(questlineItems().findIndex(item => item.id === task.id), ListView.Contain); });
        }
    }

    function openQuestlineNewTask(): void {
        open("questline");
        switchQuestlineTab("Tasks");
        questlinePendingNewTask = true;
        if (questlineLoaded && questlineWorkspace.ready) {
            questlinePendingNewTask = false;
            beginQuestlineEdit(null);
        }
    }

    function openQuestlineNewScroll(): void {
        open("questline");
        questlinePendingNewScroll = true;
        continueQuestlineQuickScroll();
    }
    function continueQuestlineQuickScroll(): void {
        if (!questlinePendingNewScroll || !questlineLoaded || !questlineWorkspace.ready) return;
        if (!questline.available) return;
        questlinePendingNewScroll = false;
        questlineRestorePending = false;
        const projectId = questlineWorkspace.selectedProjectId;
        const campaigns = (questline.campaigns || []).filter(c => !c.is_shared);
        if (projectId && campaigns.some(campaign => campaign.id === projectId)) {
            beginQuestlineQuickScroll(projectId);
        } else {
            switchQuestlineTab("Scrolls");
            questlineQuickScrollPicker = true;
            questlineEditing = false;
            questlineStepParent = null;
            questlineStepSelected = null;
            rememberQuestline();
            Qt.callLater(() => {
                questlineView.quickScrollProjects.currentIndex = 0;
                if (expanded) questlineView.quickScrollProjects.forceActiveFocus();
            });
        }
    }
    function beginQuestlineQuickScroll(projectId): void {
        const campaigns = (questline.campaigns || []).filter(c => !c.is_shared);
        if (!campaigns.some(campaign => campaign.id === projectId)) return;
        switchQuestlineTab("Scrolls");
        questlineQuickScrollPicker = false;
        syncQuestlineCampaign(projectId);
        beginQuestlineEdit(null);
        questlineView.questlineTitle.text = "Quick note · " + Qt.formatDateTime(new Date(),"yyyy-MM-dd HH:mm");
        rememberQuestline();
        Qt.callLater(() => { if (expanded) questlineView.questlineBody.forceActiveFocus(); });
    }

    function openQuestlineFullApp(): void {
        expanded = false;
        ApplicationLaunch.start([backendDir + "/questline-open"]);
    }

    function beginColorPick(): void {
        if (colorPickActive)
            return;
        colorPickActive = true;
        colorPickCount = 0;
        expanded = false;
        if (!colorProcess.running)
            colorPickDelay.restart();
    }

    function saveColor(value): void {
        pendingColor = value;
        if (!colorHistoryProcess.running) {
            colorHistoryProcess.exec([backendDir + "/spectrum-shell-tools", "color-add", pendingColor]);
            pendingColor = "";
        }
    }

    function generatePassword(): void {
        const options = (useLetters ? "l" : "") + (useNumbers ? "n" : "") + (useSymbols ? "s" : "");
        if (options && !passwordProcess.running) {
            requestedPasswordOptions = options;
            requestedPasswordLength = passwordLength;
            passwordProcess.exec([backendDir + "/spectrum-shell-tools", "password", String(passwordLength), options]);
        }
    }

    function refreshQuestline(): void {
        if (!questlineProcess.running)
            questlineProcess.exec([backendDir + "/questline-adapter", "--json"]);
    }

    function questlineItems() {
        if (questlineTab === "Tasks") return questlineTasks.items;
        if (questlineTab === "Scrolls") return (questline.scrolls || []).filter(item => (item.project_id || "") === questlineScrollProjectId);
        if (questlineTab === "Treasury") return questlineTreasury.items;
        if (questlineTab === "Chronicles") return (questline.chronicles || []).filter(item => item.project_id === questlineCampaignId);
        if (questlineTab === "Sidequests") return questline.sidequests || [];
        return [];
    }

    function questlineSteps() {
        return questlineSelected && questlineTab === "Tasks" ? (questline.steps || []).filter(step => step.parent_task_id === questlineSelected.id) : [];
    }

    function questlineProjects() {
        const projects = new Map();
        for (const campaign of questline.campaigns || []) projects.set(campaign.id,{id:campaign.id,name:campaign.name});
        for (const item of (questline.tasks || []).concat(questline.scrolls || [],questline.entries || [],questline.accounts || [],questline.chronicles || [])) {
            const id = item.project_id || item.campaign_id || "";
            if (!projects.has(id)) projects.set(id,{id:id,name:item.campaign || "Unfiled"});
        }
        return Array.from(projects.values()).sort((a,b)=>a.name.localeCompare(b.name));
    }

    function syncQuestlineCampaign(id): void {
        questlineCampaignId = id;
        questlineTreasuryCampaignId = id;
        questlineScrollProjectId = id;
    }

    function selectQuestlineProject(id): void {
        rememberQuestline();
        questlineEditing = false;
        questlineDraftKey = "";
        syncQuestlineCampaign(id);
        questlineWorkspace.selectedProjectId = id;
        if (questlineTab === "Focus") {
            questlineView.questlineFocusEditor.projectId = id;
            questlineView.questlineFocusEditor.taskId = "";
        }
        questlineSelected = null;
        questlineStepParent = null;
        questlineStepSelected = null;
        questlineDeleteTarget = null;
        questlinePendingId = "";
        questlineError = "";
        questlineMessage = "";
        selectQuestlineItem();
        rememberQuestline();
        if (id) Quickshell.execDetached([backendDir + "/spectrum-shell-tools", "questline-campaign", id]);
    }

    function selectQuestlineTaskProject(id): void { selectQuestlineProject(id); }
    function selectQuestlineTreasuryProject(id): void { selectQuestlineProject(id); }
    function selectQuestlineScrollProject(id): void { selectQuestlineProject(id); }

    function selectQuestlineItem(): void {
        const items = questlineItems();
        const previousId = questlinePendingId || (questlineSelected ? questlineSelected.id : "");
        questlineSelected = items.find(item => item.id === previousId) || items[0] || null;
        questlinePendingId = "";
    }

    function beginQuestlineEdit(item): void {
        questlineContent.ensureLoaded();
        const draft = item ? questlineWorkspace.drafts[questlineTab + ":" + item.id] : null;
        if (draft && draft.view && (!draft.valid || draft.error || draft.saved !== JSON.stringify(draft.payload))) {
            restoreQuestline(questlineTab,draft.view);
            return;
        }
        rememberQuestline();
        questlineRestoring = true;
        questlineDraftKey = questlineTab + ":" + (item ? item.id : "new-" + Date.now() + "-" + Math.random().toString(36).slice(2));
        questlineStepParent = null;
        questlineStepSelected = null;
        questlineDeleteTarget = null;
        questlineSelected = item;
        questlineEditing = true;
        questlineCalendarOpen = false;
        questlineError = "";
        questlineView.questlineTitle.text = item ? item.title : questlineTab === "Chronicles" ? Qt.formatDate(new Date(), "yyyy-MM-dd") : "";
        questlineView.questlineBody.text = item ? (questlineTab === "Scrolls" ? item.markdown_content : item.description || "") : "";
        questlineView.questlineDate.text = item && item.due_date ? item.due_date : "";
        questlineTaskPriority = item && item.priority ? item.priority : "Medium";
        questlineTaskRecurrence = item && item.recurrence ? item.recurrence : "None";
        questlineView.questlineAmount.text = item && item.amount_minor ? (item.amount_minor / 100).toFixed(2) : "";
        questlineSidequestFrequency = item && item.frequency ? item.frequency : "Daily";
        questlineSidequestReward = item && item.reward_xp !== undefined ? item.reward_xp : 20;
        questlineEntryType = item && item.entry_type ? item.entry_type : "Expense";
        questlineEntryStatus = item && item.status ? item.status : "Planned";
        questlineEntryFields = loadQuestlineEntryFields(item);
        const campaigns = (questline.campaigns || []).filter(c => !c.is_shared);
        const campaignId = item ? (item.project_id || item.campaign_id) : questlineTab === "Scrolls" ? questlineScrollProjectId : questlineTab === "Treasury" ? questlineTreasuryCampaignId : questlineCampaignId;
        questlineCampaignIndex = Math.max(0, campaigns.findIndex(c => c.id === campaignId));
        questlineEditCampaignId = campaigns.length ? campaigns[questlineCampaignIndex].id : "";
        if (["Tasks","Scrolls","Treasury","Chronicles"].includes(questlineTab)) syncQuestlineCampaign(item ? campaignId || "" : questlineEditCampaignId);
        questlineRestoring = false;
        rememberQuestline(!!item);
        if (questlineTab === "Chronicles") Qt.callLater(() => questlineView.questlineBody.forceActiveFocus());
    }

    function beginQuestlineStepEdit(step): void {
        questlineContent.ensureLoaded();
        if (!questlineSelected)
            return;
        rememberQuestline();
        questlineRestoring = true;
        questlineDraftKey = "Steps:" + (step ? step.id : "new-" + Date.now() + "-" + Math.random().toString(36).slice(2));
        questlineDeleteTarget = null;
        questlineStepParent = questlineSelected;
        questlineStepSelected = step;
        questlineEditing = true;
        questlineCalendarOpen = false;
        questlineError = "";
        questlineView.questlineTitle.text = step ? step.title : "";
        questlineView.questlineBody.text = step ? step.description || "" : "";
        questlineView.questlineDate.text = step && step.due_date ? step.due_date : "";
        questlineTaskPriority = step && step.priority ? step.priority : "Medium";
        questlineTaskRecurrence = "None";
        questlineRestoring = false;
        rememberQuestline(!!step);
        Qt.callLater(() => questlineView.questlineTitle.forceActiveFocus());
    }

    function questlineEntryDetails(entry): string {
        if (!entry) return "";
        const accountName = id => ((questline.accounts || []).find(item => item.id === id) || {}).name || qsTranslate("Spectrum", "Default account");
        const categoryName = ((questline.categories || []).find(item => item.id === entry.category_id) || {}).name || qsTranslate("Spectrum", "Default category");
        const lines = [qsTranslate("Spectrum", entry.entry_type) + " · " + qsTranslate("Spectrum", entry.status),
            entry.currency_code + " " + (entry.amount_minor / 100).toFixed(2),
            qsTranslate("Spectrum", "Campaign: ") + entry.campaign, qsTranslate("Spectrum", "Account: ") + accountName(entry.account_id), qsTranslate("Spectrum", "Category: ") + categoryName];
        if (entry.transfer_account_id) lines.push(qsTranslate("Spectrum", "To account: ") + accountName(entry.transfer_account_id));
        for (const [key,label] of [["created_at","Entry date"],["due_date","Due date"],["payment_date","Payment date"],
                                  ["vendor_source","Vendor / source"],["description","Description"],["notes","Notes"],
                                  ["attachment_ref","Attachment"],["recurrence","Recurrence"],["custom_recurrence","Schedule"]])
            if (entry[key] && entry[key] !== "None") lines.push(qsTranslate("Spectrum", label) + ": " + (key.endsWith("date") || key === "created_at" ? entry[key].slice(0,10) : entry[key]));
        return lines.join("\n");
    }
    property var questlineEntryFields: ({})
    function questlineLegacyAccountIds() {
        if (!questlineSelected) return [];
        const entry = (questline.entries || []).find(item => item.id === questlineSelected.id) || questlineSelected;
        const implicit = (questline.accounts || []).find(item => item.campaign_id === entry.campaign_id && item.is_default && item.name === "Spending");
        return [entry.account_id || (implicit || {}).id, entry.transfer_account_id].filter(Boolean);
    }
    function loadQuestlineEntryFields(item) {
        const fields = {};
        for (const name of ["account_id","category_id","transfer_account_id","related_task_id",
                            "description","vendor_source","notes","attachment_ref","custom_recurrence"])
            fields[name] = item && item[name] ? item[name] : "";
        for (const name of ["due_date","payment_date"])
            fields[name] = item && item[name] ? item[name].slice(0,10) : "";
        fields.entry_date = item && item.created_at ? item.created_at.slice(0,10) : Qt.formatDate(new Date(),"yyyy-MM-dd");
        fields.recurrence = item && item.recurrence ? item.recurrence : "None";
        if (item && !fields.account_id) {
            const implicit = (questline.accounts || []).find(account => account.campaign_id === item.campaign_id && account.is_default && account.name === "Spending");
            if (implicit) fields.account_id = implicit.id;
        }
        return fields;
    }
    property string questlineEntryType: "Expense"
    property string questlineEntryStatus: "Planned"
    function setQuestlineDate(offset): void {
        const date = new Date();
        date.setHours(12, 0, 0, 0);
        date.setDate(date.getDate() + offset);
        questlineView.questlineDate.text = Qt.formatDate(date, "yyyy-MM-dd");
        questlineCalendarOpen = false;
    }

    function selectQuestlineCampaign(id = ""): void {
        const campaigns = (questline.campaigns || []).filter(c => !c.is_shared);
        if (!campaigns.length) return;
        const index = id ? campaigns.findIndex(c => c.id === id) : (questlineCampaignIndex + 1) % campaigns.length;
        if (index < 0) return;
        questlineCampaignIndex = index;
        questlineEditCampaignId = campaigns[questlineCampaignIndex].id;
        if (questlineTab === "Treasury") questlineEntryFields = Object.assign({},questlineEntryFields,{account_id:"",category_id:"",transfer_account_id:"",related_task_id:""});
        syncQuestlineCampaign(questlineEditCampaignId);
        rememberQuestline();
        if (questlineEditCampaignId) Quickshell.execDetached([backendDir + "/spectrum-shell-tools", "questline-campaign", questlineEditCampaignId]);
    }

    function questlineDraftPayload() {
        const kind = questlineStepParent ? "step" : questlineTab === "Tasks" ? "task"
            : questlineTab === "Chronicles" ? "chronicle" : questlineTab === "Scrolls" ? "scroll" : questlineTab === "Sidequests" ? "sidequest" : "entry";
        const selected = questlineStepParent ? questlineStepSelected : questlineSelected;
        const payload = {action:(selected ? "update_" : "create_") + kind,title:questlineView.questlineTitle.text.trim()};
        let reason = "";
        if (selected) payload.id = selected.id;
        else if (kind === "step") payload.parent_id = questlineStepParent.id;
        else if (kind !== "sidequest") {
            const campaigns = (questline.campaigns || []).filter(c => !c.is_shared);
            const campaign = campaigns.find(item => item.id === questlineEditCampaignId);
            if (!campaign) reason = "Choose an active campaign.";
            else payload.project_id = campaign.id;
        }
        if (!payload.title || payload.title.length > 200) reason = "Enter a title of 1–200 characters.";
        if (kind === "task" || kind === "step") {
            payload.description = questlineView.questlineBody.text;
            payload.due_date = questlineView.questlineDate.text.trim();
            payload.priority = questlineTaskPriority;
            if (kind === "task") {
                payload.recurrence = questlineTaskRecurrence;
                if (!questline.task_recurrence_available && (payload.recurrence !== "None" || (selected && selected.recurrence)))
                    reason = "Update Questline to save task recurrence.";
            }
            const date = new Date(payload.due_date + "T12:00:00");
            if (payload.due_date && (!/^\d{4}-\d{2}-\d{2}$/.test(payload.due_date)
                || Number.isNaN(date.getTime()) || Qt.formatDate(date,"yyyy-MM-dd") !== payload.due_date)) reason = "Enter a valid date as YYYY-MM-DD.";
        } else if (kind === "scroll") {
            payload.content = questlineView.questlineBody.text;
            if (!payload.content.trim() || payload.content.trim().length > 100000) reason = "Add scroll content (up to 100,000 characters).";
        } else if (kind === "chronicle") {
            payload.content = questlineView.questlineBody.text;
            if (!payload.content.trim() || Array.from(payload.content.trim()).length > 255) reason = "Add chronicle content (up to 255 characters).";
        } else if (kind === "sidequest") {
            payload.description = questlineView.questlineBody.text;
            payload.frequency = questlineSidequestFrequency;
            payload.reward_xp = questlineSidequestReward;
        } else {
            payload.amount_minor = Math.round(Number(questlineView.questlineAmount.text) * 100);
            payload.entry_type = questlineEntryType;
            payload.status = questlineEntryStatus;
            Object.assign(payload, questlineEntryFields);
            payload.custom_accounts_only = true;
            if (!questline.treasury_fields_available) reason = "Update Questline to save the complete Treasury form.";
            const campaignId = selected && selected.campaign_id ? selected.campaign_id : questlineEditCampaignId;
            const accounts = (questline.accounts || []).filter(item => item.campaign_id === campaignId && (!item.is_default || questlineLegacyAccountIds().includes(item.id)));
            const categories = (questline.categories || []).filter(item => item.campaign_id === campaignId && item.entry_type === questlineEntryType);
            if (!payload.account_id || !accounts.some(item => item.id === payload.account_id)) reason = "Choose a user-created account in this campaign. Create one in Questline if the list is empty.";
            if (payload.category_id && !categories.some(item => item.id === payload.category_id)) reason = "Choose a category matching this campaign and entry type.";
            if (questlineEntryType === "Transfer" && (!payload.transfer_account_id || payload.transfer_account_id === (payload.account_id || (accounts[0] || {}).id)
                || !accounts.some(item => item.id === payload.transfer_account_id))) reason = "Choose a different destination account for the transfer.";
            if (questlineEntryType !== "Transfer") payload.transfer_account_id = "";
            if (payload.related_task_id && !(questline.tasks || []).some(item => item.id === payload.related_task_id && item.project_id === campaignId)) reason = "Choose a related task in this campaign.";
            for (const name of ["entry_date","due_date","payment_date"]) {
                const value = payload[name] || "";
                const date = new Date(value + "T12:00:00");
                if ((name === "entry_date" && !value) || (value && (!/^\d{4}-\d{2}-\d{2}$/.test(value) || Number.isNaN(date.getTime())
                    || Qt.formatDate(date,"yyyy-MM-dd") !== value))) reason = "Enter valid dates as YYYY-MM-DD.";
            }
            if (payload.recurrence === "Custom" && !(payload.custom_recurrence || "").trim()) reason = "Describe the custom recurrence.";
            if (!/^\d+(\.\d{1,2})?$/.test(questlineView.questlineAmount.text.trim()) || !Number.isSafeInteger(payload.amount_minor)
                || payload.amount_minor <= 0) reason = "Enter a positive amount with up to two decimals.";
        }
        return {payload:payload,valid:!reason,reason:reason};
    }

    function rememberQuestline(initial = false): void {
        if (!questlineContent.item || questlineRestoring || !questlineWorkspace.ready || !questlineLoaded) return;
        if (questlineEditing && questlineDraftKey) {
            const draft = questlineDraftPayload();
            questlineWorkspace.update(questlineDraftKey,draft.payload,draft.valid,draft.reason,initial);
        }
        const view = {selected:questlineSelected,editing:questlineEditing,key:questlineDraftKey,quickScrollPicker:questlineQuickScrollPicker,
            stepParent:questlineStepParent,stepSelected:questlineStepSelected,campaignId:questlineCampaignId,
            treasuryCampaignId:questlineTreasuryCampaignId,scrollProjectId:questlineScrollProjectId,
            campaignIndex:questlineCampaignIndex,editCampaignId:questlineEditCampaignId,title:questlineView.questlineTitle.text,body:questlineView.questlineBody.text,
            date:questlineView.questlineDate.text,taskPriority:questlineTaskPriority,taskRecurrence:questlineTaskRecurrence,amount:questlineView.questlineAmount.text,frequency:questlineSidequestFrequency,
            reward:questlineSidequestReward,entryType:questlineEntryType,entryStatus:questlineEntryStatus,entryFields:questlineEntryFields,
            titleCursor:questlineView.questlineTitle.cursorPosition,bodyCursor:questlineView.questlineBody.cursorPosition,
            editorScroll:questlineView.questlineEditorFlick.contentY,listScroll:questlineView.questlineItemList.contentY,detailScroll:questlineView.questlineDetailFlick.contentY,
            focus:{projectId:questlineView.questlineFocusEditor.projectId,taskId:questlineView.questlineFocusEditor.taskId,
                duration:questlineView.questlineFocusEditor.duration,soundscape:questlineView.questlineFocusEditor.soundscape}};
        questlineWorkspace.remember(questlineTab,view);
        if (questlineEditing && questlineDraftKey) questlineWorkspace.keepDraftView(questlineDraftKey,questlineTab,view);
    }

    function queueQuestlineState(): void {
        if (questlineContent.item && !questlineRestoring && page === "questline" && expanded) questlineRememberDelay.restart();
    }
    function restoreQuestline(tab, suppliedView = null): void {
        if (!questlineContent.item || !questlineWorkspace.ready) return;
        questlineRestoring = true;
        questlineTab = ["Overview","Tasks","Scrolls","Treasury","Chronicles","Tree","Focus","Hero","Sidequests","Sync"].includes(tab) ? tab : "Overview";
        let view = suppliedView || questlineWorkspace.views[questlineTab] || {};
        const campaignTab = ["Tasks","Scrolls","Treasury","Chronicles"].includes(questlineTab);
        if (campaignTab) {
            const projects = questlineProjects();
            const requested = suppliedView ? questlineWorkspace.projectForView(questlineTab,view) : questlineWorkspace.selectedProjectId;
            const project = projects.find(c=>c.id===requested) || projects.find(c=>c.id===questlineCampaignId) || projects[0] || {id:""};
            if (!suppliedView && questlineWorkspace.projectForView(questlineTab,view)!==project.id) view = {};
            syncQuestlineCampaign(project.id);
        }
        questlineSelected = view.selected || null;
        questlineQuickScrollPicker = !!view.quickScrollPicker;
        questlineEditing = !!view.editing;
        questlineDraftKey = view.key || "";
        questlineStepParent = view.stepParent || null;
        questlineStepSelected = view.stepSelected || null;
        const draft = questlineWorkspace.drafts[questlineDraftKey];
        if (draft && draft.payload.id) {
            if (questlineStepParent) questlineStepSelected = Object.assign({},questlineStepSelected || {},{id:draft.payload.id});
            else questlineSelected = Object.assign({},questlineSelected || {},{id:draft.payload.id});
        }
        questlineDeleteTarget = null;
        questlineEditCampaignId = (draft && draft.payload.project_id) || view.editCampaignId || "";
        const campaigns = (questline.campaigns || []).filter(c => !c.is_shared);
        questlineCampaignIndex = Math.max(0,campaigns.findIndex(item => item.id === questlineEditCampaignId));
        questlineView.questlineTitle.text = view.title || "";
        questlineView.questlineBody.text = view.body || "";
        questlineView.questlineDate.text = view.date || "";
        const task = questlineStepParent ? questlineStepSelected : questlineSelected;
        questlineTaskPriority = view.taskPriority || (draft && draft.payload.priority) || (task && task.priority) || "Medium";
        questlineTaskRecurrence = view.taskRecurrence || (draft && draft.payload.recurrence) || (task && task.recurrence) || "None";
        questlineView.questlineAmount.text = view.amount || "";
        questlineSidequestFrequency = view.frequency || "Daily";
        questlineSidequestReward = view.reward === undefined ? 20 : view.reward;
        questlineEntryType = view.entryType || "Expense";
        questlineEntryStatus = view.entryStatus || "Planned";
        questlineEntryFields = view.entryFields || loadQuestlineEntryFields((questline.entries || []).find(item => questlineSelected && item.id === questlineSelected.id) || questlineSelected);
        if (view.focus && !questlineView.questlineFocusEditor.active) {
            questlineView.questlineFocusEditor.projectId = view.focus.projectId || "";
            questlineView.questlineFocusEditor.taskId = view.focus.taskId || "";
            questlineView.questlineFocusEditor.duration = view.focus.duration || 25;
            questlineView.questlineFocusEditor.soundscape = view.focus.soundscape || "Silent";
        }
        if (!questlineEditing) selectQuestlineItem();
        questlineRestoring = false;
        Qt.callLater(() => {
            if (panel.questlineTab !== tab || panel.questlineDraftKey !== (view.key || "")) return;
            questlineRestoring = true;
            questlineView.questlineTitle.cursorPosition = Math.min(view.titleCursor || 0,questlineView.questlineTitle.length);
            questlineView.questlineBody.cursorPosition = Math.min(view.bodyCursor || 0,questlineView.questlineBody.length);
            questlineView.questlineEditorFlick.contentY = Math.max(0,Math.min(view.editorScroll || 0,questlineView.questlineEditorFlick.contentHeight - questlineView.questlineEditorFlick.height));
            questlineView.questlineItemList.contentY = view.listScroll || 0;
            questlineView.questlineDetailFlick.contentY = view.detailScroll || 0;
            questlineRestoring = false;
            rememberQuestline();
        });
    }
    function switchQuestlineTab(tab): void {
        questlineContent.ensureLoaded();
        rememberQuestline();
        questlineWorkspace.flush();
        restoreQuestline(tab);
        questlineError = "";
        questlineMessage = "";
        rememberQuestline();
    }
    function leaveQuestlineEditor(): void {
        rememberQuestline();
        questlineWorkspace.flush();
        questlineEditing = false;
        questlineStepParent = null;
        questlineStepSelected = null;
        selectQuestlineItem();
        rememberQuestline();
    }
    Timer { id: questlineRememberDelay; interval: 80; onTriggered: panel.rememberQuestline() }
    onExpandedChanged: {
        if (!expanded) {
            pendingFocusPage = "";
            if (page === "questline") { rememberQuestline(); questlineWorkspace.flush(); }
        }
    }
    onQuestlineSelectedChanged: queueQuestlineState()
    onQuestlineSidequestFrequencyChanged: queueQuestlineState()
    onQuestlineSidequestRewardChanged: queueQuestlineState()
    onQuestlineTaskPriorityChanged: queueQuestlineState()
    onQuestlineTaskRecurrenceChanged: queueQuestlineState()
    onQuestlineEntryFieldsChanged: queueQuestlineState()
    onQuestlineEntryTypeChanged: {
        if (!questlineRestoring) questlineEntryFields = Object.assign({},questlineEntryFields,{category_id:"",transfer_account_id:""});
        queueQuestlineState();
    }
    onQuestlineEntryStatusChanged: queueQuestlineState()
    onQuestlineCampaignIndexChanged: queueQuestlineState()
    onQuestlineEditCampaignIdChanged: queueQuestlineState()
    Connections {
        target: panel.questlineWorkspace
        function onReadyChanged() {
            if(panel.questlineWorkspace.ready && panel.questline.profile_key)panel.questlineWorkspace.bindProfile(panel.questline.profile_key);
            if (panel.questlineDueTarget) { panel.continueQuestlineDueItem(); return; }
            if (panel.questlinePendingNewScroll) { panel.continueQuestlineQuickScroll(); return; }
            if (panel.questlineWorkspace.ready && panel.questlineLoaded && panel.questlineRestorePending) {
                panel.restoreQuestline(panel.questlineWorkspace.activeTab);
                panel.questlineRestorePending = false;
            }
        }
        function onProfileChanged() {
            panel.questlineRestoring=true;
            panel.questlineEditing=false;panel.questlineSelected=null;panel.questlineStepParent=null;panel.questlineStepSelected=null;
            panel.questlineDraftKey="";panel.questlineDeleteTarget=null;panel.questlineQuickScrollPicker=false;panel.questlineTab="Sync";
            panel.questlineRestoring=false;panel.refreshQuestline();
        }
        function onSaved(key, id) {
            if (panel.questlineDraftKey === key && panel.questlineEditing && panel.expanded && panel.page === "questline" && id) {
                if (panel.questlineStepParent) panel.questlineStepSelected = Object.assign({},panel.questlineStepSelected || {},{id:id});
                else panel.questlineSelected = Object.assign({},panel.questlineSelected || {},{id:id});
                const draft = panel.questlineWorkspace.drafts[key];
                if (draft && draft.payload.project_id) panel.syncQuestlineCampaign(draft.payload.project_id);
                panel.rememberQuestline();
            }
            panel.refreshQuestline();
        }
    }

    signal questlineCompleted()
    property bool questlineCompletionPending: false

    function runQuestlineAction(payload): void {
        if(questlineWorkspace.externalActions>0 || questlineWorkspace.blocked){questlineError=qsTranslate("Spectrum", "Wait for the current operation to finish.");return;}
        if(questline.profile_key)payload.profile_key=questline.profile_key;
        if (!questlineActionProcess.running && !panel.questlineWorkspace.busy) {
            questlineError = "";
            const step = (questline.steps || []).find(item => item.id === payload.id);
            questlineCompletionPending = payload.action === "complete_task" || payload.action === "complete_sidequest"
                || (payload.action === "toggle_step" && !!step && !step.completed);
            questlineWorkspace.externalActions += 1;
            questlineActionProcess.exec([backendDir + "/questline-action", JSON.stringify(payload)]);
        }
    }

    function askQuestlineDelete(kind, item): void {
        if (!item || questlineActionProcess.running)
            return;
        questlineDeleteTarget = {
            kind: kind,
            id: item.id,
            title: item.title,
            stepCount: kind === "task" ? (questline.steps || []).filter(step => step.parent_task_id === item.id).length : 0
        };
    }

    function confirmQuestlineDelete(): void {
        if (questlineDeleteTarget)
            runQuestlineAction({ action: "delete_" + questlineDeleteTarget.kind, id: questlineDeleteTarget.id });
    }

    Process {
        id: questlineCampaignProcess
        stdout: StdioCollector { onStreamFinished: {
            const saved = text.trim();
            if (!panel.questlineCampaignId && saved) {
                panel.syncQuestlineCampaign(saved);
                if (panel.questlineEditing && !panel.questlineSelected && panel.questlineTab === "Tasks") {
                    const campaigns = (panel.questline.campaigns || []).filter(c => !c.is_shared);
                    panel.questlineCampaignIndex = Math.max(0, campaigns.findIndex(c => c.id === saved));
                }
            }
        } }
    }

    Process {
        id: questlineActionProcess
        onExited: panel.questlineWorkspace.externalActions = Math.max(0,panel.questlineWorkspace.externalActions - 1)
        stdout: StdioCollector { onStreamFinished: {
            try {
                const result = JSON.parse(text);
                panel.questlineError = result.error || "";
                panel.questlineMessage = result.message || "";
                if (!result.error) {
                    if (panel.questlineCompletionPending && result.id)
                        panel.questlineCompleted();
                    if (panel.questlineDeleteTarget) panel.questlineWorkspace.forget(panel.questlineDeleteTarget.id);
                    panel.questlineEditing = false;
                    panel.questlineSelected = null;
                    panel.questlinePendingId = panel.questlineStepParent ? panel.questlineStepParent.id : result.id || "";
                    panel.questlineStepParent = null;
                    panel.questlineStepSelected = null;
                    panel.questlineDeleteTarget = null;
                    panel.rememberQuestline();
                    panel.refreshQuestline();
                }
            } catch (error) { panel.questlineError = qsTranslate("Spectrum", "Questline action failed."); }
            panel.questlineCompletionPending = false;
        } }
    }

    Process {
        id: questlineProcess
        stdout: StdioCollector { onStreamFinished: {
            try {
                panel.questline = JSON.parse(text);
                if(panel.questline.profile_key)panel.questlineWorkspace.bindProfile(panel.questline.profile_key);
                panel.questlineLoaded = true;
                const projects = panel.questlineProjects();
                const project = projects.find(c=>c.id===panel.questlineWorkspace.selectedProjectId) || projects.find(c=>c.id===panel.questlineCampaignId) || projects[0] || {id:""};
                if (!panel.questlineEditing) panel.syncQuestlineCampaign(project.id);
                if (panel.questlineDueTarget) {
                    panel.questlineDueReady = true;
                    panel.continueQuestlineDueItem();
                } else if (!panel.questline.available)
                    panel.questlineEditing = false;
                else if (panel.questlinePendingNewScroll) {
                    panel.continueQuestlineQuickScroll();
                }
                else if (panel.questlinePendingNewTask) {
                    panel.questlinePendingNewTask = false;
                    panel.beginQuestlineEdit(null);
                    Qt.callLater(() => questlineView.questlineTitle.forceActiveFocus());
                } else if (panel.questlineRestorePending && panel.questlineWorkspace.ready) {
                    panel.restoreQuestline(panel.questlineWorkspace.activeTab);
                    panel.questlineRestorePending = false;
                } else if (!panel.questlineEditing)
                    panel.selectQuestlineItem();
            }
            catch (error) {
                panel.questline = { available: false, installed: false, error: qsTranslate("Spectrum", "Could not read Questline status.") };
                panel.questlineLoaded = true;
                panel.questlineDueReady = true;
                panel.continueQuestlineDueItem();
            }
        } }
    }

    Timer {
        interval: 30000
        running: panel.expanded && panel.page === "questline"
        repeat: true
        onTriggered: panel.refreshQuestline()
    }

    Process {
        id: passwordProcess
        stdout: StdioCollector { onStreamFinished: {
            const options = (panel.useLetters ? "l" : "") + (panel.useNumbers ? "n" : "") + (panel.useSymbols ? "s" : "");
            if (options === panel.requestedPasswordOptions && panel.passwordLength === panel.requestedPasswordLength)
                panel.password = text.trim();
        } }
        onExited: {
            const options = (panel.useLetters ? "l" : "") + (panel.useNumbers ? "n" : "") + (panel.useSymbols ? "s" : "");
            if (panel.page === "password" && (options !== panel.requestedPasswordOptions || panel.passwordLength !== panel.requestedPasswordLength))
                Qt.callLater(() => panel.generatePassword());
        }
    }

    Timer {
        id: emojiDelay
        interval: 240
        onTriggered: {
            if (panel.page === "emoji" && !emojiProcess.running) {
                panel.submittedEmojiQuery = query.text;
                emojiProcess.exec([panel.backendDir + "/spectrum-shell-tools", "emoji", query.text]);
            }
        }
    }

    Process {
        id: emojiProcess
        stdout: StdioCollector { onStreamFinished: {
            if (panel.submittedEmojiQuery !== query.text || panel.page !== "emoji")
                return;
            try { panel.emojis = JSON.parse(text); }
            catch (error) { panel.emojis = []; }
            panel.emojiSelectedIndex = 0;
            if (panel.emojis.length)
                Qt.callLater(() => emojiList.positionViewAtBeginning());
        } }
        onExited: {
            if (panel.expanded && panel.page === "emoji" && panel.submittedEmojiQuery !== query.text)
                emojiDelay.restart();
        }
    }

    Timer {
        id: colorPickDelay
        interval: panel.colorPickCount === 0 ? 380 : 180
        onTriggered: {
            if (panel.colorPickActive && !colorProcess.running) {
                panel.colorPickedThisRun = false;
                colorProcess.exec(["hyprpicker", "-r"]);
            }
        }
    }

    Process {
        id: colorProcess
        stdout: StdioCollector { onStreamFinished: {
            const value = text.trim();
            if (/^#[0-9A-Fa-f]{6}$/.test(value)) {
                panel.colorValue = value.toUpperCase();
                panel.saveColor(panel.colorValue);
                panel.colorPickedThisRun = true;
            }
        } }
        onExited: Qt.callLater(() => {
            if (panel.colorPickActive && panel.colorPickedThisRun) {
                panel.colorPickCount += 1;
                colorPickDelay.restart();
            } else {
                panel.colorPickActive = false;
                panel.open("color");
            }
        })
    }

    Process {
        id: colorHistoryProcess
        stdout: StdioCollector { onStreamFinished: {
            try {
                panel.savedColors = JSON.parse(text);
                if (panel.savedColors.length && !panel.colorValue)
                    panel.colorValue = panel.savedColors[0];
            } catch (error) {
                console.warn("SpectrumShell saved colors:", error);
            }
        } }
        onExited: {
            if (panel.pendingColor) {
                const value = panel.pendingColor;
                panel.pendingColor = "";
                Qt.callLater(() => colorHistoryProcess.exec([panel.backendDir + "/spectrum-shell-tools", "color-add", value]));
            }
        }
    }

    QtObject {
        id: spectrumDrop
        objectName: "spectrumdrop-state"
        property string transport: "pc"
        property string pendingTransport: ""
        property bool awaitingChooser: false
        property var pendingAfterScan: []
        property var pendingAfterScanPayload: ({})
        property var state: ({available: true, receiving: false, transfer: {}, lan: {receiving: false, incoming: []}})
        property var peers: []
        property string error: ""
        property var requested: []
        property var inputPayload: ({})
        property var pendingPayload: ({})
        readonly property bool busy: (spectrumDropProcess.running && !["status", "status-lan"].includes(requested[0])) || pending.length > 0 || pendingAfterScan.length > 0
        property var pending: []
        readonly property bool scanning: spectrumDropScan.running
        function selectTransport(value) {
            if (!["pc", "airdrop"].includes(value) || busy || state.transfer?.active) return;
            if (scanning) {
                pendingTransport = value;
                spectrumDropScan.signal(15);
                return;
            }
            transport = value;
            peers = [];
            error = "";
            command(["status"]);
        }
        function command(args, payload) {
            if (busy) return;
            if (args[0] === "status" && transport === "pc") args = ["status-lan"];
            const sending = args[0] === "send" || args[0] === "send-lan";
            if (spectrumDropProcess.running) {
                if (!["status", "status-lan"].includes(args[0])) { pending = args; pendingPayload = payload || {}; }
                return;
            }
            if (sending && scanning) {
                pendingAfterScan = args;
                pendingAfterScanPayload = payload || {};
                spectrumDropScan.signal(15);
                return;
            }
            requested = args;
            inputPayload = payload || {};
            if (sending) awaitingChooser = !(state.selection?.count > 0);
            if (!["status", "status-lan"].includes(args[0])) error = "";
            spectrumDropProcess.exec([panel.backendDir + "/spectrumdrop-adapter"].concat(args));
            if ((sending && awaitingChooser) || args[0] === "folder") panel.expanded = false;
        }
        function scan() {
            if (scanning || busy || awaitingChooser || (transport === "airdrop" && !state.visible) || state.transfer?.active) return;
            spectrumDropScan.exec([panel.backendDir + "/spectrumdrop-adapter", transport === "pc" ? "scan-lan" : "scan"]);
        }
    }
    Process {
        id: spectrumDropProcess
        stdinEnabled: true
        onStarted: {
            write(JSON.stringify(spectrumDrop.inputPayload) + "\n");
            spectrumDrop.inputPayload = {};
        }
        onExited: {
            if (spectrumDrop.pending.length) {
                Qt.callLater(() => {
                    const next = spectrumDrop.pending, payload = spectrumDrop.pendingPayload;
                    spectrumDrop.pending = []; spectrumDrop.pendingPayload = {};
                    spectrumDrop.command(next, payload);
                });
                return;
            }
            if (panel.expanded && panel.page === "spectrumdrop" && ["receive", "receive-lan"].includes(spectrumDrop.requested[0]))
                Qt.callLater(() => spectrumDrop.scan());
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    if (!result.ok) {
                        spectrumDrop.error = result.error;
                        spectrumDrop.awaitingChooser = false;
                        if (["send", "send-lan", "folder"].includes(spectrumDrop.requested[0])) panel.expanded = true;
                        return;
                    }
                    if (spectrumDrop.requested[0] === "folder") panel.expanded = true;
                    spectrumDrop.state = result;
                    if (spectrumDrop.awaitingChooser && result.transfer?.phase && result.transfer.phase !== "choosing") {
                        spectrumDrop.awaitingChooser = false;
                        if (panel.page === "spectrumdrop" && !panel.expanded) panel.spectrumDropReturnRequested();
                    }
                    if (!["status", "status-lan"].includes(spectrumDrop.requested[0])) spectrumDrop.error = "";
                    if (spectrumDrop.transport === "airdrop" && !result.visible && spectrumDrop.peers.length) spectrumDrop.peers = [];
                } catch (error) { spectrumDrop.error = qsTranslate("Spectrum", "SpectrumDrop returned an invalid response."); }
            }
        }
    }
    Process {
        id: spectrumDropScan
        onExited: {
            if (spectrumDrop.pendingAfterScan.length) Qt.callLater(() => {
                const next = spectrumDrop.pendingAfterScan, payload = spectrumDrop.pendingAfterScanPayload;
                spectrumDrop.pendingAfterScan = []; spectrumDrop.pendingAfterScanPayload = {};
                spectrumDrop.command(next, payload);
            });
            else if (spectrumDrop.pendingTransport) Qt.callLater(() => {
                const next = spectrumDrop.pendingTransport;
                spectrumDrop.pendingTransport = "";
                spectrumDrop.selectTransport(next);
            });
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (spectrumDrop.pendingAfterScan.length || spectrumDrop.pendingTransport) return;
                try {
                    const result = JSON.parse(text);
                    if (result.ok && (spectrumDrop.transport === "pc" || spectrumDrop.state.visible)) {
                        if (JSON.stringify(spectrumDrop.peers) !== JSON.stringify(result.peers)) spectrumDrop.peers = result.peers;
                        spectrumDrop.error = result.warning || "";
                    }
                    else if (!result.ok) spectrumDrop.error = result.error;
                } catch (error) { spectrumDrop.error = qsTranslate("Spectrum", "Device search returned an invalid response."); }
            }
        }
    }
    Timer { interval: 2000; repeat: true; running: (panel.expanded && panel.page === "spectrumdrop") || spectrumDrop.awaitingChooser; onTriggered: spectrumDrop.command(["status"]) }
    Timer { interval: 15000; repeat: true; running: panel.expanded && panel.page === "spectrumdrop" && (spectrumDrop.transport === "pc" || !!spectrumDrop.state.visible); onTriggered: spectrumDrop.scan() }

    QtObject {
        id: hotkeys
        objectName: "hotkey-state"
        property var rules: []
        property var diagnostics: ({})
        property string error: ""
        readonly property bool busy: (hotkeyProcess.running && requested[0] !== "status") || pending.length > 0
        property var pending: []
        property var requested: []
        function command(args) {
            if (busy) return;
            if (hotkeyProcess.running) {
                if (args[0] !== "status") pending = args;
                return;
            }
            requested = args;
            if (args[0] !== "status") error = "";
            hotkeyProcess.exec([panel.backendDir + "/hotkey-adapter"].concat(args));
        }
    }
    Process {
        id: hotkeyProcess
        onExited: if (hotkeys.pending.length) Qt.callLater(() => {
            const next = hotkeys.pending; hotkeys.pending = []; hotkeys.command(next);
        })
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    if (!result.ok) { hotkeys.error = result.error || "HotKey operation failed."; return; }
                    if (JSON.stringify(hotkeys.rules) !== JSON.stringify(result.rules)) hotkeys.rules = result.rules;
                    hotkeys.diagnostics = result.diagnostics || {};
                    if (hotkeys.requested[0] === "save" && hotkeyContent.item) hotkeyContent.item.clearForm();
                    if (hotkeys.requested[0] === "toggle" && result.rules.some(rule => rule.id === hotkeys.requested[1] && rule.active)) panel.expanded = false;
                } catch (error) { hotkeys.error = qsTranslate("Spectrum", "HotKey service returned an invalid response."); }
            }
        }
    }
    Timer { interval: 1000; repeat: true; running: panel.expanded && panel.page === "hotkey"; onTriggered: hotkeys.command(["status"]) }

    MouseArea {
        anchors.fill: parent
        onClicked: panel.expanded = false
    }

    ShellSurface {
        id: frame
        enabled: !panel.questlineWorkspace.incomingProfileKey
        transform: ShellMotion {
            id: motion
            surface: frame
            animationsEnabled: panel.theme.animationsEnabled !== false
            bounceEnabled: panel.theme.widgetBounceEnabled !== false
            expanded: panel.expanded
            edge: panel.cornerPanel ? (panel.cornerTop ? "top" : "left") : panel.sidePanel ? "left" : panel.topPanel ? "top" : "bottom"
            viewportWidth: panel.screen.width
            viewportHeight: panel.screen.height
        }
        attachTop: panel.sidePanel || panel.topPanel || panel.cornerTop
        attachBottom: !panel.cornerTop && (panel.sidePanel || !panel.topPanel)
        attachRight: panel.cornerTop
        attachLeft: panel.sidePanel || (panel.cornerPanel && !panel.cornerTop)
        topAttachmentHeight: panel.theme.barStyle === "islands" && panel.theme.barPosition === "top"
            ? Math.max(0, y - 8) : 0
        leftAttachmentWidth: panel.theme.barStyle === "islands" && panel.theme.barPosition === "left"
            ? Math.max(0, x - leftFrameThickness) : 0
        width: panel.page === "breaks" ? Math.min(390, panel.screen.width - panel.panelLeftInset - 16) : panel.cornerPanel ? Math.min(680, panel.screen.width - (panel.cornerTop ? 16 : panel.panelLeftInset + 16)) : panel.sidePanel ? Math.min(660, panel.screen.width - panel.panelLeftInset) : panel.page === "questline" ? Math.min(1500, panel.screen.width * 0.88) : Math.min(680, panel.screen.width - 40)
        height: panel.page === "breaks" ? Math.min(460, panel.screen.height - panel.topInset - 24) : panel.cornerPanel ? Math.min(650, panel.screen.height - (panel.cornerTop ? panel.topInset + 16 : 24)) : panel.sidePanel ? panel.screen.height - panel.topInset - 8 : (panel.page === "hotkey" || panel.page === "breaks" || panel.page === "services" || panel.page === "default-apps") ? Math.min(650, panel.screen.height - 70) : panel.page === "questline" ? Math.min(1120, panel.screen.height * 0.82) : panel.page === "search" || panel.page === "emoji" ? Math.min(570, panel.screen.height - 90) : panel.page === "calculator" ? Math.min(calculatorContent.implicitHeight + 100, panel.screen.height - 50) : panel.page === "focus" ? Math.min(focusContent.implicitHeight + 100, panel.screen.height - 50) : panel.page === "color" ? Math.min(530, 330 + panel.savedColors.length * 40, panel.screen.height - 50) : panel.page === "updates" ? Math.min(430, panel.screen.height - 50) : Math.min(350, panel.screen.height - 50)
        x: panel.cornerPanel ? (panel.cornerTop ? panel.screen.width - width : panel.panelLeftInset) : panel.sidePanel ? panel.panelLeftInset : (panel.screen.width + panel.leftInset - width) / 2
        y: panel.cornerTop || panel.sidePanel || panel.topPanel ? panel.topInset : panel.screen.height - height - (panel.theme.gamingActive ? 0 : 8)

        radius: 32
        color: panel.theme.colors.surface
        focus: panel.visible && panel.page !== "search" && panel.page !== "calculator" && panel.page !== "emoji"
        Keys.onEscapePressed: panel.expanded = false

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: panelContent
            anchors { fill: parent; margins: 22 }
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                QuestlineCharacterHeader {
                    objectName: "questline-character-header"
                    Layout.fillWidth: true
                    visible: panel.page === "questline" && !!panel.questline.hero
                    theme: panel.theme
                    hero: panel.questline.hero || null
                }
                Text {
                    visible: panel.page !== "questline" || !panel.questline.hero
                    text: panel.page === "default-apps" ? qsTranslate("Spectrum", "Default applications") : panel.page === "breaks" ? qsTranslate("Spectrum", "Break reminders") : panel.page === "services" ? qsTranslate("Spectrum", "Local services") : panel.page === "spectrumdrop" ? "SpectrumDrop" : panel.page === "hotkey" ? "HotKey" : panel.page === "search" ? qsTranslate("Spectrum", "Files") : panel.page === "calculator" ? qsTranslate("Spectrum", "Calculator") : panel.page === "password" ? qsTranslate("Spectrum", "Password generator") : panel.page === "shortcuts" ? qsTranslate("Spectrum", "Keyboard shortcuts") : panel.page === "emoji" ? qsTranslate("Spectrum", "Emoji") : panel.page === "focus" ? qsTranslate("Spectrum", "Focus timer") : panel.page === "questline" ? "Questline" : panel.page === "color" ? qsTranslate("Spectrum", "Color picker") : qsTranslate("Spectrum", "Updates")
                    color: panel.theme.colors.foreground
                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + (panel.page === "questline" ? 10 : 5); bold: true }
                }
                Item { Layout.fillWidth: true; visible: panel.page !== "questline" || !panel.questline.hero }
                ShellButton {
                    label: "✕"
                    fontFamily: panel.theme.fontFamily
                    fontSize: panel.theme.fontSize
                    backgroundColor: panel.theme.colors.surface_alt
                    foregroundColor: panel.theme.colors.foreground
                    onClicked: panel.expanded = false
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 46
                radius: 10
                color: panel.theme.colors.background
                visible: panel.page === "emoji"
                Text {
                    anchors { fill: parent; leftMargin: 14 }
                    verticalAlignment: Text.AlignVCenter
                    visible: !query.text
                    text: qsTranslate("Spectrum", "Search emoji by name")
                    color: panel.theme.colors.muted
                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                }
                TextInput {
                    activeFocusOnTab: true
                    id: query
                    anchors { fill: parent; margins: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: panel.theme.colors.foreground
                    selectionColor: panel.theme.colors.accent
                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                    onTextChanged: {
                        if (panel.page === "emoji") {
                            panel.emojis = [];
                            panel.emojiSelectedIndex = 0;
                            emojiDelay.restart();
                        }
                    }
                    Keys.onEscapePressed: panel.expanded = false
                    Keys.onUpPressed: event => {
                        if (panel.page === "emoji") panel.moveEmojiSelection(-1);
                        else event.accepted = false;
                    }
                    Keys.onDownPressed: event => {
                        if (panel.page === "emoji") panel.moveEmojiSelection(1);
                        else event.accepted = false;
                    }
                    Keys.onReturnPressed: {
                        if (panel.page === "emoji")
                            panel.copySelectedEmoji();
                    }
                    Keys.onEnterPressed: {
                        if (panel.page === "emoji") panel.copySelectedEmoji();
                    }
                }
            }

            CachedContent {
                id: fileSearchContent
                requested: panel.expanded && panel.page === "search"
                visible: panel.page === "search"
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: FileSearch {
                    active: fileSearchContent.requested
                    theme: panel.theme
                    backendDir: panel.backendDir
                    onOpenRequested: path => panel.openFile(path)
                    onCloseRequested: panel.expanded = false
                }
            }

            CachedContent {
                id: calculatorContent
                requested: panel.expanded && panel.page === "calculator"
                visible: panel.page === "calculator"
                Layout.fillWidth: true
                sourceComponent: Calculator {
                    id: calculatorEditor
                    theme: panel.theme
                    backendDir: panel.backendDir
                    onCloseRequested: panel.expanded = false
                }
            }

            ListView {
                id: emojiList
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: panel.page === "emoji"
                clip: true
                spacing: 4
                model: panel.emojis
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool selected: index === panel.emojiSelectedIndex
                    width: ListView.view.width
                    height: 42
                    radius: 8
                    color: selected ? panel.theme.colors.accent : emojiMouse.containsMouse ? panel.theme.colors.surface_alt : panel.theme.colors.surface
                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        spacing: 12
                        Text {
                            text: parent.parent.modelData.character
                            color: panel.theme.colors.foreground
                            font { family: "Noto Color Emoji"; pixelSize: panel.theme.fontSize + 8 }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: parent.parent.modelData.name
                            elide: Text.ElideRight
                            color: parent.parent.selected ? panel.theme.colors.background : panel.theme.colors.foreground
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                        }
                    }
                    KeyboardAction {
                        id: emojiMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onActivated: panel.copyEmoji(parent.modelData.character)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: panel.page === "shortcuts"
                text: qsTranslate("Spectrum", "Click a shortcut to run it, or use ↑ / ↓ and Enter.")
                wrapMode: Text.Wrap
                color: panel.theme.colors.muted
                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
            }

            ListView {
                id: shortcutList
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: panel.page === "shortcuts"
                clip: true
                spacing: 4
                model: panel.shortcuts
                keyNavigationEnabled: true
                highlightMoveDuration: 0
                Keys.onReturnPressed: panel.activateShortcut(currentIndex)
                Keys.onEnterPressed: panel.activateShortcut(currentIndex)
                Keys.onEscapePressed: panel.expanded = false
                Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
                delegate: Rectangle {
                    id: shortcutRow
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: Math.max(42, shortcutLabel.implicitHeight + 16)
                    radius: 8
                    color: shortcutList.currentIndex === index ? Qt.lighter(panel.theme.colors.surface_alt, 1.4) : panel.theme.colors.surface_alt
                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 16 }
                        Text {
                            Layout.preferredWidth: Math.min(220, shortcutRow.width * 0.43)
                            text: shortcutRow.modelData.combo
                            elide: Text.ElideRight
                            color: panel.theme.colors.accent
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize; bold: true }
                        }
                        Text {
                            id: shortcutLabel
                            Layout.fillWidth: true
                            text: shortcutRow.modelData.action
                            wrapMode: Text.Wrap
                            color: panel.theme.colors.foreground
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                        }
                    }
                    KeyboardAction {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: shortcutList.currentIndex = shortcutRow.index
                        onActivated: panel.activateShortcut(shortcutRow.index)
                    }
                }
            }

            CachedContent {
                id: questlineContent
                requested: panel.expanded && panel.page === "questline"
                visible: panel.page === "questline"
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: ColumnLayout {
                    spacing: panelContent.spacing
                    property alias quickScrollProjects: viewQuickScrollProjects
                    property alias questlineTitle: viewQuestlineTitle
                    property alias questlineDate: viewQuestlineDate
                    property alias questlineAmount: viewQuestlineAmount
                    property alias questlineEditorFlick: viewQuestlineEditorFlick
                    property alias questlineBody: viewQuestlineBody
                    property alias questlineItemList: viewQuestlineItemList
                    property alias questlineDetailFlick: viewQuestlineDetailFlick
                    property alias questlineFocusEditor: viewQuestlineFocusEditor
                    RowLayout {
                        Layout.fillWidth: true
                        visible: panel.page === "questline"
                        Item { Layout.fillWidth: true }
                        ShellButton {
                            label: qsTranslate("Spectrum", "Open full app")
                            visible: panel.questline.available
                            enabled: panel.questline.installed
                            fontFamily: panel.theme.fontFamily
                            fontSize: panel.theme.fontSize
                            backgroundColor: panel.theme.colors.surface_alt
                            foregroundColor: panel.theme.colors.foreground
                            onClicked: panel.openQuestlineFullApp()
                        }
                        ShellButton {
                            label: qsTranslate("Spectrum", "Refresh")
                            fontFamily: panel.theme.fontFamily
                            fontSize: panel.theme.fontSize
                            backgroundColor: panel.theme.colors.surface_alt
                            foregroundColor: panel.theme.colors.foreground
                            onClicked: panel.refreshQuestline()
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: panel.page === "questline" && !panel.questlineLoaded
                        text: qsTranslate("Spectrum", "Checking Questline profile…")
                        color: panel.theme.colors.muted
                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: panel.page === "questline" && panel.questlineLoaded && !panel.questline.available && !panel.questline.needs_onboarding
                        text: qsTranslate("Spectrum", panel.questline.error) || (panel.questline.installed ? qsTranslate("Spectrum", "Questline could not load your character. Open the full app to inspect your profile.") : qsTranslate("Spectrum", "Questline is not installed yet."))
                        color: panel.theme.colors.muted
                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: panel.page === "questline" && panel.questlineLoaded && !!panel.questline.needs_onboarding
                        spacing: 18
                        Item { Layout.fillHeight: true }
                        Text {
                            Layout.fillWidth: true
                            text: qsTranslate("Spectrum", "Set up Questline")
                            color: panel.theme.colors.foreground
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 15; bold: true }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: qsTranslate("Spectrum", "Choose how to begin. Your character and progress will appear here after Questline finishes setup.")
                            wrapMode: Text.WordWrap
                            color: panel.theme.colors.muted
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 2 }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 280
                                radius: 16
                                color: panel.theme.colors.background
                                ColumnLayout {
                                    anchors { fill: parent; margins: 20 }
                                    spacing: 12
                                    Text {
                                        text: qsTranslate("Spectrum", "Create a character")
                                        color: panel.theme.colors.foreground
                                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 6; bold: true }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: qsTranslate("Spectrum", "Open the full app, choose New Adventurer, then pick a name and class.")
                                        wrapMode: Text.WordWrap
                                        color: panel.theme.colors.muted
                                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 1 }
                                    }
                                    Item { Layout.fillHeight: true }
                                    ShellButton {
                                        enabled: panel.questline.installed
                                        label: qsTranslate("Spectrum", "Create in Questline")
                                        fontFamily: panel.theme.fontFamily
                                        fontSize: panel.theme.fontSize
                                        backgroundColor: panel.theme.colors.accent
                                        foregroundColor: panel.theme.colors.background
                                        onClicked: panel.openQuestlineFullApp()
                                    }
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 280
                                radius: 16
                                color: panel.theme.colors.background
                                ColumnLayout {
                                    anchors { fill: parent; margins: 20 }
                                    spacing: 12
                                    Text {
                                        text: qsTranslate("Spectrum", "Continue from another PC")
                                        color: panel.theme.colors.foreground
                                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 6; bold: true }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: qsTranslate("Spectrum", "On the old PC, use Sync → Export Profile and wait for the backup. Here, choose Continue the Adventure in Questline and paste its Transfer Code. Keep the code private.")
                                        wrapMode: Text.WordWrap
                                        color: panel.theme.colors.muted
                                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 1 }
                                    }
                                    Item { Layout.fillHeight: true }
                                    ShellButton {
                                        enabled: panel.questline.installed
                                        label: qsTranslate("Spectrum", "Enter Transfer Code")
                                        fontFamily: panel.theme.fontFamily
                                        fontSize: panel.theme.fontSize
                                        backgroundColor: panel.theme.colors.accent
                                        foregroundColor: panel.theme.colors.background
                                        onClicked: panel.openQuestlineFullApp()
                                    }
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: qsTranslate("Spectrum", "Return here and press Refresh when setup is complete.")
                            color: panel.theme.colors.muted
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                        }
                        Item { Layout.fillHeight: true }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: panel.page === "questline" && panel.questline.available && !panel.questline.actions_available
                        text: qsTranslate("Spectrum", "Update Questline to enable editing and tree care here.")
                        color: panel.theme.colors.muted
                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                    }
                    QuestlineCampaignBar {
                        objectName:"questline-campaign-bar"
                        Layout.fillWidth:true
                        Layout.minimumWidth:0
                        readonly property bool choosingNewTaskCampaign: panel.questlineEditing && panel.questlineTab === "Tasks" && panel.questlineSelected === null && panel.questlineStepParent === null
                        visible:panel.page==="questline" && panel.questline.available && !panel.questlineQuickScrollPicker
                        enabled:!choosingNewTaskCampaign || !panel.questlineWorkspace.busy
                        theme:panel.theme
                        campaigns:choosingNewTaskCampaign ? (panel.questline.campaigns || []).filter(c=>!c.is_shared).slice().sort((a,b)=>a.name.localeCompare(b.name)) : panel.questlineProjects()
                        selectedId:choosingNewTaskCampaign ? panel.questlineEditCampaignId : panel.questlineCampaignId
                        onChosen:campaignId=> {
                            if (choosingNewTaskCampaign) panel.selectQuestlineCampaign(campaignId);
                            else panel.selectQuestlineProject(campaignId);
                        }
                    }
                    Flow {
                        Layout.fillWidth: true
                        visible: panel.page === "questline" && (panel.questline.available || panel.questline.installed)
                        spacing: 6
                        Repeater {
                            objectName:"questline-tabs"
                            model: panel.questline.available ? ["Overview", "Tasks", "Scrolls", "Treasury", "Chronicles", "Tree", "Focus", "Hero", "Sidequests", "Sync"] : ["Sync"]
                            ShellButton {
                                required property string modelData
                                objectName: "questline-tab-" + modelData
                                label: qsTranslate("Spectrum", modelData)
                                fontFamily: panel.theme.fontFamily
                                fontSize: panel.theme.fontSize
                                backgroundColor: panel.questlineTab === modelData ? panel.theme.colors.accent : panel.theme.colors.surface_alt
                                foregroundColor: panel.questlineTab === modelData ? panel.theme.colors.background : panel.theme.colors.foreground
                                onClicked: {
                                    panel.switchQuestlineTab(modelData);
                                }
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: panel.page === "questline" && panel.questline.available && panel.questlineQuickScrollPicker
                        spacing: 12
                        Text {
                            Layout.fillWidth: true
                            text: qsTranslate("Spectrum", "Quick note — choose a project")
                            color: panel.theme.colors.foreground
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 4; bold: true }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: viewQuickScrollProjects.count ? qsTranslate("Spectrum", "Select a project and start writing. Your note saves automatically.") : qsTranslate("Spectrum", "Create an active personal campaign in Questline first, then try the shortcut again.")
                            wrapMode: Text.Wrap
                            color: panel.theme.colors.muted
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                        }
                        ListView {
                            id: viewQuickScrollProjects
                            objectName: "questline-quick-scroll-projects"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 8
                            model: (panel.questline.campaigns || []).filter(campaign => !campaign.is_shared)
                            Keys.onReturnPressed: if (currentIndex >= 0 && currentIndex < count) panel.beginQuestlineQuickScroll(model[currentIndex].id)
                            Keys.onEnterPressed: if (currentIndex >= 0 && currentIndex < count) panel.beginQuestlineQuickScroll(model[currentIndex].id)
                            delegate: ShellButton {
                                required property var modelData
                                required property int index
                                width: ListView.view.width
                                label: modelData.name
                                fontFamily: panel.theme.fontFamily; fontSize: panel.theme.fontSize
                                backgroundColor: viewQuickScrollProjects.currentIndex === index ? panel.theme.colors.accent : panel.theme.colors.surface_alt
                                foregroundColor: viewQuickScrollProjects.currentIndex === index ? panel.theme.colors.background : panel.theme.colors.foreground
                                onClicked: panel.beginQuestlineQuickScroll(modelData.id)
                            }
                        }
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: panel.page === "questline" && !panel.questlineEditing && !panel.questlineQuickScrollPicker
                        Repeater {
                            model: Object.keys(panel.questlineWorkspace.drafts).filter(key => {
                                const d = panel.questlineWorkspace.drafts[key];
                                return d.tab === panel.questlineTab && d.view && (!d.valid || d.error || d.saved !== JSON.stringify(d.payload));
                            })
                            ShellButton {
                                required property string modelData
                                label: qsTranslate("Spectrum", "Resume draft: ") + (panel.questlineWorkspace.drafts[modelData].view.title || qsTranslate("Spectrum", "Untitled"))
                                fontFamily: panel.theme.fontFamily; fontSize: panel.theme.fontSize
                                onClicked: panel.restoreQuestline(panel.questlineTab,panel.questlineWorkspace.drafts[modelData].view)
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        visible: panel.page === "questline" && panel.questline.available && !panel.questlineEditing && !panel.questlineQuickScrollPicker && panel.questlineTab !== "Tree" && panel.questlineTab !== "Overview" && panel.questlineTab !== "Focus" && panel.questlineTab !== "Hero"
                        ShellButton {
                            visible: ["Tasks", "Sidequests", "Scrolls", "Treasury", "Chronicles"].includes(panel.questlineTab)
                            enabled: !!panel.questline.actions_available && (panel.questlineTab !== "Sidequests" || !!panel.questline.sidequests_available) && (panel.questlineTab !== "Chronicles" || !!panel.questline.chronicles_available)
                            objectName: "questline-new-item"
                            label: panel.questlineTab === "Chronicles" ? qsTranslate("Spectrum", "+ New chronicle") : panel.questlineTab === "Sidequests" ? qsTranslate("Spectrum", "+ New sidequest") : panel.questlineTab === "Scrolls" ? qsTranslate("Spectrum", "+ New scroll") : panel.questlineTab === "Treasury" ? qsTranslate("Spectrum", "+ New entry") : qsTranslate("Spectrum", "+ New task")
                            fontFamily: panel.theme.fontFamily
                            fontSize: panel.theme.fontSize
                            backgroundColor: panel.theme.colors.accent
                            foregroundColor: panel.theme.colors.background
                            onClicked: panel.beginQuestlineEdit(null)
                        }
                        ShellButton {
                            visible: panel.questlineSelected !== null && ["Tasks", "Sidequests", "Scrolls", "Treasury", "Chronicles"].includes(panel.questlineTab)
                            enabled: !!panel.questline.actions_available && (panel.questlineTab !== "Sidequests" || !!panel.questline.sidequests_available) && (panel.questlineTab !== "Chronicles" || !!panel.questline.chronicles_available)
                            objectName: "questline-edit-item"
                            label: qsTranslate("Spectrum", "Edit")
                            fontFamily: panel.theme.fontFamily
                            fontSize: panel.theme.fontSize
                            backgroundColor: panel.theme.colors.surface_alt
                            foregroundColor: panel.theme.colors.foreground
                            onClicked: panel.beginQuestlineEdit(panel.questlineSelected)
                        }
                        ShellButton {
                            visible: panel.questlineSelected !== null && ["Tasks", "Sidequests", "Scrolls"].includes(panel.questlineTab)
                            enabled: !!panel.questline.actions_available && (panel.questlineTab !== "Sidequests" || !!panel.questline.sidequests_available) && (panel.questlineTab !== "Chronicles" || !!panel.questline.chronicles_available) && !questlineActionProcess.running && !panel.questlineWorkspace.busy
                            label: qsTranslate("Spectrum", "Delete")
                            fontFamily: panel.theme.fontFamily
                            fontSize: panel.theme.fontSize
                            backgroundColor: panel.theme.colors.surface_alt
                            foregroundColor: panel.theme.colors.foreground
                            onClicked: panel.askQuestlineDelete(panel.questlineTab === "Tasks" ? "task" : panel.questlineTab === "Sidequests" ? "sidequest" : "scroll", panel.questlineSelected)
                        }
                        Item { Layout.fillWidth: true }
                        ShellButton {
                            visible: panel.questlineSelected !== null && ["Tasks", "Sidequests"].includes(panel.questlineTab)
                            enabled: !!panel.questline.actions_available && (panel.questlineTab !== "Sidequests" || !!panel.questline.sidequests_available) && (panel.questlineTab !== "Chronicles" || !!panel.questline.chronicles_available) && !questlineActionProcess.running && !panel.questlineWorkspace.busy && (panel.questlineTab !== "Sidequests" || (!!panel.questlineSelected && panel.questlineSelected.completion_count < panel.questlineSelected.daily_target))
                            label: panel.questlineTab === "Sidequests" ? qsTranslate("Spectrum", "Complete sidequest") : qsTranslate("Spectrum", "Complete task")
                            fontFamily: panel.theme.fontFamily
                            fontSize: panel.theme.fontSize
                            backgroundColor: panel.theme.colors.accent
                            foregroundColor: panel.theme.colors.background
                            onClicked: panel.runQuestlineAction({ action: panel.questlineTab === "Sidequests" ? "complete_sidequest" : "complete_task", id: panel.questlineSelected.id })
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        visible: panel.page === "questline" && panel.questlineDeleteTarget !== null
                        spacing: 8
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: {
                                const target = panel.questlineDeleteTarget;
                                if (!target) return "";
                                const kind = target.kind === "task" ? qsTranslate("Spectrum", "task") : target.kind;
                                const linked = target.kind === "task" && target.stepCount ? qsTranslate("Spectrum", " and its ") + target.stepCount + qsTranslate("Spectrum", " linked step") + (target.stepCount === 1 ? "" : "s") : "";
                                return qsTranslate("Spectrum", "Permanently delete ") + kind + " ‘" + target.title + "’" + linked + "?";
                            }
                            color: panel.theme.colors.foreground
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                        }
                        ShellButton {
                            label: qsTranslate("Spectrum", "Cancel")
                            fontFamily: panel.theme.fontFamily
                            fontSize: panel.theme.fontSize
                            backgroundColor: panel.theme.colors.surface_alt
                            foregroundColor: panel.theme.colors.foreground
                            onClicked: panel.questlineDeleteTarget = null
                        }
                        ShellButton {
                            enabled: !questlineActionProcess.running && !panel.questlineWorkspace.busy
                            label: qsTranslate("Spectrum", "Delete permanently")
                            fontFamily: panel.theme.fontFamily
                            fontSize: panel.theme.fontSize
                            backgroundColor: panel.theme.colors.accent
                            foregroundColor: panel.theme.colors.background
                            onClicked: panel.confirmQuestlineDelete()
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: panel.page === "questline" && (!!panel.questlineError || !!panel.questlineWorkspace.storageError)
                        text: panel.questlineError || panel.questlineWorkspace.storageError
                        wrapMode: Text.Wrap
                        color: panel.theme.colors.accent
                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: panel.page === "questline" && !!panel.questlineMessage && !panel.questlineError
                        text: panel.questlineMessage
                        color: panel.theme.colors.muted
                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: panel.page === "questline" && panel.questlineEditing
                        spacing: 10
                        Text {
                            text: panel.questlineStepParent ? (panel.questlineStepSelected ? qsTranslate("Spectrum", "Edit step") : qsTranslate("Spectrum", "New step for ") + panel.questlineStepParent.title) : (panel.questlineSelected ? qsTranslate("Spectrum", "Edit ") : qsTranslate("Spectrum", "New ")) + (panel.questlineTab === "Chronicles" ? qsTranslate("Spectrum", "chronicle") : panel.questlineTab === "Sidequests" ? qsTranslate("Spectrum", "sidequest") : panel.questlineTab === "Scrolls" ? qsTranslate("Spectrum", "scroll") : panel.questlineTab === "Treasury" ? qsTranslate("Spectrum", "treasury entry") : qsTranslate("Spectrum", "task"))
                            color: panel.theme.colors.foreground
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 3; bold: true }
                        }
                        ShellButton {
                            visible: panel.questlineSelected === null && panel.questlineStepParent === null && panel.questlineTab !== "Sidequests" && panel.questlineTab !== "Tasks"
                            label: {
                                const campaigns = (panel.questline.campaigns || []).filter(c => !c.is_shared);
                                return campaigns.length ? qsTranslate("Spectrum", "Campaign: ") + campaigns[panel.questlineCampaignIndex % campaigns.length].name + "  ›" : qsTranslate("Spectrum", "No active campaign");
                            }
                            fontFamily: panel.theme.fontFamily
                            fontSize: panel.theme.fontSize
                            backgroundColor: panel.theme.colors.surface_alt
                            foregroundColor: panel.theme.colors.foreground
                            onClicked: panel.selectQuestlineCampaign()
                        }
                        Text {
                            visible: panel.questlineTab === "Tasks" && panel.questlineSelected === null && panel.questlineStepParent === null && !(panel.questline.campaigns || []).some(c=>!c.is_shared)
                            text: qsTranslate("Spectrum", "No active campaign")
                            color: panel.theme.colors.muted
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                        }
                        Text {
                            visible: panel.questlineTab === "Chronicles"
                            text: viewQuestlineTitle.text + " · " + Array.from(viewQuestlineBody.text.trim()).length + "/255"
                            color: panel.theme.colors.muted
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                        }
                        Rectangle {
                            visible: panel.questlineTab !== "Chronicles"
                            Layout.fillWidth: true; implicitHeight: 44; radius: 8; color: panel.theme.colors.background
                            TextInput {
                                activeFocusOnTab: true
                                id: viewQuestlineTitle
                                    clip: true
                                    objectName: "questline-title"
                                    onTextChanged: panel.queueQuestlineState()
                                    onCursorPositionChanged: panel.queueQuestlineState()
                                anchors { fill: parent; margins: 10 }
                                verticalAlignment: TextInput.AlignVCenter
                                color: panel.theme.colors.foreground
                                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            visible: panel.questlineTab === "Sidequests"
                            spacing: 10
                            Text {
                                text: qsTranslate("Spectrum", "Frequency")
                                color: panel.theme.colors.foreground
                                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                            }
                            FocusChoice {
                                Layout.preferredWidth: 220
                                theme: panel.theme
                                translateModel: true
                                model: panel.questlineSidequestFrequencies
                                currentIndex: Math.max(0, panel.questlineSidequestFrequencies.indexOf(panel.questlineSidequestFrequency))
                                onActivated: panel.questlineSidequestFrequency = panel.questlineSidequestFrequencies[currentIndex]
                            }
                            Text {
                                text: qsTranslate("Spectrum", "XP per completion")
                                color: panel.theme.colors.foreground
                                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                            }
                            Controls.SpinBox {
                                Layout.preferredWidth: 140
                                from: 0; to: 100; editable: true
                                value: panel.questlineSidequestReward
                                onValueModified: panel.questlineSidequestReward = value
                                background: Rectangle { radius: 8; color: panel.theme.colors.surface_alt }
                                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                                palette { base: panel.theme.colors.surface_alt; text: panel.theme.colors.foreground; button: panel.theme.colors.surface_alt; buttonText: panel.theme.colors.foreground }
                            }
                            Item { Layout.fillWidth: true }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            visible: panel.questlineTab === "Tasks"
                            spacing: 10
                            Text {
                                text: qsTranslate("Spectrum", "Priority")
                                color: panel.theme.colors.foreground
                                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                            }
                            FocusChoice {
                                objectName: "questline-task-priority"
                                Layout.preferredWidth: 160
                                theme: panel.theme
                                translateModel: true
                                model: panel.questlineTaskPriorities
                                currentIndex: Math.max(0, panel.questlineTaskPriorities.indexOf(panel.questlineTaskPriority))
                                onActivated: panel.questlineTaskPriority = panel.questlineTaskPriorities[currentIndex]
                            }
                            Text {
                                visible: !panel.questlineStepParent
                                text: qsTranslate("Spectrum", "Recurrence")
                                color: panel.theme.colors.foreground
                                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                            }
                            FocusChoice {
                                objectName: "questline-task-recurrence"
                                visible: !panel.questlineStepParent
                                Layout.preferredWidth: 180
                                theme: panel.theme
                                translateModel: true
                                model: panel.questlineTaskRecurrences
                                currentIndex: Math.max(0, panel.questlineTaskRecurrences.indexOf(panel.questlineTaskRecurrence))
                                onActivated: panel.questlineTaskRecurrence = panel.questlineTaskRecurrences[currentIndex]
                            }
                            Item { Layout.fillWidth: true }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: panel.questlineTab === "Tasks"
                            spacing: 6
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: qsTranslate("Spectrum", "Due date"); color: panel.theme.colors.foreground; font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize } }
                                ShellButton {
                                    label: qsTranslate("Spectrum", "Today")
                                    fontFamily: panel.theme.fontFamily; fontSize: panel.theme.fontSize
                                    backgroundColor: panel.theme.colors.surface_alt; foregroundColor: panel.theme.colors.foreground
                                    onClicked: panel.setQuestlineDate(0)
                                }
                                ShellButton {
                                    label: qsTranslate("Spectrum", "Tomorrow")
                                    fontFamily: panel.theme.fontFamily; fontSize: panel.theme.fontSize
                                    backgroundColor: panel.theme.colors.surface_alt; foregroundColor: panel.theme.colors.foreground
                                    onClicked: panel.setQuestlineDate(1)
                                }
                                ShellButton {
                                    label: qsTranslate("Spectrum", "Choose date")
                                    fontFamily: panel.theme.fontFamily; fontSize: panel.theme.fontSize
                                    backgroundColor: panel.theme.colors.surface_alt; foregroundColor: panel.theme.colors.foreground
                                    onClicked: {
                                        const selected = viewQuestlineDate.text ? new Date(viewQuestlineDate.text + "T12:00:00") : new Date();
                                        panel.questlineCalendarMonth = Number.isNaN(selected.getTime()) ? new Date() : selected;
                                        panel.questlineCalendarOpen = !panel.questlineCalendarOpen;
                                    }
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true; implicitHeight: 44; radius: 8; color: panel.theme.colors.background
                                TextInput {
                                    activeFocusOnTab: true
                                    id: viewQuestlineDate
                                    clip: true
                                    objectName: "questline-date"
                                    onTextChanged: panel.queueQuestlineState()
                                    onCursorPositionChanged: panel.queueQuestlineState()
                                    anchors { fill: parent; margins: 10 }
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: panel.theme.colors.foreground
                                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                                }
                                Text {
                                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 10 }
                                    visible: !viewQuestlineDate.text
                                    text: qsTranslate("Spectrum", "No due date")
                                    color: panel.theme.colors.muted
                                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: panel.questlineCalendarOpen
                                RowLayout {
                                    Layout.fillWidth: true
                                    ShellButton {
                                        label: "‹"
                                        fontFamily: panel.theme.fontFamily; fontSize: panel.theme.fontSize
                                        onClicked: panel.questlineCalendarMonth = new Date(panel.questlineCalendarMonth.getFullYear(), panel.questlineCalendarMonth.getMonth() - 1, 1)
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: Qt.formatDate(panel.questlineCalendarMonth, "MMMM yyyy")
                                        color: panel.theme.colors.foreground
                                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                                    }
                                    ShellButton {
                                        label: "›"
                                        fontFamily: panel.theme.fontFamily; fontSize: panel.theme.fontSize
                                        onClicked: panel.questlineCalendarMonth = new Date(panel.questlineCalendarMonth.getFullYear(), panel.questlineCalendarMonth.getMonth() + 1, 1)
                                    }
                                }
                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 7
                                    rowSpacing: 2
                                    columnSpacing: 2
                                    Repeater {
                                        model: [qsTranslate("Calendar", "M"), qsTranslate("Calendar", "Tu"), qsTranslate("Calendar", "W"), qsTranslate("Calendar", "Th"), qsTranslate("Calendar", "F"), qsTranslate("Calendar", "Sa"), qsTranslate("Calendar", "Su")]
                                        Text {
                                            required property string modelData
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignHCenter
                                            text: modelData
                                            color: panel.theme.colors.muted
                                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize - 1 }
                                        }
                                    }
                                    Repeater {
                                        model: {
                                            const first = new Date(panel.questlineCalendarMonth.getFullYear(), panel.questlineCalendarMonth.getMonth(), 1);
                                            const offset = (first.getDay() + 6) % 7;
                                            const count = new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate();
                                            return Array.from({ length: offset + count }, (_, index) => index < offset ? 0 : index - offset + 1);
                                        }
                                        ShellButton {
                                            required property int modelData
                                            Layout.fillWidth: true
                                            label: modelData ? String(modelData) : ""
                                            enabled: modelData > 0
                                            fontFamily: panel.theme.fontFamily; fontSize: panel.theme.fontSize - 1
                                            backgroundColor: panel.theme.colors.background
                                            foregroundColor: panel.theme.colors.foreground
                                            onClicked: {
                                                const date = new Date(panel.questlineCalendarMonth.getFullYear(), panel.questlineCalendarMonth.getMonth(), modelData);
                                                viewQuestlineDate.text = Qt.formatDate(date, "yyyy-MM-dd");
                                                panel.questlineCalendarOpen = false;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            visible: panel.questlineTab === "Treasury"
                            ShellButton {
                                objectName: "questline-entry-type"
                                label: qsTranslate("Spectrum", panel.questlineEntryType) + "  ›"
                                fontFamily: panel.theme.fontFamily; fontSize: panel.theme.fontSize
                                backgroundColor: panel.theme.colors.surface_alt; foregroundColor: panel.theme.colors.foreground
                                onClicked: {
                                    const types = ["Expense","Income","Transfer","Adjustment"];
                                    panel.questlineEntryType = types[(types.indexOf(panel.questlineEntryType) + 1) % types.length];
                                }
                            }
                            ShellButton {
                                label: qsTranslate("Spectrum", "Status: ") + qsTranslate("Spectrum", panel.questlineEntryStatus) + "  ›"
                                fontFamily: panel.theme.fontFamily; fontSize: panel.theme.fontSize
                                backgroundColor: panel.theme.colors.surface_alt; foregroundColor: panel.theme.colors.foreground
                                onClicked: {
                                    const statuses = ["Planned", "Approved", "Paid", "Cancelled"];
                                    panel.questlineEntryStatus = statuses[(statuses.indexOf(panel.questlineEntryStatus) + 1) % statuses.length];
                                }
                            }
                            Text { text: qsTranslate("Spectrum", "Amount"); color: panel.theme.colors.foreground; font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize } }
                            Rectangle {
                                Layout.fillWidth: true; implicitHeight: 44; radius: 8; color: panel.theme.colors.background
                                TextInput {
                                    activeFocusOnTab: true
                                    id: viewQuestlineAmount
                                    clip: true
                                    objectName: "questline-amount"
                                    onTextChanged: panel.queueQuestlineState()
                                    onCursorPositionChanged: panel.queueQuestlineState()
                                    anchors { fill: parent; margins: 10 }
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: panel.theme.colors.foreground
                                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                                }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: panel.questlineTab !== "Treasury"
                            radius: 8
                            color: panel.theme.colors.background
                            Flickable {
                                anchors { fill: parent; margins: 10 }
                                contentWidth: width
                                id: viewQuestlineEditorFlick
                                onContentYChanged: panel.queueQuestlineState()
                                contentHeight: Math.max(height, viewQuestlineBody.implicitHeight)
                                clip: true
                                TextEdit {
                                    activeFocusOnTab: true
                                    Keys.onTabPressed: nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
                                    Keys.onBacktabPressed: nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason)
                                    id: viewQuestlineBody
                                    objectName: "questline-body"
                                    onTextChanged: panel.queueQuestlineState()
                                    onCursorPositionChanged: panel.queueQuestlineState()
                                    width: parent.width
                                    height: Math.max(viewQuestlineEditorFlick.height, implicitHeight)
                                    wrapMode: TextEdit.Wrap
                                    textFormat: TextEdit.PlainText
                                    color: panel.theme.colors.foreground
                                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                                }
                            }
                        }
                        QuestlineEntryEditor {
                            objectName: "questline-entry-editor"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: panel.questlineTab === "Treasury"
                            enabled: !!panel.questline.treasury_fields_available
                            theme: panel.theme
                            fields: panel.questlineEntryFields
                            accounts: panel.questline.accounts || []
                            categories: panel.questline.categories || []
                            tasks: panel.questline.tasks || []
                            campaignId: panel.questlineEditCampaignId
                            entryType: panel.questlineEntryType
                            legacyAccountIds: panel.questlineLegacyAccountIds()
                            onEdited: value => panel.questlineEntryFields = value
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            ShellButton {
                                label: qsTranslate("Spectrum", "Back")
                                fontFamily: panel.theme.fontFamily; fontSize: panel.theme.fontSize
                                backgroundColor: panel.theme.colors.surface_alt; foregroundColor: panel.theme.colors.foreground
                                onClicked: panel.leaveQuestlineEditor()
                            }
                            Text {
                                Layout.fillWidth: true
                                text: panel.questlineWorkspace.status(panel.questlineDraftKey)
                                wrapMode: Text.Wrap
                                color: panel.theme.colors.muted
                                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                            }
                            ShellButton {
                                label: qsTranslate("Spectrum", "Retry")
                                visible: !!panel.questlineWorkspace.storageError || !!(panel.questlineWorkspace.drafts[panel.questlineDraftKey] || {}).error
                                fontFamily: panel.theme.fontFamily; fontSize: panel.theme.fontSize
                                onClicked: panel.questlineWorkspace.retry(panel.questlineDraftKey)
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: panel.page === "questline" && panel.questline.available && panel.questlineTab === "Overview" && !panel.questlineEditing && !panel.questlineQuickScrollPicker
                        spacing: 14
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Repeater {
                                model: [
                                    { label: qsTranslate("Spectrum", "OPEN TASKS"), value: String((panel.questline.tasks || []).length), tab: "Tasks" },
                                    { label: qsTranslate("Spectrum", "SCROLLS"), value: String((panel.questline.scrolls || []).length), tab: "Scrolls" },
                                    { label: qsTranslate("Spectrum", "TREASURY ENTRIES"), value: String((panel.questline.entries || []).length), tab: "Treasury" },
                                    { label: qsTranslate("Spectrum", "EVERGROWTH"), value: panel.questline.tree ? "Stage " + panel.questline.tree.stage : "—", tab: "Tree" }
                                ]
                                Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 110
                                    radius: 14
                                    color: panel.theme.colors.background
                                    Column {
                                        anchors { fill: parent; margins: 16 }
                                        spacing: 8
                                        Text {
                                            text: parent.parent.modelData.label
                                            color: panel.theme.colors.muted
                                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize; bold: true }
                                        }
                                        Text {
                                            text: parent.parent.modelData.value
                                            color: panel.theme.colors.accent
                                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 15; bold: true }
                                        }
                                    }
                                    KeyboardAction {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onActivated: {
                                            panel.switchQuestlineTab(parent.modelData.tab);
                                            panel.selectQuestlineItem();
                                        }
                                    }
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 12
                            QuestlineOverviewColumn {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                title: qsTranslate("Spectrum", "Upcoming tasks")
                                kind: "Tasks"
                                items: panel.questline.tasks || []
                                theme: panel.theme
                                onItemChosen: item => {
                                    panel.switchQuestlineTab("Tasks");
                                    panel.selectQuestlineProject(item.project_id || "");
                                    panel.questlineSelected = item;
                                }
                            }
                            QuestlineOverviewColumn {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                title: qsTranslate("Spectrum", "Recent scrolls")
                                kind: "Scrolls"
                                items: (panel.questline.scrolls || []).slice(0, 8)
                                theme: panel.theme
                                onItemChosen: item => {
                                    panel.switchQuestlineTab("Scrolls");
                                    panel.selectQuestlineProject(item.project_id || "");
                                    panel.questlineSelected = item;
                                }
                            }
                            QuestlineOverviewColumn {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                title: qsTranslate("Spectrum", "Recent treasury")
                                kind: "Treasury"
                                items: (panel.questline.entries || []).slice(0, 8)
                                theme: panel.theme
                                onItemChosen: item => {
                                    panel.switchQuestlineTab("Treasury");
                                    panel.selectQuestlineProject(item.campaign_id || "");
                                    panel.questlineSelected = item;
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: panel.page === "questline" && panel.questline.available && panel.questlineTab === "Tree" && !panel.questlineEditing && !panel.questlineQuickScrollPicker
                        spacing: 14

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 16
                            color: panel.theme.colors.background

                            Text {
                                anchors.centerIn: parent
                                visible: !panel.questline.tree || !panel.questline.tree.bonsai_rows || !panel.questline.tree.bonsai_rows.length
                                text: qsTranslate("Spectrum", "Questline's current tree renderer is unavailable.")
                                color: panel.theme.colors.muted
                                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                            }
                            QuestlineTree {
                                anchors { fill: parent; margins: 16 }
                                rows: panel.questline.tree ? panel.questline.tree.bonsai_rows || [] : []
                                foreground: panel.theme.colors.foreground
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: Math.min(300, frame.width * 0.25)
                            Layout.fillHeight: true
                            radius: 16
                            color: panel.theme.colors.background
                            ColumnLayout {
                                anchors { fill: parent; margins: 18 }
                                spacing: 12
                                Text {
                                    text: qsTranslate("Spectrum", "THE EVERGROWTH")
                                    color: panel.theme.colors.muted
                                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize; bold: true }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: panel.questline.tree ? ["", qsTranslate("Spectrum", "Acorn"), qsTranslate("Spectrum", "Sprout"), qsTranslate("Spectrum", "Young Entling"), qsTranslate("Spectrum", "Grove Guardian"), qsTranslate("Spectrum", "Ancient Ent"), qsTranslate("Spectrum", "Evergrowth Elder")][Math.min(Math.max(panel.questline.tree.stage, 1), 6)] : qsTranslate("Spectrum", "Unplanted")
                                    wrapMode: Text.Wrap
                                    color: panel.theme.colors.foreground
                                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 7; bold: true }
                                }
                                Text {
                                    text: panel.questline.tree ? qsTranslate("Spectrum", "Stage ") + panel.questline.tree.stage + "  ·  " + panel.questline.tree.growth + qsTranslate("Spectrum", " growth") : ""
                                    color: panel.theme.colors.muted
                                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                                }
                                Text {
                                    text: panel.questline.tree ? qsTranslate("Spectrum", "Health  ") + panel.questline.tree.health + "%" : ""
                                    color: panel.theme.colors.foreground
                                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 2 }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 10
                                    radius: 5
                                    color: panel.theme.colors.surface_alt
                                    Rectangle {
                                        width: parent.width * (panel.questline.tree ? Math.max(0, Math.min(100, panel.questline.tree.health)) / 100 : 0)
                                        height: parent.height
                                        radius: parent.radius
                                        color: panel.theme.colors.accent
                                    }
                                }
                                Text {
                                    text: panel.questline.tree ? (panel.questline.tree.water_today > 0 ? qsTranslate("Spectrum", "Watered today") : qsTranslate("Spectrum", "Ready for today's watering")) : ""
                                    color: panel.theme.colors.muted
                                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                                }
                                Text {
                                    text: panel.questline.tree ? qsTranslate("Spectrum", "Total waterings  ") + panel.questline.tree.total_waterings : ""
                                    color: panel.theme.colors.muted
                                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: panel.questline.tree && panel.questline.tree.last_watered ? qsTranslate("Spectrum", "Last watered  ") + new Date(panel.questline.tree.last_watered).toLocaleDateString() : qsTranslate("Spectrum", "Ready for its first watering")
                                    wrapMode: Text.Wrap
                                    color: panel.theme.colors.muted
                                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                                }
                                Item { Layout.fillHeight: true }
                                ShellButton {
                                    Layout.fillWidth: true
                                    enabled: !!panel.questline.actions_available && !!panel.questline.tree && !questlineActionProcess.running && !panel.questlineWorkspace.busy && panel.questline.tree.water_today < 1
                                    label: panel.questline.tree && panel.questline.tree.water_today > 0 ? qsTranslate("Spectrum", "Watered today") : qsTranslate("Spectrum", "Water tree")
                                    fontFamily: panel.theme.fontFamily
                                    fontSize: panel.theme.fontSize
                                    backgroundColor: panel.theme.colors.accent
                                    foregroundColor: panel.theme.colors.background
                                    onClicked: panel.runQuestlineAction({ action: "water_tree" })
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: panel.page === "questline" && panel.questlineTab === "Treasury" && !panel.questlineEditing
                        spacing: 6
                        Repeater {
                            objectName: "questline-treasury-summary"
                            model: questlineTreasury.currencyTotals
                            GridLayout {
                                id: currencySummary
                                required property var modelData
                                Layout.fillWidth: true
                                columns: width >= 600 ? 4 : 2
                                Repeater {
                                    model: [{label:qsTranslate("Spectrum", "Available"),amount:currencySummary.modelData.available},{label:qsTranslate("Spectrum", "Saved"),amount:currencySummary.modelData.saved},
                                            {label:qsTranslate("Spectrum", "Invested"),amount:currencySummary.modelData.invested},{label:qsTranslate("Spectrum", "Available savings"),amount:currencySummary.modelData.liquidSavings}]
                                    Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        implicitHeight: 60
                                        radius: 8
                                        color: panel.theme.colors.background
                                        ColumnLayout {
                                            anchors { fill: parent; margins: 8 }
                                            spacing: 2
                                            Text {
                                                text: modelData.label
                                                color: panel.theme.colors.muted
                                                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize - 2 }
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: currencySummary.modelData.currency + " " + (modelData.amount / 100).toLocaleString(Qt.locale(),'f',2)
                                                elide: Text.ElideRight
                                                color: modelData.amount < 0 ? panel.theme.colors.error : panel.theme.colors.accent
                                                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize; bold: true }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: panel.page === "questline" && panel.questline.available && panel.questlineTab !== "Tree" && panel.questlineTab !== "Overview" && panel.questlineTab !== "Focus" && panel.questlineTab !== "Hero" && panel.questlineTab !== "Sync" && !panel.questlineEditing && !panel.questlineQuickScrollPicker
                        spacing: 14

                        Rectangle {
                            visible: panel.questlineTab === "Treasury"
                            Layout.preferredWidth: visible ? 220 : 0
                            Layout.fillHeight: true
                            radius: 16
                            color: panel.theme.colors.background
                            ColumnLayout {
                                anchors { fill: parent; margins: 12 }
                                spacing: 10
                                Text {
                                    text: qsTranslate("Spectrum", "Current accounts")
                                    color: panel.theme.colors.foreground
                                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 2; bold: true }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: questlineAccountList.count === 0
                                    text: qsTranslate("Spectrum", "Create your accounts in Questline to start recording entries.")
                                    wrapMode: Text.Wrap
                                    color: panel.theme.colors.muted
                                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                                }
                                ListView {
                                    id: questlineAccountList
                                    objectName: "questline-account-list"
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    spacing: 7
                                    model: questlineTreasury.currentAccounts
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: ListView.view.width
                                        height: accountContent.implicitHeight + 20
                                        radius: 10
                                        color: panel.theme.colors.surface_alt
                                        ColumnLayout {
                                            id: accountContent
                                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                                            spacing: 4
                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.name
                                                wrapMode: Text.Wrap
                                                color: panel.theme.colors.foreground
                                                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize; bold: true }
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.currency_code + " " + (modelData.balance_minor / 100).toLocaleString(Qt.locale(), 'f', 2)
                                                wrapMode: Text.Wrap
                                                color: modelData.balance_minor < 0 ? panel.theme.colors.error : panel.theme.colors.accent
                                                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 2; bold: true }
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: qsTranslate("Spectrum", modelData.kind) + (modelData.is_default ? qsTranslate("Spectrum", " · Legacy") : "")
                                                wrapMode: Text.Wrap
                                                color: panel.theme.colors.muted
                                                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize - 2 }
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                visible: modelData.kind === "Savings"
                                                text: qsTranslate("Spectrum", modelData.savings_status || "Available") + qsTranslate("Spectrum", " savings · ") + ((modelData.interest_rate_bps || 0) / 100).toFixed(2) + "% " + qsTranslate("Spectrum", modelData.interest_period || "Annual").toLowerCase()
                                                wrapMode: Text.Wrap
                                                color: panel.theme.colors.muted
                                                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize - 2 }
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                visible: modelData.kind === "Savings"
                                                text: questlineTreasury.estimate(modelData)
                                                wrapMode: Text.Wrap
                                                color: panel.theme.colors.accent_alt
                                                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize - 2 }
                                            }
                                            QuestlineSavingsEditor {
                                                Layout.fillWidth: true
                                                visible: modelData.kind === "Savings" && !!panel.questline.savings_accounts_available
                                                theme: panel.theme
                                                account: modelData
                                                viewport: questlineAccountList
                                                busy: panel.questlineWorkspace.busy || panel.questlineWorkspace.externalActions > 0
                                                onSaveRequested: payload => panel.runQuestlineAction(payload)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: panel.questlineTab === "Treasury" ? 300 : ["Tasks", "Sidequests", "Scrolls"].includes(panel.questlineTab) ? 340 : Math.min(430, frame.width * 0.32)
                            Layout.fillHeight: true
                            radius: 16
                            color: panel.theme.colors.background
                            ColumnLayout {
                                anchors { fill: parent; margins: 12 }
                                spacing: 10
                                Text {
                                    text: qsTranslate("Spectrum", panel.questlineTab) + "  ·  " + panel.questlineItems().length
                                    color: panel.theme.colors.foreground
                                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 2; bold: true }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: panel.questlineItems().length === 0
                                    text: panel.questlineTab === "Chronicles" ? qsTranslate("Spectrum", "No chronicles in this campaign yet.") : qsTranslate("Spectrum", "Nothing here yet. Use the New button above to get started.")
                                    wrapMode: Text.Wrap
                                    color: panel.theme.colors.muted
                                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                                }
                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    spacing: 7
                                    id: viewQuestlineItemList
                                    onContentYChanged: panel.queueQuestlineState()
                                    model: panel.questlineItems()
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: ListView.view.width
                                        height: 82
                                        radius: 10
                                        color: panel.questlineSelected && panel.questlineSelected.id === modelData.id ? Qt.tint(panel.theme.colors.surface_alt, Qt.rgba(panel.theme.colors.accent.r, panel.theme.colors.accent.g, panel.theme.colors.accent.b, 0.35)) : panel.theme.colors.surface_alt
                                        Column {
                                            anchors { fill: parent; margins: 10 }
                                            spacing: 4
                                            Text {
                                                width: parent.width
                                                elide: Text.ElideRight
                                                text: modelData.title || modelData.name || qsTranslate("Spectrum", "Untitled")
                                                color: panel.theme.colors.foreground
                                                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 4; bold: true }
                                            }
                                            Text {
                                                width: parent.width
                                                elide: Text.ElideRight
                                                text: panel.questlineTab === "Chronicles" ? (modelData.author_username || modelData.campaign || qsTranslate("Spectrum", "Unfiled")) : panel.questlineTab === "Treasury" ? qsTranslate("Spectrum", modelData.entry_type) + "  ·  " + modelData.currency_code + " " + (modelData.amount_minor / 100).toFixed(2) : panel.questlineTab === "Sidequests" ? qsTranslate("Spectrum", modelData.frequency) + " · " + modelData.completion_count + "/" + modelData.daily_target + qsTranslate("Spectrum", " today · ") + modelData.reward_xp + qsTranslate("Spectrum", " XP") : (modelData.campaign || qsTranslate("Spectrum", "Unfiled")) + (modelData.due_date ? "  ·  " + modelData.due_date : "")
                                                color: panel.theme.colors.muted
                                                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 1 }
                                            }
                                        }
                                        KeyboardAction {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onActivated: {
                                                panel.questlineDeleteTarget = null;
                                                panel.questlineSelected = parent.modelData;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 16
                            color: panel.theme.colors.background
                            ColumnLayout {
                                anchors { fill: parent; margins: 20 }
                                spacing: 12
                                TextEdit {
                                    activeFocusOnTab: true
                                    Keys.onTabPressed: nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
                                    Keys.onBacktabPressed: nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason)
                                    Layout.fillWidth: true
                                    text: panel.questlineSelected ? panel.questlineSelected.title || panel.questlineSelected.name || qsTranslate("Spectrum", "Untitled") : qsTranslate("Spectrum", "Select an item")
                                    readOnly: true
                                    selectByMouse: true
                                    persistentSelection: true
                                    wrapMode: TextEdit.Wrap
                                    textFormat: TextEdit.PlainText
                                    color: panel.theme.colors.foreground
                                    selectionColor: panel.theme.colors.accent
                                    selectedTextColor: panel.theme.colors.background
                                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 12; bold: true }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: !panel.questlineSelected ? qsTranslate("Spectrum", "Choose a row to see its details.") : panel.questlineTab === "Chronicles" ? panel.questlineSelected.campaign + (panel.questlineSelected.author_username ? " · " + panel.questlineSelected.author_username : "") : panel.questlineTab === "Sidequests" ? qsTranslate("Spectrum", panel.questlineSelected.frequency) + " · " + panel.questlineSelected.completion_count + "/" + panel.questlineSelected.daily_target + qsTranslate("Spectrum", " today · ") + panel.questlineSelected.reward_xp + qsTranslate("Spectrum", " XP per completion") : panel.questlineSelected.campaign || qsTranslate("Spectrum", "Unfiled")
                                    color: panel.theme.colors.muted
                                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: panel.questlineTab === "Treasury" && panel.questlineSelected !== null
                                    text: panel.questlineSelected ? panel.questlineSelected.currency_code + " " + (panel.questlineSelected.amount_minor / 100).toFixed(2) : ""
                                    color: panel.theme.colors.accent
                                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 15; bold: true }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: panel.questlineTab === "Treasury" && panel.questlineSelected !== null
                                    text: panel.questlineSelected ? qsTranslate("Spectrum", panel.questlineSelected.entry_type) + "  ·  " + qsTranslate("Spectrum", panel.questlineSelected.status) : ""
                                    color: panel.theme.colors.muted
                                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 1 }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: panel.questlineTab === "Tasks" && panel.questlineSelected !== null
                                    text: panel.questlineSelected ? qsTranslate("Spectrum", "Due ") + (panel.questlineSelected.due_date || qsTranslate("Spectrum", "anytime")) + "  ·  " + qsTranslate("Spectrum", panel.questlineSelected.priority) + qsTranslate("Spectrum", " priority") + (panel.questlineSelected.recurrence ? "  ·  " + qsTranslate("Spectrum", panel.questlineSelected.recurrence) : "") : ""
                                    color: panel.theme.colors.muted
                                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                                }
                                ShellButton {
                                    Layout.alignment: Qt.AlignRight
                                    visible: panel.questlineSelected !== null
                                    label: panel.questlineTab === "Scrolls" ? qsTranslate("Spectrum", "Copy scroll") : qsTranslate("Spectrum", "Copy details")
                                    fontFamily: panel.theme.fontFamily
                                    fontSize: panel.theme.fontSize
                                    backgroundColor: panel.theme.colors.surface_alt
                                    foregroundColor: panel.theme.colors.foreground
                                    onClicked: {
                                        detailText.selectAll();
                                        detailText.copy();
                                        detailText.deselect();
                                    }
                                }
                                Flickable {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    contentWidth: width
                                    id: viewQuestlineDetailFlick
                                    onContentYChanged: panel.queueQuestlineState()
                                    contentHeight: Math.max(height, detailText.implicitHeight)
                                    TextEdit {
                                        activeFocusOnTab: true
                                    Keys.onTabPressed: nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
                                    Keys.onBacktabPressed: nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason)
                                        id: detailText
                                        objectName: "questline-detail-text"
                                        width: parent.width
                                        readOnly: true
                                        selectByMouse: true
                                        persistentSelection: true
                                        wrapMode: TextEdit.Wrap
                                        textFormat: panel.questlineTab === "Scrolls" ? TextEdit.MarkdownText : TextEdit.PlainText
                                        onLinkActivated: link => Qt.openUrlExternally(link)
                                        text: !panel.questlineSelected ? "" : panel.questlineTab === "Scrolls" ? (panel.questlineSelected.markdown_content || "") : panel.questlineTab === "Treasury" ? panel.questlineEntryDetails(panel.questlineSelected) : (panel.questlineSelected.description || qsTranslate("Spectrum", "No description yet."))
                                        color: panel.theme.colors.foreground
                                        selectionColor: panel.theme.colors.accent
                                        selectedTextColor: panel.theme.colors.background
                                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 4 }
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: visible ? Math.min(430, frame.height * 0.43) : 0
                                    visible: panel.questlineTab === "Tasks" && panel.questlineSelected !== null
                                    radius: 12
                                    color: panel.theme.colors.surface_alt
                                    ColumnLayout {
                                        anchors { fill: parent; margins: 12 }
                                        spacing: 8
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                Layout.fillWidth: true
                                                text: qsTranslate("Spectrum", "Steps  ·  ") + panel.questlineSteps().filter(step => step.completed).length + "/" + panel.questlineSteps().length
                                                color: panel.theme.colors.foreground
                                                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 2; bold: true }
                                            }
                                            ShellButton {
                                                enabled: !!panel.questline.actions_available
                                                label: qsTranslate("Spectrum", "+ New step")
                                                fontFamily: panel.theme.fontFamily
                                                fontSize: panel.theme.fontSize
                                                backgroundColor: panel.theme.colors.accent
                                                foregroundColor: panel.theme.colors.background
                                                onClicked: panel.beginQuestlineStepEdit(null)
                                            }
                                        }
                                        Text {
                                            visible: panel.questlineSteps().length === 0
                                            text: qsTranslate("Spectrum", "No steps yet. Add one to break this task down.")
                                            color: panel.theme.colors.muted
                                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                                        }
                                        ListView {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            clip: true
                                            spacing: 6
                                            model: panel.questlineSteps()
                                            delegate: Rectangle {
                                                required property var modelData
                                                width: ListView.view.width
                                                height: 68
                                                radius: 8
                                                color: panel.theme.colors.background
                                                RowLayout {
                                                    anchors { fill: parent; margins: 7 }
                                                    spacing: 7
                                                    ShellButton {
                                                        enabled: !!panel.questline.actions_available && !questlineActionProcess.running && !panel.questlineWorkspace.busy
                                                        label: modelData.completed ? "↺" : "✓"
                                                        fontFamily: panel.theme.fontFamily
                                                        fontSize: panel.theme.fontSize + 2
                                                        backgroundColor: modelData.completed ? panel.theme.colors.surface_alt : panel.theme.colors.accent
                                                        foregroundColor: modelData.completed ? panel.theme.colors.foreground : panel.theme.colors.background
                                                        onClicked: panel.runQuestlineAction({ action: "toggle_step", id: modelData.id })
                                                    }
                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 1
                                                        Text {
                                                            Layout.fillWidth: true
                                                            elide: Text.ElideRight
                                                            text: modelData.title
                                                            color: panel.theme.colors.foreground
                                                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 1; strikeout: modelData.completed }
                                                        }
                                                        Text {
                                                            Layout.fillWidth: true
                                                            elide: Text.ElideRight
                                                            text: modelData.description || (modelData.due_date ? qsTranslate("Spectrum", "Due ") + modelData.due_date : "")
                                                            color: panel.theme.colors.muted
                                                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize - 1 }
                                                        }
                                                    }
                                                    ShellButton {
                                                        enabled: !!panel.questline.actions_available
                                                        label: qsTranslate("Spectrum", "Edit")
                                                        fontFamily: panel.theme.fontFamily
                                                        fontSize: panel.theme.fontSize
                                                        backgroundColor: panel.theme.colors.surface_alt
                                                        foregroundColor: panel.theme.colors.foreground
                                                        onClicked: panel.beginQuestlineStepEdit(modelData)
                                                    }
                                                    ShellButton {
                                                        enabled: !!panel.questline.actions_available && !questlineActionProcess.running && !panel.questlineWorkspace.busy
                                                        label: qsTranslate("Spectrum", "Delete")
                                                        fontFamily: panel.theme.fontFamily
                                                        fontSize: panel.theme.fontSize
                                                        backgroundColor: panel.theme.colors.surface_alt
                                                        foregroundColor: panel.theme.colors.foreground
                                                        onClicked: panel.askQuestlineDelete("step", modelData)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    CachedContent {
                        id: syncContent
                        requested: panel.expanded && panel.page === "questline" && panel.questlineTab === "Sync" && !panel.questlineEditing
                        visible: panel.page === "questline" && panel.questlineTab === "Sync" && !panel.questlineEditing
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        sourceComponent: QuestlineSync {
                            objectName:"questline-sync"
                            active: syncContent.requested
                            theme:panel.theme
                            backendDir:panel.backendDir
                            workspace:panel.questlineWorkspace
                            onRefreshRequested:panel.refreshQuestline()
                            onProfileRestored:panel.refreshQuestline()
                        }
                    }

                    CachedContent {
                        id: heroContent
                        requested: panel.expanded && panel.page === "questline" && panel.questlineTab === "Hero" && !panel.questlineEditing && !panel.questlineQuickScrollPicker
                        visible: panel.page === "questline" && panel.questlineTab === "Hero" && !panel.questlineEditing && !panel.questlineQuickScrollPicker
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        sourceComponent: QuestlineHero {
                            theme: panel.theme
                            hero: panel.questline.hero || null
                        }
                    }

                    QuestlineFocus {
                        id: viewQuestlineFocusEditor
                        objectName: "questline-focus"
                        visible: panel.page === "questline" && panel.questlineTab === "Focus" && !panel.questlineEditing && !panel.questlineQuickScrollPicker
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        theme: panel.theme
                        focusState: panel.focusState
                        questline: panel.questline
                        preferredCampaignId: panel.questlineCampaignId
                        onProjectIdChanged: panel.queueQuestlineState()
                        onTaskIdChanged: panel.queueQuestlineState()
                        onDurationChanged: panel.queueQuestlineState()
                        onSoundscapeChanged: panel.queueQuestlineState()
                        onFocusAction: action => panel.focusAction(action)
                        onFocusStart: request => panel.startFocus(request)
                    }
                }
            }

            CachedContent {
                id: focusContent
                requested: panel.expanded && panel.page === "focus"
                visible: panel.page === "focus"
                Layout.fillWidth: true
                sourceComponent: FocusControls {
                    id: focusEditor
                    viewActive: focusContent.requested
                    theme: panel.theme
                    focusState: panel.focusState
                    backendDir: panel.backendDir
                    onFocusAction: action => panel.focusAction(action)
                    onFocusStart: request => panel.startFocus(request)
                    onQuestlineRequested: { panel.switchQuestlineTab("Overview"); panel.open("questline"); }
                }
            }

            CachedContent {
                id: breakContent
                requested: panel.expanded && panel.page === "breaks"
                visible: panel.page === "breaks"
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: BreakReminders {
                    theme: panel.theme
                    manager: panel.breakState
                }
            }
            CachedContent {
                id: servicesContent
                requested: panel.expanded && panel.page === "services"
                visible: panel.page === "services"
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: LocalServices {
                    active: servicesContent.requested
                    theme: panel.theme
                    backendDir: panel.backendDir
                }
            }

            CachedContent {
                id: defaultAppsContent
                requested: panel.expanded && panel.page === "default-apps"
                visible: panel.page === "default-apps"
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: DefaultApps {
                    active: defaultAppsContent.requested
                    theme: panel.theme
                    backendDir: panel.backendDir
                }
            }

            ColorSwatch {
                Layout.fillWidth: true
                implicitHeight: 48
                visible: panel.page === "color" && panel.colorValue.length > 0
                value: panel.colorValue
                fontFamily: panel.theme.fontFamily
                fontSize: panel.theme.fontSize + 2
            }
            ShellButton {
                Layout.fillWidth: true
                visible: panel.page === "color"
                label: qsTranslate("Spectrum", "Pick colors")
                fontFamily: panel.theme.fontFamily
                fontSize: panel.theme.fontSize
                backgroundColor: panel.theme.colors.accent
                foregroundColor: panel.theme.colors.background
                onClicked: panel.beginColorPick()
            }
            Text {
                Layout.fillWidth: true
                visible: panel.page === "color"
                text: qsTranslate("Spectrum", "Click a color to copy its hex. Press Escape to finish picking.")
                color: panel.theme.colors.muted
                wrapMode: Text.WordWrap
                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize - 1 }
            }

            Text {
                Layout.fillWidth: true
                visible: panel.page === "color"
                text: qsTranslate("Spectrum", "SAVED COLORS · NEWEST FIRST")
                color: panel.theme.colors.accent
                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize; bold: true }
            }
            Text {
                Layout.fillWidth: true
                visible: panel.page === "color" && panel.savedColors.length === 0
                text: qsTranslate("Spectrum", "No saved colors yet. Pick one from the screen to start.")
                color: panel.theme.colors.muted
                wrapMode: Text.WordWrap
                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
            }
            GridView {
                id: colorGrid
                objectName: "saved-color-grid"
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: panel.page === "color"
                clip: true
                cellWidth: width / Math.max(1, Math.floor(width / Math.max(112, hexMetrics.advanceWidth("#FFFFFF") + 32)))
                cellHeight: 50
                model: panel.page === "color" ? panel.savedColors : []
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
                FontMetrics {
                    id: hexMetrics
                    font.family: panel.theme.fontFamily
                    font.pixelSize: panel.theme.fontSize
                    font.bold: true
                }
                delegate: ColorSwatch {
                    required property string modelData
                    objectName: "saved-color-" + modelData.slice(1)
                    width: colorGrid.cellWidth - 8
                    height: 42
                    value: modelData
                    selected: panel.colorValue === value
                    fontFamily: panel.theme.fontFamily
                    fontSize: panel.theme.fontSize
                    onCopied: panel.colorValue = value
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: panel.page === "password"
                spacing: 8
                Text {
                    text: qsTranslate("Spectrum", "Length: ") + panel.passwordLength
                    color: panel.theme.colors.foreground
                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                }
                Item { Layout.fillWidth: true }
                Repeater {
                    model: [{ label: "−", delta: -1 }, { label: "+", delta: 1 }]
                    ShellButton {
                        required property var modelData
                        label: modelData.label
                        fontFamily: panel.theme.fontFamily
                        fontSize: panel.theme.fontSize + 3
                        backgroundColor: panel.theme.colors.surface_alt
                        foregroundColor: panel.theme.colors.foreground
                        onClicked: {
                            panel.passwordLength = Math.max(8, Math.min(128, panel.passwordLength + modelData.delta));
                            panel.password = "";
                            panel.generatePassword();
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: panel.page === "password"
                spacing: 8
                Repeater {
                    model: [
                        { label: qsTranslate("Spectrum", "Letters"), key: "l" },
                        { label: qsTranslate("Spectrum", "Numbers"), key: "n" },
                        { label: qsTranslate("Spectrum", "Symbols"), key: "s" }
                    ]
                    ShellButton {
                        required property var modelData
                        Layout.fillWidth: true
                        label: modelData.label
                        fontFamily: panel.theme.fontFamily
                        fontSize: panel.theme.fontSize
                        backgroundColor: (modelData.key === "l" ? panel.useLetters : modelData.key === "n" ? panel.useNumbers : panel.useSymbols) ? panel.theme.colors.accent : panel.theme.colors.surface_alt
                        foregroundColor: (modelData.key === "l" ? panel.useLetters : modelData.key === "n" ? panel.useNumbers : panel.useSymbols) ? panel.theme.colors.background : panel.theme.colors.foreground
                        onClicked: {
                            if (modelData.key === "l" && (panel.useNumbers || panel.useSymbols)) panel.useLetters = !panel.useLetters;
                            if (modelData.key === "n" && (panel.useLetters || panel.useSymbols)) panel.useNumbers = !panel.useNumbers;
                            if (modelData.key === "s" && (panel.useLetters || panel.useNumbers)) panel.useSymbols = !panel.useSymbols;
                            panel.password = "";
                            panel.generatePassword();
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 48
                radius: 10
                color: panel.theme.colors.background
                visible: panel.page === "password"
                TextInput {
                    activeFocusOnTab: true
                    id: passwordValue
                    anchors { fill: parent; margins: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    readOnly: true
                    text: panel.password
                    color: panel.theme.colors.foreground
                    selectionColor: panel.theme.colors.accent
                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: panel.page === "password"
                spacing: 8
                ShellButton {
                    Layout.fillWidth: true
                    label: qsTranslate("Spectrum", "Generate")
                    fontFamily: panel.theme.fontFamily
                    fontSize: panel.theme.fontSize
                    backgroundColor: panel.theme.colors.accent
                    foregroundColor: panel.theme.colors.background
                    onClicked: panel.generatePassword()
                }
                ShellButton {
                    Layout.fillWidth: true
                    label: qsTranslate("Spectrum", "Copy")
                    enabled: panel.password.length > 0
                    fontFamily: panel.theme.fontFamily
                    fontSize: panel.theme.fontSize
                    backgroundColor: panel.theme.colors.surface_alt
                    foregroundColor: panel.theme.colors.foreground
                    onClicked: { passwordValue.selectAll(); passwordValue.copy(); passwordValue.deselect(); }
                }
            }

            CachedContent {
                id: dropContent
                requested: panel.expanded && panel.page === "spectrumdrop"
                visible: panel.page === "spectrumdrop"
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: SpectrumDrop {
                    theme: panel.theme
                    backend: spectrumDrop
                    onOpenFolderRequested: path => { panel.expanded = false; ApplicationLaunch.start(["uwsm", "app", "--", "xdg-open", path]); }
                }
            }
            CachedContent {
                id: hotkeyContent
                requested: panel.expanded && panel.page === "hotkey"
                visible: panel.page === "hotkey"
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: HotKeyEditor {
                    id: hotkeyEditor
                    theme: panel.theme
                    backend: hotkeys
                }
            }
            Item {
                visible: !["questline", "search", "emoji", "shortcuts", "hotkey", "spectrumdrop", "color", "calculator", "default-apps"].includes(panel.page)
                Layout.fillHeight: visible
            }
        }
    }

    function openFile(path): void {
        expanded = false;
        ApplicationLaunch.start(["uwsm", "app", "-t", "scope", "--", "gio", "open", path]);
    }

    function moveEmojiSelection(offset): void {
        if (!emojis.length)
            return;
        emojiSelectedIndex = Math.max(0, Math.min(emojis.length - 1, emojiSelectedIndex + offset));
        emojiList.positionViewAtIndex(emojiSelectedIndex, ListView.Contain);
    }

    function copySelectedEmoji(): void {
        const selected = emojis[emojiSelectedIndex];
        if (selected)
            copyEmoji(selected.character);
    }

    function copyEmoji(character): void {
        Quickshell.execDetached(["wl-copy", character]);
        expanded = false;
    }

}
