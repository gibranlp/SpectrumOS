import QtQuick 2.11
import QtGraphicalEffects 1.11

Rectangle {
    id: avatar
    property string username: ""
    property color accent: "#7db7ff"
    property color surface: "#1f2937"
    property color foreground: "#f8fafc"
    property bool useHome: false
    onUsernameChanged: useHome = false

    radius: width / 2
    color: surface
    border.color: accent
    border.width: 2

    Text {
        anchors.centerIn: parent
        visible: photo.status !== Image.Ready
        text: avatar.username ? avatar.username.charAt(0).toUpperCase() : "?"
        color: avatar.foreground
        font.pixelSize: avatar.height * 0.44
    }

    Image {
        id: photo
        anchors.fill: parent
        anchors.margins: 3
        source: !avatar.username ? "" : avatar.useHome
                ? "file:///home/" + encodeURIComponent(avatar.username) + "/" + encodeURIComponent(avatar.username) + ".png"
                : "file:///var/lib/spectrumos/appearance/" + encodeURIComponent(avatar.username) + ".png"
        onStatusChanged: {
            if (status === Image.Error && !avatar.useHome)
                avatar.useHome = true
        }
        fillMode: Image.PreserveAspectCrop
        mipmap: true
        cache: false
        visible: false
    }

    OpacityMask {
        anchors.fill: photo
        source: photo
        visible: photo.status === Image.Ready
        maskSource: Rectangle {
            width: photo.width
            height: photo.height
            radius: width / 2
        }
    }
}
