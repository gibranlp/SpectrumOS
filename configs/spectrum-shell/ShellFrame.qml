import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "spectrum-frame"
    id: frame
    required property var targetScreen
    required property var theme
    required property string barPosition
    ShellGeometry { id: geometry }
    readonly property int thickness: geometry.frameThickness
    readonly property int curveRadius: geometry.curveRadius
    readonly property int cornerExtent: thickness + curveRadius
    readonly property int contentInset: 14
    readonly property int barClearance: 5
    property int barHeight: 34
    property string barProfile: theme.barProfile
    readonly property bool barVisible: barProfile !== "minimal" && barProfile !== "gaming"
    visible: barProfile !== "gaming"
    readonly property bool islands: theme.barStyle === "islands"
    readonly property int topBarHeight: barVisible && !islands ? barHeight : thickness
    readonly property int leftBarWidth: barVisible && !islands ? 52 : thickness

    screen: targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    implicitWidth: targetScreen ? targetScreen.width : 0
    implicitHeight: targetScreen ? targetScreen.height : 0
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    focusable: false
    mask: Region {}
    IdleInhibitor {
        window: frame
        enabled: frame.theme.screensaverMediaBlocked === true
    }

    PanelWindow {
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "spectrum-frame-reservation"
        visible: frame.visible
        screen: frame.targetScreen
        anchors { top: true; left: true; right: true }
        implicitHeight: frame.contentInset
        exclusiveZone: frame.barVisible && frame.barPosition === "top" ? frame.barHeight + frame.barClearance : frame.contentInset
        color: "transparent"
        focusable: false
        mask: Region {}
    }

    PanelWindow {
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "spectrum-frame-reservation"
        visible: frame.visible
        screen: frame.targetScreen
        anchors { top: true; bottom: true; left: true }
        implicitWidth: frame.contentInset
        exclusiveZone: frame.barVisible && frame.barPosition === "left" ? 52 + frame.barClearance : frame.contentInset
        color: "transparent"
        focusable: false
        mask: Region {}
    }

    PanelWindow {
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "spectrum-frame-reservation"
        visible: frame.visible
        screen: frame.targetScreen
        anchors { top: true; bottom: true; right: true }
        implicitWidth: frame.contentInset
        exclusiveZone: frame.contentInset
        color: "transparent"
        focusable: false
        mask: Region {}
    }

    PanelWindow {
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "spectrum-frame-reservation"
        visible: frame.visible
        screen: frame.targetScreen
        anchors { bottom: true; left: true; right: true }
        implicitHeight: frame.contentInset
        exclusiveZone: frame.contentInset
        color: "transparent"
        focusable: false
        mask: Region {}
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: frame.leftBarWidth + frame.cornerExtent - frame.thickness; rightMargin: frame.cornerExtent }
        height: frame.thickness
        color: frame.theme.colors.surface
        visible: frame.islands || !frame.barVisible || frame.barPosition === "left"
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: frame.barPosition === "left" ? frame.leftBarWidth + frame.cornerExtent - frame.thickness : frame.cornerExtent; rightMargin: frame.cornerExtent }
        height: frame.thickness
        color: frame.theme.colors.surface
    }

    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: frame.topBarHeight + frame.cornerExtent - frame.thickness; bottomMargin: frame.cornerExtent }
        width: frame.thickness
        color: frame.theme.colors.surface
        visible: frame.islands || !frame.barVisible || frame.barPosition === "top"
    }

    Rectangle {
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: frame.barPosition === "top" ? frame.topBarHeight + frame.cornerExtent - frame.thickness : frame.cornerExtent; bottomMargin: frame.cornerExtent }
        width: frame.thickness
        color: frame.theme.colors.surface
    }

    ShellCorner {
        x: frame.barPosition === "left" ? frame.leftBarWidth - frame.thickness : 0
        y: frame.barPosition === "top" ? frame.topBarHeight - frame.thickness : 0
        frameThickness: frame.thickness
        curveRadius: frame.cornerExtent - frame.thickness
        surfaceColor: frame.theme.colors.surface
    }
    ShellCorner {
        x: frame.width - width
        y: frame.barPosition === "top" ? frame.topBarHeight - frame.thickness : 0
        frameThickness: frame.thickness
        curveRadius: frame.cornerExtent - frame.thickness
        surfaceColor: frame.theme.colors.surface
        mirrorX: true
    }
    ShellCorner {
        anchors { right: parent.right; bottom: parent.bottom }
        frameThickness: frame.thickness
        curveRadius: frame.cornerExtent - frame.thickness
        surfaceColor: frame.theme.colors.surface
        mirrorX: true
        mirrorY: true
    }
    ShellCorner {
        x: frame.barPosition === "left" ? frame.leftBarWidth - frame.thickness : 0
        y: frame.height - height
        frameThickness: frame.thickness
        curveRadius: frame.cornerExtent - frame.thickness
        surfaceColor: frame.theme.colors.surface
        mirrorY: true
    }
}
