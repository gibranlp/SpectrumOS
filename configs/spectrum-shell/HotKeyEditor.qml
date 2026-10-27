pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

ColumnLayout {
    id: editor
    required property var theme
    required property var backend
    property string editingId: ""
    property bool showDetails: false
    property bool recordingShortcut: false
    spacing: 12

    function editRule(rule) {
        recordingShortcut = false;
        editingId = rule.id;
        sequence.text = rule.keys;
        interval.text = String(rule.interval_ms);
        shortcut.text = rule.shortcut;
    }
    function clearForm() {
        recordingShortcut = false;
        editingId = "";
        sequence.text = "";
        interval.text = "50";
        shortcut.text = "";
    }
    component Label: Text {
        color: editor.theme.colors.foreground
        font.family: editor.theme.fontFamily
        font.pixelSize: editor.theme.fontSize
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
    component Field: Controls.TextField {
        Layout.fillWidth: true
        implicitHeight: 42
        color: editor.theme.colors.foreground
        placeholderTextColor: editor.theme.colors.muted
        font.family: editor.theme.fontFamily
        font.pixelSize: editor.theme.fontSize
        selectByMouse: true
        background: Rectangle { radius: 8; color: editor.theme.colors.surface_alt; border.width: parent.activeFocus ? 1 : 0; border.color: editor.theme.colors.accent }
    }
    component Button: ShellButton {
        fontFamily: editor.theme.fontFamily
        fontSize: editor.theme.fontSize
        backgroundColor: editor.theme.colors.surface_alt
        foregroundColor: editor.theme.colors.foreground
        enabled: !editor.backend.busy
    }

    component Action: WidgetAction {
        theme: editor.theme
        enabled: !editor.backend.busy
    }
    RowLayout {
        Layout.fillWidth: true
        Label { text: "󰌌"; font.pixelSize: 48; color: editor.theme.colors.accent }
        ColumnLayout {
            Layout.fillWidth: true
            Label { text: qsTranslate("Spectrum", "Repeat your keys"); font.pixelSize: editor.theme.fontSize + 6; font.bold: true }
            Label { text: qsTranslate("Spectrum", "One shortcut to start or stop"); color: editor.theme.colors.muted }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Label { text: qsTranslate("Spectrum", "󰌌  Keys"); Layout.preferredWidth: 130 }
        Field { id: sequence; objectName: "hotkey-sequence"; placeholderText: qsTranslate("Spectrum", "2 or 234"); maximumLength: 256; Accessible.name: qsTranslate("Spectrum", "Key sequence") }
        Controls.ComboBox {
            id: keySelector
            objectName: "hotkey-key-selector"
            model: ["Select key…", "Enter", "Space", "Tab", "Escape", "Backspace", "Delete", "Up", "Down", "Left", "Right", "Home", "End", "PageUp", "PageDown", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"]
            implicitWidth: 150
            implicitHeight: 42
            font.family: editor.theme.fontFamily
            font.pixelSize: editor.theme.fontSize
            background: Rectangle {
                objectName: "hotkey-selector-background"
                radius: 8
                color: editor.theme.colors.surface_alt
                border.width: keySelector.activeFocus || keySelector.popup.visible ? 1 : 0
                border.color: editor.theme.colors.accent
            }
            contentItem: Text {
                objectName: "hotkey-selector-text"
                text: keySelector.currentIndex === 0 ? qsTranslate("Spectrum", "Select key…") : keySelector.displayText
                color: editor.theme.colors.foreground
                font: keySelector.font
                leftPadding: 10
                rightPadding: 26
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            indicator: Text {
                text: "▾"
                color: editor.theme.colors.foreground
                font: keySelector.font
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            }
            delegate: Controls.ItemDelegate {
                id: keyOption
                required property int index
                required property var modelData
                width: keySelector.width
                highlighted: keySelector.highlightedIndex === index
                contentItem: Text {
                    objectName: "hotkey-option-text-" + keyOption.index
                    text: keyOption.modelData
                    color: editor.theme.colors.foreground
                    font: keySelector.font
                }
                background: Rectangle {
                    color: keyOption.highlighted ? editor.theme.colors.surface : editor.theme.colors.surface_alt
                    border.width: keyOption.highlighted ? 1 : 0
                    border.color: editor.theme.colors.accent
                }
            }
            popup: Controls.Popup {
                y: keySelector.height + 4
                width: keySelector.width
                implicitHeight: Math.min(contentItem.implicitHeight + 12, 300)
                padding: 6
                contentItem: ListView {
                    clip: true
                    implicitHeight: contentHeight
                    model: keySelector.popup.visible ? keySelector.delegateModel : null
                    currentIndex: keySelector.highlightedIndex
                    Controls.ScrollIndicator.vertical: Controls.ScrollIndicator {}
                }
                background: Rectangle {
                    objectName: "hotkey-selector-popup-background"
                    radius: 8
                    color: editor.theme.colors.surface_alt
                    border.width: 1
                    border.color: editor.theme.colors.accent
                }
            }
            onActivated: {
                if (currentIndex > 0) sequence.text += "[" + currentText + "]";
                currentIndex = 0;
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Label { text: qsTranslate("Spectrum", "󰥔  Interval"); Layout.preferredWidth: 130 }
        Field { id: interval; objectName: "hotkey-interval"; text: "50"; maximumLength: 5; validator: IntValidator { bottom: 10; top: 60000 } Accessible.name: qsTranslate("Spectrum", "Interval in milliseconds") }
        Label { text: qsTranslate("Spectrum", "ms after sequence"); color: editor.theme.colors.muted }
    }
    RowLayout {
        Layout.fillWidth: true
        Label { text: qsTranslate("Spectrum", "󰌑  Shortcut"); Layout.preferredWidth: 130 }
        Field {
            id: shortcut
            objectName: "hotkey-shortcut"
            placeholderText: editor.recordingShortcut ? qsTranslate("Spectrum", "Press a key or chord…") : qsTranslate("Spectrum", "2 or Ctrl+Shift+2")
            maximumLength: 80
            Accessible.name: qsTranslate("Spectrum", "Toggle shortcut")
            Keys.onPressed: event => {
                const mods = [];
                if (event.modifiers & Qt.ControlModifier) mods.push("Control");
                if (event.modifiers & Qt.ShiftModifier) mods.push("Shift");
                if (event.modifiers & Qt.AltModifier) mods.push("Alt");
                if (event.modifiers & Qt.MetaModifier) mods.push("Super");
                let key = "";
                if (event.key >= Qt.Key_0 && event.key <= Qt.Key_Z) key = String.fromCharCode(event.key);
                else if (event.key >= Qt.Key_F1 && event.key <= Qt.Key_F24) key = "F" + (event.key-Qt.Key_F1+1);
                const named = {32:"Space",16777220:"Enter",16777221:"Enter",16777217:"Tab",16777216:"Escape",16777219:"Backspace",16777223:"Delete",16777234:"Left",16777235:"Up",16777236:"Right",16777237:"Down",16777232:"Home",16777233:"End",16777238:"PageUp",16777239:"PageDown"};
                if (named[event.key]) key = named[event.key];
                const shiftedDigits = {33:"1",64:"2",35:"3",36:"4",37:"5",94:"6",38:"7",42:"8",40:"9",41:"0"};
                if ((event.modifiers & Qt.ShiftModifier) && shiftedDigits[event.key]) key = shiftedDigits[event.key];
                if (key && (editor.recordingShortcut || (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) || (mods.length && event.key >= Qt.Key_F1 && event.key <= Qt.Key_F24))) {
                    text = mods.concat([key]).join("+");
                    editor.recordingShortcut = false;
                    event.accepted = true;
                }
            }
        }
        Button { objectName: "hotkey-record-shortcut"; label: editor.recordingShortcut ? qsTranslate("Spectrum", "Cancel") : qsTranslate("Spectrum", "Record"); onClicked: { editor.recordingShortcut = !editor.recordingShortcut; shortcut.forceActiveFocus(); } }
    }
    RowLayout {
        Layout.fillWidth: true
        Action {
            Layout.fillWidth: true
            objectName: "hotkey-save"
            icon: editor.editingId ? "󰆓" : "󰐕"
            label: editor.editingId ? qsTranslate("Spectrum", "Save") : qsTranslate("Spectrum", "Add")
            hint: editor.editingId ? qsTranslate("Spectrum", "Save changes") : qsTranslate("Spectrum", "Add sequence and register shortcut")
            enabled: !editor.backend.busy && sequence.text.length > 0 && interval.acceptableInput && shortcut.text.length > 0
            onClicked: editor.backend.command(["save", JSON.stringify({id:editor.editingId, keys:sequence.text, interval_ms:Number(interval.text), shortcut:shortcut.text})])
        }
        Action { Layout.fillWidth: true; icon: "󰑓"; label: qsTranslate("Spectrum", "Clear"); hint: qsTranslate("Spectrum", "Clear the form for a new sequence"); onClicked: editor.clearForm() }
        Action { Layout.fillWidth: true; objectName: "hotkey-stop-all"; icon: "󰓛"; label: qsTranslate("Spectrum", "Stop all"); onClicked: editor.backend.command(["stop-all"]) }
    }
    Label { Layout.fillWidth: true; text: qsTranslate("Spectrum", editor.backend.error); visible: text.length > 0; color: editor.theme.colors.accent }
    RowLayout {
        Layout.fillWidth: true
        Label { Layout.fillWidth: true; text: qsTranslate("Spectrum", "󰓛  Ctrl+Alt+Pause stops all"); color: editor.theme.colors.muted }
        Button { label: editor.showDetails ? qsTranslate("Spectrum", "Hide details") : qsTranslate("Spectrum", "Details"); onClicked: editor.showDetails = !editor.showDetails }
    }
    Label { Layout.fillWidth: true; visible: editor.showDetails; text: qsTranslate("Spectrum", "Play all keys, wait the interval, then repeat. Type a shortcut or use Record for a single key or chord. Start closes this widget; release shortcut keys. Sequences start stopped after login."); color: editor.theme.colors.muted }
    Label { Layout.fillWidth: true; visible: editor.showDetails && editor.backend.diagnostics !== undefined; color: editor.theme.colors.muted; text: qsTranslate("Spectrum", "Toggle requests: ") + ((editor.backend.diagnostics || {}).toggle_requests || 0) + qsTranslate("Spectrum", " · Sent presses: ") + ((editor.backend.diagnostics || {}).delivered_keys || 0) }
    Controls.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 80
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: parent.width
            spacing: 8
            Repeater {
                model: editor.backend.rules
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: Math.max(104, rowContent.implicitHeight+20)
                    radius: 8
                    color: editor.theme.colors.surface_alt
                    RowLayout {
                        id: rowContent
                        anchors { fill: parent; margins: 8 }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Label { Layout.fillWidth: true; text: row.modelData.keys; font.pixelSize: editor.theme.fontSize + 8; font.bold: true }
                            Label { Layout.fillWidth: true; text: row.modelData.interval_ms + qsTranslate("Spectrum", " ms · ") + row.modelData.shortcut; color: row.modelData.active ? editor.theme.colors.accent : editor.theme.colors.muted }
                            Label { Layout.fillWidth: true; visible: !!row.modelData.error; text: qsTranslate("Spectrum", row.modelData.error) || ""; color: editor.theme.colors.accent }
                        }
                        Action { objectName: "hotkey-toggle-" + row.modelData.id; implicitWidth: 72; icon: row.modelData.active ? "󰓛" : "󰐊"; active: !!row.modelData.active; label: row.modelData.active ? qsTranslate("Spectrum", "Stop") : qsTranslate("Spectrum", "Start"); onClicked: editor.backend.command(["toggle", row.modelData.id]) }
                        Action { objectName: "hotkey-edit-" + row.modelData.id; implicitWidth: 72; icon: "󰏫"; label: qsTranslate("Spectrum", "Edit"); onClicked: editor.editRule(row.modelData) }
                        Action { objectName: "hotkey-remove-" + row.modelData.id; implicitWidth: 72; icon: "󰆴"; label: qsTranslate("Spectrum", "Remove"); onClicked: editor.backend.command(["remove", row.modelData.id]) }
                    }
                }
            }
            Label { visible: !editor.backend.rules.length; Layout.fillWidth: true; text: qsTranslate("Spectrum", "󰐕  Add your first sequence"); color: editor.theme.colors.muted }
        }
    }
}
