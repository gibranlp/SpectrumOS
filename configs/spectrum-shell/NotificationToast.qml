import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
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
    property real maximumHeight: 520
    property real exitProgress: 0
    opacity: 1 - exitProgress
    onRevealedChanged: {
        if (!revealed) {
            if (theme.animationsEnabled !== false && presented) exitAnimation.start();
            else { exitProgress = 1; Qt.callLater(() => dismissed()); }
        }
    }
    signal activated()
    signal dismissed()
    transform: [Translate { x: card.width * card.exitProgress }, ShellMotion {
        id: motion
        surface: card
        animationsEnabled: card.theme.animationsEnabled !== false
        bounceEnabled: card.theme.widgetBounceEnabled !== false
        expanded: card.presented
        edge: "right"
        viewportWidth: card.parent.width
        viewportHeight: card.parent.height
    }]
    NumberAnimation {
        id: exitAnimation
        target: card; property: "exitProgress"
        to: 1; duration: 240; easing.type: Easing.InCubic
        onFinished: card.dismissed()
    }

    height: Math.min(content.implicitHeight + 36, maximumHeight)
    radius: 18
    color: card.palette.background

    KeyboardAction {anchors.fill:parent;onActivated:card.activated()}

    Flickable {
        id: viewport
        anchors.fill: parent
        anchors.margins: 18
        contentWidth: width
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        clip: true
        Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
    RowLayout {
        id: content
        z:1
        width: viewport.width
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
                color: card.palette.foreground
                font { family: card.theme.fontFamily; pixelSize: card.theme.fontSize + 1; bold: true }
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: card.notification.body
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
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
                        label: ["spectrum-open-updates", "questline-drink"].includes(modelData.identifier) ? qsTranslate("Spectrum", modelData.text) : modelData.text
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

}
