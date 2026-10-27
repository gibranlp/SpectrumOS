import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls

ColumnLayout {
    id: focus
    required property var theme
    required property var focusState
    property var questline: ({ available: false, campaigns: [], tasks: [] })
    property string preferredCampaignId: ""
    property string projectId: focusState.project_id || ""
    property string taskId: focusState.task_id || ""
    property string soundscape: focusState.soundscape || "Silent"
    property int duration: focusState.duration || 25
    readonly property bool active: ["starting", "work", "paused"].includes(focusState.phase)
    readonly property var soundscapes: ["Silent", "LoFi Radio", "Forest Sounds", "Rain Sounds", "Ocean Waves", "White Noise", "Music For Programming", "Local Folder"]
    readonly property var campaigns: catalog.projects.map(project => ({ id: project.id, title: project.name, subtitle: project.count + qsTranslate("Spectrum", " open tasks") }))
    readonly property var tasks: [{ id: "", title: qsTranslate("Spectrum", "No specific task"), subtitle: qsTranslate("Spectrum", "Focus on the campaign") }].concat(catalog.items.map(task => ({ id: task.id, title: task.title, subtitle: task.priority + (task.due_date ? " · " + task.due_date : "") })))
    readonly property var sounds: soundscapes.map(name => ({ id: name, title: name, subtitle: name === "Silent" ? qsTranslate("Spectrum", "No background audio") : name === "Local Folder" ? qsTranslate("Spectrum", "Your Questline music folder") : name === "Music For Programming" ? qsTranslate("Spectrum", "Music For Programming mixes") : "" }))
    readonly property int remaining: active ? Math.max(0, focusState.remaining || 0) : duration * 60
    signal focusAction(string action)
    signal focusStart(var request)
    spacing: 14

    QuestlineTasks {
        id: catalog
        campaigns: [{ id: "", name: "Unfiled / no campaign" }].concat(focus.questline.campaigns || [])
        tasks: focus.questline.tasks || []
        campaignId: focus.projectId
    }
    function selectCampaign(id): void {
        if (active) return;
        projectId = id;
        taskId = "";
    }
    function selectTask(id): void {
        if (!active) taskId = id;
    }
    function selectSoundscape(name): void {
        if (!active && soundscapes.includes(name)) soundscape = name;
    }
    function reconcileSelection(): void {
        if (active) return;
        projectId = catalog.resolveCampaign(projectId);
        if (!tasks.some(task => task.id === taskId)) taskId = "";
    }
    function startOrToggle(): void {
        if (!questline.available || focusState.phase === "starting") return;
        if (active) {
            focusAction("toggle");
            return;
        }
        focusStart({ duration: duration, project_id: projectId, task_id: taskId,
            campaign: projectId ? (catalog.projects.find(project => project.id === projectId) || {}).name || "" : "",
            task: taskId ? (catalog.items.find(task => task.id === taskId) || {}).title || "" : "", soundscape: soundscape });
    }
    Component.onCompleted: {
        if (!active && !projectId && preferredCampaignId) projectId = preferredCampaignId;
        reconcileSelection();
    }
    onQuestlineChanged: Qt.callLater(reconcileSelection)
    onFocusStateChanged: {
        if (["starting", "work", "paused"].includes(focusState.phase)) {
            projectId = focusState.project_id || "";
            taskId = focusState.task_id || "";
            duration = focusState.duration || 25;
            soundscape = focusState.soundscape || "Silent";
        } else Qt.callLater(reconcileSelection);
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: timerContent.implicitHeight + 32
        radius: 16
        color: focus.theme.colors.background
        ColumnLayout {
            id: timerContent
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 8
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: String(Math.floor(focus.remaining / 60)).padStart(2, "0") + ":" + String(focus.remaining % 60).padStart(2, "0")
                color: focus.theme.colors.accent
                font { family: focus.theme.fontFamily; pixelSize: 76; bold: true }
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: focus.active ? (focus.focusState.phase === "paused" ? qsTranslate("Spectrum", "Paused") : focus.focusState.phase === "starting" ? qsTranslate("Spectrum", "Starting…") : qsTranslate("Spectrum", "Focusing")) + (focus.focusState.task ? " · " + focus.focusState.task : focus.focusState.campaign ? " · " + focus.focusState.campaign : "") : qsTranslate("Spectrum", "Choose a campaign, task, and soundscape for your session.")
                wrapMode: Text.Wrap
                color: focus.theme.colors.muted
                font { family: focus.theme.fontFamily; pixelSize: focus.theme.fontSize }
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10
                Text {
                    text: qsTranslate("Spectrum", "Minutes")
                    color: focus.theme.colors.muted
                    font { family: focus.theme.fontFamily; pixelSize: focus.theme.fontSize }
                }
                Controls.SpinBox {
                    Layout.preferredWidth: 130
                    from: 5; to: 180; stepSize: 5; editable: true
                    enabled: !focus.active
                    value: focus.duration
                    onValueModified: focus.duration = value
                    background: Rectangle { radius: 8; color: focus.theme.colors.surface_alt }
                    font { family: focus.theme.fontFamily; pixelSize: focus.theme.fontSize }
                    palette { base: focus.theme.colors.surface_alt; text: focus.theme.colors.foreground; button: focus.theme.colors.surface_alt; buttonText: focus.theme.colors.foreground }
                }
                ShellButton {
                    label: focus.focusState.phase === "work" ? qsTranslate("Spectrum", "Pause") : focus.focusState.phase === "paused" ? qsTranslate("Spectrum", "Resume") : focus.focusState.phase === "starting" ? qsTranslate("Spectrum", "Starting…") : qsTranslate("Spectrum", "Start focus")
                    enabled: focus.questline.available && focus.focusState.phase !== "starting"
                    fontFamily: focus.theme.fontFamily
                    fontSize: focus.theme.fontSize
                    backgroundColor: focus.theme.colors.accent
                    foregroundColor: focus.theme.colors.background
                    onClicked: focus.startOrToggle()
                }
                ShellButton {
                    label: qsTranslate("Spectrum", "Reset")
                    fontFamily: focus.theme.fontFamily
                    fontSize: focus.theme.fontSize
                    backgroundColor: focus.theme.colors.surface_alt
                    foregroundColor: focus.theme.colors.foreground
                    onClicked: focus.focusAction("reset")
                }
            }
            Text {
                Layout.fillWidth: true
                visible: !focus.questline.available || !!focus.focusState.message
                horizontalAlignment: Text.AlignHCenter
                text: !focus.questline.available ? qsTranslate("Spectrum", "Open Questline and complete onboarding to earn XP.") : focus.focusState.message || ""
                wrapMode: Text.Wrap
                color: focus.focusState.phase === "error" ? focus.theme.colors.error : focus.theme.colors.accent
                font { family: focus.theme.fontFamily; pixelSize: focus.theme.fontSize }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 14
        QuestlineFocusList {
            Layout.preferredWidth: 250
            Layout.fillHeight: true
            theme: focus.theme
            title: qsTranslate("Spectrum", "Campaigns")
            items: focus.campaigns
            selectedId: focus.projectId
            selectionEnabled: !focus.active
            onItemChosen: id => focus.selectCampaign(id)
        }
        QuestlineFocusList {
            Layout.fillWidth: true
            Layout.fillHeight: true
            theme: focus.theme
            title: qsTranslate("Spectrum", "Tasks · ") + catalog.items.length
            items: focus.tasks
            selectedId: focus.taskId
            selectionEnabled: !focus.active
            onItemChosen: id => focus.selectTask(id)
        }
        QuestlineFocusList {
            Layout.preferredWidth: 340
            Layout.fillHeight: true
            theme: focus.theme
            title: qsTranslate("Spectrum", "Soundscapes")
            items: focus.sounds
            selectedId: focus.soundscape
            selectionEnabled: !focus.active
            onItemChosen: id => focus.selectSoundscape(id)
        }
    }
}
