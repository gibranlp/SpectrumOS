import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: indicator
    required property var targetScreen
    required property var theme
    property string barPosition: "top"
    property int panelLeftInset: theme.panelLeftInset
    property int panelTopInset: theme.panelTopInset
    property bool blocked: false
    readonly property bool expanded: trackVisible || levelVisible
    property bool trackVisible: false
    property bool levelVisible: false
    property bool trackPresented: false
    property bool levelPresented: false
    property bool dismissing: false
    property string kind: "volume"
    property int level: 0
    property string deviceLabel: ""
    readonly property var track: theme.media
    readonly property var player: theme.mediaPlayer || null
    property bool trackPending: false
    property real positionSeconds: 0
    readonly property real durationSeconds: player && player.lengthSupported && Number.isFinite(player.length) ? Math.max(0, player.length) : 0
    readonly property bool positionAvailable: !!player && player.positionSupported
    readonly property real trackProgress: positionAvailable && durationSeconds > 0 ? Math.min(1, positionSeconds / durationSeconds) : 0
    readonly property bool playingTrack: !!track.available && !!track.playing
    property real levelReveal: levelPresented ? 1 : 0

    readonly property int percent: kind === "volume" ? theme.volumePercent : level
    readonly property bool muted: kind === "volume" && theme.volumeMuted
    onBlockedChanged: if (blocked) dismiss()
    onPlayerChanged: refreshProgress()
    onDurationSecondsChanged: refreshProgress()
    onPositionAvailableChanged: refreshProgress()
    onTrackVisibleChanged: { updatePresentation(); if (trackVisible) refreshProgress(); }
    onLevelVisibleChanged: updatePresentation()

    Behavior on levelReveal {
        enabled: indicator.theme.animationsEnabled !== false && indicator.trackVisible && motion.active
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
    // Conserva el contenido mientras la superficie termina de cerrar detrás de la barra.
    function updatePresentation(): void {
        if (!dismissing && (expanded || !motion.active)) {
            trackPresented = trackVisible;
            levelPresented = levelVisible;
        }
    }
    Connections {
        target: motion
        function onActiveChanged() { if (!motion.active) indicator.updatePresentation(); }
    }
    function refreshProgress(): void {
        const value = player && player.positionSupported ? Number(player.position) : 0;
        positionSeconds = Number.isFinite(value) ? Math.max(0, durationSeconds > 0 ? Math.min(value, durationSeconds) : value) : 0;
    }
    function formatTime(seconds): string {
        const value = Math.max(0, Math.floor(seconds));
        const hours = Math.floor(value / 3600);
        const minutes = Math.floor(value / 60) % 60;
        return (hours ? hours + ":" + String(minutes).padStart(2, "0") : String(minutes)) + ":" + String(value % 60).padStart(2, "0");
    }
    function show(kind, level, label): void {
        if (blocked || !["volume", "brightness"].includes(kind)) return;
        indicator.kind = kind;
        indicator.level = Math.max(0, Math.min(100, level));
        deviceLabel = label;
        if (kind === "volume" && playingTrack) displayTrack();
        else {
            trackPending = trackVisible && kind === "brightness";
            trackVisible = false;
            trackDelay.stop();
        }
        levelVisible = true;
        levelDelay.restart();
    }
    function showTrack(): void {
        if (blocked || !track.available) return;
        if (levelVisible && kind === "brightness") { trackPending = true; return; }
        displayTrack();
    }
    function displayTrack(): void {
        trackPending = false;
        trackVisible = true;
        refreshProgress();
        trackDelay.restart();
    }
    function dismissTrack(): void {
        trackPending = false;
        trackDelay.stop();
        trackVisible = false;
    }
    function dismiss(): void {
        dismissing = true;
        levelDelay.stop();
        dismissTrack();
        levelVisible = false;
        dismissing = false;
        updatePresentation();
    }
    Connections {
        target: indicator.theme
        function onMediaChanged() {
            if (!indicator.track.available) indicator.dismissTrack();
            else if (indicator.levelVisible && indicator.kind === "volume") {
                if (indicator.playingTrack && !indicator.trackVisible) indicator.displayTrack();
                else if (!indicator.playingTrack) indicator.dismissTrack();
            }
        }
    }
    Connections {
        target: indicator.player
        ignoreUnknownSignals: true
        function onPositionChanged() { if (indicator.trackVisible) indicator.refreshProgress(); }
    }
    function state(): var {
        return {visible: expanded, kind: trackVisible && !levelVisible ? "media" : kind, percent: percent, muted: muted,
            trackVisible: trackVisible, levelVisible: levelVisible, levelReveal: levelReveal, trackPresented: trackPresented,
            trackPending: trackPending, artworkReady: trackArt.hasArtwork,
            positionSeconds: positionSeconds, durationSeconds: durationSeconds, trackProgress: trackProgress,
            monitor: targetScreen ? targetScreen.name : "", position: barPosition, x: card.x, y: card.y, width: card.width, height: card.height};
    }
    Timer {
        id: levelDelay
        interval: 1700
        onTriggered: {
            indicator.levelVisible = false;
            if (indicator.trackPending && indicator.track.available && !indicator.blocked) indicator.displayTrack();
        }
    }
    Timer {
        id: trackDelay
        interval: 3500
        onTriggered: {
            if (indicator.levelVisible && indicator.kind === "volume" && indicator.playingTrack) restart();
            else indicator.trackVisible = false;
        }
    }
    Timer {
        interval: 250
        repeat: true
        running: indicator.trackVisible && indicator.playingTrack && indicator.positionAvailable
        onTriggered: indicator.refreshProgress()
    }

    screen: targetScreen
    implicitWidth: targetScreen ? targetScreen.width : 0
    implicitHeight: targetScreen ? targetScreen.height : 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "spectrum-level-indicator"
    focusable: false
    color: "transparent"
    visible: !!targetScreen && motion.active
    mask: Region {}

    ShellSurface {
        id: card
        transform: ShellMotion {
            id: motion
            surface: card
            animationsEnabled: indicator.theme.animationsEnabled !== false
            bounceEnabled: indicator.theme.widgetBounceEnabled !== false
            expanded: indicator.expanded
            edge: indicator.barPosition === "top" ? "top" : "left"
            viewportWidth: indicator.width
            viewportHeight: indicator.height
        }
        attachTop: indicator.barPosition === "top"
        attachRight: indicator.barPosition === "top"
        attachBottom: indicator.barPosition === "left"
        attachLeft: indicator.barPosition === "left"
        topAttachmentHeight: indicator.theme.barStyle === "islands" && attachTop ? Math.max(0, y - 8) : 0
        leftAttachmentWidth: indicator.theme.barStyle === "islands" && attachLeft ? Math.max(0, x - leftFrameThickness) : 0
        width: Math.min(indicator.trackPresented ? 400 : 340, indicator.width - (indicator.barPosition === "left" ? indicator.panelLeftInset + 16 : 16))
        height: content.implicitHeight + 36
        x: indicator.barPosition === "top" ? indicator.width - width : indicator.panelLeftInset
        y: indicator.barPosition === "top" ? indicator.panelTopInset : indicator.height - height - (indicator.theme.gamingActive ? 0 : 8)
        radius: 24
        color: indicator.theme.colors.surface

        ColumnLayout {
            id: content
            anchors { fill: parent; margins: 18 }
            spacing: 0
            ColumnLayout {
                Layout.fillWidth: true
                visible: indicator.trackPresented
                spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    MediaArtwork {
                        id: trackArt
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 64
                        artUrl: motion.active && indicator.trackPresented ? indicator.track.artUrl || "" : ""
                        backgroundColor: indicator.theme.colors.surface_alt
                        foregroundColor: indicator.theme.colors.accent
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            Layout.fillWidth: true
                            text: indicator.track.title || qsTranslate("Spectrum", "Unknown track")
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            color: indicator.theme.colors.foreground
                            font { family: indicator.theme.fontFamily; pixelSize: indicator.theme.fontSize + 1; bold: true }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: indicator.track.artist || qsTranslate("Spectrum", "Unknown artist")
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: indicator.theme.colors.muted
                            font { family: indicator.theme.fontFamily; pixelSize: indicator.theme.fontSize }
                        }
                    }
                }
                Rectangle {
                    objectName: "track-progress-bar"
                    Layout.fillWidth: true
                    implicitHeight: 4
                    radius: 2
                    color: indicator.theme.colors.surface_alt
                    Rectangle {
                        width: parent.width * indicator.trackProgress
                        height: parent.height
                        radius: 2
                        color: indicator.theme.colors.accent
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        objectName: "track-elapsed"
                        text: indicator.positionAvailable ? indicator.formatTime(indicator.positionSeconds) : "--:--"
                        color: indicator.theme.colors.muted
                        font { family: indicator.theme.fontFamily; pixelSize: indicator.theme.fontSize - 1 }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        objectName: "track-remaining"
                        text: indicator.positionAvailable && indicator.durationSeconds > 0 ? "−" + indicator.formatTime(indicator.durationSeconds - indicator.positionSeconds) : "--:--"
                        color: indicator.theme.colors.muted
                        font { family: indicator.theme.fontFamily; pixelSize: indicator.theme.fontSize - 1 }
                    }
                }
            }
            Item {
                objectName: "level-reveal"
                Layout.fillWidth: true
                implicitHeight: (levelContent.implicitHeight + (indicator.trackPresented ? 14 : 0)) * indicator.levelReveal
                visible: indicator.levelReveal > 0
                clip: true
                ColumnLayout {
                    id: levelContent
                    width: parent.width
                    y: (indicator.trackPresented ? 14 : 0) - (implicitHeight + (indicator.trackPresented ? 14 : 0)) * (1 - indicator.levelReveal)
                    spacing: 12
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            text: indicator.kind === "brightness" ? "󰃞" : indicator.muted ? "󰖁" : "󰕾"
                            color: indicator.theme.colors.accent
                            font { family: indicator.theme.fontFamily; pixelSize: indicator.theme.fontSize + 7 }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: indicator.kind === "brightness" ? qsTranslate("Spectrum", "Brightness") + (indicator.deviceLabel ? " · " + indicator.deviceLabel : "") : qsTranslate("Spectrum", "Volume")
                            elide: Text.ElideRight
                            color: indicator.theme.colors.foreground
                            font { family: indicator.theme.fontFamily; pixelSize: indicator.theme.fontSize; bold: true }
                        }
                        Text {
                            text: indicator.muted ? qsTranslate("Spectrum", "Muted") : indicator.percent + "%"
                            color: indicator.theme.colors.foreground
                            font { family: indicator.theme.fontFamily; pixelSize: indicator.theme.fontSize; bold: true }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 8
                        radius: 4
                        color: indicator.theme.colors.surface_alt
                        Rectangle {
                            width: parent.width * (indicator.muted ? 0 : Math.max(0, Math.min(100, indicator.percent))) / 100
                            height: parent.height
                            radius: 4
                            color: indicator.theme.colors.accent
                            Behavior on width {
                                enabled: indicator.theme.animationsEnabled !== false
                                NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }
            }
        }
    }
}
