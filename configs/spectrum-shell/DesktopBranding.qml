import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: branding
    required property var targetScreen
    property string imagePath: "/var/lib/spectrumos/appearance/lock-branding.png"
    property string corner: "bottom-right"
    property int leftInset: 0
    property int topInset: 0
    readonly property int logoWidth: Math.round(Math.max(128, Math.min(184, targetScreen.height * 0.085)))

    screen: targetScreen
    anchors {
        top: branding.corner.startsWith("top-")
        bottom: branding.corner.startsWith("bottom-")
        left: branding.corner.endsWith("-left")
        right: branding.corner.endsWith("-right")
    }
    margins { top: 32 + branding.topInset; bottom: 32; left: 32 + branding.leftInset; right: 32 }
    implicitWidth: logoWidth
    implicitHeight: Math.round(logoWidth * 346 / 278)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "spectrum-desktop-branding"
    color: "transparent"
    focusable: false
    mask: Region {}

    function reloadImage(): void {
        logo.source = "";
        Qt.callLater(() => logo.source = "file://" + branding.imagePath);
    }

    FileView {
        path: branding.imagePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: branding.reloadImage()
    }

    Image {
        id: logo
        anchors.fill: parent
        source: "file://" + branding.imagePath
        fillMode: Image.PreserveAspectFit
        cache: false
        smooth: true
        mipmap: true
    }
}
