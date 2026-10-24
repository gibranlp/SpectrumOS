import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: panel
    required property var targetScreen
    required property var theme
    required property string backendDir
    property int topInset: 8
    property int leftInset: 0
    property bool expanded: false
    property var state: ({ active: false, available: false, sources: [], sinks: [] })
    property string captureMode: "input"
    property string inputName: ""
    property string outputName: ""
    property string recordingFormat: "mp3"
    property int bitrate: 192
    property int sampleRate: 48000
    property int channels: 2
    property string actionError: ""
    readonly property bool busy: action.running
    readonly property bool inputSelected: captureMode === "input" || captureMode === "both"
    readonly property bool outputSelected: captureMode === "output" || captureMode === "both"
    readonly property var selectedInput: (state.sources || []).find(row => row.name === inputName) || null
    readonly property var selectedOutput: (state.sinks || []).find(row => row.name === outputName) || null
    readonly property bool canStart: !!state.available && !busy && !state.active &&
        (!inputSelected || !!selectedInput) && (!outputSelected || (!!selectedOutput && selectedOutput.recordable))
    signal recordingRefreshRequested()

    function refresh(): void { if (!status.running) status.running = true; }
    function runAction(args): void {
        if (busy) return;
        actionError = "";
        action.exec([backendDir + "/audio-recorder", ...args]);
    }
    function start(): void {
        runAction(["--start", JSON.stringify({mode: captureMode, input: inputName, output: outputName,
            format: recordingFormat, bitrate: bitrate, sample_rate: sampleRate, channels: channels})]);
    }
    function duration(seconds): string {
        return Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0");
    }
    onRecordingFormatChanged: if (recordingFormat === "opus") sampleRate = 48000
    onExpandedChanged: if (expanded) refresh()

    screen: targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "spectrum-widget-audiorecorderpanel"
    color: "transparent"
    visible: motion.active
    WlrLayershell.keyboardFocus: panelFocus.mode
    ShellFocus { id: panelFocus; window: panel; enabled: expanded }

    Process {
        id: status
        command: [panel.backendDir + "/audio-recorder", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const next = JSON.parse(text);
                    panel.state = next;
                    if (next.active && next.options) {
                        panel.captureMode = next.options.mode;
                        panel.inputName = next.options.input;
                        panel.outputName = next.options.output;
                        panel.recordingFormat = next.options.format;
                        panel.bitrate = next.options.bitrate;
                        panel.sampleRate = next.options.sample_rate;
                        panel.channels = next.options.channels;
                    } else {
                        if (!panel.inputName) panel.inputName = ((next.sources || []).find(row => row.default) || (next.sources || [])[0] || {}).name || "";
                        if (!panel.outputName) panel.outputName = ((next.sinks || []).find(row => row.default && row.recordable) || (next.sinks || []).find(row => row.recordable) || {}).name || "";
                    }
                } catch (error) { panel.actionError = "Could not read audio recording settings"; }
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) panel.actionError = text.trim() }
    }
    Process {
        id: action
        stderr: StdioCollector { onStreamFinished: panel.actionError = text.trim() }
        onExited: (code) => {
            if (code !== 0 && !panel.actionError) panel.actionError = "Audio recording action failed";
            panel.refresh();
            panel.recordingRefreshRequested();
        }
    }
    Timer { interval: 2000; repeat: true; running: panel.expanded && !panel.busy; onTriggered: panel.refresh() }

    component Label: Text {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: panel.theme.colors.foreground
        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
    }
    component Button: ShellButton {
        enabled: !panel.busy
        fontFamily: panel.theme.fontFamily
        fontSize: panel.theme.fontSize
        backgroundColor: panel.theme.colors.surface_alt
        foregroundColor: panel.theme.colors.foreground
    }
    component DeviceControls: ColumnLayout {
        required property var device
        required property string kind
        Layout.fillWidth: true
        spacing: 5
        Label {
            text: parent.device ? "Device level · " + parent.device.volume + "%" + (parent.device.muted ? " · muted" : "") : "Selected device is unavailable"
            color: panel.theme.colors.muted
            font.pixelSize: panel.theme.fontSize - 1
        }
        RowLayout {
            Layout.fillWidth: true
            Controls.Slider {
                id: level
                readonly property var controls: parent.parent
                Layout.fillWidth: true
                from: 0; to: 150; stepSize: 1
                enabled: !!controls.device && !panel.busy
                value: controls.device ? controls.device.volume : 0
                focusPolicy: Qt.StrongFocus
                palette.highlight: panel.theme.colors.accent
                palette.button: panel.theme.colors.surface_alt
                function apply(): void {
                    if (controls.device) panel.runAction(["--device", controls.kind, controls.device.name, "volume", String(Math.round(value))]);
                }
                onPressedChanged: if (!pressed) apply()
                onMoved: if (!pressed) apply()
            }
            Button {
                readonly property var controls: parent.parent
                label: controls.device && controls.device.muted ? "Unmute" : "Mute"
                enabled: !!controls.device && !panel.busy
                onClicked: panel.runAction(["--device", controls.kind, controls.device.name, "mute", controls.device.muted ? "off" : "on"])
            }
        }
    }

    MouseArea { anchors.fill: parent; onClicked: panel.expanded = false }
    ShellSurface {
        id: card
        transform: ShellMotion {
            id: motion
            surface: card
            animationsEnabled: panel.theme.animationsEnabled !== false
            bounceEnabled: panel.theme.widgetBounceEnabled !== false
            expanded: panel.expanded
            edge: "left"
            viewportWidth: panel.screen.width
            viewportHeight: panel.screen.height
        }
        attachLeft: true
        leftAttachmentWidth: panel.theme.barStyle === "islands" && panel.theme.barPosition === "left"
            ? Math.max(0, x - leftFrameThickness) : 0
        width: Math.min(570, panel.width - panel.leftInset - 24)
        height: Math.min(840, panel.height - panel.topInset - 24)
        x: Math.max(leftFrameThickness, panel.leftInset)
        y: panel.topInset + Math.max(0, (panel.height - panel.topInset - height) / 2)
        radius: 30
        color: panel.theme.colors.surface
        focus: panel.expanded
        Keys.onEscapePressed: panel.expanded = false
        MouseArea { anchors.fill: parent }
        ColumnLayout {
            anchors { fill: parent; margins: 24 }
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                Label { text: "AUDIO RECORDER"; font.pixelSize: panel.theme.fontSize + 8; font.bold: true }
                Button { label: "✕"; enabled: true; onClicked: panel.expanded = false }
            }
            Label {
                text: panel.state.active ? "● Recording · " + panel.duration(panel.state.elapsed || 0) : panel.state.phase === "saved" ? "Saved · " + panel.duration(panel.state.duration || 0) : "Record an input, desktop output, or both."
                color: panel.state.active ? panel.theme.colors.accent : panel.theme.colors.muted
            }
            Label { visible: !!panel.actionError || !!panel.state.error || !!panel.state.device_error; text: panel.actionError || panel.state.error || panel.state.device_error || ""; color: panel.theme.colors.accent; font.pixelSize: panel.theme.fontSize - 1 }
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: body.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
                ColumnLayout {
                    id: body
                    width: parent.width
                    spacing: 9
                    Label { text: "AUDIO SOURCE"; color: panel.theme.colors.accent; font.bold: true }
                    RowLayout {
                        Layout.fillWidth: true
                        Repeater {
                            model: [{label: "Input", key: "input"}, {label: "Output", key: "output"}, {label: "Both", key: "both"}]
                            Button {
                                required property var modelData
                                Layout.fillWidth: true
                                enabled: !panel.busy && !panel.state.active
                                label: modelData.label
                                backgroundColor: panel.captureMode === modelData.key ? panel.theme.colors.accent : panel.theme.colors.surface_alt
                                foregroundColor: panel.captureMode === modelData.key ? panel.theme.colors.background : panel.theme.colors.foreground
                                onClicked: panel.captureMode = modelData.key
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: panel.inputSelected
                        Label { text: "INPUT DEVICE"; color: panel.theme.colors.accent; font.bold: true }
                        Label { visible: !(panel.state.sources || []).length; text: "No input devices connected"; color: panel.theme.colors.muted }
                        Repeater {
                            model: panel.state.sources || []
                            Button {
                                required property var modelData
                                Layout.fillWidth: true
                                enabled: !panel.busy && !panel.state.active
                                label: modelData.label + (modelData.default ? " · default" : "")
                                backgroundColor: panel.inputName === modelData.name ? panel.theme.colors.accent : panel.theme.colors.surface_alt
                                foregroundColor: panel.inputName === modelData.name ? panel.theme.colors.background : panel.theme.colors.foreground
                                onClicked: panel.inputName = modelData.name
                            }
                        }
                        DeviceControls { device: panel.selectedInput; kind: "input" }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: panel.outputSelected
                        Label { text: "OUTPUT DEVICE"; color: panel.theme.colors.accent; font.bold: true }
                        Label { visible: !(panel.state.sinks || []).length; text: "No output devices connected"; color: panel.theme.colors.muted }
                        Repeater {
                            model: panel.state.sinks || []
                            Button {
                                required property var modelData
                                Layout.fillWidth: true
                                enabled: !panel.busy && !panel.state.active && modelData.recordable
                                label: modelData.label + (modelData.default ? " · default" : "") + (modelData.recordable ? "" : " · capture unavailable")
                                backgroundColor: panel.outputName === modelData.name ? panel.theme.colors.accent : panel.theme.colors.surface_alt
                                foregroundColor: panel.outputName === modelData.name ? panel.theme.colors.background : panel.theme.colors.foreground
                                onClicked: panel.outputName = modelData.name
                            }
                        }
                        DeviceControls { device: panel.selectedOutput; kind: "output" }
                    }
                    Label { text: "Levels and mute affect the selected system devices, including during recording. Both sources are mixed into one file."; color: panel.theme.colors.muted; font.pixelSize: panel.theme.fontSize - 1 }
                    Repeater {
                        model: [
                            {title: "FORMAT", key: "recordingFormat", choices: [{label: "MP3", value: "mp3"}, {label: "Opus", value: "opus"}, {label: "AAC", value: "aac"}, {label: "FLAC", value: "flac"}, {label: "WAV", value: "wav"}]},
                            {title: "BITRATE · kbps", key: "bitrate", choices: [64, 96, 128, 192, 256, 320].map(value => ({label: String(value), value: value}))},
                            {title: "SAMPLE RATE", key: "sampleRate", choices: [{label: "44.1 kHz", value: 44100}, {label: "48 kHz", value: 48000}]},
                            {title: "CHANNELS", key: "channels", choices: [{label: "Mono", value: 1}, {label: "Stereo", value: 2}]}
                        ]
                        ColumnLayout {
                            id: option
                            required property var modelData
                            Layout.fillWidth: true
                            enabled: !panel.busy && !panel.state.active && (modelData.key !== "bitrate" || !["flac", "wav"].includes(panel.recordingFormat))
                            Label { text: option.modelData.title; color: panel.theme.colors.accent; font.bold: true }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 5
                                Repeater {
                                    model: option.modelData.choices
                                    Button {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        enabled: option.enabled && !(option.modelData.key === "sampleRate" && panel.recordingFormat === "opus" && modelData.value === 44100)
                                        label: modelData.label
                                        backgroundColor: panel[option.modelData.key] === modelData.value ? panel.theme.colors.accent : panel.theme.colors.surface_alt
                                        foregroundColor: panel[option.modelData.key] === modelData.value ? panel.theme.colors.background : panel.theme.colors.foreground
                                        onClicked: panel[option.modelData.key] = modelData.value
                                    }
                                }
                            }
                        }
                    }
                    Label { text: panel.recordingFormat === "flac" || panel.recordingFormat === "wav" ? "Lossless audio · bitrate is determined by the sample rate and channels." : "Higher bitrate improves quality and increases file size. AAC saves as .m4a."; color: panel.theme.colors.muted; font.pixelSize: panel.theme.fontSize - 1 }
                    Label { visible: !!panel.state.file; text: panel.state.file || ""; color: panel.theme.colors.muted; font.pixelSize: panel.theme.fontSize - 2 }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Button {
                    Layout.fillWidth: true
                    enabled: !panel.busy && (panel.state.active || panel.canStart)
                    label: panel.busy ? "Please wait…" : panel.state.active ? "Stop and save" : "Start recording"
                    backgroundColor: panel.theme.colors.accent
                    foregroundColor: panel.theme.colors.background
                    onClicked: panel.state.active ? panel.runAction(["--stop"]) : panel.start()
                }
                Button { label: "Open folder"; onClicked: Quickshell.execDetached([panel.backendDir + "/audio-recorder", "--open"]) }
            }
        }
    }
}
