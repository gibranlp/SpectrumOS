import QtQuick

Item {
    id: content
    required property var theme
    property bool previewActive: false
    readonly property bool available: !!theme.igorWardrobe
    implicitHeight: available ? 620 : 80
    function load(): void {
        if (!available) { loader.source = ""; return; }
        loader.setSource(Qt.resolvedUrl("IgorWardrobeModule.qml"), {theme:theme,active:previewActive});
    }
    onAvailableChanged: load()
    Component.onCompleted: load()
    Loader { id: loader; anchors.fill: parent }
    Binding { target: loader.item; property: "active"; value: content.previewActive; when: !!loader.item }
    Text {
        anchors.fill: parent
        visible: !content.available || loader.status === Loader.Error
        text: qsTranslate("Spectrum", "Igor’s wardrobe is unavailable. Try updating Igor.")
        color: content.theme.colors.muted
        wrapMode: Text.Wrap
        font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize }
    }
}
