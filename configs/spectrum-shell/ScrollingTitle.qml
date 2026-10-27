import QtQuick

Item {
    id: control
    property string title: ""
    property string windowIdentity: ""
    property string fontFamily: "monospace"
    property int fontPixelSize: 13
    property color textColor: "white"
    property bool animationsEnabled: true
    onAnimationsEnabledChanged: if (!animationsEnabled) scrollOffset = 0
    property bool autoScroll: false
    property bool centered: false
    property bool bold: false
    property bool vertical: false
    property int verticalExtent: 240
    readonly property real measuredTextWidth: label.implicitWidth
    property int scrollOffset: 0
    implicitWidth: vertical ? 42 : 420
    implicitHeight: vertical ? verticalExtent : 30

    HoverHandler { id: titleHover; onHoveredChanged: if (!hovered && !control.autoScroll) control.scrollOffset = 0 }

    Item {
        id: viewport
        width: control.vertical ? control.implicitHeight : control.width
        height: control.vertical ? 28 : control.height
        anchors.centerIn: parent
        rotation: control.vertical ? -90 : 0
        clip: true

        Text {
            id: label
            x: -control.scrollOffset
            width: Math.max(viewport.width, control.measuredTextWidth)
            height: viewport.height
            text: control.title
            textFormat: Text.PlainText
            color: control.textColor
            font { family: control.fontFamily; pixelSize: control.fontPixelSize; bold: control.bold }
            horizontalAlignment: control.centered ? Text.AlignHCenter : Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.NoWrap
        }

        Timer {
            interval: 30
            repeat: true
            running: control.animationsEnabled && control.visible && (control.autoScroll || titleHover.hovered) && control.measuredTextWidth > viewport.width
            onTriggered: {
                const maxOffset = Math.max(0, control.measuredTextWidth - viewport.width);
                control.scrollOffset = control.scrollOffset >= maxOffset ? 0 : control.scrollOffset + 1;
            }
        }
    }

    onTitleChanged: {
        scrollOffset = 0;
    }
    onWindowIdentityChanged: {
        scrollOffset = 0;
    }
}
