import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "spectrum-widget-controlcenter"
    id: center
    required property var theme
    property var themeState: ({ palette: {}, gowall: {} })
    property string barPosition: "top"
    property string barProfile: theme.barProfile
    property int topInset: theme.panelTopInset
    property int sideInset: theme.panelLeftInset
    property bool expanded: false
    signal closeRequested()
    signal actionRequested(var command)
    signal widgetBounceSelected(bool enabled)
    signal barPositionSelected(string position)
    signal barProfileSelected(string profile)

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: motion.active
    focusable: expanded
    EscapeDismissal { active: center.expanded; onDismissed: center.closeRequested() }
    onExpandedChanged: {
        if (expanded) {
            settingsScroll.contentY = 0;
            Qt.callLater(() => {
                if (center.expanded) {
                    frame.forceActiveFocus();
                    frame.keyboardController.move(true);
                }
            });
        }
    }

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
            edge: "left"
            viewportWidth: center.screen.width
            viewportHeight: center.screen.height
        }
        topAttachmentHeight: center.theme.barStyle === "islands" && center.theme.barPosition === "top"
            ? Math.max(0, y - 8) : 0
        attachTop: true
        attachBottom: true
        attachLeft: true
        leftAttachmentWidth: center.theme.barStyle === "islands" && center.theme.barPosition === "left"
            ? Math.max(0, x - leftFrameThickness) : 0
        width: Math.min(660, center.width - center.sideInset)
        height: center.height - center.topInset - 8
        x: center.sideInset
        y: center.topInset
        focus: center.expanded
        color: center.theme.colors.surface
        radius: 32

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "CONTROL CENTER"
                    color: center.theme.colors.foreground
                    font { family: center.theme.fontFamily; pixelSize: center.theme.fontSize + 8; bold: true }
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
            Text {
                visible: center.theme.actionError.length > 0
                Layout.fillWidth: true
                text: center.theme.actionError
                color: center.theme.colors.accent
                wrapMode: Text.WordWrap
                font { family: center.theme.fontFamily; pixelSize: center.theme.fontSize - 1 }
            }
            Text {
                visible: center.theme.actionBusy
                text: "Applying change…"
                color: center.theme.colors.muted
                font { family: center.theme.fontFamily; pixelSize: center.theme.fontSize - 1 }
            }
            Flickable {
                id: settingsScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: content.implicitHeight + 20
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: content
                    width: parent.width
                    enabled: !center.theme.actionBusy
                    spacing: 13

                    Text {
                        text: "THEME COLORS"
                        color: center.theme.colors.accent
                        font { family: center.theme.fontFamily; pixelSize: center.theme.fontSize; bold: true }
                    }
                    Text {
                        text: "PALETTE BACKEND"
                        color: center.theme.colors.accent
                        font { family: center.theme.fontFamily; pixelSize: center.theme.fontSize; bold: true }
                    }
                    Flow {
                        Layout.fillWidth: true
                        Layout.maximumWidth: content.width
                        spacing: 7
                        Repeater {
                            model: [
                                {key: "spectrum", label: "Spectrum"},
                                {key: "clustered", label: "Clustered"},
                                {key: "median-cut", label: "Median cut"},
                                {key: "weighted-regions", label: "Weighted regions"}
                            ]
                            ShellButton {
                                required property var modelData
                                label: modelData.label
                                fontFamily: center.theme.fontFamily
                                fontSize: center.theme.fontSize
                                backgroundColor: center.themeState.palette.mode === modelData.key ? center.theme.colors.accent : center.theme.colors.surface_alt
                                foregroundColor: center.themeState.palette.mode === modelData.key ? center.theme.colors.background : center.theme.colors.foreground
                                onClicked: center.actionRequested([center.theme.backend("theme-adapter"), "mode", modelData.key])
                            }
                        }
                    }
                    Text {
                        text: "LIGHT AND DARK"
                        color: center.theme.colors.accent
                        font { family: center.theme.fontFamily; pixelSize: center.theme.fontSize; bold: true }
                    }
                    Flow {
                        Layout.fillWidth: true
                        Layout.maximumWidth: content.width
                        spacing: 7
                        Repeater {
                            model: ["auto", "dark", "light"]
                            ShellButton {
                                required property string modelData
                                label: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                fontFamily: center.theme.fontFamily
                                fontSize: center.theme.fontSize
                                backgroundColor: center.themeState.palette.variant === modelData ? center.theme.colors.accent : center.theme.colors.surface_alt
                                foregroundColor: center.themeState.palette.variant === modelData ? center.theme.colors.background : center.theme.colors.foreground
                                onClicked: center.actionRequested([center.theme.backend("theme-adapter"), "variant", modelData])
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: center.theme.colors.surface_alt }

                    Text {
                        text: "WINDOW LAYOUT"
                        color: center.theme.colors.accent
                        font { family: center.theme.fontFamily; pixelSize: center.theme.fontSize; bold: true }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Choose how Hyprland arranges windows."
                        color: center.theme.colors.muted
                        font { family: center.theme.fontFamily; pixelSize: center.theme.fontSize - 1 }
                    }
                    Flow {
                        Layout.fillWidth: true
                        Layout.maximumWidth: content.width
                        spacing: 6
                        Repeater {
                            model: ["dwindle", "master", "scrolling", "monocle"]
                            ShellButton {
                                required property string modelData
                                label: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                fontFamily: center.theme.fontFamily
                                fontSize: center.theme.fontSize
                                backgroundColor: center.theme.overview.hyprland && center.theme.overview.hyprland.layout === modelData ? center.theme.colors.accent : center.theme.colors.surface_alt
                                foregroundColor: center.theme.overview.hyprland && center.theme.overview.hyprland.layout === modelData ? center.theme.colors.background : center.theme.colors.foreground
                                onClicked: center.actionRequested([center.theme.backend("hyprland-menu"), "--set", "layout", modelData])
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: center.theme.colors.surface_alt }

                    Text {
                        text: "SHELL LAYOUT · ALL MONITORS"
                        color: center.theme.colors.accent
                        font { family: center.theme.fontFamily; pixelSize: center.theme.fontSize; bold: true }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        ShellButton {
                            Layout.fillWidth: true
                            label: "Top bar"
                            fontFamily: center.theme.fontFamily
                            fontSize: center.theme.fontSize
                            backgroundColor: center.barPosition === "top" ? center.theme.colors.accent : center.theme.colors.surface_alt
                            foregroundColor: center.barPosition === "top" ? center.theme.colors.background : center.theme.colors.foreground
                            onClicked: center.barPositionSelected("top")
                        }
                        ShellButton {
                            Layout.fillWidth: true
                            label: "Left bar"
                            fontFamily: center.theme.fontFamily
                            fontSize: center.theme.fontSize
                            backgroundColor: center.barPosition === "left" ? center.theme.colors.accent : center.theme.colors.surface_alt
                            foregroundColor: center.barPosition === "left" ? center.theme.colors.background : center.theme.colors.foreground
                            onClicked: center.barPositionSelected("left")
                        }
                    }
                    Text {
                        text: "BAR STYLE · ALL PROFILES"
                        color: center.theme.colors.accent
                        font { family: center.theme.fontFamily; pixelSize: center.theme.fontSize; bold: true }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Repeater {
                            model: [{ key: "full", label: "Full" }, { key: "islands", label: "Islands" }]
                            ShellButton {
                                required property var modelData
                                Layout.fillWidth: true
                                label: modelData.label
                                fontFamily: center.theme.fontFamily
                                fontSize: center.theme.fontSize
                                backgroundColor: center.theme.barStyle === modelData.key ? center.theme.colors.accent : center.theme.colors.surface_alt
                                foregroundColor: center.theme.barStyle === modelData.key ? center.theme.colors.background : center.theme.colors.foreground
                                onClicked: center.theme.setBarStyle(modelData.key)
                            }
                        }
                    }
                    ShellButton {
                        objectName: "widgetBounceToggle"
                        Layout.fillWidth: true
                        label: "Widget bounce: " + (center.theme.widgetBounceEnabled !== false ? "On" : "Off")
                        fontFamily: center.theme.fontFamily
                        fontSize: center.theme.fontSize
                        backgroundColor: center.theme.widgetBounceEnabled !== false ? center.theme.colors.accent : center.theme.colors.surface_alt
                        foregroundColor: center.theme.widgetBounceEnabled !== false ? center.theme.colors.background : center.theme.colors.foreground
                        onClicked: center.widgetBounceSelected(center.theme.widgetBounceEnabled === false)
                    }
                    Text {
                        text: "BAR PROFILE · " + (center.theme.gamingActive ? "All monitors" : center.screen ? center.screen.name : "This monitor")
                        color: center.theme.colors.accent
                        font { family: center.theme.fontFamily; pixelSize: center.theme.fontSize; bold: true }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: center.theme.gamingActive === true
                        text: center.theme.gamingStatus.error || (center.theme.gamingStatus.active ? "Gaming · All monitors · Animations off · GameMode active" : "Activating GameMode…")
                        wrapMode: Text.WordWrap
                        color: center.theme.gamingStatus.error ? center.theme.colors.error : center.theme.colors.muted
                        font { family: center.theme.fontFamily; pixelSize: center.theme.fontSize - 1 }
                    }
                    Flow {
                        Layout.fillWidth: true
                        Layout.maximumWidth: content.width
                        spacing: 5
                        Repeater {
                            model: ["standard", "minimal", "detailed", "multimedia", "gaming"]
                            ShellButton {
                                required property string modelData
                                label: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                fontFamily: center.theme.fontFamily
                                fontSize: center.theme.fontSize - 1
                                backgroundColor: center.barProfile === modelData ? center.theme.colors.accent : center.theme.colors.surface_alt
                                foregroundColor: center.barProfile === modelData ? center.theme.colors.background : center.theme.colors.foreground
                                onClicked: center.barProfileSelected(modelData)
                            }
                        }
                    }

                    ShellButton {
                        Layout.fillWidth: true
                        visible: center.theme.gamingActive === true
                        label: "Leave Gaming · Restore previous profiles"
                        fontFamily: center.theme.fontFamily
                        fontSize: center.theme.fontSize
                        backgroundColor: center.theme.colors.surface_alt
                        foregroundColor: center.theme.colors.foreground
                        onClicked: { center.theme.leaveGaming(); center.expanded = false; }
                    }
                    Text {
                        text: "WORKSPACE ICONS"
                        color: center.theme.colors.accent
                        font { family: center.theme.fontFamily; pixelSize: center.theme.fontSize; bold: true }
                    }
                    Flow {
                        Layout.fillWidth: true
                        Layout.maximumWidth: content.width
                        spacing: 7
                        Repeater {
                            model: center.theme.workspaceIcons.sets || []
                            ShellButton {
                                required property var modelData
                                label: modelData.label + "  ·  " + modelData.preview.join(" ")
                                fontFamily: center.theme.fontFamily
                                fontSize: center.theme.fontSize - 1
                                backgroundColor: modelData.current ? center.theme.colors.accent : center.theme.colors.surface_alt
                                foregroundColor: modelData.current ? center.theme.colors.background : center.theme.colors.foreground
                                onClicked: center.actionRequested([center.theme.backend("waybar-workspace-icons"), "set", modelData.key])
                            }
                        }
                    }

                    Text {
                        text: "DESKTOP LOGO · ALL MONITORS"
                        color: center.theme.colors.accent
                        font { family: center.theme.fontFamily; pixelSize: center.theme.fontSize; bold: true }
                    }
                    ShellButton {
                        Layout.fillWidth: true
                        label: "Desktop logo · " + (center.theme.desktopLogoEnabled ? "On" : "Off")
                        fontFamily: center.theme.fontFamily
                        fontSize: center.theme.fontSize
                        backgroundColor: center.theme.desktopLogoEnabled ? center.theme.colors.accent : center.theme.colors.surface_alt
                        foregroundColor: center.theme.desktopLogoEnabled ? center.theme.colors.background : center.theme.colors.foreground
                        onClicked: center.theme.toggleDesktopLogo()
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 5
                        Repeater {
                            model: [
                                { corner: "top-left", label: "Top left" },
                                { corner: "top-right", label: "Top right" },
                                { corner: "bottom-left", label: "Bottom left" },
                                { corner: "bottom-right", label: "Bottom right" }
                            ]
                            ShellButton {
                                required property var modelData
                                label: modelData.label
                                fontFamily: center.theme.fontFamily
                                fontSize: center.theme.fontSize
                                backgroundColor: center.theme.desktopLogoCorner === modelData.corner ? center.theme.colors.accent : center.theme.colors.surface_alt
                                foregroundColor: center.theme.desktopLogoCorner === modelData.corner ? center.theme.colors.background : center.theme.colors.foreground
                                onClicked: center.theme.setDesktopLogoCorner(modelData.corner)
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: center.theme.colors.surface_alt }
                    Text {
                        text: "WINDOW STYLE"
                        color: center.theme.colors.accent
                        font { family: center.theme.fontFamily; pixelSize: center.theme.fontSize; bold: true }
                    }
                    Repeater {
                        model: [
                            { key: "gaps", label: "Gaps", options: ["none", "compact", "balanced", "spacious"] },
                            { key: "border", label: "Border", options: ["none", "thin", "spectrum", "thick"] },
                            { key: "rounding", label: "Corners", options: ["square", "subtle", "spectrum", "soft"] },
                            { key: "blur", label: "Blur", options: ["off", "light", "spectrum", "strong"] },
                            { key: "transparency", label: "Transparency", options: ["opaque", "subtle", "balanced", "glass"] },
                            { key: "animations", label: "Animations", options: ["off", "smooth", "balanced", "heavy"] }
                        ]
                        ColumnLayout {
                            id: windowField
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 5
                            Text {
                                text: windowField.modelData.label.toUpperCase()
                                color: center.theme.colors.foreground
                                font { family: center.theme.fontFamily; pixelSize: center.theme.fontSize - 1; bold: true }
                            }
                            Flow {
                                Layout.fillWidth: true
                                Layout.maximumWidth: content.width
                                spacing: 5
                                Repeater {
                                    model: windowField.modelData.options
                                    ShellButton {
                                        required property string modelData
                                        label: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                        fontFamily: center.theme.fontFamily
                                        fontSize: center.theme.fontSize - 1
                                        backgroundColor: center.theme.overview.hyprland && center.theme.overview.hyprland[windowField.modelData.key] === modelData ? center.theme.colors.accent : center.theme.colors.surface_alt
                                        foregroundColor: center.theme.overview.hyprland && center.theme.overview.hyprland[windowField.modelData.key] === modelData ? center.theme.colors.background : center.theme.colors.foreground
                                        onClicked: center.actionRequested([center.theme.backend("hyprland-menu"), "--set", windowField.modelData.key, modelData])
                                    }
                                }
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: center.theme.colors.surface_alt }

                    Text {
                        text: "WALLPAPER FILTERS"
                        color: center.theme.colors.accent
                        font { family: center.theme.fontFamily; pixelSize: center.theme.fontSize; bold: true }
                    }
                    Flow {
                        visible: Boolean(center.themeState.gowall && center.themeState.gowall.installed)
                        Layout.fillWidth: true
                        Layout.maximumWidth: content.width
                        spacing: 6
                        Repeater {
                            model: center.themeState.gowall ? center.themeState.gowall.schemes || [] : []
                            ShellButton {
                                required property var modelData
                                label: modelData.label
                                fontFamily: center.theme.fontFamily
                                fontSize: center.theme.fontSize - 1
                                backgroundColor: modelData.current ? center.theme.colors.accent : center.theme.colors.surface_alt
                                foregroundColor: modelData.current ? center.theme.colors.background : center.theme.colors.foreground
                                onClicked: center.actionRequested([center.theme.backend("theme-adapter"), "scheme", modelData.name])
                            }
                        }
                    }
                    Text {
                        visible: !center.themeState.gowall || !center.themeState.gowall.installed
                        text: "Wallpaper filters unavailable"
                        color: center.theme.colors.muted
                        font { family: center.theme.fontFamily; pixelSize: center.theme.fontSize - 1 }
                    }
                }
            }
        }
    }
}
