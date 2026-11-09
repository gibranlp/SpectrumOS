pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: downloads
    required property var theme
    required property string backendDir
    property bool active: false
    property var state: ({installed: true, running: false, rows: []})
    property string error: ""
    property string actionError: ""
    property string message: ""
    property string tab: "search"
    property string category: "all"
    property var results: []
    property var sources: []
    property bool searched: false
    property string searchError: ""
    property string submittedQuery: ""
    readonly property bool searching: searchProcess.running
    readonly property var categories: ["all", "games", "movies", "tv", "anime", "music", "other"]
    readonly property var categoryLabels: [qsTranslate("Spectrum", "All"), qsTranslate("Spectrum", "Games"), qsTranslate("Spectrum", "Movies"), "TV", qsTranslate("Spectrum", "Anime"), qsTranslate("Spectrum", "Music"), qsTranslate("Spectrum", "Other")]
    readonly property var stateLabels: ({Starting: qsTranslate("Spectrum", "Finding peers"), Downloading: qsTranslate("Spectrum", "Downloading"), Seeding: qsTranslate("Spectrum", "Seeding"), Paused: qsTranslate("Spectrum", "Paused"), Done: qsTranslate("Spectrum", "Finished"), Error: qsTranslate("Spectrum", "Error")})
    property string lastAction: ""
    property string submittedMagnet: ""
    property var queuedMagnets: []
    property string pendingRemoval: ""
    readonly property bool busy: backend.running
    spacing: 12

    function command(args): void {
        if (backend.running) return;
        lastAction = args[0];
        if (lastAction !== "status") { actionError = ""; message = ""; }
        if (lastAction === "add") submittedMagnet = args[1];
        backend.exec([backendDir + "/magnet-adapter"].concat(args));
    }
    function search(): void {
        if (searching) return;
        searchError = "";
        message = "";
        searched = true;
        results = [];
        sources = [];
        submittedQuery = query.text.trim();
        searchProcess.exec([backendDir + "/magnet-adapter", "search", submittedQuery, category]);
    }
    function download(magnet, name): void { command(["add", magnet, name || ""]); }
    function isMagnet(value): bool { return /^magnet:\?/i.test(value.trim()) || /^[a-fA-F0-9]{40}$|^[A-Za-z2-7]{32}$/.test(value.trim()); }
    function bytes(value): string {
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let index = 0;
        value = Math.max(0, Number(value) || 0);
        while (value >= 1024 && index < units.length - 1) { value /= 1024; index++; }
        return value.toFixed(index ? 1 : 0) + " " + units[index];
    }
    onActiveChanged: {
        pendingRemoval = "";
        if (active) { command(["status"]); Qt.callLater(() => query.forceActiveFocus()); }
    }
    Component.onCompleted: if (active) command(["status"])
    Process {
        id: backend
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(text);
                    const error = response.ok ? "" : response.error || qsTranslate("Spectrum", "Could not contact Magnet");
                    if (downloads.lastAction === "status") downloads.error = error;
                    else downloads.actionError = error;
                    if (response.ok && response.rows !== undefined) downloads.state = response;
                    if (response.ok && downloads.lastAction === "add") {
                        downloads.queuedMagnets = downloads.queuedMagnets.concat([downloads.submittedMagnet]);
                        downloads.message = qsTranslate("Spectrum", "Download added. It will continue in the background.");
                        downloads.tab = "downloads";
                    }
                } catch (exception) { downloads.error = qsTranslate("Spectrum", "Invalid response from Magnet"); }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                if (downloads.lastAction === "status" && !downloads.error) downloads.error = qsTranslate("Spectrum", "Could not contact Magnet");
                else if (downloads.lastAction !== "status" && !downloads.actionError) downloads.actionError = qsTranslate("Spectrum", "Could not contact Magnet");
            }
            if (downloads.lastAction !== "status" && downloads.active) Qt.callLater(() => downloads.command(["status"]));
        }
    }
    Process {
        id: searchProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(text);
                    downloads.searchError = response.ok ? "" : response.error || qsTranslate("Spectrum", "Search failed");
                    downloads.results = response.ok ? response.results || [] : [];
                    downloads.sources = response.ok ? response.sources || [] : [];
                } catch (exception) { downloads.searchError = qsTranslate("Spectrum", "Invalid search response from Magnet"); }
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && !downloads.searchError) downloads.searchError = qsTranslate("Spectrum", "Search failed");
        }
    }
    Timer { interval: 2000; repeat: true; running: downloads.active; onTriggered: downloads.command(["status"]) }
    RowLayout {
        Layout.fillWidth: true
        ShellButton {
            objectName: "magnet-search-tab"
            label: qsTranslate("Spectrum", "Search")
            fontFamily: downloads.theme.fontFamily
            fontSize: downloads.theme.fontSize
            backgroundColor: downloads.tab === "search" ? downloads.theme.colors.accent : downloads.theme.colors.surface_alt
            foregroundColor: downloads.tab === "search" ? downloads.theme.colors.background : downloads.theme.colors.foreground
            onClicked: { downloads.tab = "search"; query.forceActiveFocus(); }
        }
        ShellButton {
            objectName: "magnet-downloads-tab"
            label: qsTranslate("Spectrum", "Downloads") + " (" + (downloads.state.rows || []).length + ")"
            fontFamily: downloads.theme.fontFamily
            fontSize: downloads.theme.fontSize
            backgroundColor: downloads.tab === "downloads" ? downloads.theme.colors.accent : downloads.theme.colors.surface_alt
            foregroundColor: downloads.tab === "downloads" ? downloads.theme.colors.background : downloads.theme.colors.foreground
            onClicked: { downloads.tab = "downloads"; downloads.command(["status"]); }
        }
        Item { Layout.fillWidth: true }
        ShellButton {
            label: qsTranslate("Spectrum", "Open terminal")
            fontFamily: downloads.theme.fontFamily
            fontSize: downloads.theme.fontSize
            backgroundColor: downloads.theme.colors.surface_alt
            foregroundColor: downloads.theme.colors.foreground
            onClicked: ApplicationLaunch.start([downloads.backendDir + "/magnet-open"])
        }
    }
    RowLayout {
        visible: downloads.tab === "search"
        Layout.fillWidth: true
        Controls.TextField {
            id: query
            objectName: "magnet-query"
            Layout.fillWidth: true
            selectByMouse: true
            placeholderText: qsTranslate("Spectrum", "Search torrents or paste a magnet link")
            color: downloads.theme.colors.foreground
            placeholderTextColor: downloads.theme.colors.muted
            selectionColor: downloads.theme.colors.accent
            selectedTextColor: downloads.theme.colors.background
            font { family: downloads.theme.fontFamily; pixelSize: downloads.theme.fontSize }
            background: Rectangle { color: downloads.theme.colors.surface_alt; radius: 8; border.width: query.activeFocus ? 1 : 0; border.color: downloads.theme.colors.accent }
            onAccepted: { if (downloads.isMagnet(text)) downloads.download(text); else downloads.search(); }
        }
        ShellButton {
            objectName: "magnet-search-submit"
            label: downloads.isMagnet(query.text) ? qsTranslate("Spectrum", "Download") : downloads.searching ? qsTranslate("Spectrum", "Searching…") : qsTranslate("Spectrum", "Search")
            enabled: downloads.isMagnet(query.text) ? !downloads.busy : !downloads.searching
            fontFamily: downloads.theme.fontFamily
            fontSize: downloads.theme.fontSize
            backgroundColor: downloads.theme.colors.accent
            foregroundColor: downloads.theme.colors.background
            onClicked: { if (downloads.isMagnet(query.text)) downloads.download(query.text); else downloads.search(); }
        }
    }
    ShellButton {
        objectName: "magnet-top100"
        visible: downloads.tab === "search"
        label: qsTranslate("Spectrum", "Top 100")
        enabled: !downloads.searching
        fontFamily: downloads.theme.fontFamily
        fontSize: downloads.theme.fontSize
        backgroundColor: downloads.theme.colors.surface_alt
        foregroundColor: downloads.theme.colors.foreground
        onClicked: { query.text = "top100"; downloads.search(); }
    }
    Flow {
        visible: downloads.tab === "search"
        Layout.fillWidth: true
        spacing: 5
        Repeater {
            model: downloads.categories
            ShellButton {
                required property string modelData
                required property int index
                label: downloads.categoryLabels[index]
                fontFamily: downloads.theme.fontFamily
                fontSize: downloads.theme.fontSize - 1
                backgroundColor: downloads.category === modelData ? downloads.theme.colors.accent : downloads.theme.colors.surface_alt
                foregroundColor: downloads.category === modelData ? downloads.theme.colors.background : downloads.theme.colors.foreground
                enabled: !downloads.searching
                onClicked: {
                    downloads.category = modelData;
                    if (downloads.searched && !downloads.isMagnet(query.text)) downloads.search();
                }
            }
        }
    }
    Text {
        Layout.fillWidth: true
        visible: !!(downloads.actionError || downloads.message || downloads.error)
        text: downloads.actionError || downloads.message || downloads.error
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: downloads.theme.colors.accent
        font { family: downloads.theme.fontFamily; pixelSize: downloads.theme.fontSize }
    }
    Text {
        Layout.fillWidth: true
        visible: downloads.tab === "search"
        text: downloads.searchError || (downloads.searching ? qsTranslate("Spectrum", "Searching sources… This may take up to 45 seconds.") : !downloads.searched ? qsTranslate("Spectrum", "Search here to download without opening the terminal. Leave the search empty to browse, or enter top100.") : downloads.results.length ? downloads.results.length + qsTranslate("Spectrum", " results") : qsTranslate("Spectrum", "No results found. Try another search or category."))
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: downloads.theme.colors.muted
        font { family: downloads.theme.fontFamily; pixelSize: downloads.theme.fontSize - 1 }
    }
    Text {
        Layout.fillWidth: true
        visible: downloads.tab === "search" && downloads.sources.some(source => !source.ok)
        text: qsTranslate("Spectrum", "Unavailable sources: ") + downloads.sources.filter(source => !source.ok).map(source => source.source).join(", ")
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: downloads.theme.colors.muted
        font { family: downloads.theme.fontFamily; pixelSize: downloads.theme.fontSize - 1 }
    }
    ListView {
        id: resultList
        objectName: "magnet-search-results"
        visible: downloads.tab === "search"
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 8
        model: downloads.results
        Controls.ScrollBar.vertical: Controls.ScrollBar {}
        delegate: Rectangle {
            id: resultRow
            required property var modelData
            width: resultList.width
            implicitHeight: resultBody.implicitHeight + 24
            radius: 12
            color: downloads.theme.colors.surface_alt
            ColumnLayout {
                id: resultBody
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: resultRow.modelData.name
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: downloads.theme.colors.foreground
                    font { family: downloads.theme.fontFamily; pixelSize: downloads.theme.fontSize; bold: true }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: downloads.bytes(resultRow.modelData.sizeBytes) + " · " + resultRow.modelData.seeders + qsTranslate("Spectrum", " seeders") + " · " + resultRow.modelData.source
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        color: downloads.theme.colors.muted
                        font { family: downloads.theme.fontFamily; pixelSize: downloads.theme.fontSize - 1 }
                    }
                    ShellButton {
                        objectName: "magnet-result-download"
                        readonly property bool queued: downloads.queuedMagnets.includes(resultRow.modelData.magnet)
                        label: queued ? qsTranslate("Spectrum", "Added") : qsTranslate("Spectrum", "Download")
                        enabled: !downloads.busy && !!resultRow.modelData.magnet
                        fontFamily: downloads.theme.fontFamily
                        fontSize: downloads.theme.fontSize
                        backgroundColor: downloads.theme.colors.accent
                        foregroundColor: downloads.theme.colors.background
                        onClicked: downloads.download(resultRow.modelData.magnet, resultRow.modelData.name)
                    }
                }
            }
        }
    }
    RowLayout {
        visible: downloads.tab === "downloads"
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: !downloads.state.installed ? qsTranslate("Spectrum", "Install Magnet to search and download torrents.") : downloads.state.running ? qsTranslate("Spectrum", "Downloads continue when this panel closes.") : qsTranslate("Spectrum", "The download service is idle. Search to add a download, or resume saved downloads.")
            wrapMode: Text.Wrap
            color: downloads.theme.colors.muted
            font { family: downloads.theme.fontFamily; pixelSize: downloads.theme.fontSize - 1 }
        }
        ShellButton {
            label: downloads.state.running ? qsTranslate("Spectrum", "Refresh") : qsTranslate("Spectrum", "Resume saved")
            enabled: !downloads.busy
            fontFamily: downloads.theme.fontFamily
            fontSize: downloads.theme.fontSize
            backgroundColor: downloads.theme.colors.surface_alt
            foregroundColor: downloads.theme.colors.foreground
            onClicked: downloads.command([downloads.state.running ? "status" : "start"])
        }
    }
    Controls.ScrollView {
        visible: downloads.tab === "downloads"
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: parent.width
            spacing: 10
            Repeater {
                model: downloads.state.rows || []
                Rectangle {
                    id: row
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: body.implicitHeight + 24
                    radius: 12
                    color: downloads.theme.colors.surface_alt
                    ColumnLayout {
                        id: body
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 8
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            color: downloads.theme.colors.foreground
                            font { family: downloads.theme.fontFamily; pixelSize: downloads.theme.fontSize; bold: true }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 5
                            radius: 2
                            color: downloads.theme.colors.background
                            Rectangle {
                                width: parent.width * Math.min(1, Math.max(0, row.modelData.total ? row.modelData.done / row.modelData.total : 0))
                                height: parent.height
                                radius: 2
                                color: downloads.theme.colors.accent
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: (downloads.stateLabels[row.modelData.state] || row.modelData.state) + " · " + downloads.bytes(row.modelData.done) + " / " + downloads.bytes(row.modelData.total) + " · ↓ " + downloads.bytes(row.modelData.down) + "/s" + (row.modelData.eta ? " · " + Math.ceil(row.modelData.eta / 60) + qsTranslate("Spectrum", " min remaining") : "")
                            wrapMode: Text.Wrap
                            color: downloads.theme.colors.muted
                            font { family: downloads.theme.fontFamily; pixelSize: downloads.theme.fontSize - 1 }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: !!row.modelData.error
                            text: row.modelData.error || ""
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            color: downloads.theme.colors.accent
                            font { family: downloads.theme.fontFamily; pixelSize: downloads.theme.fontSize - 1 }
                        }
                        RowLayout {
                            ShellButton {
                                label: ["Paused", "Done"].includes(row.modelData.state) ? qsTranslate("Spectrum", "Resume") : qsTranslate("Spectrum", "Pause")
                                enabled: !downloads.busy && row.modelData.state !== "Starting" && row.modelData.state !== "Error"
                                fontFamily: downloads.theme.fontFamily
                                fontSize: downloads.theme.fontSize
                                backgroundColor: downloads.theme.colors.background
                                foregroundColor: downloads.theme.colors.foreground
                                onClicked: downloads.command(["toggle", String(row.modelData.id)])
                            }
                            ShellButton {
                                label: qsTranslate("Spectrum", "Open folder")
                                fontFamily: downloads.theme.fontFamily
                                fontSize: downloads.theme.fontSize
                                backgroundColor: downloads.theme.colors.background
                                foregroundColor: downloads.theme.colors.foreground
                                onClicked: ApplicationLaunch.start(["uwsm", "app", "--", "xdg-open", row.modelData.folder])
                            }
                            ShellButton {
                                objectName: "magnet-remove"
                                label: downloads.pendingRemoval === row.modelData.info_hash ? qsTranslate("Spectrum", "Confirm removal") : qsTranslate("Spectrum", "Remove")
                                enabled: !downloads.busy
                                fontFamily: downloads.theme.fontFamily
                                fontSize: downloads.theme.fontSize
                                backgroundColor: downloads.theme.colors.background
                                foregroundColor: downloads.theme.colors.foreground
                                onClicked: {
                                    if (downloads.pendingRemoval === row.modelData.info_hash) {
                                        downloads.command(["remove", String(row.modelData.id)]);
                                        downloads.pendingRemoval = "";
                                    } else downloads.pendingRemoval = row.modelData.info_hash;
                                }
                            }
                        }
                        ShellButton {
                            objectName: "magnet-delete-files"
                            label: downloads.pendingRemoval === "delete:" + row.modelData.info_hash ? qsTranslate("Spectrum", "Confirm file deletion") : qsTranslate("Spectrum", "Delete files")
                            enabled: !downloads.busy
                            fontFamily: downloads.theme.fontFamily
                            fontSize: downloads.theme.fontSize
                            backgroundColor: downloads.theme.colors.background
                            foregroundColor: downloads.theme.colors.foreground
                            onClicked: {
                                const key = "delete:" + row.modelData.info_hash;
                                if (downloads.pendingRemoval === key) {
                                    downloads.command(["delete", String(row.modelData.id)]);
                                    downloads.pendingRemoval = "";
                                } else downloads.pendingRemoval = key;
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: downloads.pendingRemoval === "delete:" + row.modelData.info_hash
                            text: qsTranslate("Spectrum", "This permanently deletes the downloaded files and removes the download.")
                            wrapMode: Text.Wrap
                            color: downloads.theme.colors.muted
                            font { family: downloads.theme.fontFamily; pixelSize: downloads.theme.fontSize - 1 }
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: (downloads.state.rows || []).length === 0 && downloads.state.running
                text: qsTranslate("Spectrum", "No downloads yet. Use the Search tab to add one.")
                wrapMode: Text.Wrap
                color: downloads.theme.colors.muted
                font { family: downloads.theme.fontFamily; pixelSize: downloads.theme.fontSize }
            }
        }
    }
    Text {
        Layout.fillWidth: true
        visible: downloads.tab === "downloads"
        text: qsTranslate("Spectrum", "Removing a download keeps its files.")
        color: downloads.theme.colors.muted
        font { family: downloads.theme.fontFamily; pixelSize: downloads.theme.fontSize - 1 }
    }
}
