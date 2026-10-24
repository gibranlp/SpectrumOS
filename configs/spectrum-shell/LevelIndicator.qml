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
    property bool expanded: false
    property string kind: "volume"
    property int level: 0
    property string deviceLabel: ""
    property var track: ({})
    property bool trackPending: false

    readonly property int percent: kind === "volume" ? theme.volumePercent : level
    readonly property bool muted: kind === "volume" && theme.volumeMuted
    onBlockedChanged: if (blocked) dismiss()

    function show(kind, level, label): void {
        if (blocked || !["volume", "brightness"].includes(kind)) return;
        if (expanded && indicator.kind === "media") trackPending = true;
        indicator.kind = kind;
        indicator.level = Math.max(0, Math.min(100, level));
        deviceLabel = label;
        expanded = true;
        dismissDelay.interval = 1700;
        dismissDelay.restart();
    }
    function showTrack(): void {
        if (blocked || !theme.media.available) return;
        if (expanded && kind !== "media") { trackPending = true; return; }
        displayTrack();
    }
    function displayTrack(): void {
        trackPending = false;
        track = theme.media;
        kind = "media";
        expanded = true;
        dismissDelay.interval = 3500;
        dismissDelay.restart();
    }
    function dismissTrack(): void {
        trackPending = false;
        if (kind === "media") dismiss();
    }
    function dismiss(): void { dismissDelay.stop(); trackPending = false; expanded = false; }
    Connections {
        target: indicator.theme
        function onMediaChanged() {
            if (indicator.expanded && indicator.kind === "media" && indicator.theme.media.available)
                indicator.track = indicator.theme.media;
        }
    }
    function state(): var {
        return {visible: expanded, kind: kind, percent: percent, muted: muted, trackPending: trackPending, artworkReady: trackArt.hasArtwork,
            monitor: targetScreen.name, position: barPosition, x: card.x, y: card.y, width: card.width, height: card.height};
    }
    Timer {
        id: dismissDelay
        interval: 1700
        onTriggered: {
            if (indicator.trackPending && indicator.theme.media.available && !indicator.blocked) indicator.displayTrack();
            else indicator.expanded = false;
        }
    }

    screen: targetScreen
    implicitWidth: targetScreen.width
    implicitHeight: targetScreen.height
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "spectrum-level-indicator"
    focusable: false
    color: "transparent"
    visible: motion.active
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
        width: Math.min(indicator.kind === "media" ? 400 : 340, indicator.width - (indicator.barPosition === "left" ? indicator.panelLeftInset + 16 : 16))
        height: content.implicitHeight + 36
        x: indicator.barPosition === "top" ? indicator.width - width : indicator.panelLeftInset
        y: indicator.barPosition === "top" ? indicator.panelTopInset : indicator.height - height - (indicator.theme.gamingActive ? 0 : 8)
        radius: 24
        color: indicator.theme.colors.surface

        ColumnLayout {
            id: content
            anchors { fill: parent; margins: 18 }
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                visible: indicator.kind !== "media"
                spacing: 12
                Text {
                    text: indicator.kind === "brightness" ? "󰃞" : indicator.muted ? "󰖁" : "󰕾"
                    color: indicator.theme.colors.accent
                    font { family: indicator.theme.fontFamily; pixelSize: indicator.theme.fontSize + 7 }
                }
                Text {
                    Layout.fillWidth: true
                    text: indicator.kind === "brightness" ? "Brightness" + (indicator.deviceLabel ? " · " + indicator.deviceLabel : "") : "Volume"
                    elide: Text.ElideRight
                    color: indicator.theme.colors.foreground
                    font { family: indicator.theme.fontFamily; pixelSize: indicator.theme.fontSize; bold: true }
                }
                Text {
                    text: indicator.muted ? "Muted" : indicator.percent + "%"
                    color: indicator.theme.colors.foreground
                    font { family: indicator.theme.fontFamily; pixelSize: indicator.theme.fontSize; bold: true }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: indicator.kind === "media"
                spacing: 14
                MediaArtwork {
                    id: trackArt
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64
                    artUrl: motion.active && indicator.kind === "media" ? indicator.track.artUrl || "" : ""
                    backgroundColor: indicator.theme.colors.surface_alt
                    foregroundColor: indicator.theme.colors.accent
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        Layout.fillWidth: true
                        text: indicator.track.title || "Unknown track"
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        color: indicator.theme.colors.foreground
                        font { family: indicator.theme.fontFamily; pixelSize: indicator.theme.fontSize + 1; bold: true }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: indicator.track.artist || "Unknown artist"
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: indicator.theme.colors.muted
                        font { family: indicator.theme.fontFamily; pixelSize: indicator.theme.fontSize }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                visible: indicator.kind !== "media"
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
