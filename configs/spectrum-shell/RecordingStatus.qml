import QtQuick

Item {
    id: status
    property bool screenRecording: false
    property bool audioRecording: false
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 16
    property bool animationsEnabled: true
    signal screenRequested()
    signal audioRequested()
    implicitWidth: contents.implicitWidth
    implicitHeight: 34
    visible: screenRecording || audioRecording

    Row {
        id: contents
        anchors.centerIn: parent
        spacing: 8

        Item {
            objectName: "screenRecordingIcon"
            visible: status.screenRecording
            width: 24
            height: 34
            Accessible.role: Accessible.Button
            Accessible.name: qsTranslate("Spectrum", "Open screen recorder")
            Accessible.onPressAction: status.screenRequested()
            Text {
                anchors.centerIn: parent
                text: ""
                color: "#ff3b30"
                font { family: status.fontFamily; pixelSize: status.fontSize + 2 }
            }
            KeyboardAction {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onActivated: status.screenRequested()
            }
        }
        Item {
            objectName: "audioRecordingIcon"
            visible: status.audioRecording
            width: 24
            height: 34
            Accessible.role: Accessible.Button
            Accessible.name: qsTranslate("Spectrum", "Open audio recorder")
            Accessible.onPressAction: status.audioRequested()
            Text {
                anchors.centerIn: parent
                text: "󰍬"
                color: "#ff3b30"
                font { family: status.fontFamily; pixelSize: status.fontSize + 2 }
            }
            KeyboardAction {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onActivated: status.audioRequested()
            }
        }
        RecordingDot {
            objectName: "recordingStatusDot"
            animationsEnabled: status.animationsEnabled
            anchors.verticalCenter: parent.verticalCenter
            screenRecording: status.screenRecording
            audioRecording: status.audioRecording
        }
    }
}
