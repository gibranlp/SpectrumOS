import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io

PanelWindow {
    id: launcher

    property var theme
    property bool expanded: false
    property var applicationEntries: []
    property string catalogSnapshot: ""

    function refreshApplications(): void {
        if (!catalog.running) catalog.running = true;
    }

    Timer {
        interval: 2000
        running: launcher.expanded
        repeat: true
        onTriggered: launcher.refreshApplications()
    }

    Process {
        id: catalog
        command: [(Quickshell.env("SPECTRUM_SHELL_BACKEND_DIR") || "/usr/lib/spectrumos") + "/application-adapter", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const entries = JSON.parse(text).applications;
                    if (Array.isArray(entries) && text !== launcher.catalogSnapshot) {
                        launcher.applicationEntries = entries;
                        launcher.catalogSnapshot = text;
                    }
                } catch (error) {
                    console.warn("SpectrumShell application catalog:", error);
                }
            }
        }
    }
    property int leftInset: 0

    visible: motion.active
    color: "transparent"
    WlrLayershell.keyboardFocus: panelFocus.mode
    ShellFocus { id: panelFocus; window: launcher; enabled: expanded }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "spectrum-widget-launcher"
    anchors { top: true; bottom: true; left: true; right: true }

    function toggle(): void {
        expanded = !expanded;
    }

    function launch(entry): void {
        if (!entry)
            return;
        expanded = false;
        ApplicationLaunch.start(["uwsm", "app", "-t", "scope", "--", entry.id + ".desktop"]);
    }

    onExpandedChanged: {
        if (expanded) {
            refreshApplications();
            search.text = "";
            Qt.callLater(() => search.forceActiveFocus());
        } else {
            search.text = "";
        }
    }

    ScriptModel {
        id: filteredApps
        values: {
            const query = search.text.trim().toLocaleLowerCase();
            const items = [...launcher.applicationEntries].filter(entry => entry.name && !entry.noDisplay);
            const matches = query ? items.filter(entry => {
                const fields = [entry.name, entry.genericName, entry.comment, ...(entry.keywords || [])];
                return fields.some(value => (value || "").toLocaleLowerCase().includes(query));
            }) : items;
            matches.sort((left, right) => {
                const leftPrefix = query && left.name.toLocaleLowerCase().startsWith(query);
                const rightPrefix = query && right.name.toLocaleLowerCase().startsWith(query);
                if (leftPrefix !== rightPrefix)
                    return leftPrefix ? -1 : 1;
                return left.name.localeCompare(right.name);
            });
            return matches.slice(0, 80);
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        MouseArea {
            anchors.fill: parent
            onClicked: launcher.expanded = false
        }
    }

    ShellSurface {
        id: frame
        transform: ShellMotion {
            id: motion
            surface: frame
            animationsEnabled: launcher.theme.animationsEnabled !== false
            bounceEnabled: launcher.theme.widgetBounceEnabled !== false
            expanded: launcher.expanded
            edge: "bottom"
            viewportWidth: launcher.screen.width
            viewportHeight: launcher.screen.height
        }
        attachBottom: true
        width: Math.min(680, launcher.screen.width - 40)
        height: Math.min(610, launcher.screen.height - 80)
        x: (launcher.screen.width + launcher.leftInset - width) / 2
        y: launcher.screen.height - height - (launcher.theme.gamingActive ? 0 : 8)

        radius: 32
        color: launcher.theme.colors.surface

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: qsTranslate("Spectrum", "Applications")
                    color: launcher.theme.colors.foreground
                    font { family: launcher.theme.fontFamily; pixelSize: launcher.theme.fontSize + 5; bold: true }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: qsTranslate("Spectrum", "Esc to close")
                    color: launcher.theme.colors.muted
                    font { family: launcher.theme.fontFamily; pixelSize: launcher.theme.fontSize - 2 }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 44
                radius: 10
                color: launcher.theme.colors.background

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    verticalAlignment: Text.AlignVCenter
                    visible: search.text.length === 0
                    text: qsTranslate("Spectrum", "Search applications")
                    color: launcher.theme.colors.muted
                    font { family: launcher.theme.fontFamily; pixelSize: launcher.theme.fontSize }
                }
                TextInput {
                    activeFocusOnTab: true
                    id: search
                    anchors.fill: parent
                    anchors.margins: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: launcher.theme.colors.foreground
                    selectionColor: launcher.theme.colors.accent
                    font { family: launcher.theme.fontFamily; pixelSize: launcher.theme.fontSize }
                    onTextChanged: results.currentIndex = results.count > 0 ? 0 : -1
                    Keys.onEscapePressed: launcher.expanded = false
                    Keys.onDownPressed: results.currentIndex = Math.min(results.count - 1, results.currentIndex + 1)
                    Keys.onUpPressed: results.currentIndex = Math.max(0, results.currentIndex - 1)
                    Keys.onReturnPressed: launcher.launch(results.currentItem ? results.currentItem.entry : null)
                    Keys.onEnterPressed: launcher.launch(results.currentItem ? results.currentItem.entry : null)
                }
            }

            Text {
                text: results.count + (results.count === 1 ? qsTranslate("Spectrum", " application") : qsTranslate("Spectrum", " applications"))
                color: launcher.theme.colors.muted
                font { family: launcher.theme.fontFamily; pixelSize: launcher.theme.fontSize - 2 }
            }

            ListView {
                id: results
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: filteredApps
                onCountChanged: currentIndex = count > 0 ? 0 : -1

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property var entry: modelData
                    width: ListView.view.width
                    height: Math.max(54, launcher.theme.fontSize * 3 + 12)
                    radius: 9
                    color: ListView.isCurrentItem ? launcher.theme.colors.surface_alt : launcher.theme.colors.surface

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 12

                        IconImage {
                            source: Quickshell.iconPath(modelData.icon || "application-x-executable", true)
                            implicitWidth: 30
                            implicitHeight: 30
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                elide: Text.ElideRight
                                color: launcher.theme.colors.foreground
                                font { family: launcher.theme.fontFamily; pixelSize: launcher.theme.fontSize; bold: true }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: [modelData.source || "", modelData.genericName || modelData.comment || qsTranslate("Spectrum", "Application")].filter(value => value).join(" · ")
                                elide: Text.ElideRight
                                color: launcher.theme.colors.muted
                                font { family: launcher.theme.fontFamily; pixelSize: launcher.theme.fontSize - 2 }
                            }
                        }
                    }

                    KeyboardAction {
                        anchors.fill: parent
                        onActivated: launcher.launch(modelData)
                    }
                }
            }
        }
    }

}
