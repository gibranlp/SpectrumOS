import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: picker
    required property var theme
    required property string backendDir
    property string requestDir: ""
    property string pendingAnswer: ""
    property var rows: []
    property string prompt: "Select"
    property bool password: false
    property bool expanded: false
    property int selectedIndex: 0
    property var targetScreen: Quickshell.screens[0]
    property var sourceBar: null
    property string anchorContext: ""
    readonly property bool besideWeather: anchorContext === "weather" && !!sourceBar && sourceBar.widgetOpen && sourceBar.widgetPage === "weather"
    readonly property bool weatherOnLeft: besideWeather && sourceBar.weatherPickerBarPosition === "left"
    readonly property var weatherAnchor: besideWeather ? sourceBar.weatherPickerAnchor : Qt.rect(0, 0, 0, 0)
    readonly property var filteredRows: rows.filter(row => row.toLowerCase().includes(query.text.toLowerCase()))

    screen: targetScreen
    visible: motion.active
    WlrLayershell.keyboardFocus: panelFocus.mode
    ShellFocus { id: panelFocus; window: picker; enabled: expanded }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "spectrum-widget-pickerpanel"
    anchors { top: true; bottom: true; left: true; right: true }

    function open(directory): void {
        if (expanded)
            respond("");
        requestDir = directory;
        requestFile.path = directory + "/request.json";
        requestFile.reload();
        query.text = "";
        selectedIndex = 0;
        expanded = true;
        Qt.callLater(() => query.forceActiveFocus());
    }

    function respond(value): void {
        if (!expanded || answerProcess.running)
            return;
        pendingAnswer = value;
        answerProcess.exec([backendDir + "/spectrum-shell-picker", "--answer", requestDir]);
        expanded = false;
    }

    FileView {
        id: requestFile
        onTextChanged: {
            try {
                const request = JSON.parse(text());
                picker.anchorContext = request.anchor || "";
                picker.prompt = request.prompt || "Select";
                picker.password = !!request.password;
                picker.rows = request.rows || [];
            } catch (error) {
                picker.rows = [];
            }
        }
    }

    Process {
        id: answerProcess
        stdinEnabled: true
        onStarted: {
            write(picker.pendingAnswer + "\n");
            picker.pendingAnswer = "";
        }
    }

    MouseArea { anchors.fill: parent; onClicked: picker.respond("") }

    ShellSurface {
        id: card
        transform: ShellMotion {
            id: motion
            surface: card
            expanded: picker.expanded
            animationsEnabled: picker.theme.animationsEnabled !== false
            bounceEnabled: picker.theme.widgetBounceEnabled !== false
            edge: picker.besideWeather ? (picker.weatherOnLeft ? "left" : "top") : "bottom"
            viewportWidth: picker.width
            viewportHeight: picker.height
        }
        Keys.onEscapePressed: picker.respond("")
        width: Math.min(520, picker.besideWeather
            ? Math.max(120, picker.weatherOnLeft ? picker.width - picker.weatherAnchor.x - picker.weatherAnchor.width - 24 : picker.weatherAnchor.x - 24)
            : picker.width - 32)
        height: Math.min(480, picker.height - (picker.besideWeather ? Math.max(16, picker.weatherAnchor.y) + 16 : 32))
        x: picker.besideWeather ? (picker.weatherOnLeft ? picker.weatherAnchor.x + picker.weatherAnchor.width + 12 : picker.weatherAnchor.x - width - 12) : (picker.width - width) / 2
        y: picker.besideWeather ? Math.max(8, Math.min(picker.weatherAnchor.y, picker.height - height - 12)) : picker.height - height - (picker.theme.gamingActive ? 0 : 12)
        radius: 17
        color: picker.theme.colors.surface
        border { color: picker.theme.colors.accent; width: 1 }
        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12
            Text {
                text: picker.prompt
                color: picker.theme.colors.foreground
                font { family: picker.theme.fontFamily; pixelSize: 18; bold: true }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 9
                color: picker.theme.colors.background
                TextInput {
                    activeFocusOnTab: true
                    id: query
                    anchors.fill: parent
                    anchors.margins: 10
                    color: picker.theme.colors.foreground
                    font { family: picker.theme.fontFamily; pixelSize: 15 }
                    echoMode: picker.password ? TextInput.Password : TextInput.Normal
                    onTextChanged: picker.selectedIndex = 0
                    Keys.onEscapePressed: picker.respond("")
                    Keys.onDownPressed: picker.selectedIndex = Math.min(picker.selectedIndex + 1, picker.filteredRows.length - 1)
                    Keys.onUpPressed: picker.selectedIndex = Math.max(0, picker.selectedIndex - 1)
                    Keys.onReturnPressed: picker.respond(picker.password || !picker.filteredRows.length ? text : picker.filteredRows[picker.selectedIndex])
                    Keys.onEnterPressed: picker.respond(picker.password || !picker.filteredRows.length ? text : picker.filteredRows[picker.selectedIndex])
                }
            }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !picker.password
                clip: true
                spacing: 4
                model: picker.filteredRows
                currentIndex: picker.selectedIndex
                highlightMoveDuration: 0
                delegate: Rectangle {
                    required property string modelData
                    required property int index
                    width: ListView.view.width
                    height: 38
                    radius: 8
                    color: index === picker.selectedIndex ? picker.theme.colors.accent : picker.theme.colors.background
                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        text: modelData
                        color: index === picker.selectedIndex ? picker.theme.colors.background : picker.theme.colors.foreground
                        font { family: picker.theme.fontFamily; pixelSize: 13 }
                    }
                    KeyboardAction { anchors.fill: parent; onActivated: picker.respond(modelData) }
                }
            }
        }
    }
}
