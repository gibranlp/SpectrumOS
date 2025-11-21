import QtQuick 2.11
import QtQuick.Layouts 1.11
import QtQuick.Controls 2.4
import QtGraphicalEffects 1.11
import "Components"

Pane {
    id: root

    // Read pywal colors
    QtObject {
        id: colors
        
        function readColor(file, key, defaultVal) {
            var xhr = new XMLHttpRequest();
            xhr.open("GET", file, false);
            xhr.send();
            if (xhr.status === 200) {
                var lines = xhr.responseText.split('\n');
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].indexOf(key + '=') === 0) {
                        return lines[i].split('=')[1];
                    }
                }
            }
            return defaultVal;
        }
        
            property string background: readColor("/var/lib/spectrumos/colors.conf", "background", "#0d1e1e")
            property string foreground: readColor("/var/lib/spectrumos/colors.conf", "foreground", "#c2c6c6")
            property string color1: readColor("/var/lib/spectrumos/colors.conf", "color1", "#9C886B")
            property string color2: readColor("/var/lib/spectrumos/colors.conf", "color2", "#FF0000")
            property string color3: readColor("/var/lib/spectrumos/colors.conf", "color3", "#00FF00")
            property string color4: readColor("/var/lib/spectrumos/colors.conf", "color4", "#8C9092")
            property string color5: readColor("/var/lib/spectrumos/colors.conf", "color5", "#0000FF")
            property string color6: readColor("/var/lib/spectrumos/colors.conf", "color6", "#FF00FF")
            property string color7: readColor("/var/lib/spectrumos/colors.conf", "color7", "#00FFFF")
            property string color8: readColor("/var/lib/spectrumos/colors.conf", "color8", "#FFFF00")
            property string color9: readColor("/var/lib/spectrumos/colors.conf", "color9", "#FFFFFF")
        }


    height: config.ScreenHeight || Screen.height
    width: config.ScreenWidth || Screen.ScreenWidth

    LayoutMirroring.enabled: config.ForceRightToLeft == "true" ? true : Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    padding: config.ScreenPadding
    palette.button: "transparent"
    palette.highlight: colors.color4  
    palette.text: colors.foreground
    palette.buttonText: colors.foreground
    palette.window: colors.background 

    font.family: config.Font
    font.pointSize: config.FontSize !== "" ? config.FontSize : parseInt(height / 80)
    focus: true

    property bool leftleft: config.HaveFormBackground == "true" &&
                            config.PartialBlur == "false" &&
                            config.FormPosition == "left" &&
                            config.BackgroundImageAlignment == "left"

    property bool leftcenter: config.HaveFormBackground == "true" &&
                              config.PartialBlur == "false" &&
                              config.FormPosition == "left" &&
                              config.BackgroundImageAlignment == "center"

    property bool rightright: config.HaveFormBackground == "true" &&
                              config.PartialBlur == "false" &&
                              config.FormPosition == "right" &&
                              config.BackgroundImageAlignment == "right"

    property bool rightcenter: config.HaveFormBackground == "true" &&
                               config.PartialBlur == "false" &&
                               config.FormPosition == "right" &&
                               config.BackgroundImageAlignment == "center"

    Item {
        id: sizeHelper

        anchors.fill: parent
        height: parent.height
        width: parent.width

        ShaderEffectSource {
            id: formBackgroundBlur
            anchors.fill: form
            sourceItem: backgroundImage
            sourceRect: Qt.rect(form.x, form.y, form.width, form.height)
            z: 0
        }

        FastBlur {
            anchors.fill: form
            source: formBackgroundBlur
            radius: 64  // Adjust blur amount
            z: 1
        }

        Rectangle {
            id: formBackground
            anchors.fill: form
            color: colors.background
            opacity: 0.40  // Lower opacity for glassmorphism
            z: 1
        }
        // SpectrumOS Logo
        SpectrumLogo {
            id: spectrumLogo
            width: 350
            height: 350
            anchors.horizontalCenter: formBackground.horizontalCenter
            anchors.horizontalCenterOffset: parent.width * 0.033
            anchors.top: parent.top
            anchors.topMargin: 20
            anchors.bottomMargin: 20
            z: 10
            
            // Pass pywal colors to logo
            color0: colors.color0
            color1: colors.color1
            color2: colors.color2
            color3: colors.color3
            color4: colors.color4
            color5: colors.color5
            color6: colors.color6
            color7: colors.color7
        }

        LoginForm {
            id: form

            height: virtualKeyboard.state == "visible" ? parent.height - virtualKeyboard.implicitHeight : parent.height
            width: parent.width / 2.5
            anchors.horizontalCenter: config.FormPosition == "center" ? parent.horizontalCenter : undefined
            anchors.left: config.FormPosition == "left" ? parent.left : undefined
            anchors.right: config.FormPosition == "right" ? parent.right : undefined
            virtualKeyboardActive: virtualKeyboard.state == "visible" ? true : false
            z: 1
        }

        Button {
            id: vkb
            onClicked: virtualKeyboard.switchState()
            visible: virtualKeyboard.status == Loader.Ready && config.ForceHideVirtualKeyboardButton == "false"
            anchors.bottom: parent.bottom
            anchors.bottomMargin: implicitHeight
            anchors.horizontalCenter: form.horizontalCenter
            z: 1
            contentItem: Text {
                text: config.TranslateVirtualKeyboardButton || "Virtual Keyboard"
                color: parent.visualFocus ? palette.highlight : palette.text
                font.pointSize: root.font.pointSize * 0.8
            }
            background: Rectangle {
                id: vkbbg
                color: "transparent"
            }
        }

        Loader {
            id: virtualKeyboard
            source: "Components/VirtualKeyboard.qml"
            state: "hidden"
            property bool keyboardActive: item ? item.active : false
            onKeyboardActiveChanged: keyboardActive ? state = "visible" : state = "hidden"
            width: parent.width
            z: 1
            function switchState() { state = state == "hidden" ? "visible" : "hidden" }
            states: [
                State {
                    name: "visible"
                    PropertyChanges {
                        target: form
                        systemButtonVisibility: false
                        clockVisibility: false
                    }
                    PropertyChanges {
                        target: virtualKeyboard
                        y: root.height - virtualKeyboard.height
                        opacity: 1
                    }
                },
                State {
                    name: "hidden"
                    PropertyChanges {
                        target: virtualKeyboard
                        y: root.height - root.height/4
                        opacity: 0
                    }
                }
            ]
            transitions: [
                Transition {
                    from: "hidden"
                    to: "visible"
                    SequentialAnimation {
                        ScriptAction {
                            script: {
                                virtualKeyboard.item.activated = true;
                                Qt.inputMethod.show();
                            }
                        }
                        ParallelAnimation {
                            NumberAnimation {
                                target: virtualKeyboard
                                property: "y"
                                duration: 100
                                easing.type: Easing.OutQuad
                            }
                            OpacityAnimator {
                                target: virtualKeyboard
                                duration: 100
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                },
                Transition {
                    from: "visible"
                    to: "hidden"
                    SequentialAnimation {
                        ParallelAnimation {
                            NumberAnimation {
                                target: virtualKeyboard
                                property: "y"
                                duration: 100
                                easing.type: Easing.InQuad
                            }
                            OpacityAnimator {
                                target: virtualKeyboard
                                duration: 100
                                easing.type: Easing.InQuad
                            }
                        }
                        ScriptAction {
                            script: {
                                Qt.inputMethod.hide();
                            }
                        }
                    }
                }
            ]
        }

        Image {
            id: backgroundImage

            height: parent.height
            width: config.HaveFormBackground == "true" && config.FormPosition != "center" && config.PartialBlur != "true" ? parent.width - formBackground.width : parent.width
            anchors.left: leftleft || 
                          leftcenter ?
                                formBackground.right : undefined

            anchors.right: rightright ||
                           rightcenter ?
                                formBackground.left : undefined

            horizontalAlignment: config.BackgroundImageAlignment == "left" ?
                                 Image.AlignLeft :
                                 config.BackgroundImageAlignment == "right" ?
                                 Image.AlignRight :
                                 config.BackgroundImageAlignment == "center" ?
                                 Image.AlignHCenter : undefined

            source: config.background || config.Background
            fillMode: config.ScaleImageCropped == "true" ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            asynchronous: true
            cache: true
            clip: true
            mipmap: true
        }

        MouseArea {
            anchors.fill: backgroundImage
            onClicked: parent.forceActiveFocus()
        }
    }
}
