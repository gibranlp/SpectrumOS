pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls

Flickable {
    id: strip
    required property var theme
    property bool vertical: false
    readonly property var widgets: [
        {icon:"󰕮", label:qsTranslate("Spectrum", "Dashboard"), action:"dashboard"},
        {icon:"★", label:qsTranslate("Spectrum", "Favorites"), action:"favorites"},
        {icon:"󰏗", label:qsTranslate("Spectrum", "App Store"), action:"app-store"},
        {icon:"󰏖", label:"AppImages", action:"appimages"},
        {icon:"󰒡", label:"SpectrumDrop", action:"spectrumdrop"},
        {icon:"󰄬", label:"Questline", action:"questline"},
        {icon:"󰔟", label:qsTranslate("Spectrum", "Focus timer"), action:"focus"},
        {icon:"󰒲", label:qsTranslate("Spectrum", "Break reminders"), action:"breaks", shortcut:"Super+Shift+B"},
        {icon:"󰒋", label:qsTranslate("Spectrum", "Local services"), action:"services", shortcut:"Super+Shift+C"},
        {icon:"󰈔", label:qsTranslate("Spectrum", "Default applications"), action:"default-apps", shortcut:"Super+Shift+G"},
        {icon:"󰍉", label:qsTranslate("Spectrum", "File search"), action:"search"},
        {icon:"󰃬", label:qsTranslate("Spectrum", "Calculator"), action:"calculator"},
        {icon:"󰌾", label:qsTranslate("Spectrum", "Password generator"), action:"password"},
        {icon:"󰞅", label:qsTranslate("Spectrum", "Emoji"), action:"emoji"},
        {icon:"󰈋", label:qsTranslate("Spectrum", "Pick colors"), action:"color"},
        {icon:"󰏘", label:qsTranslate("Spectrum", "Saved colors"), action:"color-history"},
        {icon:"󰌌", label:"HotKey", action:"hotkey"},
        {icon:"󰌐", label:qsTranslate("Spectrum", "Keyboard shortcuts"), action:"shortcuts"},
        {icon:"󰚰", label:qsTranslate("Spectrum", "Updates"), action:"updates"},
        {icon:"󰸉", label:qsTranslate("Spectrum", "Wallpapers"), action:"wallpapers"},
        {icon:"󰕾", label:qsTranslate("Spectrum", "Audio"), action:"audio"},
        {icon:"󰖩", label:qsTranslate("Spectrum", "Network"), action:"network"},
        {icon:"󰂯", label:qsTranslate("Spectrum", "Bluetooth"), action:"bluetooth"},
        {icon:"󰍹", label:qsTranslate("Spectrum", "Displays"), action:"displays"},
        {icon:"󰍽", label:qsTranslate("Spectrum", "Mouse"), action:"mouse"},
        {icon:"Aa", label:qsTranslate("Spectrum", "Typography"), action:"typography"},
        {icon:"󰖕", label:qsTranslate("Spectrum", "Weather"), action:"weather"},
        {icon:"󰥔", label:qsTranslate("Spectrum", "Time & region"), action:"time"},
        {icon:"󰓅", label:qsTranslate("Spectrum", "Power & battery"), action:"battery"},
        {icon:"󰂚", label:qsTranslate("Spectrum", "Notifications"), action:"notifications"},
        {icon:"󰹑", label:qsTranslate("Spectrum", "Screenshot"), action:"screenshot"},
        {icon:"󰑋", label:qsTranslate("Spectrum", "Screen recorder"), action:"recorder"},
        {icon:"󰍬", label:qsTranslate("Spectrum", "Audio recorder"), action:"audio-recorder"},
        {icon:"󰒓", label:qsTranslate("Spectrum", "Control Center"), action:"control"},
        {icon:"󰐥", label:qsTranslate("Spectrum", "Session"), action:"session"},
        {icon:"󰍺", label:"UniversalKVM", action:"ukvm"},
        {icon:"󰅶", label:qsTranslate("Spectrum", "Keep Awake"), action:"keep-awake"}
    ]
    property real cellSize: vertical ? 26 : Math.max(22, Math.min(24, (width + 2) / widgets.length - 2))
    readonly property real naturalWidth: widgets.length * 26 - 2
    readonly property real naturalHeight: Math.ceil(widgets.length / 2) * 28 - 2
    signal chosen(string action)
    implicitWidth: vertical ? 44 : naturalWidth
    implicitHeight: vertical ? naturalHeight : 28
    contentWidth: vertical ? width : icons.implicitWidth
    contentHeight: vertical ? icons.implicitHeight : height
    flickableDirection: vertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded; visible:strip.vertical && strip.contentHeight > strip.height; width:3 }
    onWidthChanged: contentX = Math.max(0, Math.min(contentX, contentWidth - width))
    onHeightChanged: contentY = Math.max(0, Math.min(contentY, contentHeight - height))
    Grid {
        id: icons
        y: strip.vertical ? 0 : (strip.height - strip.cellSize) / 2
        columns: strip.vertical ? 2 : strip.widgets.length
        spacing: 2
        Repeater {
            model: strip.widgets
            Rectangle {
                id: icon
                required property var modelData
                width: strip.vertical ? (strip.width - 2) / 2 : strip.cellSize
                height: strip.cellSize
                radius: 6
                color: action.containsMouse ? strip.theme.colors.surface_alt : "transparent"
                Accessible.role: Accessible.Button
                Accessible.name: modelData.label
                Accessible.onPressAction: strip.chosen(modelData.action)
                Text {
                    anchors.centerIn: parent
                    text: icon.modelData.icon
                    color: icon.modelData.action === "keep-awake" && strip.theme.idle.active ? strip.theme.colors.accent : strip.theme.colors.foreground
                    font { family:strip.theme.fontFamily; pixelSize:Math.min(strip.theme.fontSize + 2, icon.width - 4) }
                }
                ShellToolTip {
                    parent: icon
                    theme: strip.theme
                    visible: action.containsMouse
                    text: icon.modelData.label + (icon.modelData.shortcut ? " · " + icon.modelData.shortcut : "")
                }
                KeyboardAction {
                    id: action
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onActivated: strip.chosen(icon.modelData.action)
                    onActiveFocusChanged: {
                        if (!activeFocus) return;
                        if (strip.vertical) strip.contentY = Math.max(0, Math.min(icon.y, strip.contentHeight - strip.height));
                        else strip.contentX = Math.max(0, Math.min(icon.x, strip.contentWidth - strip.width));
                    }
                    onWheel: wheel => {
                        const delta = wheel.angleDelta.y || wheel.angleDelta.x;
                        if (strip.vertical) strip.contentY = Math.max(0, Math.min(strip.contentY - delta / 3, strip.contentHeight - strip.height));
                        else strip.contentX = Math.max(0, Math.min(strip.contentX - delta / 3, strip.contentWidth - strip.width));
                        wheel.accepted = true;
                    }
                }
            }
        }
    }
}
