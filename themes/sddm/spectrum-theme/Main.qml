// themes/sddm/spectrum-theme/Main.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080

    // Read colors from pywal cache
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
        cache: false

        // Blur overlay
        Rectangle {
            anchors.fill: parent
            color: root.background
            opacity: 0.3
        }
    }

    // Main container
    Item {
        id: mainContainer
        anchors.fill: parent

        // Clock and date
        Column {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 80
            spacing: 10

            Text {
                id: timeLabel
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: 72
                font.weight: Font.Bold
                color: root.foreground
                
                function updateTime() {
                    text = Qt.formatDateTime(new Date(), "hh:mm")
                }
            }

            Text {
                id: dateLabel
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: 24
                color: root.foreground
                
                function updateDate() {
                    text = Qt.formatDateTime(new Date(), "dddd, MMMM d, yyyy")
                }
            }
        }

        // Timer for clock
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
            height: 300
            radius: 20
            color: root.background
            opacity: 0.9

            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width - 60

                // Welcome text
                Text {
                    text: "Welcome to SpectrumOS"
                    font.pixelSize: 24
                    font.weight: Font.Bold
                    color: root.foreground
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // Username field
                TextField {
                    id: usernameField
                    width: parent.width
                    placeholderText: "Username"
                    font.pixelSize: 16
                    color: root.foreground
                    
                    background: Rectangle {
                        radius: 10
                        color: "#313244"
                        border.color: usernameField.activeFocus ? root.color4 : "transparent"
                        border.width: 2
                    }

                    text: userModel.lastUser
                    KeyNavigation.tab: passwordField
                }

                // Password field
                TextField {
                    id: passwordField
                    width: parent.width
                    placeholderText: "Password"
                    font.pixelSize: 16
                    color: root.foreground
                    echoMode: TextInput.Password
                    
                    background: Rectangle {
                        radius: 10
                        color: "#313244"
                        border.color: passwordField.activeFocus ? root.color4 : "transparent"
                        border.width: 2
                    }

                    Keys.onPressed: {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            loginButton.clicked()
                        }
                    }

                    KeyNavigation.tab: loginButton
                }

                // Login button
                Button {
                    id: loginButton
                    text: "Login"
                    width: parent.width
                    height: 50
                    
                    background: Rectangle {
                        radius: 10
                        color: loginButton.down ? root.color1 : root.color4
                        
                        Behavior on color {
                            ColorAnimation { duration: 200 }
                        }
                    }

                    contentItem: Text {
                        text: loginButton.text
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        color: root.background
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        sddm.login(usernameField.text, passwordField.text, sessionCombo.currentIndex)
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

            background: Rectangle {
                radius: 10
                color: root.background
                opacity: 0.9
            }

            contentItem: Text {
                text: sessionCombo.displayText
                color: root.foreground
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
                leftPadding: 10
            }
        }

        // Power buttons
        Row {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: 30
            spacing: 20

            // Shutdown button
            Button {
                width: 50
                height: 50
                
                background: Rectangle {
                    radius: 10
                    color: parent.down ? root.color1 : root.background
                    opacity: 0.9
                }

                contentItem: Text {
                    text: "⏻"
                    font.pixelSize: 24
                    color: root.foreground
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: sddm.powerOff()
            }

            // Reboot button
            Button {
                width: 50
                height: 50
                
                background: Rectangle {
                    radius: 10
                    color: parent.down ? root.color3 : root.background
                    opacity: 0.9
                }

                contentItem: Text {
                    text: "⟳"
                    font.pixelSize: 24
                    color: root.foreground
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: sddm.reboot()
            }
        }
    }

    // Focus password field on start
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