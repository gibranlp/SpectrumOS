import QtQuick

Item {
    id: dismissal
    property bool active: false
    signal dismissed()
    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: dismissal.active
        autoRepeat: false
        onActivated: dismissal.dismissed()
    }
}
