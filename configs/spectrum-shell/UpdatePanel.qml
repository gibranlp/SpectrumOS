import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "spectrum-widget-updatepanel"
    id: panel
    required property var targetScreen
    required property var theme
    required property string backendDir
    property int topInset: 8
    property int leftInset: 0
    property bool expanded: false
    property bool ready: false
    property bool planReady: false
    property string planText: ""
    property string planError: ""

    function refresh(): void {
        if (theme.checkStableUpdates) theme.checkStableUpdates();
        if (planProcess.running)
            return;
        ready = false;
        planReady = false;
        planText = "";
        planError = "";
        planProcess.exec(["spectrum", "update", "plan", "--json"]);
    }

    function update(mode): void {
        if (!ready || planProcess.running)
            return;
        expanded = false;
        Quickshell.execDetached(["uwsm", "app", "--", "kitty", "--hold", "-e", backendDir + "/spectrum-update-run", mode]);
    }

    screen: targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: motion.active
    focusable: expanded

    Process {
        id: planProcess
        stdout: StdioCollector { onStreamFinished: {
            try {
                const plan = JSON.parse(text);
                const checks = plan.preflight;
                const lines = [
                    "SpectrumOS " + plan.release.version + " · " + plan.release.channel,
                    "",
                    "Free disk space: " + Math.floor(checks.disk.free_bytes / (1024 * 1024 * 1024)) + " GiB · " + (checks.disk.status === "pass" ? "ready" : "low"),
                    "Package manager: " + (checks.pacman_lock.status === "pass" ? "available" : "busy"),
                    "Previous package transaction: " + (checks.pacman_transaction.status === "pass" ? "complete" : checks.pacman_transaction.status),
                    "Restore points: " + (checks.snapshots.status === "pass" ? "available" : "unavailable"),
                    "",
                    "Package updates in the local database: " + plan.packages.official.count,
                    "AUR / other foreign packages installed: " + plan.packages.foreign.count,
                    "The update refreshes the repositories before installing new versions.",
                    "SpectrumOS packages are included in the full system upgrade."
                ];
                if (plan.blockers.length)
                    lines.push("", "Needs attention:", ...plan.blockers);
                if (plan.warnings.length)
                    lines.push("", "Notes:", ...plan.warnings);
                panel.planText = lines.join("\n");
                panel.planReady = plan.ready_for_execution === true;
            } catch (error) {
                panel.planError = "Could not read the safety checks. Try Check again.";
            }
        } }
        stderr: StdioCollector { onStreamFinished: panel.planError = text.trim() }
        onExited: exitCode => {
            panel.ready = exitCode === 0 && panel.planReady;
            if (!panel.ready && !panel.planError && !panel.planText)
                panel.planError = "Could not run the safety checks. Make sure the SpectrumOS tools are installed.";
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
        height: Math.min(720, panel.height - panel.topInset - 24)
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
                    Layout.fillWidth: true
                    text: "SPECTRUMOS UPDATES"
                    elide: Text.ElideRight
                    color: panel.theme.colors.foreground
                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 6; bold: true }
                }
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
                text: "Update Arch and SpectrumOS packages together. Update everything also includes AUR packages when Paru is installed, plus system and user Flatpak apps."
                wrapMode: Text.Wrap
                color: panel.theme.colors.muted
                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
            }
            Text {
                Layout.fillWidth: true
                text: panel.theme.checkingStableUpdates ? "Checking Stable…"
                    : panel.theme.stableUpdates && panel.theme.stableUpdates.error ? "Stable check unavailable. Try Check again."
                    : !panel.theme.stableUpdates || !panel.theme.stableUpdates.checked_at ? "Stable check runs shortly."
                    : !panel.theme.stableUpdates.eligible ? "Stable notifications require the SpectrumOS Stable repository."
                    : panel.theme.stableUpdates.packages.length ? panel.theme.stableUpdates.packages.length + " SpectrumOS package update(s) ready on Stable."
                    : "SpectrumOS packages are up to date on Stable."
                wrapMode: Text.Wrap
                color: panel.theme.colors.muted
                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize }
            }
            Text {
                Layout.fillWidth: true
                text: planProcess.running ? "Checking update safety…" : panel.ready ? "Safety checks passed" : "Resolve the blockers below, then check again."
                wrapMode: Text.Wrap
                color: panel.theme.colors.accent
                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize; bold: true }
            }
            Controls.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                Controls.TextArea {
                    id: safetyText
                    readOnly: true
                    text: [panel.planText, panel.planError].filter(value => value !== "").join("\n\n")
                    wrapMode: TextEdit.Wrap
                    color: panel.theme.colors.foreground
                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize - 1 }
                    background: Rectangle { color: panel.theme.colors.surface_alt; radius: 12 }
                    padding: 12
                }
            }
            Text {
                Layout.fillWidth: true
                text: "Review and confirm in the terminal before changes begin. System upgrades create a restore point, apply SpectrumOS migrations, and finish with a health check."
                wrapMode: Text.Wrap
                color: panel.theme.colors.muted
                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize - 1 }
            }
            ShellButton {
                Layout.fillWidth: true
                label: "Check again"
                enabled: !planProcess.running
                fontFamily: panel.theme.fontFamily
                fontSize: panel.theme.fontSize
                backgroundColor: panel.theme.colors.surface_alt
                foregroundColor: panel.theme.colors.foreground
                onClicked: panel.refresh()
            }
            Repeater {
                model: [{ label: "Update everything", mode: "all" }, { label: "Update Arch + SpectrumOS packages", mode: "official" }]
                ShellButton {
                    required property var modelData
                    Layout.fillWidth: true
                    enabled: panel.ready && !planProcess.running
                    label: modelData.label
                    fontFamily: panel.theme.fontFamily
                    fontSize: panel.theme.fontSize
                    backgroundColor: modelData.mode === "all" ? panel.theme.colors.accent : panel.theme.colors.surface_alt
                    foregroundColor: modelData.mode === "all" ? panel.theme.colors.background : panel.theme.colors.foreground
                    onClicked: panel.update(modelData.mode)
                }
            }
        }
    }
}
