import QtQuick
import QtQuick.Layouts
import "NotificationStyle.js" as NotificationStyle

ShellSurface {
    id: card
    attachRight: true
    required property var theme
    required property var notification
    readonly property var palette: NotificationStyle.palette(notification,theme.colors)
    readonly property var actionList: JSON.parse(notification.actionsJson || "[]")
    signal actionInvoked(string identifier)
    property bool revealed: true
    required property bool presented
    onRevealedChanged: {
        if (!revealed && !motion.active)
            Qt.callLater(() => dismissed());
    }
    signal activated()
    signal dismissed()
    transform: ShellMotion {
        id: motion
        surface: card
        animationsEnabled: card.theme.animationsEnabled !== false
        bounceEnabled: card.theme.widgetBounceEnabled !== false
        expanded: card.revealed && card.presented
        edge: "right"
        viewportWidth: card.parent.width
        viewportHeight: card.parent.height
        onActiveChanged: {
            if (!active && !card.revealed)
                card.dismissed();
        }
    }

    height: content.implicitHeight + 28
    radius: 18
    color: card.palette.background

    KeyboardAction {anchors.fill:parent;onActivated:card.activated()}

    RowLayout {
        id: content
        z:1
        x: 14
        y: 14
        width: card.width - 28
        spacing: 12

        Rectangle {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            radius: 11
            color: card.palette.alternate
            Image {
                id: appIcon
                anchors.centerIn: parent
                width: 28
                height: 28
                source: card.notification.iconSource || ""
                fillMode: Image.PreserveAspectFit
                visible: status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                visible: appIcon.status !== Image.Ready
                text: ""
                color: card.palette.accent
                font { family: card.theme.fontFamily; pixelSize: 27 }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                Layout.fillWidth: true
                text: card.notification.appName || "SpectrumOS"
                elide: Text.ElideRight
                color: card.palette.accent
                font { family: card.theme.fontFamily; pixelSize: Math.max(8, card.theme.fontSize - 1); bold: true }
            }
            Text {
                Layout.fillWidth: true
                text: card.notification.summary
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: card.palette.foreground
                font { family: card.theme.fontFamily; pixelSize: card.theme.fontSize + 1; bold: true }
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: card.notification.body
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: card.palette.persistent ? 5 : 2
                elide: Text.ElideRight
                color: card.palette.muted
                font { family: card.theme.fontFamily; pixelSize: card.theme.fontSize }
            }
            Flow {
                Layout.fillWidth:true
                visible:card.actionList.length>0
                spacing:6
                Repeater {
                    objectName:"notification-actions"
                    model:card.actionList
                    ShellButton {
                        required property var modelData
                        objectName:"notification-action-"+modelData.identifier
                        label:modelData.text
                        enabled:!card.notification.actionBusy
                        fontFamily:card.theme.fontFamily
                        fontSize:card.theme.fontSize
                        backgroundColor:card.palette.accent
                        foregroundColor:card.palette.background
                        onClicked:card.actionInvoked(modelData.identifier)
                    }
                }
            }
        }
    }

}
