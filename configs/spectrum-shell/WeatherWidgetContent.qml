import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell.Io

ColumnLayout {
    id: content
    required property var theme
    property bool adding: false
    property var results: []
    property string searchError: ""
    spacing: 9

    Text {
        Layout.fillWidth: true
        text: content.theme.weather.location || qsTranslate("Spectrum", "Current location")
        elide: Text.ElideRight
        color: content.theme.colors.accent
        font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize; bold: true }
    }
    RowLayout {
        visible: !content.adding
        Layout.fillWidth: true
        spacing: 12
        Text {
            Layout.fillWidth: true
            text: (content.theme.weather.icon || "󰖕") + "  " + content.theme.weather.temperature + "\n" + qsTranslate("Weather", content.theme.weather.condition || "")
            elide: Text.ElideRight
            color: content.theme.colors.foreground
            font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize + 4; bold: true }
        }
        ColumnLayout {
            spacing: 2
            Repeater {
                model: [
                    qsTranslate("Spectrum", "Feels like  ") + (content.theme.weather.apparent || "—"),
                    qsTranslate("Spectrum", "Humidity  ") + (content.theme.weather.humidity || "—"),
                    qsTranslate("Spectrum", "Wind  ") + (content.theme.weather.wind || "—")
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
        model: content.adding ? [] : content.theme.weather.days || []
        Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 38
            radius: 8
            color: content.theme.colors.surface_alt
            Text {
                anchors { fill: parent; margins: 9 }
                text: modelData.date + "  " + modelData.icon + "  " + qsTranslate("Weather", modelData.condition) + "     " + modelData.high + " / " + modelData.low
                elide: Text.ElideRight
                color: content.theme.colors.foreground
                font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize - 1 }
            }
        }
    }
    Text {
        visible: !content.adding
        text: qsTranslate("Spectrum", "LOCATIONS")
        color: content.theme.colors.accent
        font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize; bold: true }
    }
    Repeater {
        model: content.adding ? [] : content.theme.weather.locations || []
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
                label: qsTranslate("Spectrum", "Remove")
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
        visible: !content.adding
        Layout.fillWidth: true
        ShellButton {
            label: qsTranslate("Spectrum", "Add location")
            fontFamily: content.theme.fontFamily
            fontSize: content.theme.fontSize
            backgroundColor: content.theme.colors.surface_alt
            foregroundColor: content.theme.colors.foreground
            objectName: "weather-add-location"
            onClicked: { content.adding = true; content.results = []; content.searchError = ""; cityQuery.text = ""; Qt.callLater(() => cityQuery.forceActiveFocus()); }
        }
        ShellButton {
            label: qsTranslate("Spectrum", "Refresh")
            fontFamily: content.theme.fontFamily
            fontSize: content.theme.fontSize
            backgroundColor: content.theme.colors.surface_alt
            foregroundColor: content.theme.colors.foreground
            onClicked: content.theme.runAction([content.theme.backend("weather-adapter"), "--refresh"])
        }
    }
    ColumnLayout {
        visible: content.adding
        Layout.fillWidth: true
        spacing: 9
        Text { text: qsTranslate("Spectrum", "Add weather location"); color: content.theme.colors.accent; font.family: content.theme.fontFamily; font.pixelSize: content.theme.fontSize; font.bold: true }
        Controls.TextField {
            id: cityQuery
            objectName: "weather-city-query"
            Layout.fillWidth: true
            placeholderText: qsTranslate("Spectrum", "City or postal code")
            maximumLength: 200
            enabled: !searchProcess.running && !addProcess.running
            color: content.theme.colors.foreground
            font.family: content.theme.fontFamily
            font.pixelSize: content.theme.fontSize
            background: Rectangle { radius: 8; color: content.theme.colors.surface_alt }
            onAccepted: if (text.trim().length >= 2 && !searchProcess.running) content.searchCity()
        }
        RowLayout {
            ShellButton {
                objectName: "weather-city-search"
                label: searchProcess.running ? qsTranslate("Spectrum", "Searching…") : qsTranslate("Spectrum", "Search")
                enabled: cityQuery.text.trim().length >= 2 && !searchProcess.running && !addProcess.running
                fontFamily: content.theme.fontFamily; fontSize: content.theme.fontSize
                backgroundColor: content.theme.colors.accent; foregroundColor: content.theme.colors.background
                onClicked: content.searchCity()
            }
            ShellButton {
                label: qsTranslate("Spectrum", "Cancel")
                enabled: !addProcess.running
                fontFamily: content.theme.fontFamily; fontSize: content.theme.fontSize
                backgroundColor: content.theme.colors.surface_alt; foregroundColor: content.theme.colors.foreground
                onClicked: { content.adding = false; if (searchProcess.running) searchProcess.signal(15); }
            }
        }
        Text { Layout.fillWidth: true; visible: text.length > 0; text: content.searchError; textFormat: Text.PlainText; wrapMode: Text.Wrap; color: content.theme.colors.muted; font.family: content.theme.fontFamily; font.pixelSize: content.theme.fontSize }
        Repeater {
            model: content.results
            ShellButton {
                required property var modelData
                Layout.fillWidth: true
                label: [modelData.name, modelData.admin1, modelData.country].filter(value => !!value).join(", ")
                enabled: !searchProcess.running && !addProcess.running
                fontFamily: content.theme.fontFamily; fontSize: content.theme.fontSize
                backgroundColor: content.theme.colors.surface_alt; foregroundColor: content.theme.colors.foreground
                onClicked: { content.searchError = ""; addProcess.exec([content.theme.backend("weather-adapter"), "add-location", JSON.stringify(modelData)]); }
            }
        }
    }
    function searchCity(): void {
        results = []; searchError = "";
        searchProcess.exec([theme.backend("weather-adapter"), "search", cityQuery.text.trim()]);
    }
    Process {
        id: searchProcess
        stdout: StdioCollector {
            onStreamFinished: {
                if (!content.adding) return;
                try {
                    const response = JSON.parse(text);
                    content.results = response.ok ? response.results || [] : [];
                    content.searchError = response.ok ? (content.results.length ? "" : qsTranslate("Spectrum", "No cities found. Try another search.")) : response.error;
                } catch (error) { content.searchError = qsTranslate("Spectrum", "City search failed. Try again."); }
            }
        }
    }
    Process {
        id: addProcess
        onExited: code => {
            if (code === 0) { content.adding = false; content.results = []; content.theme.refreshControls("weather"); }
            else content.searchError = qsTranslate("Spectrum", "Could not save this city. Try again.");
        }
    }
}
