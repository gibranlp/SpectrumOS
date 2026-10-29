pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "spectrum-widget-screenshotpanel"
    id: panel
    required property var targetScreen
    required property var theme
    property int topInset: 34
    property int leftInset: 0
    readonly property bool leftBar: theme.barPosition === "left"
    property bool expanded: false
    property bool annotate: false
    property string pendingMode: ""
    signal captureRequested(string mode)

    screen: targetScreen
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: motion.active
    WlrLayershell.keyboardFocus: panelFocus.mode
    ShellFocus { id: panelFocus; window: panel; enabled: expanded }

    function select(mode): void {
        pendingMode = (annotate ? "" : "quick-") + mode;
        expanded = false;
        captureDelay.restart();
    }

    onExpandedChanged: {
        if (expanded) {
            captureDelay.stop();
        }
    }

    Timer {
        id: captureDelay
        interval: 370
        onTriggered: panel.captureRequested(panel.pendingMode)
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
            edge: panel.leftBar ? "left" : "top"
            viewportWidth: panel.screen ? panel.screen.width : 0
            viewportHeight: panel.screen ? panel.screen.height : 0
        }
        attachTop: true
        attachLeft: true
        leftAttachmentWidth: panel.leftBar && panel.theme.barStyle === "islands"
            ? Math.max(0, x - leftFrameThickness) : 0
        topAttachmentHeight: !panel.leftBar && panel.theme.barStyle === "islands"
            ? Math.max(0, y - 8) : 0
        width: Math.min(350, panel.width - (panel.leftBar ? panel.leftInset : 0) - 24)
        height: Math.min(body.implicitHeight + 40, panel.height - panel.topInset - 24)
        x: Math.max(leftFrameThickness, panel.leftInset)
        y: panel.topInset
        radius: 28
        color: panel.theme.colors.surface
        focus: panel.visible
        Keys.onEscapePressed: panel.expanded = false

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: 20
            spacing: 9

            Text {
                text: qsTranslate("Spectrum", "SCREENSHOT")
                color: panel.theme.colors.accent
                font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 2; bold: true }
            }
            ShellButton {
                Layout.fillWidth: true
                label: panel.annotate ? qsTranslate("Spectrum", "Annotations · On") : qsTranslate("Spectrum", "Annotations · Off")
                fontFamily: panel.theme.fontFamily
                fontSize: panel.theme.fontSize
                backgroundColor: panel.annotate ? panel.theme.colors.accent : panel.theme.colors.surface_alt
                foregroundColor: panel.annotate ? panel.theme.colors.background : panel.theme.colors.foreground
                onClicked: panel.annotate = !panel.annotate
            }
            Repeater {
                model: [
                    { label: qsTranslate("Spectrum", "Capture area"), mode: "area" },
                    { label: qsTranslate("Spectrum", "Capture window"), mode: "window" },
                    { label: qsTranslate("Spectrum", "Capture monitor"), mode: "monitor" },
                    { label: qsTranslate("Spectrum", "Capture full screen"), mode: "full" },
                    { label: qsTranslate("Spectrum", "Capture after 5 seconds"), mode: "delay" }
                ]
                ShellButton {
                    required property var modelData
                    Layout.fillWidth: true
                    label: modelData.label
                    fontFamily: panel.theme.fontFamily
                    fontSize: panel.theme.fontSize
                    backgroundColor: panel.theme.colors.surface_alt
                    foregroundColor: panel.theme.colors.foreground
                    onClicked: panel.select(modelData.mode)
                }
            }
        }
    }

}
