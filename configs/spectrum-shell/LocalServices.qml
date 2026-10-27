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
    property string kind: "user"
    property var rows: []
    property var available: []
    property string error: ""
    property string message: ""
    property string logs: ""
    property string logId: ""
    property string lastAction: "status"
    property string query: ""
    readonly property bool busy: backend.running
    readonly property var filtered: rows.filter(row => (row.name + " " + row.description + " " + row.ports).toLowerCase().includes(query.toLowerCase()))
    spacing: 10

    function command(action, id): void {
        if (backend.running) return;
        lastAction = action;
        if (action !== "status") { error = ""; message = ""; }
        backend.exec([backendDir + "/local-services-adapter", action, JSON.stringify({kind:kind, id:id || ""})]);
    }
    onActiveChanged: if (active) command("status", "")
    Process {
        id: backend
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    if (!result.ok) { widget.error = result.error || "Could not read local services."; return; }
                    widget.error = "";
                    if (result.logs !== undefined) { widget.logs = result.logs || "No recent log entries."; widget.logId = result.log_id; return; }
                    if (JSON.stringify(widget.rows) !== JSON.stringify(result.rows || [])) widget.rows = result.rows || [];
                    if (JSON.stringify(widget.available) !== JSON.stringify(result.available || [])) widget.available = result.available || [];
                    if (widget.lastAction !== "status") widget.message = qsTranslate("Spectrum", "Updated successfully.");
                } catch (error) { widget.error = qsTranslate("Spectrum", "Could not read the local services response."); }
            }
        }
    }
    Timer { interval:5000; running:widget.active && !widget.logId; repeat:true; onTriggered:widget.command("status", "") }
    RowLayout {
        Layout.fillWidth:true
        Repeater {
            model:[{key:"user",label:qsTranslate("Spectrum", "User services")},{key:"docker",label:"Docker"},{key:"podman",label:"Podman"}]
            ShellButton {
                required property var modelData
                Layout.fillWidth:true
                label:modelData.label
                enabled:!widget.busy
                fontFamily:widget.theme.fontFamily
                fontSize:widget.theme.fontSize
                backgroundColor:widget.kind === modelData.key ? widget.theme.colors.accent : widget.theme.colors.surface_alt
                foregroundColor:widget.kind === modelData.key ? widget.theme.colors.background : widget.theme.colors.foreground
                onClicked: {
                    widget.kind = modelData.key; widget.rows = []; widget.available = [];
                    widget.error = ""; widget.message = ""; widget.logs = ""; widget.logId = "";
                    widget.command("status", "");
                }
            }
        }
        ShellButton {
            label:widget.busy ? "…" : "↻"
            enabled:!widget.busy
            fontFamily:widget.theme.fontFamily
            fontSize:widget.theme.fontSize
            backgroundColor:widget.theme.colors.surface_alt
            foregroundColor:widget.theme.colors.foreground
            onClicked:widget.command(widget.logId ? "logs" : "status", widget.logId)
        }
    }
    RowLayout {
        visible:widget.kind === "user" && !widget.logId
        Layout.fillWidth:true
        FocusChoice {
            id: unitChoice
            Layout.fillWidth:true
            theme:widget.theme
            model:widget.available
            enabled:!widget.busy && widget.available.length > 0
            displayText:widget.available.length ? currentText : qsTranslate("Spectrum", "No additional user services")
        }
        ShellButton {
            label:qsTranslate("Spectrum", "Add")
            enabled:!widget.busy && unitChoice.currentIndex >= 0 && widget.available.length > 0
            fontFamily:widget.theme.fontFamily
            fontSize:widget.theme.fontSize
            backgroundColor:widget.theme.colors.accent
            foregroundColor:widget.theme.colors.background
            onClicked:widget.command("add", unitChoice.currentText)
        }
    }
    Controls.TextField {
        Layout.fillWidth:true
        visible:!widget.logId
        placeholderText:qsTranslate("Spectrum", "Filter services, images or ports")
        color:widget.theme.colors.foreground
        placeholderTextColor:widget.theme.colors.muted
        font { family:widget.theme.fontFamily; pixelSize:widget.theme.fontSize }
        background:Rectangle { color:widget.theme.colors.surface_alt; radius:8 }
        onTextChanged:widget.query = text
    }
    Text {
        Layout.fillWidth:true
        visible:!!widget.error || !!widget.message
        text:qsTranslate("Spectrum", widget.error) || widget.message
        textFormat:Text.PlainText
        color:widget.error ? "#f38ba8" : widget.theme.colors.accent
        wrapMode:Text.WrapAnywhere
        font { family:widget.theme.fontFamily; pixelSize:widget.theme.fontSize - 1 }
    }
    ShellButton {
        visible:!!widget.logId
        label:qsTranslate("Spectrum", "← Back to services")
        fontFamily:widget.theme.fontFamily
        fontSize:widget.theme.fontSize
        backgroundColor:widget.theme.colors.surface_alt
        foregroundColor:widget.theme.colors.foreground
        onClicked: { widget.logs = ""; widget.logId = ""; widget.command("status", ""); }
    }
    Controls.ScrollView {
        id: serviceScroll
        Layout.fillWidth:true
        Layout.fillHeight:true
        contentWidth:availableWidth
        clip:true
        ColumnLayout {
            width:serviceScroll.availableWidth
            spacing:10
            Controls.TextArea {
                Layout.fillWidth:true
                visible:!!widget.logId
                readOnly:true
                selectByMouse:true
                text:widget.logs
                textFormat:TextEdit.PlainText
                wrapMode:TextEdit.WrapAnywhere
                color:widget.theme.colors.foreground
                font { family:widget.theme.fontFamily; pixelSize:widget.theme.fontSize - 1 }
                background:Rectangle { color:widget.theme.colors.background; radius:10 }
            }
            Text {
                Layout.fillWidth:true
                visible:!widget.logId && widget.filtered.length === 0 && !widget.busy && !widget.error
                text:widget.kind === "user" && widget.rows.length === 0 ? qsTranslate("Spectrum", "Add a development user service above to watch it here. System services are managed outside this widget.") : qsTranslate("Spectrum", "No matching services or containers.")
                wrapMode:Text.WordWrap
                color:widget.theme.colors.muted
                font { family:widget.theme.fontFamily; pixelSize:widget.theme.fontSize }
            }
            Repeater {
                model:widget.logId ? [] : widget.filtered
                Rectangle {
                    id: service
                    required property var modelData
                    Layout.fillWidth:true
                    implicitHeight:details.implicitHeight + 24
                    radius:14
                    color:widget.theme.colors.surface_alt
                    ColumnLayout {
                        id:details
                        anchors { left:parent.left; right:parent.right; top:parent.top; margins:12 }
                        spacing:7
                        Text {
                            Layout.fillWidth:true
                            text:service.modelData.name
                            textFormat:Text.PlainText
                            wrapMode:Text.WrapAnywhere
                            color:widget.theme.colors.foreground
                            font { family:widget.theme.fontFamily; pixelSize:widget.theme.fontSize + 1; bold:true }
                        }
                        Text {
                            Layout.fillWidth:true
                            text:[service.modelData.state,service.modelData.detail,service.modelData.description,service.modelData.ports].filter(value => !!value).join(" · ")
                            textFormat:Text.PlainText
                            wrapMode:Text.WrapAnywhere
                            color:widget.theme.colors.muted
                            font { family:widget.theme.fontFamily; pixelSize:widget.theme.fontSize - 1 }
                        }
                        Flow {
                            Layout.fillWidth:true
                            spacing:6
                            Repeater {
                                model:["start","stop","restart","logs"].concat(widget.kind === "user" ? ["remove"] : [])
                                ShellButton {
                                    required property string modelData
                                    label:qsTranslate("Spectrum", modelData.charAt(0).toUpperCase() + modelData.slice(1))
                                    enabled:!widget.busy && (service.modelData.manageable || modelData === "logs" || modelData === "remove")
                                    fontFamily:widget.theme.fontFamily
                                    fontSize:widget.theme.fontSize - 1
                                    backgroundColor:widget.theme.colors.background
                                    foregroundColor:widget.theme.colors.foreground
                                    onClicked:widget.command(modelData, service.modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Text {
        Layout.fillWidth:true
        visible:!widget.logId
        text:qsTranslate("Spectrum", "Local user services and container sockets only. Ports show TCP listeners or container mappings; logs show the latest 80 lines.")
        wrapMode:Text.WordWrap
        color:widget.theme.colors.muted
        font { family:widget.theme.fontFamily; pixelSize:widget.theme.fontSize - 2 }
    }
}
