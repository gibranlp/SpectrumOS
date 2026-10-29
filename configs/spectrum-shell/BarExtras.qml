pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: extras
    required property var theme
    required property var window
    property bool detailed: false
    WidgetActions { id: catalog }
    signal chosen(string action)
    spacing: 14
    readonly property var directActions: detailed
        ? ["favorites", "breaks", "battery", "keep-awake", "brightness", "weather", "displays", "typography", "network", "bluetooth", "audio", "notifications"]
        : ["battery", "keep-awake", "weather", "network", "bluetooth", "audio", "notifications"]
    readonly property var actions: catalog.widgets.filter(item => !directActions.includes(item.action)).sort((a, b) => a.label.localeCompare(b.label))

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
}
