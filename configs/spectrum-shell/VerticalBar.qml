import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower

PanelWindow {
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "spectrum-bar"
    id: bar
    required property var targetScreen
    required property var theme
    ShellGeometry { id: geometry }
    property string barProfile: theme.barProfile
    readonly property var islandSegments: leftIslands.segments
    required property var monitor
    required property var network
    required property var overview
    required property var weather
    required property var recording
    required property var media
    required property string activeWindowTitle
    property string activeWindowIdentity: ""
    property bool keyboardActive: false
    signal keyboardDismissed()
    focusable: keyboardActive
    function focusFirst(): void {
        contents.forceActiveFocus();
        navigation.move(true);
    }
    property bool active: false
    property string currentTime: Qt.formatDateTime(new Date(), "HH:mm")
    signal widgetRequested(string action)
    signal extrasRequested()
    signal spectrumDropRequested()
    signal launcherRequested()
    signal dashboardRequested()
    signal timeRegionRequested()
    signal controlCenterRequested()
    signal notificationsRequested()
    signal audioRequested()
    signal wifiRequested()
    signal bluetoothRequested()
    signal displaysRequested()
    signal weatherRequested()
    signal mouseRequested()
    signal typographyRequested()
    signal batteryRequested()
    signal performanceRequested()
    signal idleRequested()
    signal sessionRequested()
    signal mediaRequested(string action)

    screen: targetScreen
    anchors { top: true; bottom: true; left: true }
    implicitWidth: 52
    implicitHeight: targetScreen ? targetScreen.height : 0
    exclusionMode: ExclusionMode.Ignore
    visible: active
    color: theme.barStyle === "islands" ? "transparent" : theme.colors.surface

    mask: BarInputRegion { backdrop: leftIslands; islands: bar.theme.barStyle === "islands" }

    BarIslands {
        id: leftIslands
        anchors.fill: parent
        horizontal: false
        padding: 10
        visible: bar.theme.barStyle === "islands"
        surfaceColor: bar.theme.colors.surface
        readonly property var lastWorkspace: workspaceRepeater.count ? workspaceRepeater.itemAt(workspaceRepeater.count - 1) : null
        groups: [
            { start: contents.y + launcherButton.y, length: (lastWorkspace ? lastWorkspace.y + lastWorkspace.height : igorButton.y + igorButton.height) - launcherButton.y },
            { start: contents.y + windowTitleGroup.y, length: windowTitleGroup.height, visible: windowTitleGroup.visible },
            { start: contents.y + mediaGroup.y + mediaContent.y, length: mediaContent.height, visible: mediaGroup.visible },
            { start: contents.y + statsGroup.y + statsContent.y, length: statsContent.height, visible: statsGroup.visible },
            { start: contents.y + statusGroup.y, length: contents.y + clockText.y + clockText.height - (contents.y + statusGroup.y) }
        ]
    }

    Timer {
        interval: 60000
        running: bar.active
        triggeredOnStart: true
        repeat: true
        onTriggered: bar.currentTime = Qt.formatDateTime(new Date(), "HH:mm")
    }

    ColumnLayout {
        id: contents
        KeyboardNavigation { id: navigation }
        Keys.onEscapePressed: bar.keyboardDismissed()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                navigation.move(event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier));
                event.accepted = true;
            } else if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].includes(event.key)) {
                navigation.moveDirection(event.key);
                event.accepted = true;
            }
        }
        anchors { fill: parent; topMargin: 8; bottomMargin: geometry.frameThickness + geometry.curveRadius + 8 }
        spacing: bar.theme.barStyle === "islands" ? 6 : 8

        Rectangle {
            id: launcherButton
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 36
            implicitHeight: 36
            radius: 11
            color: bar.theme.colors.accent
            Text {
                anchors.centerIn: parent
                text: ""
                color: bar.theme.colors.background
                font { family: bar.theme.fontFamily; pixelSize: bar.theme.fontSize + 8; bold: true }
            }
            KeyboardAction { anchors.fill: parent; onActivated: bar.launcherRequested() }
        }

        IgorButton {
            id: igorButton
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 34
            implicitHeight: 30
            theme: bar.theme
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 32
            implicitHeight: 2
            color: bar.theme.colors.surface_alt
        }

        Repeater {
            id: workspaceRepeater
            model: bar.theme.workspacesForMonitor(bar.screen ? bar.screen.name : "")
            Rectangle {
                required property int modelData
                readonly property bool selected: bar.monitor && bar.monitor.activeWorkspace && bar.monitor.activeWorkspace.id === modelData
                readonly property bool occupied: bar.theme.workspaceOccupied(modelData)
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 34
                implicitHeight: bar.theme.barStyle === "islands" ? 28 : 34
                radius: 11
                color: selected ? bar.theme.colors.accent : occupied || workspaceMouse.containsMouse ? bar.theme.colors.surface_alt : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: bar.theme.workspaceGlyph(parent.modelData, parent.selected ? qsTranslate("Spectrum", "active") : parent.occupied ? qsTranslate("Spectrum", "occupied") : qsTranslate("Spectrum", "empty"))
                    color: parent.selected ? bar.theme.colors.background : parent.occupied ? bar.theme.colors.foreground : bar.theme.colors.muted
                    font { family: bar.theme.fontFamily; pixelSize: bar.theme.fontSize; bold: parent.selected }
                }
                KeyboardAction {
                    id: workspaceMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onActivated: Hyprland.dispatch("hl.dsp.focus({ workspace = " + parent.modelData + " })")
                }
            }
        }

        Item {
            id: windowTitleGroup
            Layout.alignment: Qt.AlignHCenter
            visible: bar.barProfile === "standard" && bar.activeWindowTitle.length > 0
            implicitWidth: visible ? 42 : 0
            implicitHeight: visible ? bar.theme.barStyle === "islands" ? Math.min(100, bar.height * 0.06) : Math.min(240, bar.height * 0.25) : 0
            ScrollingTitle {
                animationsEnabled: bar.active && bar.theme.animationsEnabled !== false
                anchors.centerIn: parent
                vertical: true
                verticalExtent: parent.height
                title: bar.activeWindowTitle
                windowIdentity: bar.activeWindowIdentity
                fontFamily: bar.theme.fontFamily
                fontPixelSize: Math.max(9, bar.theme.fontSize - 2)
                textColor: bar.theme.colors.muted
            }
        }

        Item {
            Layout.fillHeight: true
            visible: bar.barProfile !== "detailed" && bar.barProfile !== "multimedia"
        }

        Item {
            id: mediaGroup
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitHeight: mediaContent.implicitHeight
            visible: bar.barProfile === "multimedia"
            ColumnLayout {
                id: mediaContent
                anchors.centerIn: parent
                width: parent.width
                spacing: bar.theme.barStyle === "islands" ? 3 : 5
                MediaArtwork {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 34
                    implicitHeight: 34
                    artUrl: bar.media.artUrl || ""
                    backgroundColor: bar.theme.colors.surface_alt
                    foregroundColor: bar.theme.colors.accent
                    KeyboardAction { anchors.fill: parent; onActivated: bar.dashboardRequested() }
                }
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 42
                    implicitHeight: bar.theme.barStyle === "islands" ? Math.max(90, Math.min(240, bar.height * 0.1)) : 135
                    ScrollingTitle {
                        animationsEnabled: bar.active && bar.theme.animationsEnabled !== false
                        anchors.centerIn: parent
                        vertical: true
                        verticalExtent: parent.height - 8
                        centered: true
                        title: bar.media.available ? [bar.media.artist, bar.media.title].filter(Boolean).join(" - ") : qsTranslate("Spectrum", "No media")
                        fontFamily: bar.theme.fontFamily
                        fontPixelSize: Math.max(9, bar.theme.fontSize - 2)
                        textColor: bar.theme.colors.foreground
                    }
                    KeyboardAction { anchors.fill: parent; onActivated: bar.dashboardRequested() }
                }
                Repeater {
                    model: [
                        { icon: "⏮", action: "previous" },
                        { icon: bar.media.playing ? "⏸" : "⏵", action: "toggle" },
                        { icon: "⏭", action: "next" }
                    ]
                    Rectangle {
                        required property var modelData
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 34
                        implicitHeight: 28
                        radius: 8
                        color: mediaMouse.containsMouse ? bar.theme.colors.accent : bar.theme.colors.surface_alt
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.icon
                            color: mediaMouse.containsMouse ? bar.theme.colors.background : bar.theme.colors.foreground
                            font { family: bar.theme.fontFamily; pixelSize: bar.theme.fontSize }
                        }
                        KeyboardAction {
                            id: mediaMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: bar.media.available
                            onActivated: bar.mediaRequested(modelData.action)
                        }
                    }
                }
            }
        }

        Item {
            id: statsGroup
            Layout.alignment: Qt.AlignHCenter
            visible: bar.barProfile === "detailed"
            Layout.preferredWidth: 44
            Layout.maximumWidth: 44
            Layout.fillHeight: bar.barProfile === "detailed"
            implicitHeight: statsContent.implicitHeight
            ColumnLayout {
                id: statsContent
                anchors.centerIn: parent
                spacing: 3
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTranslate("Spectrum", "CPU")
                    color: bar.theme.colors.accent
                    font { family: bar.theme.fontFamily; pixelSize: Math.max(9, bar.theme.fontSize - 3); bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 44
                    text: bar.overview.load
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    color: bar.theme.colors.foreground
                    font { family: bar.theme.fontFamily; pixelSize: Math.max(9, bar.theme.fontSize - 3) }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTranslate("Spectrum", "RAM")
                    color: bar.theme.colors.accent
                    font { family: bar.theme.fontFamily; pixelSize: Math.max(9, bar.theme.fontSize - 3); bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 44
                    text: bar.overview.memory
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    color: bar.theme.colors.foreground
                    font { family: bar.theme.fontFamily; pixelSize: Math.max(9, bar.theme.fontSize - 3) }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 44
                    visible: !!bar.overview.gpu
                    text: String(bar.overview.gpu).trim().split(/\s{2,}/)[0]
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    color: bar.theme.colors.muted
                    font { family: bar.theme.fontFamily; pixelSize: Math.max(8, bar.theme.fontSize - 4) }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 44
                    visible: !!bar.overview.temperature
                    text: String(bar.overview.temperature).trim()
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    color: bar.theme.colors.muted
                    font { family: bar.theme.fontFamily; pixelSize: Math.max(8, bar.theme.fontSize - 4) }
                }
            }
        }

        ColumnLayout {
            id: statusGroup
            Layout.fillHeight: bar.barProfile === "detailed"
            Layout.minimumHeight: bar.barProfile === "detailed" ? 80 : implicitHeight
            Layout.maximumHeight: bar.barProfile === "detailed" ? detailedWidgets.naturalHeight : Infinity
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 44
            Layout.maximumWidth: 44
            spacing: bar.theme.barStyle === "islands" ? 5 : 7
            HoverHandler { id: minimalStatusHover }
            WidgetIcons {
                id: detailedWidgets
                visible: bar.barProfile === "detailed"
                theme: bar.theme
                vertical: true
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 80
                Layout.maximumHeight: naturalHeight
                onChosen: action => bar.widgetRequested(action)
            }
            ColumnLayout {
                visible: bar.barProfile !== "detailed"
                Layout.fillWidth: true
                spacing: bar.theme.barStyle === "islands" ? 5 : 7
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: bar.barProfile === "minimal" && !minimalStatusHover.hovered
                    text: "󰕮"
                    color: bar.theme.colors.foreground
                    font { family: bar.theme.fontFamily; pixelSize: bar.theme.fontSize + (bar.theme.barStyle === "islands" ? 3 : 5) }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: bar.barProfile !== "standard" && bar.theme.performance.available && (bar.barProfile !== "minimal" || minimalStatusHover.hovered)
                    text: bar.theme.performance.mode === "performance" ? "󰓅" : bar.theme.performance.mode === "power-saver" ? "󰌪" : ""
                    color: bar.theme.performance.mode === "performance" ? bar.theme.colors.accent : bar.theme.colors.foreground
                    font { family: bar.theme.fontFamily; pixelSize: bar.theme.fontSize + (bar.theme.barStyle === "islands" ? 3 : 5) }
                    KeyboardAction { anchors.fill: parent; onActivated: bar.performanceRequested() }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: bar.barProfile !== "minimal" || minimalStatusHover.hovered
                    text: bar.theme.idle.active ? "󰅶" : "󰾪"
                    color: bar.theme.idle.active ? bar.theme.colors.accent : bar.theme.colors.foreground
                    font { family: bar.theme.fontFamily; pixelSize: bar.theme.fontSize + (bar.theme.barStyle === "islands" ? 3 : 5) }
                    KeyboardAction { anchors.fill: parent; onActivated: bar.idleRequested() }
                }
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    visible: bar.barProfile !== "minimal" || minimalStatusHover.hovered
                    implicitWidth: 44
                    implicitHeight: weatherTemperature.visible ? 36 : 24
                    Text {
                        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
                        text: bar.weather.icon || "󰖕"
                        color: bar.theme.colors.foreground
                        font { family: bar.theme.fontFamily; pixelSize: bar.theme.fontSize + (bar.theme.barStyle === "islands" ? 3 : 5) }
                    }
                    Text {
                        id: weatherTemperature
                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                        width: parent.width
                        visible: (bar.barProfile === "standard" || bar.barProfile === "detailed") && bar.weather.temperature !== "—"
                        text: bar.weather.temperature
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        color: bar.theme.colors.muted
                        font { family: bar.theme.fontFamily; pixelSize: Math.max(9, bar.theme.fontSize - 3) }
                    }
                    KeyboardAction { anchors.fill: parent; onActivated: bar.weatherRequested() }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: bar.barProfile !== "minimal" || minimalStatusHover.hovered
                    text: bar.network.connection_type === "ethernet" ? "󰈀" : bar.network.connection_type === "wifi" ? "󰖩" : "󰖪"
                    color: bar.theme.colors.foreground
                    font { family: bar.theme.fontFamily; pixelSize: bar.theme.fontSize + (bar.theme.barStyle === "islands" ? 3 : 5) }
                    KeyboardAction { anchors.fill: parent; onActivated: bar.wifiRequested() }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: bar.barProfile !== "minimal" || minimalStatusHover.hovered
                    text: "󰂯"
                    color: bar.theme.colors.foreground
                    font { family: bar.theme.fontFamily; pixelSize: bar.theme.fontSize + (bar.theme.barStyle === "islands" ? 3 : 5) }
                    KeyboardAction { anchors.fill: parent; onActivated: bar.bluetoothRequested() }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: bar.barProfile !== "standard" && (bar.barProfile !== "minimal" || minimalStatusHover.hovered)
                    text: "󰍹"
                    color: bar.theme.colors.foreground
                    font { family: bar.theme.fontFamily; pixelSize: bar.theme.fontSize + (bar.theme.barStyle === "islands" ? 3 : 5) }
                    KeyboardAction { anchors.fill: parent; onActivated: bar.displaysRequested() }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: bar.barProfile !== "standard" && (bar.barProfile !== "minimal" || minimalStatusHover.hovered)
                    text: "󰍽"
                    color: bar.theme.colors.foreground
                    font { family: bar.theme.fontFamily; pixelSize: bar.theme.fontSize + (bar.theme.barStyle === "islands" ? 3 : 5) }
                    KeyboardAction { anchors.fill: parent; onActivated: bar.mouseRequested() }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: bar.barProfile !== "standard" && (bar.barProfile !== "minimal" || minimalStatusHover.hovered)
                    text: qsTranslate("Spectrum", "Aa")
                    color: bar.theme.colors.foreground
                    font { family: bar.theme.fontFamily; pixelSize: bar.theme.fontSize + (bar.theme.barStyle === "islands" ? 3 : 5); bold: true }
                    KeyboardAction { anchors.fill: parent; onActivated: bar.typographyRequested() }
                }
                VolumeIndicator {
                    Layout.alignment: Qt.AlignHCenter
                    visible: bar.barProfile !== "minimal"
                    compact: true
                    percent: bar.theme.volumePercent
                    muted: bar.theme.volumeMuted
                    available: bar.theme.volumeAvailable
                    theme: bar.theme
                    onClicked: bar.audioRequested()
                }

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    visible: bar.barProfile !== "standard" && UPower.displayDevice.ready && UPower.displayDevice.isLaptopBattery && (bar.barProfile !== "minimal" || minimalStatusHover.hovered)
                    implicitWidth: 44
                    implicitHeight: batteryContent.height
                    Column {
                        id: batteryContent
                        width: parent.width
                        spacing: 2
                        Text {
                            width: parent.width
                            text: UPower.onBattery ? "󰁹" : "󰂄"
                            horizontalAlignment: Text.AlignHCenter
                            color: bar.theme.colors.foreground
                            font { family: bar.theme.fontFamily; pixelSize: bar.theme.fontSize + (bar.theme.barStyle === "islands" ? 3 : 5) }
                        }
                        Text {
                            width: parent.width
                            text: Math.round(UPower.displayDevice.percentage * 100) + "%"
                            horizontalAlignment: Text.AlignHCenter
                            color: bar.theme.colors.foreground
                            font { family: bar.theme.fontFamily; pixelSize: bar.theme.fontSize - 1 }
                            fontSizeMode: Text.Fit
                            minimumPixelSize: 8
                        }
                    }
                    KeyboardAction { anchors.fill: parent; onActivated: bar.batteryRequested() }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: bar.barProfile !== "minimal" || minimalStatusHover.hovered
                    text: "󰂚"
                    color: bar.theme.colors.foreground
                    font { family: bar.theme.fontFamily; pixelSize: bar.theme.fontSize + (bar.theme.barStyle === "islands" ? 3 : 5) }
                    KeyboardAction { anchors.fill: parent; onActivated: bar.notificationsRequested() }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: ["standard", "multimedia"].includes(bar.barProfile)
                    text: "󰇘"
                    color: bar.theme.colors.foreground
                    font { family: bar.theme.fontFamily; pixelSize: bar.theme.fontSize + 5 }
                    Accessible.name: qsTranslate("Spectrum", "More bar controls")
                    KeyboardAction { anchors.fill: parent; onActivated: bar.extrasRequested() }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: bar.barProfile !== "standard" && bar.barProfile !== "minimal"
                    text: "󰒡"
                    color: bar.theme.colors.foreground
                    font { family: bar.theme.fontFamily; pixelSize: bar.theme.fontSize + 3 }
                    Accessible.name: "SpectrumDrop"
                    KeyboardAction { anchors.fill: parent; onActivated: bar.spectrumDropRequested() }
                }
                Repeater {
                    model: bar.barProfile === "standard" ? [] : SystemTray.items
                    Item {
                        required property var modelData
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 36
                        implicitHeight: 28
                        Image {
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            source: modelData.icon
                            fillMode: Image.PreserveAspectFit
                        }
                        KeyboardAction {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onActivated: button => {
                                const position = bar.itemPosition(parent);
                                if (button === Qt.RightButton || modelData.onlyMenu)
                                    modelData.display(bar, position.x + parent.width, position.y + parent.height / 2);
                                else
                                    modelData.activate();
                            }
                        }
                    }
                }
            }
        }

        Repeater {
            model: ["standard", "detailed"].includes(bar.barProfile) ? [] : [
                { icon: "󰒓", action: "control" },
                { icon: "󰐥", action: "session" }
            ]
            Rectangle {
                required property var modelData
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 34
                implicitHeight: 34
                radius: 11
                color: actionMouse.containsMouse ? bar.theme.colors.surface_alt : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: parent.modelData.icon
                    color: bar.theme.colors.foreground
                    font { family: bar.theme.fontFamily; pixelSize: bar.theme.fontSize + 7 }
                }
                KeyboardAction {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onActivated: {
                        switch (modelData.action) {
                        case "dashboard": bar.dashboardRequested(); break;
                        case "typography": bar.typographyRequested(); break;
                        case "notifications": bar.notificationsRequested(); break;
                        case "control": bar.controlCenterRequested(); break;
                        case "session": bar.sessionRequested(); break;
                        }
                    }
                }
            }
        }

        Text {
            id: clockText
            Layout.alignment: Qt.AlignHCenter
            text: bar.currentTime
            color: bar.theme.colors.muted
            font { family: bar.theme.fontFamily; pixelSize: Math.max(9, bar.theme.fontSize - 3); bold: true }
            KeyboardAction { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onActivated: bar.timeRegionRequested() }
        }
    }
}
