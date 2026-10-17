import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "spectrum-widget-dashboard"
    id: dashboard
    required property var targetScreen
    required property var theme
    required property var weather
    required property var media
    property int topInset: 34
    property int leftInset: 0
    property bool expanded: false
    property string currentTime: Qt.formatDateTime(new Date(), "HH:mm")
    property string currentDate: Qt.formatDateTime(new Date(), "ddd, d MMMM")
    property date calendarMonth: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    readonly property int calendarOffset: (calendarMonth.getDay() + 6) % 7
    readonly property int daysInMonth: new Date(calendarMonth.getFullYear(), calendarMonth.getMonth() + 1, 0).getDate()
    signal actionRequested(string action)

    screen: targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: motion.active
    focusable: expanded

    Timer {
        interval: 10000
        running: dashboard.visible
        repeat: true
        onTriggered: {
            dashboard.currentTime = Qt.formatDateTime(new Date(), "HH:mm");
            dashboard.currentDate = Qt.formatDateTime(new Date(), "ddd, d MMMM");
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: dashboard.expanded = false
    }

    ShellSurface {
        id: card
        transform: ShellMotion {
            id: motion
            surface: card
            animationsEnabled: dashboard.theme.animationsEnabled !== false
            bounceEnabled: dashboard.theme.widgetBounceEnabled !== false
            expanded: dashboard.expanded
            edge: "top"
            viewportWidth: dashboard.screen.width
            viewportHeight: dashboard.screen.height
        }
        attachTop: true
        topAttachmentHeight: dashboard.theme.barStyle === "islands" && dashboard.theme.barPosition === "top"
            ? Math.max(0, y - 8) : 0
        width: Math.min(560, dashboard.width - 32)
        height: Math.min(content.implicitHeight + 48, dashboard.height - dashboard.topInset - 8)
        x: (dashboard.width + dashboard.leftInset - width) / 2
        y: dashboard.topInset
        radius: 32
        color: dashboard.theme.colors.surface
        focus: dashboard.visible
        Keys.onEscapePressed: dashboard.expanded = false

        MouseArea { anchors.fill: parent }

        Flickable {
            anchors.fill: parent
            anchors.margins: 24
            clip: true
            contentWidth: width
            contentHeight: content.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: content
            width: parent.width
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 20
                ColumnLayout {
                    Layout.preferredWidth: 270
                    Layout.maximumWidth: 270
                    Text {
                        text: dashboard.currentTime
                        color: dashboard.theme.colors.foreground
                        font { family: dashboard.theme.fontFamily; pixelSize: dashboard.theme.fontSize + 34; bold: true }
                        KeyboardAction { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onActivated: dashboard.actionRequested("time") }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: dashboard.currentDate + "  ▾"
                        elide: Text.ElideRight
                        color: dashboard.theme.colors.muted
                        font { family: dashboard.theme.fontFamily; pixelSize: dashboard.theme.fontSize + 1 }
                        KeyboardAction {
                            anchors.fill: parent
                            onActivated: dashboard.calendarMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1)
                        }
                    }
                }
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: weatherContent.implicitHeight
                    ColumnLayout {
                        id: weatherContent
                        anchors.fill: parent
                        Text {
                            text: dashboard.weather.icon + "  " + dashboard.weather.temperature
                            color: dashboard.theme.colors.foreground
                            font { family: dashboard.theme.fontFamily; pixelSize: dashboard.theme.fontSize + 12; bold: true }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: dashboard.weather.location || "Weather"
                            elide: Text.ElideRight
                            color: dashboard.theme.colors.muted
                            font { family: dashboard.theme.fontFamily; pixelSize: dashboard.theme.fontSize }
                        }
                    }
                    KeyboardAction {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onActivated: dashboard.actionRequested("weather")
                    }
                }

            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                MediaArtwork {
                    implicitWidth: 72
                    implicitHeight: 72
                    artUrl: dashboard.media.artUrl || ""
                    backgroundColor: dashboard.theme.colors.surface_alt
                    foregroundColor: dashboard.theme.colors.accent
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Item {
                        id: mediaViewport
                        Layout.fillWidth: true
                        implicitHeight: mediaLabel.implicitHeight
                        clip: true
                        Text {
                            id: mediaLabel
                            text: dashboard.media.available ? dashboard.media.artist + " - " + dashboard.media.title : "No media playing"
                            color: dashboard.theme.colors.muted
                            font { family: dashboard.theme.fontFamily; pixelSize: dashboard.theme.fontSize }
                        }
                        SequentialAnimation {
                            id: mediaMarquee
                            running: dashboard.theme.animationsEnabled !== false && dashboard.expanded && dashboard.media.playing && mediaLabel.implicitWidth > mediaViewport.width
                            loops: Animation.Infinite
                            onRunningChanged: { if (!running) mediaLabel.x = 0; }
                            PauseAnimation { duration: 1000 }
                            NumberAnimation {
                                target: mediaLabel
                                property: "x"
                                from: 0
                                to: -Math.max(0, mediaLabel.implicitWidth - mediaViewport.width)
                                duration: Math.max(2200, Math.round((mediaLabel.implicitWidth - mediaViewport.width) * 32))
                            }
                            PauseAnimation { duration: 1000 }
                            NumberAnimation {
                                target: mediaLabel
                                property: "x"
                                from: -Math.max(0, mediaLabel.implicitWidth - mediaViewport.width)
                                to: 0
                                duration: 400
                            }
                        }
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6
                        Repeater {
                            model: [
                                { label: "⏮", action: "mediaPrevious" },
                                { label: dashboard.media.playing ? "⏸" : "⏵", action: "mediaToggle" },
                                { label: "⏭", action: "mediaNext" }
                            ]
                            ShellButton {
                                required property var modelData
                                label: modelData.label
                                enabled: dashboard.media.available
                                fontFamily: dashboard.theme.fontFamily
                                fontSize: dashboard.theme.fontSize + 2
                                backgroundColor: dashboard.theme.colors.surface_alt
                                foregroundColor: dashboard.theme.colors.foreground
                                onClicked: dashboard.actionRequested(modelData.action)
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: dashboard.theme.colors.surface_alt }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 270
                radius: 16
                color: dashboard.theme.colors.surface_alt
                ColumnLayout {
                    anchors { fill: parent; margins: 14 }
                    spacing: 5
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: Qt.formatDateTime(dashboard.calendarMonth, "MMMM yyyy")
                            color: dashboard.theme.colors.foreground
                            font { family: dashboard.theme.fontFamily; pixelSize: dashboard.theme.fontSize; bold: true }
                        }
                        ShellButton {
                            label: "‹"
                            fontFamily: dashboard.theme.fontFamily
                            fontSize: dashboard.theme.fontSize
                            backgroundColor: dashboard.theme.colors.surface
                            foregroundColor: dashboard.theme.colors.foreground
                            onClicked: dashboard.calendarMonth = new Date(dashboard.calendarMonth.getFullYear(), dashboard.calendarMonth.getMonth() - 1, 1)
                        }
                        ShellButton {
                            label: "›"
                            fontFamily: dashboard.theme.fontFamily
                            fontSize: dashboard.theme.fontSize
                            backgroundColor: dashboard.theme.colors.surface
                            foregroundColor: dashboard.theme.colors.foreground
                            onClicked: dashboard.calendarMonth = new Date(dashboard.calendarMonth.getFullYear(), dashboard.calendarMonth.getMonth() + 1, 1)
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 7
                        rowSpacing: 2
                        columnSpacing: 2
                        Repeater {
                            model: ["M", "T", "W", "T", "F", "S", "S"]
                            Text {
                                required property string modelData
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                color: dashboard.theme.colors.muted
                                font { family: dashboard.theme.fontFamily; pixelSize: dashboard.theme.fontSize - 2 }
                            }
                        }
                        Repeater {
                            model: 42
                            Rectangle {
                                required property int index
                                readonly property int day: index - dashboard.calendarOffset + 1
                                readonly property bool isToday: day === new Date().getDate() && dashboard.calendarMonth.getMonth() === new Date().getMonth() && dashboard.calendarMonth.getFullYear() === new Date().getFullYear()
                                Layout.fillWidth: true
                                implicitHeight: 27
                                radius: 7
                                color: isToday ? dashboard.theme.colors.accent : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.day > 0 && parent.day <= dashboard.daysInMonth ? String(parent.day) : ""
                                    color: parent.isToday ? dashboard.theme.colors.background : dashboard.theme.colors.foreground
                                    font { family: dashboard.theme.fontFamily; pixelSize: dashboard.theme.fontSize - 2 }
                                }
                            }
                        }
                    }
                }
            }

            ShellButton {
                Layout.fillWidth: true
                label: "Questline"
                fontFamily: dashboard.theme.fontFamily
                fontSize: dashboard.theme.fontSize
                backgroundColor: dashboard.theme.colors.surface_alt
                foregroundColor: dashboard.theme.colors.foreground
                onClicked: dashboard.actionRequested("questline")
            }

        }
        }
    }

}
