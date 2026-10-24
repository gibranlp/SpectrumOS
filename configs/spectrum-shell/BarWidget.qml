pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Wayland

PanelWindow {
    id: widget
    required property var targetScreen
    required property var theme
    property string page: "audio"
    property string barPosition: "top"
    property int panelLeftInset: theme.panelLeftInset
    property int panelTopInset: theme.panelTopInset
    property bool expanded: false
    property int previewMasterVolume: -1
    readonly property bool draggingVolume: volumeSlider.pressed || deviceDragging(outputDevices) || deviceDragging(inputDevices)
    function deviceDragging(repeater): bool {
        for (let index = 0; index < repeater.count; index++) {
            const item = repeater.itemAt(index);
            if (item && item.dragging) return true;
        }
        return false;
    }
    signal extraRequested(string action)
    property string pendingSsid: ""
    onExpandedChanged: if (!expanded && page === "audio") theme.dismissMediaChoice()
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery.ready && battery.isLaptopBattery

    function batteryTime(seconds): string {
        const minutes = Math.round(seconds / 60);
        return Math.floor(minutes / 60) + "h " + String(minutes % 60).padStart(2, "0") + "m";
    }

    screen: targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "spectrum-widget-barwidget"
    color: "transparent"
    visible: motion.active
    WlrLayershell.keyboardFocus: panelFocus.mode
    ShellFocus { id: panelFocus; window: widget; enabled: expanded && !(page === "time" && timeRegionContent.busy) && !(page === "appimages" && appImageContent.busy) }

    function open(name): void {
        page = name;
        pendingSsid = "";
        passwordInput.text = "";
        theme.actionError = "";
        expanded = true;
        theme.refreshControls();
    }

    AppImageManager { id: appImageManager; theme: widget.theme }

    MouseArea { anchors.fill: parent; onClicked: widget.expanded = false }

    ShellSurface {
        id: card
        transform: ShellMotion {
            id: motion
            surface: card
            animationsEnabled: widget.theme.animationsEnabled !== false
            bounceEnabled: widget.theme.widgetBounceEnabled !== false
            expanded: widget.expanded
            edge: widget.barPosition === "top" ? "top" : "left"
            viewportWidth: widget.screen.width
            viewportHeight: widget.screen.height
        }
        topAttachmentHeight: widget.theme.barStyle === "islands" && widget.theme.barPosition === "top"
            ? Math.max(0, y - 8) : 0
        attachTop: widget.barPosition === "top"
        attachRight: widget.barPosition === "top"
        attachLeft: widget.barPosition === "left"
        leftAttachmentWidth: widget.theme.barStyle === "islands" && widget.theme.barPosition === "left"
            ? Math.max(0, x - leftFrameThickness) : 0
        attachBottom: widget.barPosition === "left"
        readonly property int contentHeight: body.implicitHeight + 44
        width: Math.min(["displays", "appimages"].includes(widget.page) ? 560 : 440, widget.width - (widget.barPosition === "left" ? widget.panelLeftInset + 16 : 16))
        height: Math.min(contentHeight, widget.height - (widget.barPosition === "top" ? widget.panelTopInset + 16 : 24))
        x: widget.barPosition === "top" ? widget.width - width : widget.panelLeftInset
        y: widget.barPosition === "top" ? widget.panelTopInset : widget.height - height - (widget.theme.gamingActive ? 0 : 8)
        radius: 26
        color: widget.theme.colors.surface
        focus: widget.expanded
        Keys.onEscapePressed: widget.expanded = false

        MouseArea { anchors.fill: parent }

        Flickable {
            objectName: "audio-scroll"
            interactive: !widget.draggingVolume
            flickableDirection: Flickable.VerticalFlick
            anchors.fill: parent
            anchors.margins: 22
            clip: true
            contentWidth: width
            contentHeight: body.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: body
                width: parent.width
                spacing: 9

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: widget.page === "appimages" ? "APPIMAGES" : widget.page === "extras" ? "MORE" : widget.page === "mouse" ? "MOUSE" : widget.page === "time" ? "TIME & REGION" : widget.page === "typography" ? "TYPOGRAPHY" : widget.page === "wifi" ? "NETWORK" : widget.page === "bluetooth" ? "BLUETOOTH" : widget.page === "displays" ? "DISPLAYS" : widget.page === "weather" ? "WEATHER" : widget.page === "battery" ? (widget.hasBattery ? "POWER & BATTERY" : "POWER & SYSTEM") : "AUDIO"
                        color: widget.theme.colors.accent
                        font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize + 3; bold: true }
                    }
                    Item { Layout.fillWidth: true }
                    ShellButton {
                        label: "✕"
                        fontFamily: widget.theme.fontFamily
                        fontSize: widget.theme.fontSize
                        backgroundColor: widget.theme.colors.surface_alt
                        foregroundColor: widget.theme.colors.foreground
                        onClicked: widget.expanded = false
                    }
                }
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: widget.theme.colors.surface_alt }

                BarExtras {
                    visible: widget.page === "extras"
                    Layout.fillWidth: true
                    theme: widget.theme
                    window: widget
                    trayItems: SystemTray.items
                    onChosen: action => { widget.expanded = false; widget.extraRequested(action); }
                }
                AppImageWidgetContent {
                    id: appImageContent
                    manager: appImageManager
                    Layout.fillWidth: true
                    visible: widget.page === "appimages"
                    active: widget.expanded && visible
                    theme: widget.theme
                }
                MouseWidgetContent {
                    Layout.fillWidth: true
                    visible: widget.page === "mouse"
                    active: widget.expanded && visible
                    theme: widget.theme
                }

                TimeRegionWidgetContent {
                    id: timeRegionContent
                    Layout.fillWidth: true
                    visible: widget.page === "time"
                    active: widget.expanded && visible
                    theme: widget.theme
                }

                Text {
                    visible: widget.page === "typography"
                    text: "GLOBAL FONT SIZE  ·  " + widget.theme.fontSize + "px"
                    color: widget.theme.colors.foreground
                    font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize; bold: true }
                }
                Flow {
                    visible: widget.page === "typography"
                    Layout.fillWidth: true
                    Layout.maximumWidth: body.width
                    spacing: 5
                    Repeater {
                        model: [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24]
                        ShellButton {
                            required property int modelData
                            label: String(modelData)
                            fontFamily: widget.theme.fontFamily
                            fontSize: widget.theme.fontSize - 1
                            backgroundColor: widget.theme.fontSize === modelData ? widget.theme.colors.accent : widget.theme.colors.surface_alt
                            foregroundColor: widget.theme.fontSize === modelData ? widget.theme.colors.background : widget.theme.colors.foreground
                            onClicked: widget.theme.runAction([widget.theme.backend("font-size-menu"), "--set", String(modelData)])
                        }
                    }
                }
                Text {
                    visible: widget.page === "typography"
                    text: "MONOSPACE FONT FAMILY"
                    color: widget.theme.colors.foreground
                    font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize; bold: true }
                }
                Flow {
                    visible: widget.page === "typography"
                    Layout.fillWidth: true
                    Layout.maximumWidth: body.width
                    spacing: 5
                    Repeater {
                        model: widget.theme.overview.font_families || []
                        ShellButton {
                            required property var modelData
                            label: modelData.label
                            fontFamily: widget.theme.fontFamily
                            fontSize: widget.theme.fontSize - 1
                            backgroundColor: widget.theme.overview.font_family === modelData.key ? widget.theme.colors.accent : widget.theme.colors.surface_alt
                            foregroundColor: widget.theme.overview.font_family === modelData.key ? widget.theme.colors.background : widget.theme.colors.foreground
                            onClicked: widget.theme.runAction([widget.theme.backend("font-family-menu"), "--set", modelData.key])
                        }
                    }
                }

                Rectangle {
                    visible: widget.page === "typography"
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: widget.theme.colors.surface_alt
                }
                Text {
                    visible: widget.page === "typography"
                    text: "KEYBOARD LAYOUT"
                    color: widget.theme.colors.accent
                    font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize; bold: true }
                }
                Text {
                    visible: widget.page === "typography"
                    Layout.fillWidth: true
                    text: "Current: " + widget.theme.keyboardLayout.label
                    wrapMode: Text.Wrap
                    color: widget.theme.colors.muted
                    font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 1 }
                }
                Flow {
                    visible: widget.page === "typography"
                    Layout.fillWidth: true
                    Layout.maximumWidth: body.width
                    spacing: 6
                    Repeater {
                        model: [
                            { id: "us", label: "English (US)" },
                            { id: "us-intl", label: "US International" },
                            { id: "latam", label: "Spanish (Latin America)" },
                            { id: "es", label: "Spanish (Spain)" },
                            { id: "us,latam", label: "US + Latin America" },
                            { id: "us-intl,latam", label: "US International + Latin America" },
                            { id: "us-intl,es", label: "US International + Spain" }
                        ]
                        ShellButton {
                            required property var modelData
                            label: modelData.label
                            fontFamily: widget.theme.fontFamily
                            fontSize: widget.theme.fontSize - 1
                            backgroundColor: widget.theme.keyboardLayout.id === modelData.id ? widget.theme.colors.accent : widget.theme.colors.surface_alt
                            foregroundColor: widget.theme.keyboardLayout.id === modelData.id ? widget.theme.colors.background : widget.theme.colors.foreground
                            onClicked: widget.theme.runAction([widget.theme.backend("keyboard-layout"), "--set", modelData.id])
                        }
                    }
                }

                ColumnLayout {
                    visible: widget.page === "audio" && widget.theme.mediaPlayers.length > 0
                    Layout.fillWidth: true
                    spacing: 7
                    Text {
                        Layout.fillWidth: true
                        text: widget.theme.mediaChoiceRequired ? "Choose which app media keys control" : "Media keys control"
                        wrapMode: Text.Wrap
                        color: widget.theme.colors.accent
                        font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize; bold: true }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: !!widget.theme.mediaPendingAction
                        text: "Select an app to " + ({toggle: "play / pause", next: "skip to the next track", previous: "go to the previous track", stop: "stop playback"}[widget.theme.mediaPendingAction] || "control playback") + "."
                        wrapMode: Text.Wrap
                        color: widget.theme.colors.muted
                        font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 1 }
                    }
                    Repeater {
                        model: widget.theme.mediaPlayers
                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: mediaPlayerContent.implicitHeight + 20
                            radius: 10
                            color: modelData.selected ? Qt.tint(widget.theme.colors.surface_alt, Qt.rgba(widget.theme.colors.accent.r, widget.theme.colors.accent.g, widget.theme.colors.accent.b, 0.35)) : widget.theme.colors.surface_alt
                            ColumnLayout {
                                id: mediaPlayerContent
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                                spacing: 4
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name + (modelData.selected ? " · Selected" : "")
                                    elide: Text.ElideRight
                                    color: widget.theme.colors.foreground
                                    font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize; bold: true }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.status + " · " + modelData.title
                                    elide: Text.ElideRight
                                    color: widget.theme.colors.muted
                                    font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 1 }
                                }
                            }
                            KeyboardAction {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onActivated: widget.theme.selectMediaPlayer(parent.modelData.id)
                            }
                        }
                    }
                }

                RowLayout {
                    visible: widget.page === "audio"
                    Layout.fillWidth: true
                    spacing: 12
                    MediaArtwork {
                        artUrl: widget.theme.media.artUrl || ""
                        backgroundColor: widget.theme.colors.surface_alt
                        foregroundColor: widget.theme.colors.accent
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: widget.theme.media.title
                            elide: Text.ElideRight
                            color: widget.theme.colors.foreground
                            font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize; bold: true }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: widget.theme.media.artist
                            elide: Text.ElideRight
                            color: widget.theme.colors.muted
                            font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 1 }
                        }
                    }
                }

                Canvas {
                    visible: widget.page === "audio"
                    Layout.fillWidth: true
                    implicitHeight: 28
                    property var values: widget.theme.waveSamples
                    property color first: widget.theme.colors.accent
                    property color second: widget.theme.colors.accent_alt || widget.theme.colors.accent
                    property color third: widget.theme.colors.accent
                    onValuesChanged: if (visible) requestPaint()
                    onFirstChanged: requestPaint()
                    onSecondChanged: requestPaint()
                    onThirdChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onPaint: {
                        const painter = getContext("2d");
                        painter.clearRect(0, 0, width, height);
                        if (values.length < 2 || width <= 0) return;
                        const gradient = painter.createLinearGradient(0, 0, width, 0);
                        gradient.addColorStop(0, first);
                        gradient.addColorStop(0.5, second);
                        gradient.addColorStop(1, third);
                        painter.strokeStyle = gradient;
                        painter.lineWidth = 1.6;
                        painter.beginPath();
                        for (let index = 0; index < values.length; index++) {
                            const x = index * width / (values.length - 1);
                            const amplitude = Math.max(0, Math.min(1, values[index] / 100));
                            const y = height / 2 + Math.sin(index * 1.35) * amplitude * height * 0.43;
                            if (index === 0) painter.moveTo(x, y);
                            else painter.lineTo(x, y);
                        }
                        painter.stroke();
                    }
                }
                RowLayout {
                    visible: widget.page === "audio"
                    Layout.fillWidth: true
                    ShellButton {
                        label: widget.theme.volumeMuted ? "󰖁" : "󰕾"
                        fontFamily: widget.theme.fontFamily
                        fontSize: widget.theme.fontSize + 2
                        backgroundColor: widget.theme.colors.surface_alt
                        foregroundColor: widget.theme.colors.foreground
                        onClicked: widget.theme.runAction([widget.theme.backend("volume"), "mute", "--quiet"])
                    }
                    Controls.Slider {
                        id: volumeSlider
                        objectName: "master-volume"
                        enabled: widget.theme.volumeAvailable || !!widget.theme.audioDevices.available
                        Layout.fillWidth: true
                        implicitHeight: 32
                        from: 0
                        to: 100
                        stepSize: 1
                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: widget.theme.colors.accent
                            opacity: 0.2
                            visible: volumeSlider.activeFocus
                        }
                        onMoved: {
                            widget.previewMasterVolume = Math.round(value);
                            widget.theme.setAudioVolume("sink", "@DEFAULT_SINK@", widget.previewMasterVolume);
                        }
                        Binding { target: volumeSlider; property: "value"; value: widget.theme.volumeAvailable ? widget.theme.volumePercent : widget.previewMasterVolume >= 0 ? widget.previewMasterVolume : parseInt(widget.theme.audioDevices.volume) || 0; when: !volumeSlider.pressed && !widget.theme.audioVolumeBusy; restoreMode: Binding.RestoreNone }
                        background: Rectangle {
                            x: volumeSlider.leftPadding
                            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                            width: volumeSlider.availableWidth
                            height: 5
                            radius: 3
                            color: widget.theme.colors.surface_alt
                            Rectangle {
                                width: parent.width * volumeSlider.visualPosition
                                height: parent.height
                                radius: parent.radius
                                color: widget.theme.colors.accent
                            }
                        }
                        handle: Rectangle {
                            x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                            width: 14
                            height: 14
                            radius: 7
                            color: volumeSlider.activeFocus ? widget.theme.colors.foreground : widget.theme.colors.accent
                        }
                    }
                    Text {
                        text: volumeSlider.enabled ? Math.round(volumeSlider.value) + "%" : "—"
                        color: widget.theme.colors.foreground
                        font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 1 }
                    }
                }
                Text {
                    visible: widget.page === "audio"
                    text: "OUTPUT DEVICE"
                    color: widget.theme.colors.accent
                    font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 2; bold: true }
                }
                Repeater {
                    id: outputDevices
                    objectName: "audio-output-devices"
                    model: widget.page === "audio" ? widget.theme.audioDevices.sinks || [] : []
                    AudioDeviceControl {
                        required property var modelData
                        Layout.fillWidth: true
                        theme: widget.theme
                        device: modelData
                        output: true
                    }
                }
                Text {
                    visible: widget.page === "audio"
                    text: "INPUT DEVICE"
                    color: widget.theme.colors.accent
                    font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 2; bold: true }
                }
                Repeater {
                    id: inputDevices
                    objectName: "audio-input-devices"
                    model: widget.page === "audio" ? widget.theme.audioDevices.sources || [] : []
                    AudioDeviceControl {
                        required property var modelData
                        Layout.fillWidth: true
                        theme: widget.theme
                        device: modelData
                        output: false
                    }
                }

                Text {
                    visible: widget.page === "wifi" && (widget.theme.network.profiles || []).length > 0
                    text: "CONNECTION PROTOCOLS"
                    color: widget.theme.colors.accent
                    font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 2; bold: true }
                }
                Text {
                    visible: widget.page === "wifi" && (widget.theme.network.profiles || []).length > 0
                    Layout.fillWidth: true
                    text: "Choose IPv4, IPv6 or both. Changes may reconnect that connection."
                    color: widget.theme.colors.muted
                    wrapMode: Text.WordWrap
                    font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 2 }
                }
                Repeater {
                    model: widget.page === "wifi" ? widget.theme.network.profiles || [] : []
                    ConnectionIpControl {
                        required property var modelData
                        Layout.fillWidth: true
                        theme: widget.theme
                        profile: modelData
                    }
                }
                RowLayout {
                    visible: widget.page === "wifi"
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: widget.theme.network.status
                        elide: Text.ElideRight
                        color: widget.theme.colors.foreground
                        font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 1 }
                    }
                    ShellButton {
                        label: widget.theme.network.wifi_enabled ? "Wi-Fi on" : "Wi-Fi off"
                        enabled: widget.theme.network.available
                        fontFamily: widget.theme.fontFamily
                        fontSize: widget.theme.fontSize - 1
                        backgroundColor: widget.theme.network.wifi_enabled ? widget.theme.colors.accent : widget.theme.colors.surface_alt
                        foregroundColor: widget.theme.network.wifi_enabled ? widget.theme.colors.background : widget.theme.colors.foreground
                        onClicked: widget.theme.runAction([widget.theme.backend("network-adapter"), "toggle"])
                    }
                }
                Text {
                    visible: widget.page === "wifi" && widget.theme.network.ethernet.connected
                    text: "ETHERNET  ·  " + widget.theme.network.ethernet.connection
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    color: widget.theme.colors.accent
                    font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 2; bold: true }
                }
                Text {
                    visible: widget.page === "wifi" && widget.theme.network.ethernet.connected
                    Layout.fillWidth: true
                    text: "Interface  " + widget.theme.network.ethernet.interface + "    Link  " + widget.theme.network.ethernet.speed
                    elide: Text.ElideRight
                    color: widget.theme.colors.muted
                    font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 2 }
                }
                Text {
                    visible: widget.page === "wifi" && widget.theme.network.ethernet.connected
                    text: "↓ " + widget.theme.network.ethernet.download + "    ↑ " + widget.theme.network.ethernet.upload
                    color: widget.theme.colors.muted
                    font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 2 }
                }
                Text {
                    visible: widget.page === "wifi" && widget.theme.network.ethernet.connected
                    Layout.fillWidth: true
                    text: "IPv4  " + widget.theme.network.ethernet.ipv4 + "\nIPv6  " + widget.theme.network.ethernet.ipv6 + "\nGateway  " + widget.theme.network.ethernet.gateway + "\nPublic IP  " + (widget.theme.network.public_ip || "—")
                    wrapMode: Text.WrapAnywhere
                    color: widget.theme.colors.muted
                    font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 2 }
                }
                Text {
                    visible: widget.page === "wifi"
                    text: "WI-FI" + (widget.theme.network.wifi.connected ? "  ·  " + widget.theme.network.wifi.ssid : "")
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    color: widget.theme.colors.accent
                    font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 2; bold: true }
                }
                Text {
                    visible: widget.page === "wifi" && widget.theme.network.wifi.connected
                    Layout.fillWidth: true
                    text: "Interface  " + widget.theme.network.wifi.interface + "    Rate  " + widget.theme.network.wifi.speed + "    Signal  " + widget.theme.network.wifi.signal + "%"
                    elide: Text.ElideRight
                    color: widget.theme.colors.muted
                    font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 2 }
                }
                Text {
                    visible: widget.page === "wifi" && widget.theme.network.wifi.connected
                    text: "↓ " + widget.theme.network.wifi.download + "    ↑ " + widget.theme.network.wifi.upload
                    color: widget.theme.colors.muted
                    font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 2 }
                }
                Text {
                    visible: widget.page === "wifi" && widget.theme.network.wifi.connected
                    Layout.fillWidth: true
                    text: "IPv4  " + widget.theme.network.wifi.ipv4 + "\nIPv6  " + widget.theme.network.wifi.ipv6 + "\nGateway  " + widget.theme.network.wifi.gateway + (widget.theme.network.ethernet.connected ? "" : "\nPublic IP  " + (widget.theme.network.public_ip || "—"))
                    wrapMode: Text.WrapAnywhere
                    color: widget.theme.colors.muted
                    font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 2 }
                }
                RowLayout {
                    visible: widget.page === "wifi"
                    Layout.fillWidth: true
                    Text {
                        text: "NEARBY NETWORKS"
                        color: widget.theme.colors.accent
                        font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 2; bold: true }
                    }
                    Item { Layout.fillWidth: true }
                    ShellButton {
                        label: "Rescan"
                        fontFamily: widget.theme.fontFamily
                        fontSize: widget.theme.fontSize - 1
                        backgroundColor: widget.theme.colors.surface_alt
                        foregroundColor: widget.theme.colors.foreground
                        onClicked: widget.theme.runAction([widget.theme.backend("network-adapter"), "rescan"])
                    }
                }
                Repeater {
                    model: widget.page === "wifi" ? widget.theme.network.networks || [] : []
                    ShellButton {
                        required property var modelData
                        Layout.fillWidth: true
                        label: (modelData.active ? "✓ " : "") + modelData.ssid + "  ·  " + modelData.signal + "%  ·  " + modelData.security
                        enabled: !modelData.active && !widget.theme.actionBusy
                        fontFamily: widget.theme.fontFamily
                        fontSize: widget.theme.fontSize - 1
                        backgroundColor: modelData.active ? widget.theme.colors.accent : widget.theme.colors.surface_alt
                        foregroundColor: modelData.active ? widget.theme.colors.background : widget.theme.colors.foreground
                        onClicked: {
                            if (modelData.saved)
                                widget.theme.runAction([widget.theme.backend("network-adapter"), "connect", modelData.uuid]);
                            else if (modelData.security === "Open" || modelData.security === "--")
                                widget.theme.runAction([widget.theme.backend("network-adapter"), "connect-open", modelData.ssid]);
                            else {
                                widget.pendingSsid = modelData.ssid;
                                passwordInput.forceActiveFocus();
                            }
                        }
                    }
                }
                Text {
                    visible: widget.page === "wifi" && widget.pendingSsid.length > 0
                    text: "Password · " + widget.pendingSsid
                    color: widget.theme.colors.foreground
                    font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 1 }
                }
                Rectangle {
                    visible: widget.page === "wifi" && widget.pendingSsid.length > 0
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: 8
                    color: widget.theme.colors.background
                    TextInput {
                        activeFocusOnTab: true
                        id: passwordInput
                        anchors.fill: parent
                        anchors.margins: 8
                        echoMode: TextInput.Password
                        color: widget.theme.colors.foreground
                        selectionColor: widget.theme.colors.accent
                        font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 1 }
                        Keys.onReturnPressed: {
                            widget.theme.connectSecuredWifi(widget.pendingSsid, text);
                            text = "";
                            widget.pendingSsid = "";
                        }
                    }
                }
                ShellButton {
                    visible: widget.page === "wifi" && widget.pendingSsid.length > 0
                    Layout.fillWidth: true
                    label: "Connect"
                    enabled: passwordInput.text.length > 0
                    fontFamily: widget.theme.fontFamily
                    fontSize: widget.theme.fontSize - 1
                    backgroundColor: widget.theme.colors.accent
                    foregroundColor: widget.theme.colors.background
                    onClicked: {
                        widget.theme.connectSecuredWifi(widget.pendingSsid, passwordInput.text);
                        passwordInput.text = "";
                        widget.pendingSsid = "";
                    }
                }
                RowLayout {
                    visible: widget.page === "wifi"
                    Layout.fillWidth: true
                    ShellButton {
                        Layout.fillWidth: true
                        label: "Manage networks"
                        fontFamily: widget.theme.fontFamily
                        fontSize: widget.theme.fontSize - 1
                        backgroundColor: widget.theme.colors.surface_alt
                        foregroundColor: widget.theme.colors.foreground
                        onClicked: Quickshell.execDetached([widget.theme.backend("network-adapter"), "menu"])
                    }
                    ShellButton {
                        Layout.fillWidth: true
                        label: "Edit connections"
                        fontFamily: widget.theme.fontFamily
                        fontSize: widget.theme.fontSize - 1
                        backgroundColor: widget.theme.colors.surface_alt
                        foregroundColor: widget.theme.colors.foreground
                        onClicked: ApplicationLaunch.start(["uwsm", "app", "-t", "scope", "--", "nm-connection-editor"])
                    }
                }

                BluetoothWidgetContent {
                    Layout.fillWidth: true
                    visible: widget.page === "bluetooth"
                    active: widget.expanded && visible
                    theme: widget.theme
                    onSettingsRequested: widget.expanded = false
                }

                DisplayWidgetContent {
                    visible: widget.page === "displays"
                    Layout.fillWidth: true
                    theme: widget.theme
                }
                WeatherWidgetContent {
                    visible: widget.page === "weather"
                    Layout.fillWidth: true
                    theme: widget.theme
                }

                ColumnLayout {
                    visible: widget.page === "battery"
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        visible: widget.hasBattery
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            text: "󰁹  " + Math.round(widget.battery.percentage * 100) + "%"
                            color: widget.theme.colors.foreground
                            font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize + 15; bold: true }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 8
                            radius: 4
                            color: widget.theme.colors.surface_alt
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, widget.battery.percentage))
                                height: parent.height
                                radius: parent.radius
                                color: widget.theme.colors.accent
                            }
                        }
                        Text {
                            text: widget.battery.state === UPowerDeviceState.Charging ? "Charging" : widget.battery.state === UPowerDeviceState.FullyCharged ? "Fully charged" : widget.battery.state === UPowerDeviceState.Discharging ? "On battery" : "Battery status unavailable"
                            color: widget.theme.colors.foreground
                            font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize; bold: true }
                        }
                        Text {
                            visible: (widget.battery.state === UPowerDeviceState.Charging && widget.battery.timeToFull > 0) || (widget.battery.state === UPowerDeviceState.Discharging && widget.battery.timeToEmpty > 0)
                            text: widget.battery.state === UPowerDeviceState.Charging ? widget.batteryTime(widget.battery.timeToFull) + " until full" : widget.batteryTime(widget.battery.timeToEmpty) + " remaining"
                            color: widget.theme.colors.muted
                            font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 1 }
                        }
                        Text {
                            visible: widget.battery.healthSupported
                            text: "Battery health  " + Math.round(widget.battery.healthPercentage) + "%"
                            color: widget.theme.colors.muted
                            font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 1 }
                        }
                        Text {
                            visible: widget.battery.changeRate > 0
                            text: "Power rate  " + widget.battery.changeRate.toFixed(1) + " W"
                            color: widget.theme.colors.muted
                            font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 1 }
                        }
                    }
                    ColumnLayout {
                        visible: !widget.hasBattery
                        Layout.fillWidth: true
                        spacing: 9
                        Text {
                            Layout.fillWidth: true
                            text: widget.theme.overview.hostname || "SpectrumOS"
                            elide: Text.ElideRight
                            color: widget.theme.colors.foreground
                            font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize + 3; bold: true }
                        }
                        Repeater {
                            model: [
                                { label: "CPU load", value: widget.theme.overview.load },
                                { label: "Memory", value: widget.theme.overview.memory_detail || widget.theme.overview.memory },
                                { label: "Temperature", value: widget.theme.overview.temperature },
                                { label: "Uptime", value: widget.theme.overview.uptime_long || widget.theme.overview.uptime }
                            ]
                            RowLayout {
                                required property var modelData
                                visible: !!modelData.value
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.label
                                    color: widget.theme.colors.muted
                                    font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignRight
                                    text: modelData.value || ""
                                    elide: Text.ElideRight
                                    color: widget.theme.colors.foreground
                                    font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize }
                                }
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: widget.theme.colors.surface_alt }
                    Text {
                        text: "POWER MODE"
                        color: widget.theme.colors.accent
                        font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 2; bold: true }
                    }
                    RowLayout {
                        spacing: 8
                        ShellButton {
                            label: "Balanced"
                            enabled: widget.theme.performance.available && !widget.theme.performancePending && (widget.theme.performance.modes || []).includes("balanced")
                            fontFamily: widget.theme.fontFamily
                            fontSize: widget.theme.fontSize
                            backgroundColor: widget.theme.performance.mode === "balanced" ? widget.theme.colors.accent : widget.theme.colors.surface_alt
                            foregroundColor: widget.theme.performance.mode === "balanced" ? widget.theme.colors.background : widget.theme.colors.foreground
                            onClicked: widget.theme.setPerformanceMode("balanced")
                        }
                        ShellButton {
                            label: "Performance"
                            enabled: widget.theme.performance.available && !widget.theme.performancePending && (widget.theme.performance.modes || []).includes("performance")
                            fontFamily: widget.theme.fontFamily
                            fontSize: widget.theme.fontSize
                            backgroundColor: widget.theme.performance.mode === "performance" ? widget.theme.colors.accent : widget.theme.colors.surface_alt
                            foregroundColor: widget.theme.performance.mode === "performance" ? widget.theme.colors.background : widget.theme.colors.foreground
                            onClicked: widget.theme.setPerformanceMode("performance")
                        }
                    }
                    ShellButton {
                        Layout.fillWidth: true
                        label: "Power Saver"
                        enabled: widget.theme.performance.available && !widget.theme.performancePending && (widget.theme.performance.modes || []).includes("power-saver")
                        fontFamily: widget.theme.fontFamily
                        fontSize: widget.theme.fontSize
                        backgroundColor: widget.theme.performance.mode === "power-saver" ? widget.theme.colors.accent : widget.theme.colors.surface_alt
                        foregroundColor: widget.theme.performance.mode === "power-saver" ? widget.theme.colors.background : widget.theme.colors.foreground
                        onClicked: widget.theme.setPerformanceMode("power-saver")
                    }
                    Text {
                        visible: !widget.theme.performance.available
                        text: "Power mode control is unavailable"
                        color: widget.theme.colors.muted
                        font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 1 }
                    }
                }

                Text {
                    visible: widget.theme.actionError.length > 0
                    Layout.fillWidth: true
                    text: widget.theme.actionError
                    wrapMode: Text.Wrap
                    color: widget.theme.colors.error || "#ff8c9a"
                    font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 1 }
                }
            }
        }
    }

}
