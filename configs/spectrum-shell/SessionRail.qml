import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Scope {
    id: rail
    required property var targetScreen
    required property var theme
    property bool expanded: false
    property int selectedIndex: 0
    signal actionRequested(string action)

    readonly property var actions: [
        { key: "lock", icon: "󰌾" },
        { key: "suspend", icon: "󰤄" },
        { key: "logout", icon: "󰗼" },
        { key: "reboot", icon: "󰜉" },
        { key: "poweroff", icon: "󰐥" }
    ]

    function choose(action): void {
        expanded = false;
        actionRequested(action);
    }

    onExpandedChanged: {
        if (expanded) {
            selectedIndex = 0;
            Qt.callLater(() => keyboardTarget.forceActiveFocus());
        }
    }

    PanelWindow {
        id: railWindow
        screen: rail.targetScreen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: motion.active
        WlrLayershell.keyboardFocus: panelFocus.mode
        ShellFocus { id: panelFocus; window: railWindow; enabled: rail.expanded }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "spectrum-widget-sessionrail"

        Item {
            id: keyboardTarget
            anchors.fill: parent
            focus: true
            Keys.onUpPressed: rail.selectedIndex = Math.max(0, rail.selectedIndex - 1)
            Keys.onDownPressed: rail.selectedIndex = Math.min(rail.actions.length - 1, rail.selectedIndex + 1)
            Keys.onReturnPressed: rail.choose(rail.actions[rail.selectedIndex].key)
            Keys.onEnterPressed: rail.choose(rail.actions[rail.selectedIndex].key)
            Keys.onEscapePressed: rail.expanded = false
        }

        MouseArea {
            anchors.fill: parent
            onClicked: rail.expanded = false
        }

        ShellSurface {
            id: railBody
            Keys.onEscapePressed: rail.expanded = false
            transform: ShellMotion {
                id: motion
                surface: railBody
                animationsEnabled: rail.theme.animationsEnabled !== false
                bounceEnabled: rail.theme.widgetBounceEnabled !== false
                expanded: rail.expanded
                edge: "right"
                viewportWidth: rail.targetScreen.width
                viewportHeight: rail.targetScreen.height
            }
            attachRight: true
            width: 72
            height: railContents.implicitHeight + 28
            x: railWindow.width - width
            y: (railWindow.height - height) / 2
            radius: 28
            color: rail.theme.colors.surface


            Rectangle {
                anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                width: 28
                color: parent.color
            }

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                id: railContents
                anchors.centerIn: parent
                spacing: 5
                Repeater {
                    model: rail.actions
                    Rectangle {
                        required property var modelData
                        required property int index
                        implicitWidth: 48
                        implicitHeight: 48
                        radius: 11
                        color: rail.selectedIndex === index ? Qt.tint(rail.theme.colors.surface_alt, Qt.rgba(rail.theme.colors.accent.r, rail.theme.colors.accent.g, rail.theme.colors.accent.b, 0.35)) : actionMouse.containsMouse ? rail.theme.colors.surface_alt : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            color: rail.theme.colors.foreground
                            font { family: rail.theme.fontFamily; pixelSize: rail.theme.fontSize + 10 }
                        }
                        KeyboardAction {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onActiveFocusChanged: { if (activeFocus) rail.selectedIndex = index; }
                            onActivated: { rail.selectedIndex = index; rail.choose(modelData.key); }
                        }
                    }
                }
            }
        }

    }
}
