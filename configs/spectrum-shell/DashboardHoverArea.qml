import QtQuick

Item {
    id: hotspot
    property bool dashboardOpen: false
    property int delay: 180
    readonly property bool hovered: pointer.hovered
    signal openRequested()

    onDashboardOpenChanged: if (dashboardOpen) dwell.stop()
    onEnabledChanged: if (!enabled) dwell.stop()

    HoverHandler {
        id: pointer
        onHoveredChanged: {
            if (hovered && hotspot.enabled && !hotspot.dashboardOpen) dwell.restart();
            else dwell.stop();
        }
    }
    Timer {
        id: dwell
        interval: hotspot.delay
        onTriggered: if (hotspot.enabled && pointer.hovered && !hotspot.dashboardOpen) hotspot.openRequested()
    }
}
