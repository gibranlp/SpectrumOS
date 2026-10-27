pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell.Io

ColumnLayout {
    id: search
    required property var theme
    required property string backendDir
    property bool active: false
    property string root: ""
    property var locations: []
    property var matches: []
    property string error: ""
    property string information: ""
    property bool scopeValid: false
    property bool locationBusy: false
    property bool inFlight: false
    property int revision: 0
    property int submittedRevision: -1
    property int selectedIndex: 0
    signal openRequested(string path)
    signal closeRequested()
    spacing: 9

    function cancelSearch(): void {
        revision += 1;
        delay.stop();
        matches = [];
        selectedIndex = 0;
        information = "";
        if (worker.running) worker.signal(15);
    }
    function refreshSearch(): void {
        cancelSearch();
        if (active && scopeValid && !locationBusy && query.text.trim().length >= 2) delay.restart();
    }
    function loadLocation(value): void {
        if (locationBusy) return;
        cancelSearch();
        scopeValid = false;
        locationBusy = true;
        error = "";
        settings.exec(value === undefined ? [backendDir + "/spectrum-shell-tools", "search-state"]
            : [backendDir + "/spectrum-shell-tools", "search-root", value]);
    }
    function activate(): void {
        query.text = "";
        loadLocation();
        Qt.callLater(() => query.forceActiveFocus());
    }
    onActiveChanged: if (!active) cancelSearch()
    function move(offset): void {
        if (!matches.length) return;
        selectedIndex = Math.max(0, Math.min(matches.length - 1, selectedIndex + offset));
        results.positionViewAtIndex(selectedIndex, ListView.Contain);
    }
    function openSelected(): void {
        if (matches[selectedIndex]) openRequested(matches[selectedIndex]);
    }
    Timer {
        id: delay
        interval: 260
        onTriggered: {
            if (!search.active || !search.scopeValid || search.locationBusy || search.inFlight || query.text.trim().length < 2) return;
            search.submittedRevision = search.revision;
            search.inFlight = true;
            search.error = "";
            worker.exec([search.backendDir + "/spectrum-shell-tools", "search-json",
                JSON.stringify({query: query.text, root: search.root, request_id: search.revision})]);
        }
    }
    Process {
        id: settings
        onExited: Qt.callLater(() => { search.locationBusy = false; search.refreshSearch(); })
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const value = JSON.parse(text);
                    if (value.locations) search.locations = value.locations;
                    if (value.root) { search.root = value.root; folder.text = value.root; }
                    search.scopeValid = value.ok === true;
                    search.error = value.error || "";
                } catch (error) { search.error = qsTranslate("Spectrum", "Could not read the search location."); search.scopeValid = false; }
            }
        }
    }
    Process {
        id: worker
        onStarted: if (!search.active || search.submittedRevision !== search.revision) worker.signal(15)
        onExited: Qt.callLater(() => {
            search.inFlight = false;
            if (search.active && search.submittedRevision !== search.revision && search.scopeValid && !search.locationBusy && query.text.trim().length >= 2) delay.restart();
        })
        stdout: StdioCollector {
            onStreamFinished: {
                if (!search.active || !text.trim()) return;
                try {
                    const value = JSON.parse(text);
                    if (value.request_id !== search.revision) return;
                    search.matches = value.matches || [];
                    search.selectedIndex = 0;
                    search.error = value.error || "";
                    search.information = value.timed_out ? "Search time limit reached. Try a more specific folder."
                        : value.limited ? "Showing the first 60 matches. Refine your search for more."
                        : value.skipped ? "Some folders could not be read." : "";
                    if (search.matches.length) Qt.callLater(() => results.positionViewAtBeginning());
                } catch (error) { search.error = qsTranslate("Spectrum", "Could not read search results."); }
            }
        }
    }
    Timer {
        interval: 1000
        running: search.locationBusy && !settings.running
        onTriggered: { search.locationBusy = false; search.scopeValid = false; search.error = qsTranslate("Spectrum", "Could not start the search location helper."); }
    }
    Timer {
        interval: 1000
        running: search.inFlight && !worker.running
        onTriggered: { search.inFlight = false; search.error = qsTranslate("Spectrum", "Could not start the search helper."); }
    }
    RowLayout {
        Layout.fillWidth: true
        FocusChoice {
            objectName: "search-locations"
            Layout.preferredWidth: Math.min(180, search.width * 0.3)
            theme: search.theme
            model: search.locations.map(location => location.name)
            currentIndex: search.locations.findIndex(location => location.path === search.root)
            displayText: currentIndex >= 0 ? currentText : qsTranslate("Spectrum", "Search in…")
            enabled: !search.locationBusy
            onActivated: search.loadLocation(search.locations[currentIndex].path)
        }
        Controls.TextField {
            id: folder
            objectName: "search-folder"
            Layout.fillWidth: true
            placeholderText: qsTranslate("Spectrum", "Folder path, e.g. /media/Music")
            enabled: !search.locationBusy
            selectByMouse: true
            color: search.theme.colors.foreground
            selectionColor: search.theme.colors.accent
            placeholderTextColor: search.theme.colors.muted
            font { family: search.theme.fontFamily; pixelSize: search.theme.fontSize }
            background: Rectangle { radius: 8; color: search.theme.colors.surface_alt }
            onAccepted: search.loadLocation(text)
            Keys.onEscapePressed: search.closeRequested()
        }
        ShellButton {
            objectName: "search-use-folder"
            label: qsTranslate("Spectrum", "Use")
            enabled: !search.locationBusy && folder.text.trim().length > 0
            fontFamily: search.theme.fontFamily
            fontSize: search.theme.fontSize
            backgroundColor: search.theme.colors.surface_alt
            foregroundColor: search.theme.colors.foreground
            onClicked: search.loadLocation(folder.text)
        }
    }
    Controls.TextField {
        id: query
        objectName: "search-query"
        Layout.fillWidth: true
        implicitHeight: 46
        placeholderText: qsTranslate("Spectrum", "Search files by name")
        selectByMouse: true
        color: search.theme.colors.foreground
        selectionColor: search.theme.colors.accent
        placeholderTextColor: search.theme.colors.muted
        font { family: search.theme.fontFamily; pixelSize: search.theme.fontSize }
        background: Rectangle { radius: 10; color: search.theme.colors.background }
        onTextChanged: search.refreshSearch()
        Keys.onUpPressed: search.move(-1)
        Keys.onDownPressed: search.move(1)
        Keys.onReturnPressed: search.openSelected()
        Keys.onEnterPressed: search.openSelected()
        Keys.onEscapePressed: search.closeRequested()
    }
    ListView {
        id: results
        objectName: "search-results"
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 4
        model: search.matches
        boundsBehavior: Flickable.StopAtBounds
        delegate: Rectangle {
            required property string modelData
            required property int index
            readonly property bool selected: search.selectedIndex === index
            width: ListView.view.width
            height: 48
            radius: 9
            color: selected ? search.theme.colors.accent : action.containsMouse ? search.theme.colors.surface_alt : search.theme.colors.surface
            Text {
                anchors { fill: parent; margins: 10 }
                text: parent.modelData
                textFormat: Text.PlainText
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideMiddle
                color: parent.selected ? search.theme.colors.background : search.theme.colors.foreground
                font { family: search.theme.fontFamily; pixelSize: search.theme.fontSize }
            }
            KeyboardAction { id: action; anchors.fill: parent; hoverEnabled: true; onActivated: search.openRequested(parent.modelData) }
        }
        Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
    }
    Text {
        Layout.fillWidth: true
        text: qsTranslate("Spectrum", search.error) || (search.locationBusy ? qsTranslate("Spectrum", "Reading search location…") : search.inFlight || delay.running ? qsTranslate("Spectrum", "Searching…")
            : query.text.trim().length < 2 ? qsTranslate("Spectrum", "Enter at least two characters") : search.information || (!search.matches.length ? qsTranslate("Spectrum", "No matching files") : ""))
        visible: text.length > 0
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: search.error ? search.theme.colors.accent : search.theme.colors.muted
        font { family: search.theme.fontFamily; pixelSize: search.theme.fontSize - 1 }
    }
}
