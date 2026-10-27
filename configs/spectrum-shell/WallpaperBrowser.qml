pragma ComponentBehavior: Bound

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
        if (!galleryContent.item || galleryContent.item.gallery.count === 0)
            return;
        galleryContent.item.gallery.currentIndex = Math.max(0, Math.min(galleryContent.item.gallery.count - 1, galleryContent.item.gallery.currentIndex + offset));
        galleryContent.item.gallery.positionViewAtIndex(galleryContent.item.gallery.currentIndex, ListView.Contain);
    }

    function applySelection(): void {
        if (!galleryContent.item) return;
        const item = (catalog.wallpapers || [])[galleryContent.item.gallery.currentIndex];
        if (item)
            applyWallpaper(item.token);
    }

    function open(): void {
        galleryContent.ensureLoaded();
        expanded = true;
        const index = (catalog.wallpapers || []).findIndex(item => item.current);
        galleryContent.item.gallery.currentIndex = index >= 0 ? index : 0;
        Qt.callLater(() => galleryContent.item.gallery.positionViewAtIndex(galleryContent.item.gallery.currentIndex, ListView.Center));
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
        height: Math.max(166, (galleryContent.item ? galleryContent.item.randomLabelWidth : 118) + 48)
        x: (parent.width - width + browser.leftInset) / 2
        y: parent.height - height - (browser.theme.gamingActive ? 0 : 8)
        radius: 32
        color: browser.theme.colors.surface

        MouseArea { anchors.fill: parent }

        CachedContent {
            id: galleryContent
            anchors.fill: parent
            anchors.margins: 12
            requested: browser.expanded
            sourceComponent:
            RowLayout {
                property alias gallery: thumbnailList
                readonly property real randomLabelWidth: randomLabel.implicitWidth
                spacing: 12

                ListView {
                    id: thumbnailList
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
                        readonly property bool selected: index === thumbnailList.currentIndex
                        width: 230
                        height: thumbnailList.height
                        radius: 11
                        clip: true
                        color: browser.theme.colors.background

                        Image {
                            anchors.fill: parent
                            source: "file://" + modelData.path
                            sourceSize: Qt.size(Math.max(1, Math.ceil(width * Screen.devicePixelRatio)),
                                                Math.max(1, Math.ceil(height * Screen.devicePixelRatio)))
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
                                thumbnailList.currentIndex = index;
                                browser.applyWallpaper(modelData.token);
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: wheel => {
                            const end = Math.max(0, thumbnailList.contentWidth - thumbnailList.width);
                            thumbnailList.contentX = Math.max(0, Math.min(end, thumbnailList.contentX - wheel.angleDelta.y));
                            wheel.accepted = true;
                        }
                    }

                    Text {
                        visible: thumbnailList.count === 0
                        anchors.centerIn: parent
                        text: qsTranslate("Spectrum", "Add images to ~/Pictures/Wallpapers")
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
                        text: qsTranslate("Spectrum", "Spectrumize me")
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

}
