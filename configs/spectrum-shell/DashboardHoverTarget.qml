import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
    id: target
    required property var targetScreen
    property string barPosition: "left"
    property string barProfile: "standard"
    property bool barVisible: true
    property int leftInset: 0
    property bool dashboardOpen: false
    readonly property bool topBarActive: barVisible && barPosition === "top"
    readonly property bool coversNotch: barVisible && barPosition === "left" && barProfile === "multimedia"
    signal openRequested()

    DashboardHoverArea {
        anchors.fill: parent
        enabled: target.topBarActive
        dashboardOpen: target.dashboardOpen
        onOpenRequested: target.openRequested()
    }

    PanelWindow {
        id: edge
        objectName: "dashboard-edge-window"
        visible: !target.topBarActive
        screen: target.targetScreen
        anchors { top: true; left: true; right: true }
        implicitHeight: target.coversNotch ? 34 : 8
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "spectrum-dashboard-hover"
        color: "transparent"
        focusable: false
        mask: Region { item: edgeHover }

        DashboardHoverArea {
            id: edgeHover
            objectName: "dashboard-edge-area"
            x: (edge.width + target.leftInset - width) / 2
            width: Math.min(edge.width, target.coversNotch ? edge.width * 0.2 : 260)
            height: parent.height
            dashboardOpen: target.dashboardOpen
            onOpenRequested: target.openRequested()
        }
    }
}
