import QtQuick

Item {
    id: bridge
    visible: false
    required property var targetScreen
    required property var theme
    required property var routine
    property int panelLeftInset: theme.panelLeftInset
    property int panelTopInset: theme.panelTopInset
    readonly property bool runtimeReady: visitor.status === Loader.Ready
    Loader { id: visitor; active: bridge.routine.runtimeReady }
    function loadVisitor(): void {
        if (!routine.runtimeReady || !targetScreen) { visitor.source = ""; return; }
        visitor.setSource(Qt.resolvedUrl("IgorVisitorModule.qml"), {
            targetScreen: targetScreen, theme: theme, routine: routine,
            panelLeftInset: panelLeftInset, panelTopInset: panelTopInset
        });
    }
    Component.onCompleted: loadVisitor()
    Connections {
        target: bridge.routine
        function onRuntimeReadyChanged() { bridge.loadVisitor(); }
    }
    Binding { target: visitor.item; property: "targetScreen"; value: bridge.targetScreen; when: !!visitor.item }
    Binding { target: visitor.item; property: "panelLeftInset"; value: bridge.panelLeftInset; when: !!visitor.item }
    Binding { target: visitor.item; property: "panelTopInset"; value: bridge.panelTopInset; when: !!visitor.item }
}
