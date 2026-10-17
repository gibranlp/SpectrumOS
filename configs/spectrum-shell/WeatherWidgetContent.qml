import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: content
    required property var theme
    spacing: 9

    Text {
        Layout.fillWidth: true
        text: content.theme.weather.location || "Current location"
        elide: Text.ElideRight
        color: content.theme.colors.accent
        font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize; bold: true }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Text {
            Layout.fillWidth: true
            text: (content.theme.weather.icon || "󰖕") + "  " + content.theme.weather.temperature + "\n" + (content.theme.weather.condition || "")
            elide: Text.ElideRight
            color: content.theme.colors.foreground
            font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize + 4; bold: true }
        }
        ColumnLayout {
            spacing: 2
            Repeater {
                model: [
                    "Feels like  " + (content.theme.weather.apparent || "—"),
                    "Humidity  " + (content.theme.weather.humidity || "—"),
                    "Wind  " + (content.theme.weather.wind || "—")
                ]
                Text {
                    required property string modelData
                    text: modelData
                    color: content.theme.colors.muted
                    font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize - 1 }
                }
            }
        }
    }
    Repeater {
        model: content.theme.weather.days || []
        Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 38
            radius: 8
            color: content.theme.colors.surface_alt
            Text {
                anchors { fill: parent; margins: 9 }
                text: modelData.date + "  " + modelData.icon + "  " + modelData.condition + "     " + modelData.high + " / " + modelData.low
                elide: Text.ElideRight
                color: content.theme.colors.foreground
                font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize - 1 }
            }
        }
    }
    Text {
        text: "LOCATIONS"
        color: content.theme.colors.accent
        font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize; bold: true }
    }
    Repeater {
        model: content.theme.weather.locations || []
        RowLayout {
            required property var modelData
            Layout.fillWidth: true
            ShellButton {
                Layout.fillWidth: true
                label: (modelData.active ? "✓ " : "") + modelData.name + "  ·  " + modelData.temperature
                fontFamily: content.theme.fontFamily
                fontSize: content.theme.fontSize
                backgroundColor: modelData.active ? content.theme.colors.accent : content.theme.colors.surface_alt
                foregroundColor: modelData.active ? content.theme.colors.background : content.theme.colors.foreground
                onClicked: content.theme.runAction([content.theme.backend("weather-adapter"), "use", modelData.token])
            }
            ShellButton {
                label: "Remove"
                enabled: (content.theme.weather.locations || []).length > 1
                fontFamily: content.theme.fontFamily
                fontSize: content.theme.fontSize - 1
                backgroundColor: content.theme.colors.surface_alt
                foregroundColor: content.theme.colors.foreground
                onClicked: content.theme.runAction([content.theme.backend("weather-adapter"), "remove", modelData.token])
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        ShellButton {
            label: "Add location"
            fontFamily: content.theme.fontFamily
            fontSize: content.theme.fontSize
            backgroundColor: content.theme.colors.surface_alt
            foregroundColor: content.theme.colors.foreground
            onClicked: content.theme.runAction([content.theme.backend("weather-adapter"), "select-native"])
        }
        ShellButton {
            label: "Refresh"
            fontFamily: content.theme.fontFamily
            fontSize: content.theme.fontSize
            backgroundColor: content.theme.colors.surface_alt
            foregroundColor: content.theme.colors.foreground
            onClicked: content.theme.runAction([content.theme.backend("weather-adapter"), "--refresh"])
        }
    }
}
