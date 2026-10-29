import QtQuick

Item {
    id: indicator
    required property var theme
    property bool active: false
    property string peerName: ""
    property bool animationsEnabled: true
    property bool lit: true
    readonly property string description: peerName
        ? qsTranslate("Spectrum", "This computer is being controlled by ") + peerName
        : qsTranslate("Spectrum", "This computer is being controlled remotely")
    signal activated()
    implicitWidth: 30
    implicitHeight: 30
    visible: active
    onActiveChanged: lit = true
    onAnimationsEnabledChanged: lit = true
    Accessible.role: Accessible.Button
    Accessible.name: description
    Accessible.onPressAction: activated()
    Text {
        anchors.centerIn: parent
        text: "󰢹"
        color: "#ff3b30"
        opacity: indicator.lit ? 1 : 0.4
        font { family: indicator.theme.fontFamily; pixelSize: indicator.theme.fontSize + 5; bold: true }
    }
    Timer {
        interval: 650
        running: indicator.active && indicator.visible && indicator.animationsEnabled
        repeat: true
        onTriggered: indicator.lit = !indicator.lit
    }
    KeyboardAction {
        id: action
        anchors.fill: parent
        hoverEnabled: true
        onActivated: indicator.activated()
    }
}
