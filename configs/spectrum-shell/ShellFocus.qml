import QtQuick
import QtQuick.Window
import Quickshell.Wayland

QtObject {
    id: controller
    required property var window
    required property bool enabled
    property bool active: window.contentItem.Window.active
    property bool acquiring: false
    readonly property int mode: !enabled ? WlrKeyboardFocus.None
        : acquiring ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

    // El foco exclusivo inicial libera el puntero del juego; después la barra vuelve a recibir clics.
    function acquire(): void {
        release.stop();
        acquiring = enabled && !active;
    }

    onEnabledChanged: acquire()
    Component.onCompleted: acquire()

    onActiveChanged: {
        if (active && acquiring)
            release.restart();
    }

    property Timer release: Timer {
        interval: 0
        onTriggered: controller.acquiring = false
    }
}
