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
        spacing: 14
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
                        model: reminder.modelData.key === "eye_minutes" ? [15,20,30,45] : [30,45,50,60,90]
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
            Layout.fillWidth:true
            label: widget.manager.settings.pause_focus ? qsTranslate("Spectrum", "Pause during Focus · On") : qsTranslate("Spectrum", "Pause during Focus · Off")
            enabled:widget.manager.ready && !widget.manager.busy
            fontFamily:widget.theme.fontFamily
            fontSize:widget.theme.fontSize
            backgroundColor:widget.theme.colors.surface_alt
            foregroundColor:widget.theme.colors.foreground
            onClicked:widget.manager.configure({pause_focus:!widget.manager.settings.pause_focus})
        }
        RowLayout {
            Layout.fillWidth:true
            Repeater {
                model: ["Snooze 10 min", "I took a break"]
                ShellButton {
                    required property int index
                    required property string modelData
                    Layout.fillWidth:true
                    label:modelData
                    enabled:widget.manager.settings.enabled
                    fontFamily:widget.theme.fontFamily
                    fontSize:widget.theme.fontSize
                    backgroundColor:widget.theme.colors.surface_alt
                    foregroundColor:widget.theme.colors.foreground
                    onClicked: { if (index === 0) widget.manager.snooze(); else widget.manager.reset(); }
                }
            }
        }
        Text {
            Layout.fillWidth:true
            text: qsTranslate("Spectrum", widget.manager.error) || qsTranslate("Spectrum", "Games, calls, recording and Do Not Disturb pause reminders. Two minutes away resets the timers. Eye reminders suggest a 20-second distance break; movement reminders suggest changing position. Timers restart when the shell reloads.")
            color:widget.manager.error ? "#f38ba8" : widget.theme.colors.muted
            wrapMode:Text.WordWrap
            font { family:widget.theme.fontFamily; pixelSize:widget.theme.fontSize - 1 }
        }
    }
}
