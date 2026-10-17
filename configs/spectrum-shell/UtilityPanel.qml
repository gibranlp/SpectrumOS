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
    readonly property bool cornerPanel: page === "spectrumdrop"
    readonly property bool cornerTop: cornerPanel && theme.barPosition === "top"
    readonly property bool sidePanel: page === "shortcuts"
    readonly property bool topPanel: page === "calendar" || page === "questline" || page === "focus"
    property var questline: ({ available: false, installed: false })
    required property var questlineWorkspace
    property bool questlineRestoring: false
    property bool questlineRestorePending: false
    property string questlineDraftKey: ""
    property bool questlineLoaded: false
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
    property var matches: []
    property int searchSelectedIndex: 0
    property var emojis: []
    property int emojiSelectedIndex: 0
    property string submittedEmojiQuery: ""
    property string submittedQuery: ""
    property string calculation: ""
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
    required property var focusState
    signal focusAction(string action)
    signal focusStart(var request)
    property var pendingShortcut: []

    function activateShortcut(index): void {
        if (shortcutDelay.running || index < 0 || index >= shortcuts.length)
            return;
        pendingShortcut = shortcuts[index].command;
        expanded = false;
        shortcutDelay.restart();
    }

    Timer {
        id: shortcutDelay
        // Espera a que el panel suelte el foco antes de ejecutar la acción.
        interval: 380
        onTriggered: {
            const command = panel.pendingShortcut;
            panel.pendingShortcut = [];
            Quickshell.execDetached(command);
        }
    }
    property date calendarMonth: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    readonly property var calendarDays: {
        const first = new Date(calendarMonth.getFullYear(), calendarMonth.getMonth(), 1);
        const offset = (first.getDay() + 6) % 7;
        const count = new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate();
        return Array.from({ length: offset + count }, (_, index) => index < offset ? 0 : index - offset + 1);
    }
    readonly property var shortcuts: [
        { combo: "Super + Shift + G", action: "Appearance", command: [backendDir + "/spectrum-shell-open", "appearance"] },
        { combo: "Super + Shift + E", action: "AppImage Manager", command: [backendDir + "/spectrum-shell-open", "appimages"] },
        { combo: "Super + D", action: "Applications", command: [backendDir + "/spectrum-shell-launcher"] },
        { combo: "Shift + Print", action: "Area screenshot", command: [backendDir + "/panel", "--screenshot-area"] },
        { combo: "Super + A", action: "Audio", command: [backendDir + "/spectrum-shell-open", "audio"] },
        { combo: "Super + Shift + A", action: "Audio recorder", command: [backendDir + "/spectrum-shell-open", "audio-recorder"] },
        { combo: "Super + Shift + L", action: "Bluetooth", command: [backendDir + "/spectrum-shell-open", "bluetooth"] },
        { combo: "Super + C", action: "Calculator", command: [backendDir + "/spectrum-shell-open", "calculator"] },
        { combo: "Super + Shift + C", action: "Calendar", command: [backendDir + "/spectrum-shell-open", "calendar"] },
        { combo: "Super + J", action: "Change window arrangement", command: ["hyprctl", "eval", "require(\"window-actions\").arrange()"] },
        { combo: "Ctrl + Shift + Space", action: "Clear notifications", command: [backendDir + "/spectrum-shell-open", "clear-notifications"] },
        { combo: "Super + P", action: "Control Center", command: [backendDir + "/spectrum-shell-open", "control"] },
        { combo: "Super + Shift + H", action: "Dashboard", command: [backendDir + "/spectrum-shell-open", "dashboard"] },
        { combo: "Ctrl + Space", action: "Dismiss latest notification", command: [backendDir + "/spectrum-shell-open", "dismiss-notification"] },
        { combo: "Super + Shift + O", action: "Displays", command: [backendDir + "/spectrum-shell-open", "displays"] },
        { combo: "Super + V", action: "Emoji picker", command: [backendDir + "/spectrum-shell-open", "emoji"] },
        { combo: "Super + E", action: "Files", command: ["uwsm", "app", "--", "thunar"] },
        { combo: "Super + S", action: "Find files", command: [backendDir + "/spectrum-shell-open", "search"] },
        { combo: "Super + F10", action: "Focus shell bar", command: [backendDir + "/spectrum-shell-open", "bar"] },
        { combo: "Super + Shift + F", action: "Focus timer", command: [backendDir + "/spectrum-shell-open", "focus"] },
        { combo: "Super + Down", action: "Focus window down", command: ["hyprctl", "eval", "require(\"window-actions\").focus(\"down\")"] },
        { combo: "Super + Left", action: "Focus window left", command: ["hyprctl", "eval", "require(\"window-actions\").focus(\"left\")"] },
        { combo: "Super + Right", action: "Focus window right", command: ["hyprctl", "eval", "require(\"window-actions\").focus(\"right\")"] },
        { combo: "Super + Up", action: "Focus window up", command: ["hyprctl", "eval", "require(\"window-actions\").focus(\"up\")"] },
        { combo: "Super + H", action: "HotKey", command: [backendDir + "/spectrum-shell-open", "hotkey"] },
        { combo: "Super + K", action: "Keyboard shortcuts", command: [backendDir + "/spectrum-shell-open", "shortcuts"] },
        { combo: "Super + Shift + X", action: "More widgets", command: [backendDir + "/spectrum-shell-open", "more"] },
        { combo: "Super + Shift + M", action: "Mouse Settings", command: [backendDir + "/spectrum-shell-open", "mouse"] },
        { combo: "Super + Shift + Down", action: "Move window down", command: ["hyprctl", "eval", "require(\"window-actions\").move(\"down\")"] },
        { combo: "Super + Shift + Left", action: "Move window left", command: ["hyprctl", "eval", "require(\"window-actions\").move(\"left\")"] },
        { combo: "Super + Shift + Right", action: "Move window right", command: ["hyprctl", "eval", "require(\"window-actions\").move(\"right\")"] },
        { combo: "Super + Shift + 1", action: "Move window to workspace 1", command: ["hyprctl", "eval", "local origin = hl.get_active_workspace(); hl.dispatch(hl.dsp.window.move({ workspace = 1 })); if origin then hl.dispatch(hl.dsp.focus({ workspace = origin.id })) end"] },
        { combo: "Super + Shift + 2", action: "Move window to workspace 2", command: ["hyprctl", "eval", "local origin = hl.get_active_workspace(); hl.dispatch(hl.dsp.window.move({ workspace = 2 })); if origin then hl.dispatch(hl.dsp.focus({ workspace = origin.id })) end"] },
        { combo: "Super + Shift + 3", action: "Move window to workspace 3", command: ["hyprctl", "eval", "local origin = hl.get_active_workspace(); hl.dispatch(hl.dsp.window.move({ workspace = 3 })); if origin then hl.dispatch(hl.dsp.focus({ workspace = origin.id })) end"] },
        { combo: "Super + Shift + 4", action: "Move window to workspace 4", command: ["hyprctl", "eval", "local origin = hl.get_active_workspace(); hl.dispatch(hl.dsp.window.move({ workspace = 4 })); if origin then hl.dispatch(hl.dsp.focus({ workspace = origin.id })) end"] },
        { combo: "Super + Shift + 5", action: "Move window to workspace 5", command: ["hyprctl", "eval", "local origin = hl.get_active_workspace(); hl.dispatch(hl.dsp.window.move({ workspace = 5 })); if origin then hl.dispatch(hl.dsp.focus({ workspace = origin.id })) end"] },
        { combo: "Super + Shift + 6", action: "Move window to workspace 6", command: ["hyprctl", "eval", "local origin = hl.get_active_workspace(); hl.dispatch(hl.dsp.window.move({ workspace = 6 })); if origin then hl.dispatch(hl.dsp.focus({ workspace = origin.id })) end"] },
        { combo: "Super + Shift + Up", action: "Move window up", command: ["hyprctl", "eval", "require(\"window-actions\").move(\"up\")"] },
        { combo: "Super + B", action: "Network", command: [backendDir + "/spectrum-shell-open", "network"] },
        { combo: "Super + T", action: "New Questline task", command: [backendDir + "/spectrum-shell-open", "new-task"] },
        { combo: "Super + Tab", action: "Next window", command: ["hyprctl", "eval", "require(\"window-actions\").cycle(true)"] },
        { combo: "Super + N", action: "Notification history", command: [backendDir + "/spectrum-shell-open", "notifications"] },
        { combo: "Super + G", action: "Password generator", command: [backendDir + "/spectrum-shell-open", "password"] },
        { combo: "Super + I", action: "Pick colors until Escape", command: [backendDir + "/spectrum-shell-open", "color"] },
        { combo: "Super + Shift + Space", action: "Pin floating window across workspaces", command: [backendDir + "/window-pin-toggle"] },
        { combo: "Super + Shift + P", action: "Power profiles", command: [backendDir + "/spectrum-shell-open", "power"] },
        { combo: "Super + Shift + Tab", action: "Previous window", command: ["hyprctl", "eval", "require(\"window-actions\").cycle(false)"] },
        { combo: "Super + Shift + Q", action: "Questline", command: [backendDir + "/spectrum-shell-open", "questline"] },
        { combo: "Super + Shift + N", action: "Quick note in Questline", command: [backendDir + "/spectrum-shell-open", "new-scroll"] },
        { combo: "Super + Ctrl + Down", action: "Resize window down", command: ["hyprctl", "dispatch", "hl.dsp.window.resize({ x = 0, y = 20, relative = true })"] },
        { combo: "Super + Ctrl + Left", action: "Resize window left", command: ["hyprctl", "dispatch", "hl.dsp.window.resize({ x = -20, y = 0, relative = true })"] },
        { combo: "Super + Ctrl + Right", action: "Resize window right", command: ["hyprctl", "dispatch", "hl.dsp.window.resize({ x = 20, y = 0, relative = true })"] },
        { combo: "Super + Ctrl + Up", action: "Resize window up", command: ["hyprctl", "dispatch", "hl.dsp.window.resize({ x = 0, y = -20, relative = true })"] },
        { combo: "Super + Shift + I", action: "Saved colors", command: [backendDir + "/spectrum-shell-open", "color-history"] },
        { combo: "Super + Shift + S", action: "Screen recorder", command: [backendDir + "/spectrum-shell-open", "recorder"] },
        { combo: "Print", action: "Screenshot menu", command: [backendDir + "/panel", "--capture"] },
        { combo: "Super + X", action: "Session controls", command: [backendDir + "/spectrum-shell-open", "session"] },
        { combo: "Super + Shift + D", action: "SpectrumDrop", command: [backendDir + "/spectrum-shell-open", "spectrumdrop"] },
        { combo: "Super + Shift + R", action: "Spectrumize me", command: [backendDir + "/theme-adapter", "random"] },
        { combo: "Super + U", action: "SpectrumOS updates", command: [backendDir + "/spectrum-shell-open", "updates"] },
        { combo: "Super + 1", action: "Switch to workspace 1", command: ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = 1 })"] },
        { combo: "Super + 2", action: "Switch to workspace 2", command: ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = 2 })"] },
        { combo: "Super + 3", action: "Switch to workspace 3", command: ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = 3 })"] },
        { combo: "Super + 4", action: "Switch to workspace 4", command: ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = 4 })"] },
        { combo: "Super + 5", action: "Switch to workspace 5", command: ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = 5 })"] },
        { combo: "Super + 6", action: "Switch to workspace 6", command: ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = 6 })"] },
        { combo: "Super + Return", action: "Terminal", command: ["uwsm", "app", "--", "kitty"] },
        { combo: "Super + Shift + T", action: "Time and region", command: [backendDir + "/spectrum-shell-open", "time"] },
        { combo: "Super + Space", action: "Toggle floating window", command: ["hyprctl", "dispatch", "hl.dsp.window.float({ action = \"toggle\" })"] },
        { combo: "Super + F", action: "Toggle fullscreen", command: ["hyprctl", "dispatch", "hl.dsp.window.fullscreen()"] },
        { combo: "Super + Shift + Y", action: "Typography", command: [backendDir + "/spectrum-shell-open", "typography"] },
        { combo: "Super + Shift + K", action: "UniversalKVM", command: ["/usr/bin/spectrum-ukvm"] },
        { combo: "Super + W", action: "Wallpapers", command: [backendDir + "/spectrum-shell-open", "wallpapers"] },
        { combo: "Super + Shift + W", action: "Weather", command: [backendDir + "/spectrum-shell-open", "weather"] }
    ]

    visible: motion.active
    color: "transparent"
    focusable: expanded
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "spectrum-widget-utilitypanel"
    anchors { top: true; bottom: true; left: true; right: true }

    function open(name): void {
        if (page === "questline") { rememberQuestline(); questlineWorkspace.flush(); }
        page = name;
        expanded = true;
        query.text = "";
        matches = [];
        searchSelectedIndex = 0;
        emojis = [];
        emojiSelectedIndex = 0;
        calculation = "";
        if (name === "shortcuts") {
            shortcutList.currentIndex = 0;
            shortcutList.positionViewAtBeginning();
            Qt.callLater(() => shortcutList.forceActiveFocus());
        }
        if (name === "hotkey") hotkeys.command(["status"]);
        if (name === "spectrumdrop") spectrumDrop.command(["status"]);
        if (name === "password")
            generatePassword();
        if (name === "calendar")
            calendarMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
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
        else if (name === "search" || name === "calculator" || name === "emoji")
            Qt.callLater(() => query.forceActiveFocus());
        if (name === "emoji")
            emojiDelay.restart();
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
                quickScrollProjects.currentIndex = 0;
                if (expanded) quickScrollProjects.forceActiveFocus();
            });
        }
    }
    function beginQuestlineQuickScroll(projectId): void {
        const campaigns = (questline.campaigns || []).filter(c => !c.is_shared);
        if (!campaigns.some(campaign => campaign.id === projectId)) return;
        switchQuestlineTab("Scrolls");
        questlineQuickScrollPicker = false;
        questlineScrollProjectId = projectId;
        beginQuestlineEdit(null);
        questlineTitle.text = "Quick note · " + Qt.formatDateTime(new Date(),"yyyy-MM-dd HH:mm");
        rememberQuestline();
        Qt.callLater(() => { if (expanded) questlineBody.forceActiveFocus(); });
    }

    function openQuestlineFullApp(): void {
        expanded = false;
        Quickshell.execDetached([backendDir + "/questline-open"]);
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
        if (questlineTab === "Sidequests") return questline.sidequests || [];
        return [];
    }

    function questlineSteps() {
        return questlineSelected && questlineTab === "Tasks" ? (questline.steps || []).filter(step => step.parent_task_id === questlineSelected.id) : [];
    }

    function questlineScrollProjects() {
        const projects = [];
        const seen = new Set();
        for (const scroll of questline.scrolls || []) {
            const id = scroll.project_id || "";
            if (!seen.has(id)) {
                seen.add(id);
                projects.push({ id: id, name: scroll.campaign || "Unfiled" });
            }
        }
        return projects.sort((a, b) => a.name.localeCompare(b.name));
    }

    function selectQuestlineTaskProject(id): void {
        questlineCampaignId = id;
        questlineSelected = null;
        questlineStepParent = null;
        questlineStepSelected = null;
        questlineDeleteTarget = null;
        questlinePendingId = "";
        questlineError = "";
        questlineMessage = "";
        selectQuestlineItem();
        if (id)
            Quickshell.execDetached([backendDir + "/spectrum-shell-tools", "questline-campaign", id]);
    }

    function selectQuestlineTreasuryProject(id): void {
        questlineTreasuryCampaignId = id;
        questlineSelected = null;
        questlineDeleteTarget = null;
        questlinePendingId = "";
        questlineError = "";
        questlineMessage = "";
        selectQuestlineItem();
    }

    function selectQuestlineScrollProject(id): void {
        questlineScrollProjectId = id;
        questlineSelected = null;
        questlineDeleteTarget = null;
        selectQuestlineItem();
    }

    function selectQuestlineItem(): void {
        const items = questlineItems();
        const previousId = questlinePendingId || (questlineSelected ? questlineSelected.id : "");
        questlineSelected = items.find(item => item.id === previousId) || items[0] || null;
        questlinePendingId = "";
    }

    function beginQuestlineEdit(item): void {
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
        questlineTitle.text = item ? item.title : "";
        questlineBody.text = item ? (questlineTab === "Scrolls" ? item.markdown_content : item.description || "") : "";
        questlineDate.text = item && item.due_date ? item.due_date : "";
        questlineAmount.text = item && item.amount_minor ? (item.amount_minor / 100).toFixed(2) : "";
        questlineSidequestFrequency = item && item.frequency ? item.frequency : "Daily";
        questlineSidequestReward = item && item.reward_xp !== undefined ? item.reward_xp : 20;
        questlineEntryType = item && item.entry_type ? item.entry_type : "Expense";
        questlineEntryStatus = item && item.status ? item.status : "Planned";
        const campaigns = (questline.campaigns || []).filter(c => !c.is_shared);
        const campaignId = item ? (item.project_id || item.campaign_id) : questlineTab === "Scrolls" ? questlineScrollProjectId : questlineTab === "Treasury" ? questlineTreasuryCampaignId : questlineCampaignId;
        if (item) {
            if (questlineTab === "Tasks") questlineCampaignId = campaignId || "";
            else if (questlineTab === "Scrolls") questlineScrollProjectId = campaignId || "";
            else if (questlineTab === "Treasury") questlineTreasuryCampaignId = campaignId || "";
        }
        questlineCampaignIndex = Math.max(0, campaigns.findIndex(c => c.id === campaignId));
        questlineEditCampaignId = campaigns.length ? campaigns[questlineCampaignIndex].id : "";
        questlineRestoring = false;
        rememberQuestline(!!item);
    }

    function beginQuestlineStepEdit(step): void {
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
        questlineTitle.text = step ? step.title : "";
        questlineBody.text = step ? step.description || "" : "";
        questlineDate.text = step && step.due_date ? step.due_date : "";
        questlineRestoring = false;
        rememberQuestline(!!step);
        Qt.callLater(() => questlineTitle.forceActiveFocus());
    }

    property string questlineEntryType: "Expense"
    property string questlineEntryStatus: "Planned"
    function setQuestlineDate(offset): void {
        const date = new Date();
        date.setHours(12, 0, 0, 0);
        date.setDate(date.getDate() + offset);
        questlineDate.text = Qt.formatDate(date, "yyyy-MM-dd");
        questlineCalendarOpen = false;
    }

    function selectQuestlineCampaign(): void {
        const campaigns = (questline.campaigns || []).filter(c => !c.is_shared);
        if (!campaigns.length) return;
        questlineCampaignIndex = (questlineCampaignIndex + 1) % campaigns.length;
        questlineEditCampaignId = campaigns[questlineCampaignIndex].id;
        if (questlineTab === "Treasury")
            questlineTreasuryCampaignId = campaigns[questlineCampaignIndex].id;
        if (questlineTab === "Tasks") {
            questlineCampaignId = campaigns[questlineCampaignIndex].id;
            Quickshell.execDetached([backendDir + "/spectrum-shell-tools", "questline-campaign", questlineCampaignId]);
        }
    }

    function questlineDraftPayload() {
        const kind = questlineStepParent ? "step" : questlineTab === "Tasks" ? "task"
            : questlineTab === "Scrolls" ? "scroll" : questlineTab === "Sidequests" ? "sidequest" : "entry";
        const selected = questlineStepParent ? questlineStepSelected : questlineSelected;
        const payload = {action:(selected ? "update_" : "create_") + kind,title:questlineTitle.text.trim()};
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
            payload.description = questlineBody.text;
            payload.due_date = questlineDate.text.trim();
            payload.priority = selected ? selected.priority : "Medium";
            const date = new Date(payload.due_date + "T12:00:00");
            if (payload.due_date && (!/^\d{4}-\d{2}-\d{2}$/.test(payload.due_date)
                || Number.isNaN(date.getTime()) || Qt.formatDate(date,"yyyy-MM-dd") !== payload.due_date)) reason = "Enter a valid date as YYYY-MM-DD.";
        } else if (kind === "scroll") {
            payload.content = questlineBody.text;
            if (!payload.content.trim() || payload.content.trim().length > 100000) reason = "Add scroll content (up to 100,000 characters).";
        } else if (kind === "sidequest") {
            payload.description = questlineBody.text;
            payload.frequency = questlineSidequestFrequency;
            payload.reward_xp = questlineSidequestReward;
        } else {
            payload.amount_minor = Math.round(Number(questlineAmount.text) * 100);
            payload.entry_type = questlineEntryType;
            payload.status = questlineEntryStatus;
            if (!/^\d+(\.\d{1,2})?$/.test(questlineAmount.text.trim()) || !Number.isSafeInteger(payload.amount_minor)
                || payload.amount_minor <= 0) reason = "Enter a positive amount with up to two decimals.";
        }
        return {payload:payload,valid:!reason,reason:reason};
    }

    function rememberQuestline(initial = false): void {
        if (questlineRestoring || !questlineWorkspace.ready || !questlineLoaded) return;
        if (questlineEditing && questlineDraftKey) {
            const draft = questlineDraftPayload();
            questlineWorkspace.update(questlineDraftKey,draft.payload,draft.valid,draft.reason,initial);
        }
        const view = {selected:questlineSelected,editing:questlineEditing,key:questlineDraftKey,quickScrollPicker:questlineQuickScrollPicker,
            stepParent:questlineStepParent,stepSelected:questlineStepSelected,campaignId:questlineCampaignId,
            treasuryCampaignId:questlineTreasuryCampaignId,scrollProjectId:questlineScrollProjectId,
            campaignIndex:questlineCampaignIndex,editCampaignId:questlineEditCampaignId,title:questlineTitle.text,body:questlineBody.text,
            date:questlineDate.text,amount:questlineAmount.text,frequency:questlineSidequestFrequency,
            reward:questlineSidequestReward,entryType:questlineEntryType,entryStatus:questlineEntryStatus,
            titleCursor:questlineTitle.cursorPosition,bodyCursor:questlineBody.cursorPosition,
            editorScroll:questlineEditorFlick.contentY,listScroll:questlineItemList.contentY,detailScroll:questlineDetailFlick.contentY,
            focus:{projectId:questlineFocusEditor.projectId,taskId:questlineFocusEditor.taskId,
                duration:questlineFocusEditor.duration,soundscape:questlineFocusEditor.soundscape}};
        questlineWorkspace.remember(questlineTab,view);
        if (questlineEditing && questlineDraftKey) questlineWorkspace.keepDraftView(questlineDraftKey,questlineTab,view);
    }

    function queueQuestlineState(): void {
        if (!questlineRestoring && page === "questline" && expanded) questlineRememberDelay.restart();
    }
    function restoreQuestline(tab, suppliedView = null): void {
        if (!questlineWorkspace.ready) return;
        questlineRestoring = true;
        questlineTab = ["Overview","Tasks","Sidequests","Scrolls","Treasury","Tree","Focus","Hero"].includes(tab) ? tab : "Overview";
        const view = suppliedView || questlineWorkspace.views[questlineTab] || {};
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
        questlineCampaignId = view.campaignId === undefined ? questlineCampaignId : view.campaignId;
        questlineTreasuryCampaignId = view.treasuryCampaignId === undefined ? questlineTreasuryCampaignId : view.treasuryCampaignId;
        questlineScrollProjectId = view.scrollProjectId === undefined ? questlineScrollProjectId : view.scrollProjectId;
        questlineEditCampaignId = (draft && draft.payload.project_id) || view.editCampaignId || "";
        const campaigns = (questline.campaigns || []).filter(c => !c.is_shared);
        questlineCampaignIndex = Math.max(0,campaigns.findIndex(item => item.id === questlineEditCampaignId));
        questlineTitle.text = view.title || "";
        questlineBody.text = view.body || "";
        questlineDate.text = view.date || "";
        questlineAmount.text = view.amount || "";
        questlineSidequestFrequency = view.frequency || "Daily";
        questlineSidequestReward = view.reward === undefined ? 20 : view.reward;
        questlineEntryType = view.entryType || "Expense";
        questlineEntryStatus = view.entryStatus || "Planned";
        if (view.focus && !questlineFocusEditor.active) {
            questlineFocusEditor.projectId = view.focus.projectId || "";
            questlineFocusEditor.taskId = view.focus.taskId || "";
            questlineFocusEditor.duration = view.focus.duration || 25;
            questlineFocusEditor.soundscape = view.focus.soundscape || "Silent";
        }
        if (!questlineEditing) selectQuestlineItem();
        questlineRestoring = false;
        Qt.callLater(() => {
            if (panel.questlineTab !== tab || panel.questlineDraftKey !== (view.key || "")) return;
            questlineRestoring = true;
            questlineTitle.cursorPosition = Math.min(view.titleCursor || 0,questlineTitle.length);
            questlineBody.cursorPosition = Math.min(view.bodyCursor || 0,questlineBody.length);
            questlineEditorFlick.contentY = Math.max(0,Math.min(view.editorScroll || 0,questlineEditorFlick.contentHeight - questlineEditorFlick.height));
            questlineItemList.contentY = view.listScroll || 0;
            questlineDetailFlick.contentY = view.detailScroll || 0;
            questlineRestoring = false;
            rememberQuestline();
        });
    }
    function switchQuestlineTab(tab): void {
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
    onExpandedChanged: if (!expanded && page === "questline") { rememberQuestline(); questlineWorkspace.flush(); }
    onQuestlineSelectedChanged: queueQuestlineState()
    onQuestlineSidequestFrequencyChanged: queueQuestlineState()
    onQuestlineSidequestRewardChanged: queueQuestlineState()
    onQuestlineEntryTypeChanged: queueQuestlineState()
    onQuestlineEntryStatusChanged: queueQuestlineState()
    onQuestlineCampaignIndexChanged: queueQuestlineState()
    onQuestlineEditCampaignIdChanged: queueQuestlineState()
    Connections {
        target: panel.questlineWorkspace
        function onReadyChanged() {
            if (panel.questlinePendingNewScroll) { panel.continueQuestlineQuickScroll(); return; }
            if (panel.questlineWorkspace.ready && panel.questlineLoaded && panel.questlineRestorePending) {
                panel.restoreQuestline(panel.questlineWorkspace.activeTab);
                panel.questlineRestorePending = false;
            }
        }
        function onSaved(key, id) {
            if (panel.questlineDraftKey === key && panel.questlineEditing && panel.expanded && panel.page === "questline" && id) {
                if (panel.questlineStepParent) panel.questlineStepSelected = Object.assign({},panel.questlineStepSelected || {},{id:id});
                else panel.questlineSelected = Object.assign({},panel.questlineSelected || {},{id:id});
                const draft = panel.questlineWorkspace.drafts[key];
                if (draft && draft.payload.project_id) {
                    if (panel.questlineTab === "Scrolls") panel.questlineScrollProjectId = draft.payload.project_id;
                    else if (panel.questlineTab === "Treasury") panel.questlineTreasuryCampaignId = draft.payload.project_id;
                    else if (panel.questlineTab === "Tasks") panel.questlineCampaignId = draft.payload.project_id;
                }
                panel.rememberQuestline();
            }
            panel.refreshQuestline();
        }
    }

    signal questlineCompleted()
    property bool questlineCompletionPending: false

    function runQuestlineAction(payload): void {
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
                panel.questlineCampaignId = saved;
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
            } catch (error) { panel.questlineError = "Questline action failed."; }
            panel.questlineCompletionPending = false;
        } }
    }

    Process {
        id: questlineProcess
        stdout: StdioCollector { onStreamFinished: {
            try {
                panel.questline = JSON.parse(text);
                panel.questlineLoaded = true;
                panel.questlineCampaignId = questlineTasks.resolveCampaign(panel.questlineCampaignId);
                panel.questlineTreasuryCampaignId = questlineTreasury.resolveCampaign(panel.questlineTreasuryCampaignId);
                const projects = panel.questlineScrollProjects();
                if (projects.length && !projects.some(project => project.id === panel.questlineScrollProjectId))
                    panel.questlineScrollProjectId = projects[0].id;
                if (!panel.questline.available)
                    panel.questlineEditing = false;
                else if (panel.questlinePendingNewScroll) {
                    panel.continueQuestlineQuickScroll();
                }
                else if (panel.questlinePendingNewTask) {
                    panel.questlinePendingNewTask = false;
                    panel.beginQuestlineEdit(null);
                    Qt.callLater(() => questlineTitle.forceActiveFocus());
                } else if (panel.questlineRestorePending && panel.questlineWorkspace.ready) {
                    panel.restoreQuestline(panel.questlineWorkspace.activeTab);
                    panel.questlineRestorePending = false;
                } else if (!panel.questlineEditing)
                    panel.selectQuestlineItem();
            }
            catch (error) { panel.questline = { available: false, installed: false, error: "Could not read Questline status." }; panel.questlineLoaded = true; }
        } }
    }

    Timer {
        interval: 30000
        running: panel.expanded && panel.page === "questline"
        repeat: true
        onTriggered: panel.refreshQuestline()
    }

    Timer {
        id: searchDelay
        interval: 260
        onTriggered: {
            if (panel.page === "search" && !searchProcess.running) {
                panel.submittedQuery = query.text;
                searchProcess.exec([panel.backendDir + "/spectrum-shell-tools", "search", query.text]);
            }
        }
    }

    Process {
        id: searchProcess
        stdout: StdioCollector { onStreamFinished: {
            if (panel.submittedQuery !== query.text || panel.page !== "search")
                return;
            try { panel.matches = JSON.parse(text); }
            catch (error) { panel.matches = []; }
            panel.searchSelectedIndex = 0;
            if (panel.matches.length)
                Qt.callLater(() => fileList.positionViewAtBeginning());
        } }
        onExited: {
            if (panel.expanded && panel.page === "search" && panel.submittedQuery !== query.text)
                searchDelay.restart();
        }
    }

    Process {
        id: calculatorProcess
        stdout: StdioCollector { onStreamFinished: panel.calculation = text.trim() }
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
        property bool awaitingChooser: false
        property var pendingAfterScan: []
        property var state: ({available: true, receiving: false, transfer: {}})
        property var peers: []
        property string error: ""
        property var requested: []
        readonly property bool busy: (spectrumDropProcess.running && requested[0] !== "status") || pending.length > 0 || pendingAfterScan.length > 0
        property var pending: []
        readonly property bool scanning: spectrumDropScan.running
        function command(args) {
            if (busy) return;
            if (spectrumDropProcess.running) {
                if (args[0] !== "status") pending = args;
                return;
            }
            if (args[0] === "send" && scanning) {
                pendingAfterScan = args;
                spectrumDropScan.signal(15);
                return;
            }
            requested = args;
            if (args[0] === "send") awaitingChooser = true;
            if (args[0] !== "status") error = "";
            spectrumDropProcess.exec([panel.backendDir + "/spectrumdrop-adapter"].concat(args));
            if (args[0] === "send" || args[0] === "folder") panel.expanded = false;
        }
        function scan() {
            if (scanning || busy || awaitingChooser || !state.visible || state.transfer?.active) return;
            spectrumDropScan.exec([panel.backendDir + "/spectrumdrop-adapter", "scan"]);
        }
    }
    Process {
        id: spectrumDropProcess
        onExited: {
            if (spectrumDrop.pending.length) {
                Qt.callLater(() => { const next = spectrumDrop.pending; spectrumDrop.pending = []; spectrumDrop.command(next); });
                return;
            }
            if (panel.expanded && panel.page === "spectrumdrop" && spectrumDrop.state.visible && spectrumDrop.peers.length === 0)
                Qt.callLater(() => spectrumDrop.scan());
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    if (!result.ok) {
                        spectrumDrop.error = result.error;
                        spectrumDrop.awaitingChooser = false;
                        if (spectrumDrop.requested[0] === "send" || spectrumDrop.requested[0] === "folder") panel.expanded = true;
                        return;
                    }
                    if (spectrumDrop.requested[0] === "folder") panel.expanded = true;
                    spectrumDrop.state = result;
                    if (spectrumDrop.awaitingChooser && result.transfer?.phase && result.transfer.phase !== "choosing") {
                        spectrumDrop.awaitingChooser = false;
                        if (panel.page === "spectrumdrop" && !panel.expanded) panel.spectrumDropReturnRequested();
                    }
                    if (spectrumDrop.requested[0] !== "status") spectrumDrop.error = "";
                    if (!result.visible && spectrumDrop.peers.length) spectrumDrop.peers = [];
                } catch (error) { spectrumDrop.error = "SpectrumDrop returned an invalid response."; }
            }
        }
    }
    Process {
        id: spectrumDropScan
        onExited: if (spectrumDrop.pendingAfterScan.length) Qt.callLater(() => {
            const next = spectrumDrop.pendingAfterScan;
            spectrumDrop.pendingAfterScan = [];
            spectrumDrop.command(next);
        })
        stdout: StdioCollector {
            onStreamFinished: {
                if (spectrumDrop.pendingAfterScan.length) return;
                try {
                    const result = JSON.parse(text);
                    if (result.ok && spectrumDrop.state.visible) {
                        if (JSON.stringify(spectrumDrop.peers) !== JSON.stringify(result.peers)) spectrumDrop.peers = result.peers;
                    }
                    else if (!result.ok) spectrumDrop.error = result.error;
                } catch (error) { spectrumDrop.error = "Device search returned an invalid response."; }
            }
        }
    }
    Timer { interval: 2000; repeat: true; running: (panel.expanded && panel.page === "spectrumdrop") || spectrumDrop.awaitingChooser; onTriggered: spectrumDrop.command(["status"]) }
    Timer { interval: 15000; repeat: true; running: panel.expanded && panel.page === "spectrumdrop" && !!spectrumDrop.state.visible; onTriggered: spectrumDrop.scan() }

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
                    if (hotkeys.requested[0] === "save") hotkeyEditor.clearForm();
                    if (hotkeys.requested[0] === "toggle" && result.rules.some(rule => rule.id === hotkeys.requested[1] && rule.active)) panel.expanded = false;
                } catch (error) { hotkeys.error = "HotKey service returned an invalid response."; }
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
        width: panel.cornerPanel ? Math.min(680, panel.screen.width - (panel.cornerTop ? 16 : panel.panelLeftInset + 16)) : panel.sidePanel ? Math.min(660, panel.screen.width - panel.panelLeftInset) : panel.page === "questline" ? Math.min(1500, panel.screen.width * 0.88) : Math.min(680, panel.screen.width - 40)
        height: panel.cornerPanel ? Math.min(650, panel.screen.height - (panel.cornerTop ? panel.topInset + 16 : 24)) : panel.sidePanel ? panel.screen.height - panel.topInset - 8 : panel.page === "hotkey" ? Math.min(650, panel.screen.height - 70) : panel.page === "questline" ? Math.min(1120, panel.screen.height * 0.82) : panel.page === "search" || panel.page === "emoji" ? Math.min(570, panel.screen.height - 90) : panel.page === "focus" ? Math.min(focusEditor.implicitHeight + 100, panel.screen.height - 50) : panel.page === "color" ? Math.min(530, 330 + panel.savedColors.length * 40, panel.screen.height - 50) : panel.page === "updates" || panel.page === "calendar" ? Math.min(430, panel.screen.height - 50) : Math.min(350, panel.screen.height - 50)
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
                Text {
                    text: panel.page === "spectrumdrop" ? "SpectrumDrop" : panel.page === "hotkey" ? "HotKey" : panel.page === "search" ? "Files" : panel.page === "calculator" ? "Calculator" : panel.page === "password" ? "Password generator" : panel.page === "shortcuts" ? "Keyboard shortcuts" : panel.page === "emoji" ? "Emoji" : panel.page === "focus" ? "Focus timer" : panel.page === "calendar" ? "Calendar" : panel.page === "questline" ? "Questline" : panel.page === "color" ? "Color picker" : "Updates"
                    color: panel.theme.colors.foreground
                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + (panel.page === "questline" ? 10 : 5); bold: true }
                }
                Item { Layout.fillWidth: true }
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
                visible: panel.page === "search" || panel.page === "calculator" || panel.page === "emoji"
                Text {
                    anchors { fill: parent; leftMargin: 14 }
                    verticalAlignment: Text.AlignVCenter
                    visible: !query.text
                    text: panel.page === "search" ? "Search files by name" : panel.page === "emoji" ? "Search emoji by name" : "Enter a calculation"
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
                        if (panel.page === "search") {
                            panel.matches = [];
                            panel.searchSelectedIndex = 0;
                            searchDelay.restart();
                        } else if (panel.page === "emoji") {
                            panel.emojis = [];
                            panel.emojiSelectedIndex = 0;
                            emojiDelay.restart();
                        }
                    }
                    Keys.onEscapePressed: panel.expanded = false
                    Keys.onUpPressed: event => {
                        if (panel.page === "emoji") panel.moveEmojiSelection(-1);
                        else if (panel.page === "search") panel.moveSearchSelection(-1);
                        else event.accepted = false;
                    }
                    Keys.onDownPressed: event => {
                        if (panel.page === "emoji") panel.moveEmojiSelection(1);
                        else if (panel.page === "search") panel.moveSearchSelection(1);
                        else event.accepted = false;
                    }
                    Keys.onReturnPressed: {
                        if (panel.page === "calculator" && !calculatorProcess.running)
                            calculatorProcess.exec([panel.backendDir + "/spectrum-shell-tools", "calculate", text]);
                        else if (panel.page === "emoji")
                            panel.copySelectedEmoji();
                        else if (panel.page === "search")
                            panel.openSelectedFile();
                    }
                    Keys.onEnterPressed: {
                        if (panel.page === "calculator" && !calculatorProcess.running)
                            calculatorProcess.exec([panel.backendDir + "/spectrum-shell-tools", "calculate", text]);
                        else if (panel.page === "emoji") panel.copySelectedEmoji();
                        else if (panel.page === "search") panel.openSelectedFile();
                    }
                }
            }

            ShellButton {
                Layout.fillWidth: true
                visible: panel.page === "calculator"
                label: "Calculate"
                fontFamily: panel.theme.fontFamily
                fontSize: panel.theme.fontSize
                backgroundColor: panel.theme.colors.accent
                foregroundColor: panel.theme.colors.background
                onClicked: {
                    if (!calculatorProcess.running)
                        calculatorProcess.exec([panel.backendDir + "/spectrum-shell-tools", "calculate", query.text]);
                }
            }

            Text {
                Layout.fillWidth: true
                visible: panel.page === "calculator"
                text: panel.calculation || "Use Numbat expressions, units, and conversions"
                color: panel.calculation ? panel.theme.colors.foreground : panel.theme.colors.muted
                wrapMode: Text.Wrap
                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 2 }
            }
            ShellButton {
                Layout.fillWidth: true
                visible: panel.page === "calculator"
                enabled: panel.calculation.length > 0 && !["Enter a calculation", "Invalid expression", "Calculator unavailable"].includes(panel.calculation)
                label: "Copy result"
                fontFamily: panel.theme.fontFamily
                fontSize: panel.theme.fontSize
                backgroundColor: panel.theme.colors.surface_alt
                foregroundColor: panel.theme.colors.foreground
                onClicked: Quickshell.execDetached(["wl-copy", panel.calculation])
            }

            ListView {
                id: fileList
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: panel.page === "search"
                clip: true
                spacing: 4
                model: panel.matches
                delegate: Rectangle {
                    required property string modelData
                    required property int index
                    readonly property bool selected: index === panel.searchSelectedIndex
                    width: ListView.view.width
                    height: 48
                    radius: 9
                    color: selected ? panel.theme.colors.accent : fileMouse.containsMouse ? panel.theme.colors.surface_alt : panel.theme.colors.surface
                    Text {
                        anchors { fill: parent; margins: 10 }
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideMiddle
                        text: parent.modelData
                        color: parent.selected ? panel.theme.colors.background : panel.theme.colors.foreground
                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                    }
                    KeyboardAction {
                        id: fileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onActivated: panel.openFile(parent.modelData)
                    }
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
                visible: panel.page === "search" && panel.matches.length === 0
                text: query.text.length < 2 ? "Enter at least two characters" : "No matching files"
                color: panel.theme.colors.muted
                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
            }

            Text {
                Layout.fillWidth: true
                visible: panel.page === "shortcuts"
                text: "Click a shortcut to run it, or use ↑ / ↓ and Enter."
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

            RowLayout {
                Layout.fillWidth: true
                visible: panel.page === "questline"
                Item { Layout.fillWidth: true }
                ShellButton {
                    label: "Open full app"
                    visible: panel.questline.available
                    enabled: panel.questline.installed
                    fontFamily: panel.theme.fontFamily
                    fontSize: panel.theme.fontSize
                    backgroundColor: panel.theme.colors.surface_alt
                    foregroundColor: panel.theme.colors.foreground
                    onClicked: panel.openQuestlineFullApp()
                }
                ShellButton {
                    label: "Refresh"
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
                text: "Checking Questline profile…"
                color: panel.theme.colors.muted
                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
            }
            Text {
                Layout.fillWidth: true
                visible: panel.page === "questline" && panel.questlineLoaded && !panel.questline.available && !panel.questline.needs_onboarding
                text: panel.questline.error || (panel.questline.installed ? "Questline could not load your character. Open the full app to inspect your profile." : "Questline is not installed yet.")
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
                    text: "Set up Questline"
                    color: panel.theme.colors.foreground
                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 15; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    text: "Choose how to begin. Your character and progress will appear here after Questline finishes setup."
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
                                text: "Create a character"
                                color: panel.theme.colors.foreground
                                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 6; bold: true }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Open the full app, choose New Adventurer, then pick a name and class."
                                wrapMode: Text.WordWrap
                                color: panel.theme.colors.muted
                                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 1 }
                            }
                            Item { Layout.fillHeight: true }
                            ShellButton {
                                enabled: panel.questline.installed
                                label: "Create in Questline"
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
                                text: "Continue from another PC"
                                color: panel.theme.colors.foreground
                                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 6; bold: true }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "On the old PC, use Sync → Export Profile and wait for the backup. Here, choose Continue the Adventure in Questline and paste its Transfer Code. Keep the code private."
                                wrapMode: Text.WordWrap
                                color: panel.theme.colors.muted
                                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 1 }
                            }
                            Item { Layout.fillHeight: true }
                            ShellButton {
                                enabled: panel.questline.installed
                                label: "Enter Transfer Code"
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
                    text: "Return here and press Refresh when setup is complete."
                    color: panel.theme.colors.muted
                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                }
                Item { Layout.fillHeight: true }
            }
            Text {
                Layout.fillWidth: true
                visible: panel.page === "questline" && panel.questline.available && !panel.questline.actions_available
                text: "Update Questline to enable editing and tree care here."
                color: panel.theme.colors.muted
                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
            }
            Flow {
                Layout.fillWidth: true
                visible: panel.page === "questline" && panel.questline.available
                spacing: 6
                Repeater {
                    model: ["Overview", "Tasks", "Sidequests", "Scrolls", "Treasury", "Tree", "Focus", "Hero"]
                    ShellButton {
                        required property string modelData
                        label: modelData
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
                    text: "Quick note — choose a project"
                    color: panel.theme.colors.foreground
                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 4; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    text: quickScrollProjects.count ? "Select a project and start writing. Your note saves automatically." : "Create an active personal campaign in Questline first, then try the shortcut again."
                    wrapMode: Text.Wrap
                    color: panel.theme.colors.muted
                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                }
                ListView {
                    id: quickScrollProjects
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
                        backgroundColor: quickScrollProjects.currentIndex === index ? panel.theme.colors.accent : panel.theme.colors.surface_alt
                        foregroundColor: quickScrollProjects.currentIndex === index ? panel.theme.colors.background : panel.theme.colors.foreground
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
                        label: "Resume draft: " + (panel.questlineWorkspace.drafts[modelData].view.title || "Untitled")
                        fontFamily: panel.theme.fontFamily; fontSize: panel.theme.fontSize
                        onClicked: panel.restoreQuestline(panel.questlineTab,panel.questlineWorkspace.drafts[modelData].view)
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: panel.page === "questline" && panel.questline.available && !panel.questlineEditing && !panel.questlineQuickScrollPicker && panel.questlineTab !== "Tree" && panel.questlineTab !== "Overview" && panel.questlineTab !== "Focus" && panel.questlineTab !== "Hero"
                ShellButton {
                    visible: ["Tasks", "Sidequests", "Scrolls", "Treasury"].includes(panel.questlineTab)
                    enabled: !!panel.questline.actions_available && (panel.questlineTab !== "Sidequests" || !!panel.questline.sidequests_available)
                    label: panel.questlineTab === "Sidequests" ? "+ New sidequest" : panel.questlineTab === "Scrolls" ? "+ New scroll" : panel.questlineTab === "Treasury" ? "+ New entry" : "+ New task"
                    fontFamily: panel.theme.fontFamily
                    fontSize: panel.theme.fontSize
                    backgroundColor: panel.theme.colors.accent
                    foregroundColor: panel.theme.colors.background
                    onClicked: panel.beginQuestlineEdit(null)
                }
                ShellButton {
                    visible: panel.questlineSelected !== null && ["Tasks", "Sidequests", "Scrolls", "Treasury"].includes(panel.questlineTab)
                    enabled: !!panel.questline.actions_available && (panel.questlineTab !== "Sidequests" || !!panel.questline.sidequests_available)
                    label: "Edit"
                    fontFamily: panel.theme.fontFamily
                    fontSize: panel.theme.fontSize
                    backgroundColor: panel.theme.colors.surface_alt
                    foregroundColor: panel.theme.colors.foreground
                    onClicked: panel.beginQuestlineEdit(panel.questlineSelected)
                }
                ShellButton {
                    visible: panel.questlineSelected !== null && ["Tasks", "Sidequests", "Scrolls"].includes(panel.questlineTab)
                    enabled: !!panel.questline.actions_available && (panel.questlineTab !== "Sidequests" || !!panel.questline.sidequests_available) && !questlineActionProcess.running && !panel.questlineWorkspace.busy
                    label: "Delete"
                    fontFamily: panel.theme.fontFamily
                    fontSize: panel.theme.fontSize
                    backgroundColor: panel.theme.colors.surface_alt
                    foregroundColor: panel.theme.colors.foreground
                    onClicked: panel.askQuestlineDelete(panel.questlineTab === "Tasks" ? "task" : panel.questlineTab === "Sidequests" ? "sidequest" : "scroll", panel.questlineSelected)
                }
                Item { Layout.fillWidth: true }
                ShellButton {
                    visible: panel.questlineSelected !== null && ["Tasks", "Sidequests"].includes(panel.questlineTab)
                    enabled: !!panel.questline.actions_available && (panel.questlineTab !== "Sidequests" || !!panel.questline.sidequests_available) && !questlineActionProcess.running && !panel.questlineWorkspace.busy && (panel.questlineTab !== "Sidequests" || (!!panel.questlineSelected && panel.questlineSelected.completion_count < panel.questlineSelected.daily_target))
                    label: panel.questlineTab === "Sidequests" ? "Complete sidequest" : "Complete task"
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
                        const kind = target.kind === "task" ? "task" : target.kind;
                        const linked = target.kind === "task" && target.stepCount ? " and its " + target.stepCount + " linked step" + (target.stepCount === 1 ? "" : "s") : "";
                        return "Permanently delete " + kind + " ‘" + target.title + "’" + linked + "?";
                    }
                    color: panel.theme.colors.foreground
                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                }
                ShellButton {
                    label: "Cancel"
                    fontFamily: panel.theme.fontFamily
                    fontSize: panel.theme.fontSize
                    backgroundColor: panel.theme.colors.surface_alt
                    foregroundColor: panel.theme.colors.foreground
                    onClicked: panel.questlineDeleteTarget = null
                }
                ShellButton {
                    enabled: !questlineActionProcess.running && !panel.questlineWorkspace.busy
                    label: "Delete permanently"
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
                    text: panel.questlineStepParent ? (panel.questlineStepSelected ? "Edit step" : "New step for " + panel.questlineStepParent.title) : (panel.questlineSelected ? "Edit " : "New ") + (panel.questlineTab === "Sidequests" ? "sidequest" : panel.questlineTab === "Scrolls" ? "scroll" : panel.questlineTab === "Treasury" ? "treasury entry" : "task")
                    color: panel.theme.colors.foreground
                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 3; bold: true }
                }
                ShellButton {
                    visible: panel.questlineSelected === null && panel.questlineStepParent === null && panel.questlineTab !== "Sidequests"
                    label: {
                        const campaigns = (panel.questline.campaigns || []).filter(c => !c.is_shared);
                        return campaigns.length ? "Campaign: " + campaigns[panel.questlineCampaignIndex % campaigns.length].name + "  ›" : "No active campaign";
                    }
                    fontFamily: panel.theme.fontFamily
                    fontSize: panel.theme.fontSize
                    backgroundColor: panel.theme.colors.surface_alt
                    foregroundColor: panel.theme.colors.foreground
                    onClicked: panel.selectQuestlineCampaign()
                }
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 44; radius: 8; color: panel.theme.colors.background
                    TextInput {
                        activeFocusOnTab: true
                        id: questlineTitle
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
                        text: "Frequency"
                        color: panel.theme.colors.foreground
                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                    }
                    FocusChoice {
                        Layout.preferredWidth: 220
                        theme: panel.theme
                        model: panel.questlineSidequestFrequencies
                        currentIndex: Math.max(0, panel.questlineSidequestFrequencies.indexOf(panel.questlineSidequestFrequency))
                        onActivated: panel.questlineSidequestFrequency = panel.questlineSidequestFrequencies[currentIndex]
                    }
                    Text {
                        text: "XP per completion"
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
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: panel.questlineTab === "Tasks"
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Due date"; color: panel.theme.colors.foreground; font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize } }
                        ShellButton {
                            label: "Today"
                            fontFamily: panel.theme.fontFamily; fontSize: panel.theme.fontSize
                            backgroundColor: panel.theme.colors.surface_alt; foregroundColor: panel.theme.colors.foreground
                            onClicked: panel.setQuestlineDate(0)
                        }
                        ShellButton {
                            label: "Tomorrow"
                            fontFamily: panel.theme.fontFamily; fontSize: panel.theme.fontSize
                            backgroundColor: panel.theme.colors.surface_alt; foregroundColor: panel.theme.colors.foreground
                            onClicked: panel.setQuestlineDate(1)
                        }
                        ShellButton {
                            label: "Choose date"
                            fontFamily: panel.theme.fontFamily; fontSize: panel.theme.fontSize
                            backgroundColor: panel.theme.colors.surface_alt; foregroundColor: panel.theme.colors.foreground
                            onClicked: {
                                const selected = questlineDate.text ? new Date(questlineDate.text + "T12:00:00") : new Date();
                                panel.questlineCalendarMonth = Number.isNaN(selected.getTime()) ? new Date() : selected;
                                panel.questlineCalendarOpen = !panel.questlineCalendarOpen;
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 44; radius: 8; color: panel.theme.colors.background
                        TextInput {
                            activeFocusOnTab: true
                            id: questlineDate
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
                            visible: !questlineDate.text
                            text: "No due date"
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
                                model: ["M", "T", "W", "T", "F", "S", "S"]
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
                                        questlineDate.text = Qt.formatDate(date, "yyyy-MM-dd");
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
                        visible: panel.questlineSelected === null || panel.questlineDraftKey.indexOf(":new-") >= 0
                        label: panel.questlineEntryType + "  ›"
                        fontFamily: panel.theme.fontFamily; fontSize: panel.theme.fontSize
                        backgroundColor: panel.theme.colors.surface_alt; foregroundColor: panel.theme.colors.foreground
                        onClicked: panel.questlineEntryType = panel.questlineEntryType === "Expense" ? "Income" : "Expense"
                    }
                    ShellButton {
                        label: "Status: " + panel.questlineEntryStatus + "  ›"
                        fontFamily: panel.theme.fontFamily; fontSize: panel.theme.fontSize
                        backgroundColor: panel.theme.colors.surface_alt; foregroundColor: panel.theme.colors.foreground
                        onClicked: {
                            const statuses = ["Planned", "Approved", "Paid", "Cancelled"];
                            panel.questlineEntryStatus = statuses[(statuses.indexOf(panel.questlineEntryStatus) + 1) % statuses.length];
                        }
                    }
                    Text { text: "Amount"; color: panel.theme.colors.foreground; font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize } }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 44; radius: 8; color: panel.theme.colors.background
                        TextInput {
                            activeFocusOnTab: true
                            id: questlineAmount
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
                        id: questlineEditorFlick
                        onContentYChanged: panel.queueQuestlineState()
                        contentHeight: Math.max(height, questlineBody.implicitHeight)
                        clip: true
                        TextEdit {
                            activeFocusOnTab: true
                            Keys.onTabPressed: nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
                            Keys.onBacktabPressed: nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason)
                            id: questlineBody
                            objectName: "questline-body"
                            onTextChanged: panel.queueQuestlineState()
                            onCursorPositionChanged: panel.queueQuestlineState()
                            width: parent.width
                            wrapMode: TextEdit.Wrap
                            color: panel.theme.colors.foreground
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                        }
                    }
                }
                Item { Layout.fillHeight: panel.questlineTab === "Treasury" }
                RowLayout {
                    Layout.fillWidth: true
                    ShellButton {
                        label: "Back"
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
                        label: "Retry"
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
                            { label: "OPEN TASKS", value: String((panel.questline.tasks || []).length), tab: "Tasks" },
                            { label: "SCROLLS", value: String((panel.questline.scrolls || []).length), tab: "Scrolls" },
                            { label: "TREASURY ENTRIES", value: String((panel.questline.entries || []).length), tab: "Treasury" },
                            { label: "EVERGROWTH", value: panel.questline.tree ? "Stage " + panel.questline.tree.stage : "—", tab: "Tree" }
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
                        title: "Upcoming tasks"
                        kind: "Tasks"
                        items: panel.questline.tasks || []
                        theme: panel.theme
                        onItemChosen: item => {
                            panel.switchQuestlineTab("Tasks");
                            panel.questlineCampaignId = item.project_id || "";
                            panel.questlineSelected = item;
                        }
                    }
                    QuestlineOverviewColumn {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        title: "Recent scrolls"
                        kind: "Scrolls"
                        items: (panel.questline.scrolls || []).slice(0, 8)
                        theme: panel.theme
                        onItemChosen: item => {
                            panel.switchQuestlineTab("Scrolls");
                            panel.questlineScrollProjectId = item.project_id || "";
                            panel.questlineSelected = item;
                        }
                    }
                    QuestlineOverviewColumn {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        title: "Recent treasury"
                        kind: "Treasury"
                        items: (panel.questline.entries || []).slice(0, 8)
                        theme: panel.theme
                        onItemChosen: item => {
                            panel.switchQuestlineTab("Treasury");
                            panel.questlineTreasuryCampaignId = item.campaign_id || "";
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
                        visible: !panel.questline.tree || !panel.questline.tree.bonsai_html
                        text: "Questline's current tree renderer is unavailable."
                        color: panel.theme.colors.muted
                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                    }
                    Flickable {
                        anchors { fill: parent; margins: 16 }
                        visible: !!panel.questline.tree && !!panel.questline.tree.bonsai_html
                        contentWidth: Math.max(width, bonsaiText.implicitWidth)
                        contentHeight: Math.max(height, bonsaiText.implicitHeight)
                        clip: true
                        Text {
                            id: bonsaiText
                            x: Math.max(0, (parent.width - implicitWidth) / 2)
                            y: Math.max(0, (parent.height - implicitHeight) / 2)
                            textFormat: Text.RichText
                            text: panel.questline.tree ? panel.questline.tree.bonsai_html || "" : ""
                            color: panel.theme.colors.foreground
                            font { family: "monospace"; pixelSize: Math.min(32, Math.max(16, (frame.width - 340) / 35)) }
                        }
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
                            text: "THE EVERGROWTH"
                            color: panel.theme.colors.muted
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize; bold: true }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: panel.questline.tree ? ["", "Acorn", "Sprout", "Young Entling", "Grove Guardian", "Ancient Ent", "Evergrowth Elder"][Math.min(Math.max(panel.questline.tree.stage, 1), 6)] : "Unplanted"
                            wrapMode: Text.Wrap
                            color: panel.theme.colors.foreground
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 7; bold: true }
                        }
                        Text {
                            text: panel.questline.tree ? "Stage " + panel.questline.tree.stage + "  ·  " + panel.questline.tree.growth + " growth" : ""
                            color: panel.theme.colors.muted
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                        }
                        Text {
                            text: panel.questline.tree ? "Health  " + panel.questline.tree.health + "%" : ""
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
                            text: panel.questline.tree ? (panel.questline.tree.water_today > 0 ? "Watered today" : "Ready for today's watering") : ""
                            color: panel.theme.colors.muted
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                        }
                        Text {
                            text: panel.questline.tree ? "Total waterings  " + panel.questline.tree.total_waterings : ""
                            color: panel.theme.colors.muted
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: panel.questline.tree && panel.questline.tree.last_watered ? "Last watered  " + new Date(panel.questline.tree.last_watered).toLocaleDateString() : "Ready for its first watering"
                            wrapMode: Text.Wrap
                            color: panel.theme.colors.muted
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                        }
                        Item { Layout.fillHeight: true }
                        ShellButton {
                            Layout.fillWidth: true
                            enabled: !!panel.questline.actions_available && !!panel.questline.tree && !questlineActionProcess.running && !panel.questlineWorkspace.busy && panel.questline.tree.water_today < 1
                            label: panel.questline.tree && panel.questline.tree.water_today > 0 ? "Watered today" : "Water tree"
                            fontFamily: panel.theme.fontFamily
                            fontSize: panel.theme.fontSize
                            backgroundColor: panel.theme.colors.accent
                            foregroundColor: panel.theme.colors.background
                            onClicked: panel.runQuestlineAction({ action: "water_tree" })
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: panel.page === "questline" && panel.questline.available && panel.questlineTab !== "Tree" && panel.questlineTab !== "Overview" && panel.questlineTab !== "Focus" && panel.questlineTab !== "Hero" && !panel.questlineEditing && !panel.questlineQuickScrollPicker
                spacing: 14

                Rectangle {
                    visible: ["Scrolls", "Tasks", "Treasury"].includes(panel.questlineTab)
                    Layout.preferredWidth: visible ? 250 : 0
                    Layout.fillHeight: true
                    radius: 16
                    color: panel.theme.colors.background
                    ColumnLayout {
                        anchors { fill: parent; margins: 12 }
                        spacing: 10
                        Text {
                            text: panel.questlineTab === "Scrolls" ? "Projects" : "Campaigns"
                            color: panel.theme.colors.foreground
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 2; bold: true }
                        }
                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 7
                            model: panel.questlineTab === "Tasks" ? questlineTasks.projects : panel.questlineTab === "Treasury" ? questlineTreasury.projects : panel.questlineScrollProjects()
                            delegate: Rectangle {
                                required property var modelData
                                width: ListView.view.width
                                height: 64
                                radius: 10
                                color: (panel.questlineTab === "Tasks" ? panel.questlineCampaignId : panel.questlineTab === "Treasury" ? panel.questlineTreasuryCampaignId : panel.questlineScrollProjectId) === modelData.id ? Qt.tint(panel.theme.colors.surface_alt, Qt.rgba(panel.theme.colors.accent.r, panel.theme.colors.accent.g, panel.theme.colors.accent.b, 0.35)) : panel.theme.colors.surface_alt
                                Text {
                                    anchors { fill: parent; margins: 10 }
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                    text: modelData.name + (panel.questlineTab !== "Scrolls" ? "  ·  " + modelData.count : "")
                                    color: panel.theme.colors.foreground
                                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 1 }
                                }
                                KeyboardAction {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onActivated: {
                                        if (panel.questlineTab === "Tasks") panel.selectQuestlineTaskProject(parent.modelData.id);
                                        else if (panel.questlineTab === "Treasury") panel.selectQuestlineTreasuryProject(parent.modelData.id);
                                        else panel.selectQuestlineScrollProject(parent.modelData.id);
                                    }
                                }
                            }
                        }
                    }
                }

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
                            text: "Current accounts"
                            color: panel.theme.colors.foreground
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 2; bold: true }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: questlineAccountList.count === 0
                            text: "No accounts with a nonzero balance."
                            wrapMode: Text.Wrap
                            color: panel.theme.colors.muted
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                        }
                        ListView {
                            id: questlineAccountList
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
                                        text: modelData.campaign + " · " + modelData.kind
                                        wrapMode: Text.Wrap
                                        color: panel.theme.colors.muted
                                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize - 2 }
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
                            text: panel.questlineTab + "  ·  " + panel.questlineItems().length
                            color: panel.theme.colors.foreground
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 2; bold: true }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: panel.questlineItems().length === 0
                            text: "Nothing here yet. Use the New button above to get started."
                            wrapMode: Text.Wrap
                            color: panel.theme.colors.muted
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                        }
                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 7
                            id: questlineItemList
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
                                        text: modelData.title || modelData.name || "Untitled"
                                        color: panel.theme.colors.foreground
                                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 4; bold: true }
                                    }
                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: panel.questlineTab === "Treasury" ? modelData.entry_type + "  ·  " + modelData.currency_code + " " + (modelData.amount_minor / 100).toFixed(2) : panel.questlineTab === "Sidequests" ? modelData.frequency + " · " + modelData.completion_count + "/" + modelData.daily_target + " today · " + modelData.reward_xp + " XP" : (modelData.campaign || "Unfiled") + (modelData.due_date ? "  ·  " + modelData.due_date : "")
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
                            text: panel.questlineSelected ? panel.questlineSelected.title || panel.questlineSelected.name || "Untitled" : "Select an item"
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
                            text: !panel.questlineSelected ? "Choose a row to see its details." : panel.questlineTab === "Sidequests" ? panel.questlineSelected.frequency + " · " + panel.questlineSelected.completion_count + "/" + panel.questlineSelected.daily_target + " today · " + panel.questlineSelected.reward_xp + " XP per completion" : panel.questlineSelected.campaign || "Unfiled"
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
                            text: panel.questlineSelected ? panel.questlineSelected.entry_type + "  ·  " + panel.questlineSelected.status : ""
                            color: panel.theme.colors.muted
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 1 }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: panel.questlineTab === "Tasks" && panel.questlineSelected !== null
                            text: panel.questlineSelected ? "Due " + (panel.questlineSelected.due_date || "anytime") + "  ·  " + panel.questlineSelected.priority + " priority" : ""
                            color: panel.theme.colors.muted
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                        }
                        ShellButton {
                            Layout.alignment: Qt.AlignRight
                            visible: panel.questlineSelected !== null
                            label: panel.questlineTab === "Scrolls" ? "Copy scroll" : "Copy details"
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
                            id: questlineDetailFlick
                            onContentYChanged: panel.queueQuestlineState()
                            contentHeight: Math.max(height, detailText.implicitHeight)
                            TextEdit {
                                activeFocusOnTab: true
                            Keys.onTabPressed: nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
                            Keys.onBacktabPressed: nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason)
                                id: detailText
                                width: parent.width
                                readOnly: true
                                selectByMouse: true
                                persistentSelection: true
                                wrapMode: TextEdit.Wrap
                                textFormat: TextEdit.PlainText
                                text: !panel.questlineSelected ? "" : panel.questlineTab === "Scrolls" ? (panel.questlineSelected.markdown_content || "") : panel.questlineTab === "Treasury" ? panel.questlineSelected.entry_type + " · " + panel.questlineSelected.status + "\n" + panel.questlineSelected.currency_code + " " + (panel.questlineSelected.amount_minor / 100).toFixed(2) + "\nCampaign: " + panel.questlineSelected.campaign : (panel.questlineSelected.description || "No description yet.")
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
                                        text: "Steps  ·  " + panel.questlineSteps().filter(step => step.completed).length + "/" + panel.questlineSteps().length
                                        color: panel.theme.colors.foreground
                                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 2; bold: true }
                                    }
                                    ShellButton {
                                        enabled: !!panel.questline.actions_available
                                        label: "+ New step"
                                        fontFamily: panel.theme.fontFamily
                                        fontSize: panel.theme.fontSize
                                        backgroundColor: panel.theme.colors.accent
                                        foregroundColor: panel.theme.colors.background
                                        onClicked: panel.beginQuestlineStepEdit(null)
                                    }
                                }
                                Text {
                                    visible: panel.questlineSteps().length === 0
                                    text: "No steps yet. Add one to break this task down."
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
                                                    text: modelData.description || (modelData.due_date ? "Due " + modelData.due_date : "")
                                                    color: panel.theme.colors.muted
                                                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize - 1 }
                                                }
                                            }
                                            ShellButton {
                                                enabled: !!panel.questline.actions_available
                                                label: "Edit"
                                                fontFamily: panel.theme.fontFamily
                                                fontSize: panel.theme.fontSize
                                                backgroundColor: panel.theme.colors.surface_alt
                                                foregroundColor: panel.theme.colors.foreground
                                                onClicked: panel.beginQuestlineStepEdit(modelData)
                                            }
                                            ShellButton {
                                                enabled: !!panel.questline.actions_available && !questlineActionProcess.running && !panel.questlineWorkspace.busy
                                                label: "Delete"
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

            QuestlineHero {
                visible: panel.page === "questline" && panel.questlineTab === "Hero" && !panel.questlineEditing && !panel.questlineQuickScrollPicker
                Layout.fillWidth: true
                Layout.fillHeight: true
                theme: panel.theme
                hero: panel.questline.hero || null
            }

            QuestlineFocus {
                id: questlineFocusEditor
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
                onFocusStart: request => panel.focusStart(request)
            }

            FocusControls {
                id: focusEditor
                viewActive: panel.expanded
                visible: panel.page === "focus"
                Layout.fillWidth: true
                theme: panel.theme
                focusState: panel.focusState
                backendDir: panel.backendDir
                onFocusAction: action => panel.focusAction(action)
                onFocusStart: request => panel.focusStart(request)
                onQuestlineRequested: { panel.switchQuestlineTab("Overview"); panel.open("questline"); }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: panel.page === "calendar"
                ShellButton {
                    label: "‹"
                    fontFamily: panel.theme.fontFamily
                    fontSize: panel.theme.fontSize + 4
                    backgroundColor: panel.theme.colors.surface_alt
                    foregroundColor: panel.theme.colors.foreground
                    onClicked: panel.calendarMonth = new Date(panel.calendarMonth.getFullYear(), panel.calendarMonth.getMonth() - 1, 1)
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDateTime(panel.calendarMonth, "MMMM yyyy")
                    color: panel.theme.colors.foreground
                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 3; bold: true }
                }
                ShellButton {
                    label: "›"
                    fontFamily: panel.theme.fontFamily
                    fontSize: panel.theme.fontSize + 4
                    backgroundColor: panel.theme.colors.surface_alt
                    foregroundColor: panel.theme.colors.foreground
                    onClicked: panel.calendarMonth = new Date(panel.calendarMonth.getFullYear(), panel.calendarMonth.getMonth() + 1, 1)
                }
            }
            GridLayout {
                Layout.fillWidth: true
                visible: panel.page === "calendar"
                columns: 7
                columnSpacing: 4
                rowSpacing: 4
                Repeater {
                    model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                    Text {
                        required property string modelData
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: panel.theme.colors.muted
                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize - 1; bold: true }
                    }
                }
                Repeater {
                    model: panel.calendarDays
                    Rectangle {
                        required property int modelData
                        readonly property bool isToday: modelData > 0 && modelData === new Date().getDate() && panel.calendarMonth.getMonth() === new Date().getMonth() && panel.calendarMonth.getFullYear() === new Date().getFullYear()
                        Layout.fillWidth: true
                        implicitHeight: 30
                        radius: 7
                        color: isToday ? panel.theme.colors.accent : panel.theme.colors.surface_alt
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData > 0 ? String(parent.modelData) : ""
                            color: parent.isToday ? panel.theme.colors.background : panel.theme.colors.foreground
                            font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                        }
                    }
                }
            }
            ShellButton {
                Layout.fillWidth: true
                visible: panel.page === "calendar"
                label: "Today"
                fontFamily: panel.theme.fontFamily
                fontSize: panel.theme.fontSize
                backgroundColor: panel.theme.colors.surface_alt
                foregroundColor: panel.theme.colors.foreground
                onClicked: panel.calendarMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1)
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 68
                radius: 11
                visible: panel.page === "color"
                color: panel.colorValue || panel.theme.colors.surface_alt
            }
            Text {
                Layout.fillWidth: true
                visible: panel.page === "color"
                horizontalAlignment: Text.AlignHCenter
                text: panel.colorValue || "Choose a color from the screen"
                color: panel.theme.colors.foreground
                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 3; bold: true }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: panel.page === "color"
                spacing: 8
                ShellButton {
                    Layout.fillWidth: true
                    label: "Pick colors"
                    fontFamily: panel.theme.fontFamily
                    fontSize: panel.theme.fontSize
                    backgroundColor: panel.theme.colors.accent
                    foregroundColor: panel.theme.colors.background
                    onClicked: panel.beginColorPick()
                }
                ShellButton {
                    Layout.fillWidth: true
                    label: "Copy hex"
                    enabled: panel.colorValue.length > 0
                    fontFamily: panel.theme.fontFamily
                    fontSize: panel.theme.fontSize
                    backgroundColor: panel.theme.colors.surface_alt
                    foregroundColor: panel.theme.colors.foreground
                    onClicked: Quickshell.execDetached(["wl-copy", panel.colorValue])
                }
            }
            Text {
                Layout.fillWidth: true
                visible: panel.page === "color"
                text: "Click to collect more colors. Press Escape to finish and return here."
                color: panel.theme.colors.muted
                wrapMode: Text.WordWrap
                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize - 1 }
            }

            Text {
                Layout.fillWidth: true
                visible: panel.page === "color"
                text: "SAVED COLORS · NEWEST FIRST"
                color: panel.theme.colors.accent
                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize; bold: true }
            }
            Text {
                Layout.fillWidth: true
                visible: panel.page === "color" && panel.savedColors.length === 0
                text: "No saved colors yet. Pick one from the screen to start."
                color: panel.theme.colors.muted
                wrapMode: Text.WordWrap
                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
            }
            Repeater {
                model: panel.page === "color" ? panel.savedColors : []
                RowLayout {
                    required property string modelData
                    Layout.fillWidth: true
                    spacing: 12
                    Rectangle {
                        width: 58
                        height: 34
                        radius: 8
                        color: parent.modelData
                    }
                    Text {
                        Layout.fillWidth: true
                        text: parent.modelData
                        color: panel.theme.colors.foreground
                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 1; bold: true }
                    }
                    ShellButton {
                        label: "Copy"
                        fontFamily: panel.theme.fontFamily
                        fontSize: panel.theme.fontSize
                        backgroundColor: panel.theme.colors.surface_alt
                        foregroundColor: panel.theme.colors.foreground
                        onClicked: Quickshell.execDetached(["wl-copy", parent.modelData])
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: panel.page === "password"
                spacing: 8
                Text {
                    text: "Length: " + panel.passwordLength
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
                        { label: "Letters", key: "l" },
                        { label: "Numbers", key: "n" },
                        { label: "Symbols", key: "s" }
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
                    label: "Generate"
                    fontFamily: panel.theme.fontFamily
                    fontSize: panel.theme.fontSize
                    backgroundColor: panel.theme.colors.accent
                    foregroundColor: panel.theme.colors.background
                    onClicked: panel.generatePassword()
                }
                ShellButton {
                    Layout.fillWidth: true
                    label: "Copy"
                    enabled: panel.password.length > 0
                    fontFamily: panel.theme.fontFamily
                    fontSize: panel.theme.fontSize
                    backgroundColor: panel.theme.colors.surface_alt
                    foregroundColor: panel.theme.colors.foreground
                    onClicked: { passwordValue.selectAll(); passwordValue.copy(); passwordValue.deselect(); }
                }
            }

            SpectrumDrop {
                visible: panel.page === "spectrumdrop"
                Layout.fillWidth: true
                Layout.fillHeight: true
                theme: panel.theme
                backend: spectrumDrop
            }
            HotKeyEditor {
                id: hotkeyEditor
                visible: panel.page === "hotkey"
                Layout.fillWidth: true
                Layout.fillHeight: visible
                theme: panel.theme
                backend: hotkeys
            }
            Item {
                visible: !["questline", "search", "emoji", "shortcuts", "hotkey", "spectrumdrop"].includes(panel.page)
                Layout.fillHeight: visible
            }
        }
    }

    function openFile(path): void {
        expanded = false;
        Quickshell.execDetached(["uwsm", "app", "--", "gio", "open", path]);
    }

    function moveSearchSelection(offset): void {
        if (!matches.length)
            return;
        searchSelectedIndex = Math.max(0, Math.min(matches.length - 1, searchSelectedIndex + offset));
        fileList.positionViewAtIndex(searchSelectedIndex, ListView.Contain);
    }

    function openSelectedFile(): void {
        const selected = matches[searchSelectedIndex];
        if (selected)
            openFile(selected);
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
