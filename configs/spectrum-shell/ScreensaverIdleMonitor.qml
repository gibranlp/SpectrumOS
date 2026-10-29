pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland

Loader {
    id: monitor
    property bool monitoring: false
    property real timeout: 180
    property real armedTimeout: 180
    readonly property bool isIdle: item ? item.isIdle : false
    active: false

    // Recrea el monitor para evitar que Quickshell pierda el enlace al cambiar el tiempo de espera.
    function rebuild(): void {
        active = false;
        Qt.callLater(arm);
    }
    function arm(): void {
        armedTimeout = timeout;
        active = monitoring;
    }
    onMonitoringChanged: rebuild()
    onTimeoutChanged: rebuild()
    Component.onCompleted: rebuild()

    sourceComponent: IdleMonitor {
        timeout: monitor.armedTimeout
        respectInhibitors: true
    }
}
