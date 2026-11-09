import QtQuick
import QtQuick.Window

Rectangle {
    id: button

    property string label: ""
    property color backgroundColor: "#2e2c34"
    property color foregroundColor: "#eff3fa"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 12
    property bool animationsEnabled: !Window.window || !Window.window.theme || Window.window.theme.animationsEnabled !== false
    readonly property bool pressed: enabled && (action.down || activationPulse.running)
    signal clicked()

    function activate(): void {
        if (!enabled) return;
        activationPulse.restart();
        clicked();
    }

    implicitWidth: Math.max(36, labelText.implicitWidth + 24)
    implicitHeight: 34
    radius: 8
    scale: pressed && animationsEnabled ? 0.97 : 1
    Behavior on scale { enabled: button.animationsEnabled; NumberAnimation { duration: 80 } }
    Behavior on color { enabled: button.animationsEnabled; ColorAnimation { duration: 80 } }
    color: !enabled ? Qt.darker(backgroundColor, 1.3) : pressed
        ? Qt.tint(backgroundColor, Qt.rgba(foregroundColor.r, foregroundColor.g, foregroundColor.b, 0.2)) : action.activeFocus
        ? Qt.tint(backgroundColor, Qt.rgba(foregroundColor.r, foregroundColor.g, foregroundColor.b, 0.3)) : backgroundColor
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: activate()
    Timer { id: activationPulse; interval: 120 }

    Text {
        id: labelText
        anchors.centerIn: parent
        width: parent.width - 20
        text: button.label
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        color: button.enabled ? button.foregroundColor : Qt.darker(button.foregroundColor, 1.8)
        font { family: button.fontFamily; pixelSize: button.fontSize; bold: true }
    }

    KeyboardAction {
        id: action
        highlightEnabled: false
        anchors.fill: parent
        enabled: button.enabled
        cursorShape: Qt.PointingHandCursor
        onActivated: button.activate()
    }
}
