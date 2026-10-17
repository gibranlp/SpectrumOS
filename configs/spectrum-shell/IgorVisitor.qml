import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: visitor
    required property var targetScreen
    required property var theme
    property int panelLeftInset: theme.panelLeftInset
    property int panelTopInset: theme.panelTopInset
    required property var routine
    readonly property bool largeDesktop: Math.max(targetScreen.width, targetScreen.height) >= 3840
        && Math.min(targetScreen.width, targetScreen.height) >= 2160
    readonly property real catSize: Math.max(130, Math.min(190, theme.fontSize * 10)) * (largeDesktop ? 1.3 : 1)
    readonly property int shellOverlap: 3
    readonly property int leftInset: Math.max(geometry.frameThickness, panelLeftInset)
    readonly property int topInset: panelTopInset
    ShellGeometry { id: geometry }

    screen: targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "spectrum-igor"
    color: "transparent"
    focusable: false
    mask: Region { item: sleeper.hoverTarget }
    visible: theme.animationsEnabled !== false && ((!routine.napping && stage.motionActive) || sleeper.motionActive)

    IgorNapStage {
        id: sleeper
        animationsEnabled: visitor.theme.animationsEnabled !== false
        anchors.fill: parent
        catSize: visitor.catSize
        edge: routine.edge
        position: routine.position
        leftInset: visitor.leftInset
        topInset: visitor.topInset
        rightInset: geometry.frameThickness
        bottomInset: geometry.frameThickness
        cornerClearance: geometry.curveRadius + 4
        active: routine.napping && routine.visiting && routine.selectedMonitor === visitor.targetScreen.name
        accent: visitor.theme.colors.accent
        fontFamily: visitor.theme.fontFamily
        onDismissRequested: routine.retreat()
    }

    IgorStage {
        id: stage
        animationsEnabled: visitor.theme.animationsEnabled !== false
        anchors.fill: parent
        leftInset: visitor.leftInset
        topInset: visitor.topInset
        rightInset: geometry.frameThickness
        bottomInset: geometry.frameThickness
        cornerClearance: geometry.curveRadius + 4
        shellOverlap: visitor.shellOverlap
        catSize: visitor.catSize
        musicNoteColors: ["accent", "accent_alt", "foreground", "success", "warning", "error"]
            .map(role => visitor.theme.colors[role]).filter(color => !!color)
        edge: routine.edge
        position: routine.position
        visiting: !routine.napping && routine.visiting && routine.selectedMonitor === visitor.targetScreen.name
        playing: routine.musicPlaying
        watching: routine.watching
        meeting: routine.meeting
        waving: routine.waving
        gesture: routine.gesture
        celebrationMessage: routine.celebrationMessage
        headphonesColor: visitor.theme.colors.accent
        headphonesHighlight: visitor.theme.colors.accent_alt || visitor.theme.colors.accent
        bubbleColor: visitor.theme.colors.surface_alt
        bubbleTextColor: visitor.theme.colors.foreground
        fontFamily: visitor.theme.fontFamily
        fontSize: visitor.theme.fontSize
    }
}
