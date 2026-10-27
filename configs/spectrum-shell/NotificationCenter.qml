import QtQuick
import QtQuick.Layouts
import "NotificationStyle.js" as NotificationStyle
import Quickshell
import Quickshell.Wayland

PanelWindow {
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "spectrum-widget-notificationcenter"
    id: center
    required property var theme
    required property var notificationModel
    property var history: []
    required property bool doNotDisturb
    property bool expanded: false
    property int topInset: 34
    signal closeRequested()
    signal clearHistory()
    signal dismissHistory(var item)
    signal toggleDoNotDisturb()
    signal questlineDrinkRequested(var notification)
    signal updatesRequested(var notification)

    readonly property var visibleItems: {
        const active = Array.from(notificationModel.values).filter(item => item.appName !== "Spectrum Volume");
        return active.concat(history.filter(item => item.appName !== "Spectrum Volume" && !active.includes(item.notification)));
    }

    anchors { top: true; bottom: true; left: true; right: true }
    margins.bottom: 8
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: motion.active
    WlrLayershell.keyboardFocus: panelFocus.mode
    ShellFocus { id: panelFocus; window: center; enabled: expanded }

    MouseArea {
        anchors.fill: parent
        visible: center.expanded
        onClicked: center.closeRequested()
    }

    ShellSurface {
        id: frame
        transform: ShellMotion {
            id: motion
            surface: frame
            animationsEnabled: center.theme.animationsEnabled !== false
            bounceEnabled: center.theme.widgetBounceEnabled !== false
            expanded: center.expanded
            edge: "right"
            viewportWidth: center.screen.width
            viewportHeight: center.screen.height
        }
        topAttachmentHeight: center.theme.barStyle === "islands" && center.theme.barPosition === "top"
            ? Math.max(0, y - 8) : 0
        attachTop: true
        attachBottom: true
        attachRight: true
        width: Math.min(352, parent.width)
        height: parent.height - center.topInset
        x: center.width - width
        y: center.topInset

        color: center.theme.colors.surface
        radius: 32
        focus: center.expanded
        Keys.onEscapePressed: center.closeRequested()
        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: qsTranslate("Spectrum", "NOTIFICATIONS")
                    color: center.theme.colors.foreground
                    font { family: center.theme.fontFamily; pixelSize: center.theme.fontSize + 5; bold: true }
                }
                Item { Layout.fillWidth: true }
                ShellButton {
                    label: "✕"
                    fontFamily: center.theme.fontFamily
                    fontSize: center.theme.fontSize
                    backgroundColor: center.theme.colors.surface_alt
                    foregroundColor: center.theme.colors.foreground
                    onClicked: center.closeRequested()
                }
            }
            RowLayout {
                Layout.fillWidth: true
                ShellButton {
                    label: center.doNotDisturb ? qsTranslate("Spectrum", "Do not disturb: on") : qsTranslate("Spectrum", "Do not disturb: off")
                    fontFamily: center.theme.fontFamily
                    fontSize: center.theme.fontSize - 1
                    backgroundColor: center.doNotDisturb ? center.theme.colors.accent : center.theme.colors.surface_alt
                    foregroundColor: center.doNotDisturb ? center.theme.colors.background : center.theme.colors.foreground
                    onClicked: center.toggleDoNotDisturb()
                }
                Item { Layout.fillWidth: true }
                ShellButton {
                    label: qsTranslate("Spectrum", "Clear all")
                    fontFamily: center.theme.fontFamily
                    fontSize: center.theme.fontSize - 1
                    backgroundColor: center.theme.colors.surface_alt
                    foregroundColor: center.theme.colors.foreground
                    onClicked: {
                        const items = Array.from(center.notificationModel.values);
                        for (const item of items) item.dismiss();
                        center.clearHistory();
                    }
                }
            }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                objectName:"notification-center-items"
                model: center.visibleItems
                delegate: Rectangle {
                    id:noticeEntry
                    required property var modelData
                    readonly property var palette:NotificationStyle.palette(modelData,center.theme.colors)
                    width: ListView.view.width
                    height: entry.implicitHeight + 24
                    radius: 10
                    color: noticeEntry.palette.kind ? noticeEntry.palette.background : center.theme.colors.surface_alt
                    ColumnLayout {
                        id: entry
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 5
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: modelData.appName || qsTranslate("Spectrum", "Application")
                                color: noticeEntry.palette.accent
                                font { family: center.theme.fontFamily; pixelSize: center.theme.fontSize - 2; bold: true }
                            }
                            Item { Layout.fillWidth: true }
                            ShellButton {
                                label: "✕"
                                fontFamily: center.theme.fontFamily
                                fontSize: center.theme.fontSize - 2
                                backgroundColor: noticeEntry.palette.alternate
                                foregroundColor: noticeEntry.palette.foreground
                                onClicked: {
                                    center.dismissHistory(modelData);
                                    if (modelData.dismiss) modelData.dismiss();
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.summary
                            wrapMode: Text.Wrap
                            color: noticeEntry.palette.foreground
                            font { family: center.theme.fontFamily; pixelSize: center.theme.fontSize; bold: true }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.body
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            visible: text.length > 0
                            color: noticeEntry.palette.muted
                            font { family: center.theme.fontFamily; pixelSize: center.theme.fontSize - 1 }
                        }
                        ShellButton {
                            objectName:"notification-center-drink"
                            visible:noticeEntry.palette.kind==="hydration" && !!modelData.dismiss
                            label:qsTranslate("Spectrum", "Drink")
                            fontFamily:center.theme.fontFamily
                            fontSize:center.theme.fontSize
                            backgroundColor:noticeEntry.palette.accent
                            foregroundColor:noticeEntry.palette.background
                            onClicked:center.questlineDrinkRequested(modelData)
                        }
                        ShellButton {
                            objectName: "notification-center-open-updates"
                            visible: NotificationStyle.isStableUpdate(modelData)
                            label: qsTranslate("Spectrum", "Open Updates")
                            fontFamily: center.theme.fontFamily
                            fontSize: center.theme.fontSize
                            backgroundColor: noticeEntry.palette.accent
                            foregroundColor: noticeEntry.palette.background
                            onClicked: center.updatesRequested(modelData)
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 5
                            Repeater {
                                model: modelData.actions || []
                                ShellButton {
                                    required property var modelData
                                    label: ["spectrum-open-updates", "questline-drink"].includes(modelData.identifier) ? qsTranslate("Spectrum", modelData.text) : modelData.text
                                    fontFamily: center.theme.fontFamily
                                    fontSize: center.theme.fontSize - 2
                                    backgroundColor: noticeEntry.palette.accent
                                    foregroundColor: noticeEntry.palette.background
                                    onClicked: modelData.invoke()
                                }
                            }
                        }
                    }
                }
            }
            Text {
                visible: center.visibleItems.length === 0
                text: qsTranslate("Spectrum", "All caught up")
                color: center.theme.colors.muted
                font { family: center.theme.fontFamily; pixelSize: center.theme.fontSize }
            }
        }
    }
}
