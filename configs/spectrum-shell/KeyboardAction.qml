import QtQuick

MouseArea {
    id: action
    property bool highlightEnabled: true
    property color focusColor: {
        for (let item = parent; item; item = item.parent)
            if (item.theme && item.theme.colors) return item.theme.colors.accent;
        return "#eff3fa";
    }
    signal activated(int mouseButton)
    activeFocusOnTab: true
    onClicked: mouse => activated(mouse.button)
    function activationKey(key): bool {
        return [Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(key)
            || (key === Qt.Key_Menu && (acceptedButtons & Qt.RightButton));
    }
    Keys.onPressed: event => {
        if (activationKey(event.key))
            event.accepted = true;
    }
    Keys.onReleased: event => {
        if (activationKey(event.key)) {
            if (!event.isAutoRepeat)
                activated(event.key === Qt.Key_Menu ? Qt.RightButton : Qt.LeftButton);
            event.accepted = true;
        }
    }
    Rectangle {
        anchors.fill: parent
        color: action.focusColor
        opacity: 0.25
        radius: 6
        visible: action.activeFocus && action.highlightEnabled
    }
}
