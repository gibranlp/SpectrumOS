import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: header
    required property var theme
    property var hero: null
    readonly property var profile: hero || ({})
    readonly property bool maximumLevel: (profile.level || 1) >= 100
    readonly property real progress: maximumLevel ? 1 : profile.xp_next_level > 0 ? Math.max(0, Math.min(1, (profile.xp || 0) / profile.xp_next_level)) : 0
    spacing: 5

    Text {
        objectName: "questline-character-name"
        Layout.fillWidth: true
        text: header.profile.username || "Your hero"
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: header.theme.colors.foreground
        font { family: header.theme.fontFamily; pixelSize: header.theme.fontSize + 10; bold: true }
    }
    Text {
        objectName: "questline-character-class"
        Layout.fillWidth: true
        text: (header.profile.class || "Class unavailable") + " · Level " + (header.profile.level || 1)
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: header.theme.colors.accent
        font { family: header.theme.fontFamily; pixelSize: header.theme.fontSize }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Rectangle {
            objectName: "questline-character-xp-track"
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: header.theme.colors.surface_alt
            Rectangle {
                objectName: "questline-character-xp-fill"
                width: parent.width * header.progress
                height: parent.height
                radius: 3
                color: header.theme.colors.accent
            }
        }
        Text {
            objectName: "questline-character-xp-label"
            text: header.maximumLevel ? "Maximum level · " + (header.profile.xp || 0) + " XP"
                : header.profile.xp_next_level > 0 ? (header.profile.xp || 0) + " / " + header.profile.xp_next_level + " XP"
                : (header.profile.xp || 0) + " XP"
            color: header.theme.colors.muted
            font { family: header.theme.fontFamily; pixelSize: header.theme.fontSize }
        }
    }
}
