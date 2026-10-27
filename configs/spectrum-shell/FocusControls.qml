import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell.Io

ColumnLayout {
    id: focus
    required property var theme
    required property var focusState
    required property string backendDir
    signal focusAction(string action)
    signal focusStart(var request)
    signal questlineRequested()
    property bool viewActive: false
    property var questline: ({ available: false, campaigns: [], tasks: [] })
    property string projectId: focusState.project_id || ""
    property string taskId: focusState.task_id || ""
    property string soundscape: focusState.soundscape || "Silent"
    property int duration: focusState.duration || 25
    readonly property bool active: ["starting", "work", "paused"].includes(focusState.phase)
    readonly property var campaigns: [{ id: "", name: qsTranslate("Spectrum", "Unfiled / no campaign") }].concat(questline.campaigns || [])
    readonly property var tasks: [{ id: "", title: qsTranslate("Spectrum", "No specific task") }].concat((questline.tasks || []).filter(task => (task.project_id || "") === projectId))
    readonly property var soundscapes: ["Silent", "LoFi Radio", "Forest Sounds", "Rain Sounds", "Ocean Waves", "White Noise", "Music For Programming", "Local Folder"]
    spacing: 9

    function refresh(): void {
        if (viewActive && visible && !catalog.running)
            catalog.exec([backendDir + "/questline-adapter", "--json"]);
    }
    Component.onCompleted: refresh()
    onVisibleChanged: refresh()
    onViewActiveChanged: refresh()
    onFocusStateChanged: {
        if (active) {
            projectId = focusState.project_id || "";
            taskId = focusState.task_id || "";
            duration = focusState.duration || 25;
            soundscape = focusState.soundscape || "Silent";
        }
    }
    Process {
        id: catalog
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    focus.questline = JSON.parse(text);
                    if (!focus.active) {
                        if (!focus.campaigns.some(item => item.id === focus.projectId)) focus.projectId = "";
                        if (!focus.tasks.some(item => item.id === focus.taskId)) focus.taskId = "";
                    }
                }
                catch (error) { console.warn("Questline focus:", error); }
            }
        }
    }
    Timer { interval: 10000; repeat: true; running: focus.viewActive && focus.visible; onTriggered: focus.refresh() }

    Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: String(Math.floor((focus.active ? focus.focusState.remaining : focus.duration * 60) / 60)).padStart(2, "0") + ":" + String(focus.active ? focus.focusState.remaining % 60 : 0).padStart(2, "0")
        color: focus.theme.colors.accent
        font { family: focus.theme.fontFamily; pixelSize: Math.max(64, focus.theme.fontSize * 4); bold: true }
    }
    Text {
        Layout.fillWidth: true
        visible: focus.active && text.length > 0
        text: focus.focusState.phase === "paused" ? qsTranslate("Spectrum", "Paused") : focus.focusState.task || focus.focusState.campaign || ""
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        color: focus.theme.colors.muted
        font { family: focus.theme.fontFamily; pixelSize: focus.theme.fontSize }
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: !focus.active
        spacing: 6
        Text { text: qsTranslate("Spectrum", "Campaign"); color: focus.theme.colors.muted; font { family: focus.theme.fontFamily; pixelSize: focus.theme.fontSize - 1 } }
        FocusChoice {
            Layout.fillWidth: true
            theme: focus.theme
            enabled: !focus.active
            model: focus.campaigns.map(item => item.name)
            currentIndex: Math.max(0, focus.campaigns.findIndex(item => item.id === focus.projectId))
            onActivated: { focus.projectId = focus.campaigns[currentIndex].id; focus.taskId = ""; }
        }
        Text { text: qsTranslate("Spectrum", "Task"); color: focus.theme.colors.muted; font { family: focus.theme.fontFamily; pixelSize: focus.theme.fontSize - 1 } }
        FocusChoice {
            Layout.fillWidth: true
            theme: focus.theme
            enabled: !focus.active
            model: focus.tasks.map(item => item.title)
            currentIndex: Math.max(0, focus.tasks.findIndex(item => item.id === focus.taskId))
            onActivated: focus.taskId = focus.tasks[currentIndex].id
        }
        RowLayout {
            Layout.fillWidth: true
            Text { text: qsTranslate("Spectrum", "Minutes"); color: focus.theme.colors.muted; font { family: focus.theme.fontFamily; pixelSize: focus.theme.fontSize - 1 } }
            Controls.SpinBox {
                Layout.fillWidth: true
                from: 5; to: 180; stepSize: 5; editable: true
                enabled: !focus.active
                value: focus.duration
                onValueModified: focus.duration = value
                background: Rectangle {
                    radius: 8
                    color: parent.activeFocus ? Qt.tint(focus.theme.colors.surface_alt, Qt.rgba(focus.theme.colors.accent.r, focus.theme.colors.accent.g, focus.theme.colors.accent.b, 0.3)) : focus.theme.colors.surface_alt
                }
                font { family: focus.theme.fontFamily; pixelSize: focus.theme.fontSize }
                palette { base: focus.theme.colors.surface_alt; text: focus.theme.colors.foreground; button: focus.theme.colors.surface_alt; buttonText: focus.theme.colors.foreground }
            }
        }
        Text { text: qsTranslate("Spectrum", "Soundscape"); color: focus.theme.colors.muted; font { family: focus.theme.fontFamily; pixelSize: focus.theme.fontSize - 1 } }
        FocusChoice {
            Layout.fillWidth: true
            theme: focus.theme
            enabled: !focus.active
            translateModel: true
            model: focus.soundscapes
            currentIndex: Math.max(0, focus.soundscapes.indexOf(focus.soundscape))
            onActivated: focus.soundscape = focus.soundscapes[currentIndex]
        }
    }
    RowLayout {
        Layout.fillWidth: true
        ShellButton {
            Layout.fillWidth: true
            label: focus.focusState.phase === "work" ? qsTranslate("Spectrum", "Pause") : focus.focusState.phase === "paused" ? qsTranslate("Spectrum", "Resume") : focus.focusState.phase === "starting" ? qsTranslate("Spectrum", "Starting…") : qsTranslate("Spectrum", "Start focus")
            enabled: focus.questline.available && focus.focusState.phase !== "starting"
            fontFamily: focus.theme.fontFamily
            fontSize: focus.theme.fontSize
            backgroundColor: focus.theme.colors.accent
            foregroundColor: focus.theme.colors.background
            onClicked: {
                if (focus.active) focus.focusAction("toggle");
                else focus.focusStart({ duration: focus.duration, project_id: focus.projectId, task_id: focus.taskId,
                    campaign: focus.projectId ? (focus.campaigns.find(item => item.id === focus.projectId) || {}).name || "" : "",
                    task: focus.taskId ? (focus.tasks.find(item => item.id === focus.taskId) || {}).title || "" : "", soundscape: focus.soundscape });
            }
        }
        ShellButton {
            label: qsTranslate("Spectrum", "Reset")
            fontFamily: focus.theme.fontFamily
            fontSize: focus.theme.fontSize
            backgroundColor: focus.theme.colors.surface_alt
            foregroundColor: focus.theme.colors.foreground
            onClicked: focus.focusAction("reset")
        }
        ShellButton {
            label: "Questline"
            fontFamily: focus.theme.fontFamily
            fontSize: focus.theme.fontSize
            backgroundColor: focus.theme.colors.surface_alt
            foregroundColor: focus.theme.colors.foreground
            onClicked: focus.questlineRequested()
        }
    }
    Text {
        Layout.fillWidth: true
        visible: !focus.questline.available || !!focus.focusState.message
        text: qsTranslate("Spectrum", focus.focusState.message) || (!focus.questline.available ? qsTranslate("Spectrum", "Complete Questline setup to start.") : "")
        wrapMode: Text.Wrap
        color: focus.focusState.phase === "error" ? focus.theme.colors.error || "#ff8c9a" : focus.theme.colors.accent
        font { family: focus.theme.fontFamily; pixelSize: focus.theme.fontSize - 1 }
    }
}
