pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import Qt.labs.folderlistmodel

Rectangle {
    id: picker
    required property var theme
    property bool folderMode: false
    property string peerName: ""
    property int fontSize: 12
    property url homeFolder: localUrl(StandardPaths.writableLocation(StandardPaths.HomeLocation))
    property url currentFolder: homeFolder
    property var selectedUrls: []
    property string error: ""
    readonly property int entryCount: entries.count
    readonly property int folderStatus: entries.status
    signal cancelled()
    signal chosen(var paths)
    color: theme.colors.surface
    radius: 12
    focus: visible

    function localUrl(path) {
        const value = path.toString();
        return value.startsWith("file://") ? value : "file://" + value.split("/").map(encodeURIComponent).join("/");
    }
    function open(folder) {
        selectedUrls = [];
        error = "";
        query.text = "";
        currentFolder = folder || homeFolder;
        Qt.callLater(() => picker.forceActiveFocus());
    }
    function navigate(folder) {
        currentFolder = folder;
        query.text = "";
        files.currentIndex = -1;
    }
    function chooseEntry(index) {
        if (index < 0 || index >= entries.count) return;
        const url = entries.get(index, "fileUrl").toString();
        if (entries.isFolder(index)) { navigate(url); return; }
        const previous = selectedUrls.indexOf(url);
        if (previous >= 0) selectedUrls = selectedUrls.filter(value => value !== url);
        else if (selectedUrls.length < 64) selectedUrls = selectedUrls.concat([url]);
        else error = "Select up to 64 files per transfer.";
    }
    function submit() {
        if (folderMode && entries.status === FolderListModel.Ready) chosen([currentFolder.toString()]);
        else if (!folderMode && selectedUrls.length) chosen(selectedUrls.slice());
    }
    Shortcut { sequence: "Escape"; enabled: picker.visible; onActivated: picker.cancelled() }
    MouseArea { anchors.fill: parent }
    FolderListModel {
        id: entries
        folder: picker.currentFolder
        showDotAndDotDot: false
        showHidden: false
        showFiles: !picker.folderMode
        showDirsFirst: true
        nameFilters: query.text ? ["*" + query.text + "*"] : ["*"]
        caseSensitive: false
    }
    component Label: Text {
        color: picker.theme.colors.foreground
        textFormat: Text.PlainText
        font { family: picker.theme.fontFamily; pixelSize: picker.fontSize }
        elide: Text.ElideMiddle
        maximumLineCount: 1
    }
    component Action: Button {
        id: action
        property bool prominent: false
        implicitHeight: 34
        implicitWidth: Math.max(60, contentItem.implicitWidth + 24)
        contentItem: Label {
            text: action.text
            color: action.prominent ? picker.theme.colors.background : picker.theme.colors.foreground
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: action.enabled ? 1 : 0.4
        }
        background: Rectangle {
            radius: 8
            color: action.prominent ? picker.theme.colors.accent : picker.theme.colors.surface_alt
            border.width: action.activeFocus || action.hovered ? 1 : 0
            border.color: picker.theme.colors.accent
            opacity: action.down ? 0.7 : 1
        }
    }
    ColumnLayout {
        anchors { fill: parent; margins: 12 }
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            Label { Layout.fillWidth: true; text: (picker.folderMode ? "SEND FOLDER" : "SEND FILES") + " → " + picker.peerName; color: picker.theme.colors.accent; font.bold: true }
            Action { objectName: "file-picker-cancel"; text: "Cancel"; onClicked: picker.cancelled() }
        }
        RowLayout {
            Layout.fillWidth: true
            Action { text: "Home"; onClicked: picker.navigate(picker.homeFolder) }
            Action { text: "Downloads"; onClicked: picker.navigate(picker.localUrl(StandardPaths.writableLocation(StandardPaths.DownloadLocation))) }
            Action { objectName: "file-picker-up"; text: "Up"; enabled: entries.parentFolder.toString().length > 0; onClicked: picker.navigate(entries.parentFolder) }
            Label { Layout.fillWidth: true; text: decodeURIComponent(picker.currentFolder.toString().replace(/^file:\/\//, "")); color: picker.theme.colors.muted }
        }
        TextField {
            id: query
            objectName: "file-picker-filter"
            Layout.fillWidth: true
            placeholderText: picker.folderMode ? "Find a folder…" : "Find a file…"
            color: picker.theme.colors.foreground
            placeholderTextColor: picker.theme.colors.muted
            font { family: picker.theme.fontFamily; pixelSize: picker.fontSize }
            selectByMouse: true
            background: Rectangle { radius: 8; color: picker.theme.colors.surface_alt; border.width: query.activeFocus ? 1 : 0; border.color: picker.theme.colors.accent }
        }
        ListView {
            id: files
            objectName: "file-picker-list"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: entries
            boundsBehavior: Flickable.StopAtBounds
            Keys.onReturnPressed: picker.chooseEntry(currentIndex)
            Keys.onEnterPressed: picker.chooseEntry(currentIndex)
            Keys.onSpacePressed: picker.chooseEntry(currentIndex)
            delegate: Button {
                id: entry
                required property int index
                required property string fileName
                required property url fileUrl
                required property bool fileIsDir
                readonly property bool marked: picker.selectedUrls.indexOf(fileUrl.toString()) >= 0
                objectName: "file-picker-entry-" + index
                width: files.width
                height: 36
                onClicked: { files.currentIndex = index; picker.chooseEntry(index); }
                background: Rectangle {
                    radius: 8
                    color: picker.theme.colors.surface_alt
                    border.width: entry.marked || entry.activeFocus || entry.hovered ? 1 : 0
                    border.color: picker.theme.colors.accent
                }
                contentItem: RowLayout {
                    spacing: 8
                    Label { text: entry.fileIsDir ? "›" : entry.marked ? "✓" : "□"; color: picker.theme.colors.accent }
                    Label { Layout.fillWidth: true; text: entry.fileName }
                    Label { visible: entry.fileIsDir; text: "Folder"; color: picker.theme.colors.muted }
                }
            }
            Label { anchors.centerIn: parent; width: parent.width; horizontalAlignment: Text.AlignHCenter; visible: files.count === 0; text: entries.status === FolderListModel.Loading ? "Reading folder…" : "No matching entries, or folder unavailable."; color: picker.theme.colors.muted }
        }
        Label { visible: picker.error.length > 0; Layout.fillWidth: true; text: picker.error; color: picker.theme.colors.accent }
        RowLayout {
            Layout.fillWidth: true
            Label { Layout.fillWidth: true; text: picker.folderMode ? "Open a folder, then send this folder." : picker.selectedUrls.length + " selected · click folders to open"; color: picker.theme.colors.muted }
            Action { objectName: "file-picker-send"; text: picker.folderMode ? "Send this folder" : "Send selected"; prominent: true; enabled: picker.folderMode ? entries.status === FolderListModel.Ready : picker.selectedUrls.length > 0; onClicked: picker.submit() }
        }
    }
}
