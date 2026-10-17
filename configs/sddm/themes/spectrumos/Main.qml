import QtQuick 2.11
import QtQuick.Window 2.11
import QtQuick.Controls 2.4
import QtQuick.Layouts 1.11
import QtGraphicalEffects 1.11
import "Components"

Pane {
    id: root
    width: config.ScreenWidth || Screen.width
    height: config.ScreenHeight || Screen.height
    padding: 0
    focus: true

    font.family: config.Font
    font.pointSize: config.FontSize !== "" ? config.FontSize : Math.max(10, Math.min(16, Math.round(height / 80)))
    palette.button: "transparent"
    palette.highlight: colors.accent
    palette.text: colors.foreground
    palette.buttonText: colors.foreground
    palette.window: colors.background

    QtObject {
        id: colors

        function readColor(key, fallback) {
            var request = new XMLHttpRequest()
            request.open("GET", "file:///var/lib/spectrumos/appearance/colors.conf", false)
            request.send()
            if (request.status !== 0 && request.status !== 200)
                return fallback
            var lines = request.responseText.split("\n")
            for (var index = 0; index < lines.length; index++) {
                if (lines[index].indexOf(key + "=") === 0)
                    return lines[index].substring(key.length + 1)
            }
            return fallback
        }

        property string background: readColor("background", "#111827")
        property string surface: readColor("surface", "#1f2937")
        property string foreground: readColor("foreground", "#f8fafc")
        property string muted: readColor("muted", "#aab3c2")
        property string accent: readColor("accent", "#7db7ff")
        property string accentAlt: readColor("accent_alt", "#c09cff")
        property string color0: background
        property string color1: accent
        property string color2: accentAlt
        property string color3: accent
        property string color4: muted
        property string color5: accentAlt
        property string color6: accentAlt
        property string color7: "#ffffff"
    }

    Image {
        id: backgroundImage
        anchors.fill: parent
        source: config.Background
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        mipmap: true
    }

    Rectangle {
        anchors.fill: parent
        color: "#52000000"
    }

    Item {
        id: card
        width: Math.min(parent.width * 0.60, 840)
        height: Math.min(parent.height * 0.94, 980 * Math.max(1, root.font.pointSize / 14))
        anchors.centerIn: parent

        ShaderEffectSource {
            id: cardBackground
            anchors.fill: parent
            sourceItem: backgroundImage
            sourceRect: Qt.rect(card.x, card.y, card.width, card.height)
        }

        FastBlur {
            anchors.fill: parent
            source: cardBackground
            radius: 56
        }

        Rectangle {
            anchors.fill: parent
            radius: config.RoundCorners
            color: colors.background
            opacity: 0.78
            border.width: 1
            border.color: colors.muted
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Math.max(28, parent.width * 0.065)
            spacing: root.font.pointSize

            SpectrumLogo {
                id: spectrumLogo
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(card.width * 0.62, card.height * 0.44, root.font.pointSize * 26) * 0.90
                Layout.preferredHeight: Layout.preferredWidth * 250 / 278
                Layout.maximumWidth: Layout.preferredWidth
                Layout.maximumHeight: Layout.preferredHeight
                color0: colors.background
                color1: colors.accent
                color2: colors.accentAlt
                color3: colors.muted
                color4: colors.accent
                color5: colors.accentAlt
                color6: colors.accentAlt
                color7: "#ffffff"
            }

            Image {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: spectrumLogo.width * 0.90
                Layout.preferredHeight: Layout.preferredWidth * 117 / 350
                Layout.maximumWidth: Layout.preferredWidth
                Layout.maximumHeight: Layout.preferredHeight
                source: "file:///var/lib/spectrumos/appearance/wordmark.svg"
                transform: Translate { y: -root.font.pointSize * 0.75 }
                fillMode: Image.PreserveAspectFit
                cache: false
                smooth: true
                mipmap: true
            }

            UserAvatar {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(112, card.height * 0.13)
                Layout.preferredHeight: Layout.preferredWidth
                username: loginForm.username
                accent: colors.accent
                surface: colors.surface
                foreground: colors.foreground
            }

            LoginForm {
                id: loginForm
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
}
