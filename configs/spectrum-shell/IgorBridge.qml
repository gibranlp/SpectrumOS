import QtQuick

Item {
    id: bridge
    visible: false
    property url runtimeSource: Qt.resolvedUrl("IgorRoutineModule.qml")
    property bool visitsEnabled: false
    property bool available: false
    property var monitorNames: []
    property var blockedMonitors: []
    property bool suppressed: false
    property bool playing: false
    property string mediaKind: "unknown"
    property bool meeting: false
    property bool celebrationsAllowed: true
    readonly property bool runtimeReady: runtime.status === Loader.Ready && !!runtime.item && runtime.item.apiVersion === 1
    readonly property string runtimeVersion: runtimeReady ? runtime.item.runtimeVersion : ""
    readonly property var wardrobe: runtimeReady && runtime.item.wardrobe ? runtime.item.wardrobe : null
    readonly property var outfitSelection: wardrobe ? wardrobe.selection : ({mode:"auto",outfitId:"none"})
    readonly property bool visiting: runtimeReady && runtime.item.visiting
    readonly property bool napping: runtimeReady && runtime.item.napping
    readonly property bool waving: runtimeReady && runtime.item.waving
    readonly property bool musicPlaying: runtimeReady && runtime.item.musicPlaying
    readonly property bool watching: runtimeReady && runtime.item.watching
    readonly property string selectedMonitor: runtimeReady ? runtime.item.selectedMonitor : ""
    readonly property string edge: runtimeReady ? runtime.item.edge : "bottom"
    readonly property real position: runtimeReady ? runtime.item.position : 0.5
    readonly property string gesture: runtimeReady ? runtime.item.gesture : "curious"
    readonly property string celebrationMessage: runtimeReady ? runtime.item.celebrationMessage : ""

    function greet(): bool { return runtimeReady ? runtime.item.greet() : false; }
    function nap(): bool { return runtimeReady ? runtime.item.nap() : false; }
    function celebrate(): bool { return runtimeReady ? runtime.item.celebrate() : false; }
    function appear(edge, monitor = ""): bool { return runtimeReady ? runtime.item.appear(edge, monitor) : false; }
    function retreat(): void { if (runtimeReady) runtime.item.retreat(); }

    Loader { id: runtime; source: bridge.runtimeSource }
    Binding { target: bridge.runtimeReady ? runtime.item : null; property: "visitsEnabled"; value: bridge.visitsEnabled; when: bridge.runtimeReady }
    Binding { target: bridge.runtimeReady ? runtime.item : null; property: "available"; value: bridge.available; when: bridge.runtimeReady }
    Binding { target: bridge.runtimeReady ? runtime.item : null; property: "monitorNames"; value: bridge.monitorNames; when: bridge.runtimeReady }
    Binding { target: bridge.runtimeReady ? runtime.item : null; property: "blockedMonitors"; value: bridge.blockedMonitors; when: bridge.runtimeReady }
    Binding { target: bridge.runtimeReady ? runtime.item : null; property: "suppressed"; value: bridge.suppressed; when: bridge.runtimeReady }
    Binding { target: bridge.runtimeReady ? runtime.item : null; property: "playing"; value: bridge.playing; when: bridge.runtimeReady }
    Binding { target: bridge.runtimeReady ? runtime.item : null; property: "mediaKind"; value: bridge.mediaKind; when: bridge.runtimeReady }
    Binding { target: bridge.runtimeReady ? runtime.item : null; property: "meeting"; value: bridge.meeting; when: bridge.runtimeReady }
    Binding { target: bridge.runtimeReady ? runtime.item : null; property: "celebrationsAllowed"; value: bridge.celebrationsAllowed; when: bridge.runtimeReady }
}
