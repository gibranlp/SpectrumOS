pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls

Controls.ScrollView {
    id: widget
    required property var theme
    required property var manager
    contentWidth: availableWidth
    clip: true
    ColumnLayout {
        width: widget.availableWidth
        spacing: 10
        Text {
            Layout.fillWidth: true
            text: widget.manager.status
            color: widget.theme.colors.accent
            wrapMode: Text.WordWrap
            font { family: widget.theme.fontFamily; pixelSize: widget.theme.fontSize + 2; bold:true }
        }
        ShellButton {
            Layout.fillWidth: true
            label: widget.manager.settings.enabled ? qsTranslate("Spectrum", "Turn reminders off") : qsTranslate("Spectrum", "Enable break reminders")
            enabled: widget.manager.ready && !widget.manager.busy
            fontFamily: widget.theme.fontFamily
            fontSize: widget.theme.fontSize
            backgroundColor: widget.theme.colors.accent
            foregroundColor: widget.theme.colors.background
            onClicked: widget.manager.configure({enabled: !widget.manager.settings.enabled})
        }
        Repeater {
            model: [{key:"eye_minutes", label:qsTranslate("Spectrum", "Rest your eyes"), elapsed:widget.manager.eyeElapsed},
                    {key:"movement_minutes", label:qsTranslate("Spectrum", "Move and change position"), elapsed:widget.manager.movementElapsed}]
            ColumnLayout {
                id: reminder
                required property var modelData
                Layout.fillWidth: true
                spacing: 8
                Text {
                    Layout.fillWidth:true
                    text: reminder.modelData.label + (widget.manager.settings.enabled ? " · " + widget.manager.minutesLeft(reminder.modelData.elapsed, widget.manager.settings[reminder.modelData.key]) + qsTranslate("Spectrum", " remaining") : "")
                    color: widget.theme.colors.foreground
                    wrapMode: Text.WordWrap
                    font { family:widget.theme.fontFamily; pixelSize:widget.theme.fontSize; bold:true }
                }
                Flow {
                    Layout.fillWidth:true
                    spacing:6
                    Repeater {
                        model: reminder.modelData.key === "eye_minutes" ? [15,20,30] : [30,50,60]
                        ShellButton {
                            required property int modelData
                            label: modelData + qsTranslate("Spectrum", " min")
                            enabled: widget.manager.ready && !widget.manager.busy
                            fontFamily:widget.theme.fontFamily
                            fontSize:widget.theme.fontSize
                            backgroundColor: widget.manager.settings[reminder.modelData.key] === modelData ? widget.theme.colors.accent : widget.theme.colors.surface_alt
                            foregroundColor: widget.manager.settings[reminder.modelData.key] === modelData ? widget.theme.colors.background : widget.theme.colors.foreground
                            onClicked: { const change = {}; change[reminder.modelData.key] = modelData; widget.manager.configure(change); }
                        }
                    }
                }
            }
        }
        ShellButton {
            Layout.fillWidth: true
            label: qsTranslate("Spectrum", "Snooze 10 minutes")
            enabled: widget.manager.settings.enabled
            fontFamily: widget.theme.fontFamily
            fontSize: widget.theme.fontSize
            backgroundColor: widget.theme.colors.surface_alt
            foregroundColor: widget.theme.colors.foreground
            onClicked: widget.manager.snooze()
        }
        Text {
            Layout.fillWidth:true
            text: qsTranslate("Spectrum", widget.manager.error) || qsTranslate("Spectrum", "A three-minute break follows each reminder, then the timer starts again. Games, calls and Do Not Disturb pause reminders.")
            color:widget.manager.error ? "#f38ba8" : widget.theme.colors.muted
            wrapMode:Text.WordWrap
            font { family:widget.theme.fontFamily; pixelSize:widget.theme.fontSize - 1 }
        }
    }
}
