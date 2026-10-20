pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../spectrum-shell" as Shell

ShellRoot {
    id: root
    property bool expanded: false
    property var openScreen: Quickshell.screens[0]
    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"
    readonly property var colors: widgetTheme.colors
    readonly property string fontFamily: widgetTheme.fontFamily
    readonly property int fontSize: widgetTheme.fontSize
    property var preferences: ({})
    readonly property string barProfile: (preferences.bar_profiles || {})[openScreen ? openScreen.name : ""] || preferences.bar_profile || "standard"
    property var gamingStatus: ({})
    readonly property bool gamingActive: preferences.gaming_enabled === true || gamingStatus.automatic === true
    readonly property bool animationsEnabled: !gamingActive
    readonly property int topInset: gamingActive ? 0 : preferences.bar_position === "top" && barProfile !== "minimal" ? 34 : 8
    readonly property int leftInset: gamingActive ? 0 : preferences.bar_position !== "top" && barProfile !== "minimal" ? 52 : 0
    readonly property bool widgetBounceEnabled: preferences.widget_bounce_enabled !== false
    readonly property string backendDir: Quickshell.env("SPECTRUM_SHELL_BACKEND_DIR") || "/usr/lib/spectrumos"
    function show() {
        widgetTheme.reload();
        openScreen = Quickshell.screens.find(screen => { const monitor = Hyprland.monitorFor(screen); return monitor && monitor.focused; }) || Quickshell.screens[0];
        expanded = true;
    }
    function close() { expanded = false; }
    Component.onCompleted: show()
    IpcHandler {
        target: "spectrum-ukvm"
        function themeState(): string { return JSON.stringify({colors: root.colors, fontFamily: root.fontFamily, fontSize: root.fontSize, expanded: root.expanded}); }
        function open(): void { root.show(); }
        function close(): void { root.close(); }
        function toggle(): void { if (root.expanded) root.close(); else root.show(); }
    }
    UkvmTheme {
        id: widgetTheme
        active: root.expanded
        palettePath: Quickshell.env("SPECTRUM_SHELL_PALETTE") || root.cacheHome + "/spectrumos/theme/current/palette.json"
        fontPath: root.cacheHome + "/spectrumos/theme/current/kitty.conf"
    }
    FileView {
        path: root.configHome + "/spectrumos/shell.json"
        watchChanges: true
        onFileChanged: reload()
        onTextChanged: { try { root.preferences = JSON.parse(text()); } catch (e) {} }
    }
    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/spectrumos/gaming-status.json"
        watchChanges: true
        onFileChanged: reload()
        onTextChanged: { try { root.gamingStatus = JSON.parse(text()); } catch (e) {} }
    }
    UkvmState { id: state; active: root.expanded; adapter: root.backendDir + "/ukvm-adapter" }
    PanelWindow {
        id: window
        screen: root.openScreen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: motion.active
        WlrLayershell.namespace: "spectrum-widget-ukvm"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: root.expanded ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        MouseArea { anchors.fill: parent; onClicked: root.close() }
        Shell.ShellSurface {
            id: card
            attachTop: true
            topAttachmentHeight: root.preferences.bar_style === "islands" && root.preferences.bar_position === "top"
                ? Math.max(0, y - 8) : 0
            transform: Shell.ShellMotion {
                id: motion
                surface: card
                animationsEnabled: root.animationsEnabled
                bounceEnabled: root.widgetBounceEnabled
                expanded: root.expanded
                edge: "top"
                viewportWidth: window.width
                viewportHeight: window.height
            }
            x: Math.round((parent.width + root.leftInset - width) / 2)
            y: root.topInset
            width: Math.min(960, parent.width - root.leftInset - 32)
            height: Math.min(820, parent.height - root.topInset - 12)
            radius: 32
            color: root.colors.surface
            MouseArea { anchors.fill: parent; onClicked: mouse => mouse.accepted = true }
            UkvmPage {
                anchors { fill: parent; margins: 20 }
                theme: root
                backend: state
                onCloseRequested: root.close()
                focus: root.expanded
                Keys.onEscapePressed: root.close()
            }
        }
    }
}
