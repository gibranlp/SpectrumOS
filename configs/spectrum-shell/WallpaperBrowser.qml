import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "spectrum-widget-wallpaperbrowser"
    id: browser
    required property var theme
    property var catalog: ({ wallpapers: [] })
    property string barPosition: "top"
    property int leftInset: theme.barLeftInset
    signal applyWallpaper(string token)
    signal randomWallpaper()
    signal closeRequested()

    anchors { top: true; bottom: true; left: true; right: true }
    implicitWidth: screen.width
    implicitHeight: screen.height
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    property bool expanded: false
    visible: motion.active
    WlrLayershell.keyboardFocus: panelFocus.mode
    ShellFocus { id: panelFocus; window: browser; enabled: expanded }

    function moveSelection(offset): void {
        if (gallery.count === 0)
            return;
        gallery.currentIndex = Math.max(0, Math.min(gallery.count - 1, gallery.currentIndex + offset));
        gallery.positionViewAtIndex(gallery.currentIndex, ListView.Contain);
    }

    function applySelection(): void {
        const item = (catalog.wallpapers || [])[gallery.currentIndex];
        if (item)
            applyWallpaper(item.token);
    }

    function open(): void {
        expanded = true;
        const index = (catalog.wallpapers || []).findIndex(item => item.current);
        gallery.currentIndex = index >= 0 ? index : 0;
        Qt.callLater(() => gallery.positionViewAtIndex(gallery.currentIndex, ListView.Center));
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        focus: browser.expanded
        Keys.onEscapePressed: browser.closeRequested()
        Keys.onLeftPressed: browser.moveSelection(-1)
        Keys.onRightPressed: browser.moveSelection(1)
        Keys.onReturnPressed: browser.applySelection()
        Keys.onEnterPressed: browser.applySelection()
        MouseArea { anchors.fill: parent; onClicked: browser.closeRequested() }
    }

    ShellSurface {
        id: strip
        Keys.onEscapePressed: browser.closeRequested()
        Keys.onLeftPressed: browser.moveSelection(-1)
        Keys.onRightPressed: browser.moveSelection(1)
        attachBottom: true
        transform: ShellMotion {
            id: motion
            surface: strip
            animationsEnabled: browser.theme.animationsEnabled !== false
            bounceEnabled: browser.theme.widgetBounceEnabled !== false
            expanded: browser.expanded
            edge: "bottom"
            viewportWidth: browser.screen.width
            viewportHeight: browser.screen.height
        }
        width: Math.min(1320, parent.width - (browser.leftInset + 32))
        height: Math.max(166, randomLabel.implicitWidth + 48)
        x: (parent.width - width + browser.leftInset) / 2
        y: parent.height - height - (browser.theme.gamingActive ? 0 : 8)
        radius: 32
        color: browser.theme.colors.surface

        MouseArea { anchors.fill: parent }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            ListView {
                id: gallery
                Layout.fillWidth: true
                Layout.fillHeight: true
                orientation: ListView.Horizontal
                spacing: 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: browser.catalog.wallpapers || []
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool selected: index === gallery.currentIndex
                    width: 230
                    height: gallery.height
                    radius: 11
                    clip: true
                    color: browser.theme.colors.background

                    Image {
                        anchors.fill: parent
                        source: "file://" + modelData.path
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: browser.theme.colors.accent
                        opacity: parent.selected ? 0.35 : parent.modelData.current ? 0.15 : 0
                    }
                    KeyboardAction {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onActivated: {
                            gallery.currentIndex = index;
                            browser.applyWallpaper(modelData.token);
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: wheel => {
                        const end = Math.max(0, gallery.contentWidth - gallery.width);
                        gallery.contentX = Math.max(0, Math.min(end, gallery.contentX - wheel.angleDelta.y));
                        wheel.accepted = true;
                    }
                }

                Text {
                    visible: gallery.count === 0
                    anchors.centerIn: parent
                    text: "Add images to ~/Pictures/Wallpapers"
                    color: browser.theme.colors.muted
                    font { family: browser.theme.fontFamily; pixelSize: browser.theme.fontSize }
                }
            }

            Rectangle {
                objectName: "wallpaper-random-button"
                Layout.preferredWidth: Math.max(48, randomLabel.implicitHeight + 24)
                Layout.fillHeight: true
                radius: 11
                color: browser.theme.colors.accent
                Text {
                    id: randomLabel
                    objectName: "wallpaper-random-label"
                    anchors.centerIn: parent
                    rotation: -90
                    text: "Spectrumize me"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: browser.theme.colors.background
                    font { family: browser.theme.fontFamily; pixelSize: browser.theme.fontSize; bold: true }
                }
                KeyboardAction {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onActivated: browser.randomWallpaper()
                }
            }
        }
    }

}
