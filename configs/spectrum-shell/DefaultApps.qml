pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell.Io

ColumnLayout {
    id: widget
    required property var theme
    required property string backendDir
    property bool active: false
    property bool byType: false
    property string group: "video"
    property var groups: []
    property var fileTypes: []
    property var apps: []
    property var defaults: []
    property var selected: ({types: []})
    property string error: ""
    property string message: ""
    property bool inFlight: false
    property var pending: null
    property var requested: ({})
    property string requestedAction: "status"
    readonly property bool busy: inFlight || backend.running || pending !== null || filterDelay.running
    readonly property var filteredTypes: fileTypes.filter(type =>
        (type.id + " " + type.name + " " + type.extensions.join(" ")).toLowerCase().includes(search.text.trim().toLowerCase())).slice(0, 200)
    readonly property string chosenApp: appChoice.currentIndex >= 0 && apps[appChoice.currentIndex] ? apps[appChoice.currentIndex].id : ""
    readonly property bool selectionMatches: byType ? !!options() && selected.mime === options().mime : selected.group === group
    readonly property bool unchanged: defaults.length > 0 && defaults.every(item => item.desktop === chosenApp)
    spacing: 10

    function options(): var {
        if (byType) {
            const type = filteredTypes[typeChoice.currentIndex];
            return type ? {mime: type.id} : null;
        }
        return {group: group};
    }
    function command(action, request): void {
        if (!request) return;
        if (inFlight || backend.running) {
            if (action === "status") pending = request;
            return;
        }
        error = "";
        if (action === "set") message = "";
        requested = request;
        requestedAction = action;
        inFlight = true;
        backend.exec([backendDir + "/default-apps-adapter", action, JSON.stringify(request)]);
    }
    function refresh(): void {
        const request = options();
        if (request) { request.catalogue = fileTypes.length === 0; command("status", request); }
    }
    onActiveChanged: if (active) refresh()
    Component.onCompleted: if (active && !busy) refresh()
    Process {
        id: backend
        onExited: Qt.callLater(() => {
            widget.inFlight = false;
            if (widget.pending) {
                const request = widget.pending;
                widget.pending = null;
                widget.command("status", request);
            }
        })
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    if (!result.ok) { widget.error = result.error || "Could not read default applications."; return; }
                    const oldChoice = widget.chosenApp;
                    const same = JSON.stringify(widget.selected) === JSON.stringify(result.selection);
                    if (result.groups) widget.groups = result.groups;
                    if (result.file_types) widget.fileTypes = result.file_types;
                    widget.selected = result.selection;
                    widget.defaults = result.defaults || [];
                    widget.apps = result.apps || [];
                    const current = widget.defaults.length && widget.defaults.every(item => item.desktop === widget.defaults[0].desktop)
                        ? widget.defaults[0].desktop : "";
                    const preferred = same && oldChoice ? oldChoice : current;
                    appChoice.currentIndex = widget.apps.findIndex(app => app.id === preferred);
                    widget.message = result.message || "";
                } catch (error) { widget.error = qsTranslate("Spectrum", "Could not read the default applications response."); }
            }
        }
    }
    Timer {
        interval: 1000
        running: widget.inFlight && !backend.running
        onTriggered: {
            widget.inFlight = false;
            widget.pending = null;
            widget.error = qsTranslate("Spectrum", "Could not start the default applications helper.");
        }
    }
    Timer { id: filterDelay; interval: 220; onTriggered: { typeChoice.currentIndex = 0; widget.refresh(); } }
    Text {
        textFormat: Text.PlainText
        Layout.fillWidth: true
        text: qsTranslate("Spectrum", "Choose what opens your links and files.")
        color: widget.theme.colors.muted
        font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize }
    }
    RowLayout {
        Layout.fillWidth: true
        Repeater {
            model: ["Common defaults", "File types"]
            ShellButton {
                required property int index
                required property string modelData
                Layout.fillWidth: true
                label: qsTranslate("Spectrum", modelData)
                enabled: !widget.busy
                fontFamily: widget.theme.fontFamily
                fontSize: widget.theme.fontSize
                backgroundColor: widget.byType === (index === 1) ? widget.theme.colors.accent : widget.theme.colors.surface_alt
                foregroundColor: widget.byType === (index === 1) ? widget.theme.colors.background : widget.theme.colors.foreground
                onClicked: {
                    widget.byType = index === 1;
                    widget.message = "";
                    typeChoice.currentIndex = 0;
                    widget.refresh();
                }
            }
        }
        ShellButton {
            label: widget.busy ? "…" : "↻"
            enabled: !widget.busy
            fontFamily: widget.theme.fontFamily
            fontSize: widget.theme.fontSize
            backgroundColor: widget.theme.colors.surface_alt
            foregroundColor: widget.theme.colors.foreground
            onClicked: { const request = widget.options(); if (request) { request.catalogue = true; widget.command("status", request); } }
        }
    }
    FocusChoice {
        Layout.fillWidth: true
        visible: !widget.byType
        theme: widget.theme
        translateModel: true
        model: widget.groups.map(group => group.name)
        currentIndex: widget.groups.findIndex(group => group.id === widget.group)
        enabled: !widget.busy
        onActivated: { widget.group = widget.groups[currentIndex].id; widget.refresh(); }
    }
    Controls.TextField {
        id: search
        objectName: "default-apps-search"
        visible: widget.byType
        Layout.fillWidth: true
        placeholderText: qsTranslate("Spectrum", "Search a type or extension: MKV, .mp4, PDF…")
        color: widget.theme.colors.foreground
        placeholderTextColor: widget.theme.colors.muted
        font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize }
        selectByMouse: true
        background: Rectangle { radius: 8; color: widget.theme.colors.surface_alt }
        onTextChanged: if (widget.byType) filterDelay.restart()
    }
    FocusChoice {
        id: typeChoice
        visible: widget.byType
        Layout.fillWidth: true
        theme: widget.theme
        model: widget.filteredTypes.map(type => type.name + " · " + type.id)
        enabled: !widget.busy && widget.filteredTypes.length > 0
        displayText: widget.filteredTypes.length ? currentText : qsTranslate("Spectrum", "No matching file types")
        onActivated: widget.refresh()
    }
    Text {
        textFormat: Text.PlainText
        Layout.fillWidth: true
        text: widget.busy ? qsTranslate("Spectrum", "Reading applications…") : qsTranslate("Spectrum", "CURRENT DEFAULTS")
        color: widget.theme.colors.accent
        font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize; bold: true }
    }
    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 80
        clip: true
        spacing: 5
        model: widget.selectionMatches ? widget.defaults : []
        boundsBehavior: Flickable.StopAtBounds
        delegate: RowLayout {
            required property var modelData
            width: ListView.view.width
            height: Math.max(30, mimeLabel.implicitHeight)
            Text {
                textFormat: Text.PlainText
                id: mimeLabel
                Layout.fillWidth: true
                text: modelData.mime
                color: widget.theme.colors.muted
                wrapMode: Text.WrapAnywhere
                font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 1 }
            }
            Text {
                textFormat: Text.PlainText
                Layout.preferredWidth: Math.min(240, widget.width * 0.45)
                text: modelData.name
                color: widget.theme.colors.foreground
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize }
            }
        }
        Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
    }
    Text {
        textFormat: Text.PlainText
        text: qsTranslate("Spectrum", "OPEN WITH")
        color: widget.theme.colors.accent
        font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize; bold: true }
    }
    FocusChoice {
        id: appChoice
        objectName: "default-apps-application"
        Layout.fillWidth: true
        theme: widget.theme
        model: widget.apps.map(app => app.name + " · " + app.id)
        enabled: !widget.busy && widget.selectionMatches && widget.apps.length > 0
        currentIndex: -1
        displayText: widget.chosenApp ? currentText : widget.apps.length ? qsTranslate("Spectrum", "Choose an application") : qsTranslate("Spectrum", "No compatible applications found")
    }
    Text {
        textFormat: Text.PlainText
        Layout.fillWidth: true
        visible: !widget.busy && !widget.apps.length && widget.defaults.length > 1
        text: qsTranslate("Spectrum", "No app declares support for every format here. Use File types to choose one format at a time.")
        wrapMode: Text.WordWrap
        color: widget.theme.colors.muted
        font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize - 1 }
    }
    Text {
        textFormat: Text.PlainText
        Layout.fillWidth: true
        visible: !!widget.error || !!widget.message
        text: qsTranslate("Spectrum", widget.error) || widget.message
        wrapMode: Text.WordWrap
        color: widget.error ? widget.theme.colors.accent : widget.theme.colors.foreground
        font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize }
    }
    ShellButton {
        Layout.fillWidth: true
        objectName: "default-apps-apply"
        label: widget.busy ? qsTranslate("Spectrum", "Working…") : widget.unchanged ? qsTranslate("Spectrum", "Already selected") : qsTranslate("Spectrum", "Apply to ") + widget.defaults.length + (widget.defaults.length === 1 ? qsTranslate("Spectrum", " file type") : qsTranslate("Spectrum", " file types"))
        enabled: !widget.busy && widget.selectionMatches && !!widget.chosenApp && widget.defaults.length > 0 && !widget.unchanged
        fontFamily: widget.theme.fontFamily
        fontSize: widget.theme.fontSize
        backgroundColor: widget.theme.colors.accent
        foregroundColor: widget.theme.colors.background
        onClicked: {
            const request = widget.options();
            if (request) { request.desktop = widget.chosenApp; widget.command("set", request); }
        }
    }
}
