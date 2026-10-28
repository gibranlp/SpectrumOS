pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: extras
    required property var theme
    required property var window
    property var trayItems: []
    property bool detailed: false
    WidgetActions { id: catalog }
    signal chosen(string action)
    spacing: 14
    readonly property var actions: detailed
        ? catalog.widgets.filter(item => !["weather", "time", "keep-awake", "audio", "battery"].includes(item.action))
        : standardActions
    readonly property var standardActions: [
        {icon:"󰏗", label:qsTranslate("Spectrum", "App Store"), action:"app-store"},
        {icon:"★", label:qsTranslate("Spectrum", "Favorites"), action:"favorites"},
        {icon:"󰒡", label:"SpectrumDrop", action:"spectrumdrop"},
        {icon:"󰏖", label:"AppImages", action:"appimages"},
        {icon:"󰥔", label:qsTranslate("Spectrum", "Time & region"), action:"time"},
        {icon:"󰒲", label:qsTranslate("Spectrum", "Break reminders"), action:"breaks"},
        {icon:"󰒋", label:qsTranslate("Spectrum", "Local services"), action:"services"},
        {icon:"󰈔", label:qsTranslate("Spectrum", "Default applications"), action:"default-apps"},
        {icon:"󰓅", label:qsTranslate("Spectrum", "Power & battery"), action:"battery"},
        {icon:"󰍹", label:qsTranslate("Spectrum", "Displays"), action:"displays"},
        {icon:"󰍽", label:qsTranslate("Spectrum", "Mouse"), action:"mouse"},
        {icon:"Aa", label:qsTranslate("Spectrum", "Typography"), action:"typography"},
        {icon:"󰒓", label:qsTranslate("Spectrum", "Control Center"), action:"control"},
        {icon:"󰐥", label:qsTranslate("Spectrum", "Session"), action:"session"}
    ]
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        rowSpacing: 8
        columnSpacing: 8
        Repeater {
            model: extras.actions
            ShellButton {
                required property var modelData
                objectName: "bar-extra-" + modelData.action
                Layout.fillWidth: true
                label: modelData.icon + "  " + modelData.label
                fontFamily: extras.theme.fontFamily
                fontSize: extras.theme.fontSize
                backgroundColor: extras.theme.colors.surface_alt
                foregroundColor: extras.theme.colors.foreground
                onClicked: extras.chosen(modelData.action)
            }
        }
    }
    Text {
        visible: trayIcons.count > 0
        text: qsTranslate("Spectrum", "Applications")
        color: extras.theme.colors.muted
        font.family: extras.theme.fontFamily
        font.pixelSize: extras.theme.fontSize
    }
    Flow {
        Layout.fillWidth: true
        spacing: 10
        Repeater {
            id: trayIcons
            model: extras.trayItems
            Item {
                id: trayIcon
                required property var modelData
                width: 36
                height: 36
                Accessible.name: modelData.title || "Tray application"
                Image { anchors.centerIn: parent; width: 22; height: 22; source: parent.modelData.icon; fillMode: Image.PreserveAspectFit }
                KeyboardAction {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onActivated: button => {
                        const position = parent.mapToItem(null, parent.width, parent.height);
                        if (button === Qt.RightButton || trayIcon.modelData.onlyMenu)
                            trayIcon.modelData.display(extras.window, position.x, position.y);
                        else trayIcon.modelData.activate();
                    }
                }
            }
        }
    }
}
