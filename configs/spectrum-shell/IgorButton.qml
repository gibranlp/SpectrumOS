import QtQuick

Rectangle {
    id: button
    required property var theme
    implicitWidth: 30
    implicitHeight: 28
    radius: 8
    color: theme.igorEnabled ? theme.colors.accent : (mouse.containsMouse ? theme.colors.surface_alt : "transparent")
    Accessible.role: Accessible.CheckBox
    Accessible.name: "Igor"
    Accessible.description: qsTranslate("Spectrum", "Toggle Igor visits. Right-click to open his wardrobe.")
    Accessible.checked: theme.igorEnabled

    Image {
        anchors.centerIn: parent
        width: 26
        height: 20
        source: "file:///usr/lib/qt6/qml/Spectrum/Igor/igor/face.svg"
        sourceSize.width: 52
        fillMode: Image.PreserveAspectFit
        opacity: button.theme.igorEnabled ? 1 : 0.6
    }
    KeyboardAction {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onActivated: mouseButton => {
            if (mouseButton === Qt.RightButton) button.theme.openIgorWardrobe();
            else button.theme.toggleIgor();
        }
    }
}
