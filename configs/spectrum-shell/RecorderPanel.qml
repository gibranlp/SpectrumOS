import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "spectrum-widget-recorderpanel"
    id: panel
    required property var targetScreen
    required property var theme
    required property string backendDir
    required property var recording
    property int topInset: 8
    property int leftInset: 0
    property bool expanded: false
    property string recordingFormat: "mp4"
    property string videoQuality: "balanced"
    property string frameRate: "auto"
    property string audioBitrate: "192"
    property string audioSource: "none"
    property var audio: ({ sinks: [], sources: [] })
    property string pendingMode: ""
    property string actionError: ""
    signal recordingRefreshRequested()

    function runAction(command): void {
        if (recorderAction.running) {
            actionError = "Finish or cancel the current selection with Esc first.";
            return;
        }
        actionError = "";
        recorderAction.exec(command);
    }

    screen: targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: motion.active
    WlrLayershell.keyboardFocus: panelFocus.mode
    ShellFocus { id: panelFocus; window: panel; enabled: expanded }

    function select(mode): void {
        if (recorderAction.running) {
            actionError = "Finish or cancel the current selection with Esc first.";
            return;
        }
        actionError = "";
        pendingMode = mode;
        expanded = false;
        captureDelay.restart();
    }

    onExpandedChanged: {
        if (expanded) {
            captureDelay.stop();
            if (!audioProcess.running)
                audioProcess.running = true;
        }
    }

    Process {
        id: recorderAction
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    panel.actionError = text.trim().split("\n")[0];
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                if (!panel.actionError)
                    panel.actionError = "Could not complete the recording action.";
                panel.expanded = true;
            }
            panel.recordingRefreshRequested();
        }
    }

    Process {
        id: audioProcess
        command: [panel.backendDir + "/control-adapter", "--audio-json"]
        stdout: StdioCollector { onStreamFinished: {
            try { panel.audio = JSON.parse(text); } catch (error) { console.warn("SpectrumShell recorder audio:", error); }
        } }
    }

    Timer {
        id: captureDelay
        interval: 370
        onTriggered: panel.runAction([panel.backendDir + "/recorder-menu", "--start", panel.pendingMode, panel.audioSource, panel.recordingFormat, panel.videoQuality, panel.frameRate, panel.audioBitrate])
    }

    MouseArea {
        anchors.fill: parent
        onClicked: panel.expanded = false
    }

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
        height: Math.min(760, panel.height - panel.topInset - 24)
        x: Math.max(leftFrameThickness, panel.leftInset)
        y: panel.topInset + Math.max(0, (panel.height - panel.topInset - height) / 2)
        radius: 30
        color: panel.theme.colors.surface
        focus: panel.visible
        Keys.onEscapePressed: panel.expanded = false

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors { fill: parent; margins: 24 }
            spacing: 13

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "SCREEN RECORDER"
                    color: panel.theme.colors.foreground
                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 8; bold: true }
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

            Text {
                Layout.fillWidth: true
                text: panel.recording.active ? "Recording in progress" : "Choose what to record and where to capture audio."
                color: panel.recording.active ? panel.theme.colors.accent : panel.theme.colors.muted
                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 1 }
            }

            Text {
                Layout.fillWidth: true
                visible: panel.actionError !== ""
                text: panel.actionError
                wrapMode: Text.Wrap
                color: panel.theme.colors.accent
                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
            }

            Text {
                text: "VIDEO SOURCE"
                color: panel.theme.colors.accent
                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize; bold: true }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: [
                        { label: "Monitor", mode: "monitor" },
                        { label: "Area", mode: "area" },
                        { label: "Window", mode: "window" }
                    ]
                    ShellButton {
                        required property var modelData
                        Layout.fillWidth: true
                        enabled: !panel.recording.active
                        label: modelData.label
                        fontFamily: panel.theme.fontFamily
                        fontSize: panel.theme.fontSize
                        backgroundColor: panel.theme.colors.accent
                        foregroundColor: panel.theme.colors.background
                        onClicked: panel.select(modelData.mode)
                    }
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: devices.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Controls.ScrollBar.vertical: Controls.ScrollBar {
                    policy: Controls.ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: panel.theme.colors.accent
                        opacity: 0.65
                    }
                }

                ColumnLayout {
                    id: devices
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: [
                            { title: "FORMAT", key: "recordingFormat", choices: [{ label: "MP4", value: "mp4" }, { label: "MKV", value: "mkv" }, { label: "WebM", value: "webm" }] },
                            { title: "VIDEO QUALITY", key: "videoQuality", choices: [{ label: "Small file", value: "small" }, { label: "Balanced", value: "balanced" }, { label: "High", value: "high" }] },
                            { title: "FRAME RATE", key: "frameRate", choices: [{ label: "Auto", value: "auto" }, { label: "24 fps", value: "24" }, { label: "30 fps", value: "30" }, { label: "60 fps", value: "60" }] },
                            { title: "AUDIO BITRATE · kbps", key: "audioBitrate", choices: [{ label: "96", value: "96" }, { label: "128", value: "128" }, { label: "192", value: "192" }, { label: "256", value: "256" }, { label: "320", value: "320" }] }
                        ]
                        ColumnLayout {
                            id: optionRow
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 6
                            enabled: !panel.recording.active && (modelData.key !== "audioBitrate" || panel.audioSource !== "none")
                            Text {
                                text: optionRow.modelData.title
                                color: panel.theme.colors.accent
                                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize; bold: true }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Repeater {
                                    model: optionRow.modelData.choices
                                    ShellButton {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        label: modelData.label
                                        fontFamily: panel.theme.fontFamily
                                        fontSize: panel.theme.fontSize
                                        backgroundColor: panel[optionRow.modelData.key] === modelData.value ? panel.theme.colors.accent : panel.theme.colors.surface_alt
                                        foregroundColor: panel[optionRow.modelData.key] === modelData.value ? panel.theme.colors.background : panel.theme.colors.foreground
                                        onClicked: panel[optionRow.modelData.key] = modelData.value
                                    }
                                }
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: (panel.recordingFormat === "webm" ? "WebM uses VP9 + Opus. Encoding may use more CPU." : "MP4 and MKV use H.264 + AAC.") + "\nHigher quality makes larger files. Auto records frames as the screen changes. Audio bitrate applies when audio is enabled."
                        wrapMode: Text.Wrap
                        color: panel.theme.colors.muted
                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize - 1 }
                    }
                    Text {
                        text: "AUDIO SOURCE"
                        color: panel.theme.colors.accent
                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize; bold: true }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Choose one source for this recording."
                        color: panel.theme.colors.muted
                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize - 1 }
                    }
                    ShellButton {
                        Layout.fillWidth: true
                        label: "No audio"
                        fontFamily: panel.theme.fontFamily
                        fontSize: panel.theme.fontSize
                        backgroundColor: panel.audioSource === "none" ? panel.theme.colors.accent : panel.theme.colors.surface_alt
                        foregroundColor: panel.audioSource === "none" ? panel.theme.colors.background : panel.theme.colors.foreground
                        enabled: !panel.recording.active
                        onClicked: panel.audioSource = "none"
                    }

                    Text {
                        text: "Desktop audio output"
                        color: panel.theme.colors.muted
                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                    }
                    Repeater {
                        model: panel.audio.sinks || []
                        ShellButton {
                            required property var modelData
                            Layout.fillWidth: true
                            label: modelData.label + (modelData.default ? " · default" : "")
                            fontFamily: panel.theme.fontFamily
                            fontSize: panel.theme.fontSize
                            backgroundColor: panel.audioSource === modelData.name + ".monitor" ? panel.theme.colors.accent : panel.theme.colors.surface_alt
                            foregroundColor: panel.audioSource === modelData.name + ".monitor" ? panel.theme.colors.background : panel.theme.colors.foreground
                            enabled: !panel.recording.active
                            onClicked: panel.audioSource = modelData.name + ".monitor"
                        }
                    }
                    Text {
                        text: "Microphone input"
                        color: panel.theme.colors.muted
                        font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
                    }
                    Repeater {
                        model: panel.audio.sources || []
                        ShellButton {
                            required property var modelData
                            Layout.fillWidth: true
                            label: modelData.label + (modelData.default ? " · default" : "")
                            fontFamily: panel.theme.fontFamily
                            fontSize: panel.theme.fontSize
                            backgroundColor: panel.audioSource === modelData.name ? panel.theme.colors.accent : panel.theme.colors.surface_alt
                            foregroundColor: panel.audioSource === modelData.name ? panel.theme.colors.background : panel.theme.colors.foreground
                            enabled: !panel.recording.active
                            onClicked: panel.audioSource = modelData.name
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                ShellButton {
                    Layout.fillWidth: true
                    label: panel.recording.active ? "Stop and save recording" : "Open recordings folder"
                    fontFamily: panel.theme.fontFamily
                    fontSize: panel.theme.fontSize
                    backgroundColor: panel.recording.active ? panel.theme.colors.accent : panel.theme.colors.surface_alt
                    foregroundColor: panel.recording.active ? panel.theme.colors.background : panel.theme.colors.foreground
                    onClicked: {
                        if (panel.recording.active) {
                            panel.runAction([panel.backendDir + "/recorder-menu", "--stop"]);
                        } else {
                            panel.actionError = "";
                            Quickshell.execDetached([panel.backendDir + "/recorder-menu", "--open"]);
                        }
                    }
                }
            }
        }
    }
}
