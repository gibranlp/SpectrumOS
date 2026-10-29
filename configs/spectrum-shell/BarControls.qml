import QtQuick
import QtQuick.Layouts

GridLayout {
    id: controls
    required property var theme
    property string profile: "standard"
    property bool vertical: false
    property var trayItems: []
    property var panelWindow: null
    property var batteryDevice: null
    property bool charging: false
    property bool externalPower: false
    readonly property bool hasBattery: !!batteryDevice && batteryDevice.ready && batteryDevice.isLaptopBattery
    readonly property real batteryPercent: hasBattery ? batteryDevice.percentage * 100 : 0
    readonly property var actions: hasBattery
        ? baseActions.slice(0, baseActions.indexOf("battery")).concat(["battery-level"], baseActions.slice(baseActions.indexOf("battery"))) : baseActions
    readonly property var baseActions: profile === "detailed"
        ? ["favorites", "breaks", "battery", "keep-awake", "brightness", "weather", "displays", "typography", "network", "bluetooth", "audio", "notifications", "extras"]
        : ["battery", "keep-awake", "weather", "network", "bluetooth", "audio", "notifications", "extras"]
    readonly property var labels: ({favorites:qsTranslate("Spectrum", "Favorites"), breaks:qsTranslate("Spectrum", "Break reminders"),
        battery:qsTranslate("Spectrum", "Power & battery"), "keep-awake":qsTranslate("Spectrum", "Keep Awake"),
        "battery-level":qsTranslate("Spectrum", "Power & battery"),
        brightness:qsTranslate("Spectrum", "Brightness"), weather:qsTranslate("Spectrum", "Weather"),
        displays:qsTranslate("Spectrum", "Displays"), typography:qsTranslate("Spectrum", "Typography"),
        network:qsTranslate("Spectrum", "Network"), bluetooth:qsTranslate("Spectrum", "Bluetooth"),
        audio:qsTranslate("Spectrum", "Audio"), notifications:qsTranslate("Spectrum", "Notifications"),
        extras:qsTranslate("Spectrum", "More bar controls")})
    signal chosen(string action)
    columns: vertical ? 1 : actions.length + tray.count
    columnSpacing: 8
    rowSpacing: 5

    function icon(action): string {
        if (action === "battery") return theme.performance.mode === "performance" ? "󰓅" : theme.performance.mode === "power-saver" ? "󰌪" : "";
        if (action === "keep-awake") return theme.idle.active ? "󰅶" : "󰾪";
        if (action === "weather") return (theme.weather.icon || "󰖕") + (!vertical && theme.weather.temperature !== "—" ? " " + theme.weather.temperature : "");
        if (action === "network") return theme.network.connection_type === "ethernet" ? "󰈀" : theme.network.connection_type === "wifi" ? "󰖩" : "󰖪";
        return ({favorites:"★", breaks:"󰒲", brightness:"󰃠", displays:"󰍹", typography:"Aa", bluetooth:"󰂯", notifications:"󰂚", extras:"󰇘"})[action] || "";
    }

    Repeater {
        model: controls.actions
        Item {
            id: entry
            required property string modelData
            objectName: "bar-control-" + modelData
            Layout.alignment: controls.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
            implicitWidth: controls.vertical ? 44 : modelData === "audio" ? volume.implicitWidth : modelData === "battery-level" ? batteryLevel.implicitWidth : glyph.implicitWidth
            implicitHeight: modelData === "audio" ? volume.implicitHeight : modelData === "battery-level" ? batteryLevel.implicitHeight : controls.vertical && modelData === "weather" ? 40 : 28
            Accessible.name: modelData === "battery-level" ? batteryLevel.Accessible.name : controls.labels[modelData]
            Text {
                id: glyph
                anchors.horizontalCenter: parent.horizontalCenter
                y: controls.vertical && entry.modelData === "weather" ? 0 : (parent.height - height) / 2
                visible: !["audio", "battery-level"].includes(entry.modelData)
                text: controls.icon(entry.modelData)
                color: entry.modelData === "keep-awake" && controls.theme.idle.active ? controls.theme.colors.accent : controls.theme.colors.foreground
                font { family: controls.theme.fontFamily; pixelSize: controls.theme.fontSize + (controls.vertical ? 3 : 1); bold: entry.modelData === "typography" }
            }
            Text {
                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                visible: controls.vertical && entry.modelData === "weather"
                text: controls.theme.weather.temperature
                color: controls.theme.colors.muted
                font { family: controls.theme.fontFamily; pixelSize: Math.max(9, controls.theme.fontSize - 3) }
            }
            VolumeIndicator {
                id: volume
                anchors.centerIn: parent
                visible: entry.modelData === "audio"
                theme: controls.theme
                compact: controls.vertical
                percent: controls.theme.volumePercent
                muted: controls.theme.volumeMuted
                available: controls.theme.volumeAvailable
                onClicked: controls.chosen("audio")
            }
            BatteryIndicator {
                id: batteryLevel
                objectName: "bar-battery-indicator"
                anchors.centerIn: parent
                visible: entry.modelData === "battery-level"
                theme: controls.theme
                compact: controls.vertical
                percent: controls.batteryPercent
                charging: controls.charging
                pluggedIn: controls.externalPower
            }
            KeyboardAction {
                id: button
                objectName: "bar-action-" + entry.modelData
                anchors.fill: parent
                visible: entry.modelData !== "audio"
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onActivated: controls.chosen(entry.modelData === "battery-level" ? "battery" : entry.modelData)
            }
        }
    }
    Repeater {
        id: tray
        model: controls.trayItems
        Item {
            id: application
            required property var modelData
            objectName: "bar-tray-application"
            Layout.alignment: controls.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
            implicitWidth: controls.vertical ? 36 : 22
            implicitHeight: 28
            Accessible.name: modelData.title || "Tray application"
            Image { anchors.centerIn: parent; width: 18; height: 18; source: application.modelData.icon; fillMode: Image.PreserveAspectFit }
            KeyboardAction {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onActivated: button => {
                    const point = application.mapToItem(null, application.width, application.height);
                    if (button === Qt.RightButton || application.modelData.onlyMenu)
                        application.modelData.display(controls.panelWindow, point.x, point.y);
                    else application.modelData.activate();
                }
            }
        }
    }
}
