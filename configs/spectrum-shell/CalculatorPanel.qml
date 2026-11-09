pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: panel
    required property var theme
    required property string backendDir
    property bool expanded: false
    property bool keyboardEnabled: true
    signal keyboardRequested()
    property bool paired: false
    property int leftInset: 0
    property int topInset: 8
    readonly property bool sideBySide: screen.width - leftInset >= 1200
    readonly property real panelWidth: paired && sideBySide
        ? Math.min(540, (screen.width - leftInset - 24) * 0.36)
        : Math.min(680, screen.width - leftInset - 16)
    readonly property real panelHeight: Math.min(calculatorContent.implicitHeight + 100,
        paired && !sideBySide ? (screen.height - topInset - 24) * 0.55 : screen.height - topInset - 24)
    readonly property real questlineWidth: Math.min(1500, screen.width - leftInset - panelWidth - 24)
    readonly property rect panelGeometry: Qt.rect(frame.x, frame.y, frame.width, frame.height)

    function open(): void {
        calculatorContent.ensureLoaded();
        keyboardRequested();
        expanded = true;
        calculatorContent.item.activate();
    }

    visible: motion.active
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "spectrum-widget-calculator"
    WlrLayershell.keyboardFocus: panelFocus.mode
    ShellFocus { id: panelFocus; window: panel; enabled: panel.expanded && panel.keyboardEnabled }
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region { item: panel.paired ? frame : backdrop }

    MouseArea {
        id: backdrop
        anchors.fill: parent
        onClicked: panel.expanded = false
    }

    ShellSurface {
        id: frame
        width: panel.panelWidth
        height: panel.panelHeight
        x: panel.paired ? panel.sideBySide
            ? panel.leftInset + (panel.screen.width - panel.leftInset - panel.questlineWidth - width - 8) / 2 + panel.questlineWidth + 8
            : panel.screen.width - width - 8
            : (panel.screen.width + panel.leftInset - width) / 2
        y: panel.screen.height - height - 8
        attachBottom: true
        radius: 32
        color: panel.theme.colors.surface
        transform: ShellMotion {
            id: motion
            surface: frame
            expanded: panel.expanded
            edge: "bottom"
            viewportWidth: panel.screen.width
            viewportHeight: panel.screen.height
            animationsEnabled: panel.theme.animationsEnabled !== false
            bounceEnabled: panel.theme.widgetBounceEnabled !== false
        }
        Keys.onEscapePressed: panel.expanded = false
        // Cede el clic al control original después de asignar el foco del teclado.
        MouseArea {
            anchors.fill: parent
            z: 1000
            onPressed: mouse => { panel.keyboardRequested(); mouse.accepted = false; }
        }
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors { fill: parent; margins: 22 }
            spacing: 14
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: qsTranslate("Spectrum", "Calculator")
                    color: panel.theme.colors.foreground
                    font { family: panel.theme.fontFamily; pixelSize: panel.theme.fontSize + 5; bold: true }
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
            Controls.ScrollView {
                id: scroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                CachedContent {
                    id: calculatorContent
                    requested: panel.expanded
                    width: scroll.availableWidth
                    sourceComponent: Calculator {
                        theme: panel.theme
                        backendDir: panel.backendDir
                        onCloseRequested: panel.expanded = false
                    }
                }
            }
        }
    }
}
