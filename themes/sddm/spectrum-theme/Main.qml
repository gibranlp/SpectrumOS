// themes/sddm/spectrum-theme/Main.qml
import QtQuick 2.11
import QtQuick.Controls 2.4
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080

    property string background: "#1e1e2e"
    property string foreground: "#cdd6f4"
    property string color1: "#f38ba8"
    property string color2: "#a6e3a1"
    property string color3: "#f9e2af"
    property string color4: "#89b4fa"
    property string wallpaperPath: "/home/gibranlp/.cache/wal/wal"

    // Background wallpaper
    Image {
        id: wallpaper
        anchors.fill: parent
        source: "file://" + wallpaperPath
        fillMode: Image.PreserveAspectCrop
        asynchronous: true

        Rectangle {
            anchors.fill: parent
            color: root.background
            opacity: 0.3
        }
    }

    // Clock
    Column {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 80
        spacing: 10

        Text {
            id: timeLabel
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 72
            font.bold: true
            color: root.foreground
            
            function updateTime() {
                text = Qt.formatTime(new Date(), "hh:mm")
            }
        }

        Text {
            id: dateLabel
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 24
            color: root.foreground
            
            function updateDate() {
                text = Qt.formatDate(new Date(), "dddd, MMMM d, yyyy")
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            timeLabel.updateTime()
            dateLabel.updateDate()
        }
    }

    // Login panel
    Rectangle {
        id: loginPanel
        anchors.centerIn: parent
        width: 400
        height: 320
        radius: 20
        color: root.background
        opacity: 0.95

        Column {
            anchors.centerIn: parent
            spacing: 20
            width: parent.width - 60

            Text {
                text: "Welcome to SpectrumOS"
                font.pixelSize: 24
                font.bold: true
                color: root.foreground
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Username
            Rectangle {
                width: parent.width
                height: 50
                radius: 10
                color: "#313244"
                border.color: usernameField.activeFocus ? root.color4 : "transparent"
                border.width: 2

                TextInput {
                    id: usernameField
                    anchors.fill: parent
                    anchors.margins: 15
                    font.pixelSize: 16
                    color: root.foreground
                    text: userModel.lastUser
                    verticalAlignment: TextInput.AlignVCenter
                    
                    Text {
                        anchors.fill: parent
                        text: "Username"
                        font.pixelSize: 16
                        color: "#6c7086"
                        verticalAlignment: Text.AlignVCenter
                        visible: !usernameField.text && !usernameField.activeFocus
                    }
                }
            }

            // Password
            Rectangle {
                width: parent.width
                height: 50
                radius: 10
                color: "#313244"
                border.color: passwordField.activeFocus ? root.color4 : "transparent"
                border.width: 2

                TextInput {
                    id: passwordField
                    anchors.fill: parent
                    anchors.margins: 15
                    font.pixelSize: 16
                    color: root.foreground
                    echoMode: TextInput.Password
                    verticalAlignment: TextInput.AlignVCenter
                    focus: true
                    
                    Keys.onPressed: {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sddm.login(usernameField.text, passwordField.text, sessionCombo.currentIndex)
                        }
                    }
                    
                    Text {
                        anchors.fill: parent
                        text: "Password"
                        font.pixelSize: 16
                        color: "#6c7086"
                        verticalAlignment: Text.AlignVCenter
                        visible: !passwordField.text && !passwordField.activeFocus
                    }
                }
            }

            // Login button
            Rectangle {
                width: parent.width
                height: 50
                radius: 10
                color: loginMouseArea.pressed ? root.color1 : root.color4
                
                Behavior on color {
                    ColorAnimation { duration: 200 }
                }
                
                Text {
                    anchors.centerIn: parent
                    text: "Login"
                    font.pixelSize: 18
                    font.bold: true
                    color: root.background
                }
                
                MouseArea {
                    id: loginMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        sddm.login(usernameField.text, passwordField.text, sessionCombo.currentIndex)
                    }
                }
            }
        }
    }

    // Session selector
    ComboBox {
        id: sessionCombo
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 30
        width: 200
        
        model: sessionModel
        currentIndex: sessionModel.lastIndex
        textRole: "name"
    }

    // Power buttons
    Row {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 30
        spacing: 20

        // Shutdown
        Rectangle {
            width: 50
            height: 50
            radius: 10
            color: shutdownMouseArea.pressed ? root.color1 : root.background
            opacity: 0.9
            
            Text {
                anchors.centerIn: parent
                text: "⏻"
                font.pixelSize: 24
                color: root.foreground
            }
            
            MouseArea {
                id: shutdownMouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: sddm.powerOff()
            }
        }

        // Reboot
        Rectangle {
            width: 50
            height: 50
            radius: 10
            color: rebootMouseArea.pressed ? root.color3 : root.background
            opacity: 0.9
            
            Text {
                anchors.centerIn: parent
                text: "⟳"
                font.pixelSize: 24
                color: root.foreground
            }
            
            MouseArea {
                id: rebootMouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: sddm.reboot()
            }
        }
    }

    Component.onCompleted: {
        if (usernameField.text === "") {
            usernameField.forceActiveFocus()
        } else {
            passwordField.forceActiveFocus()
        }
        timeLabel.updateTime()
        dateLabel.updateDate()
    }
}