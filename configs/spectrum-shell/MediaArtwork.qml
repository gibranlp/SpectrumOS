import QtQuick
import QtQuick.Window

Rectangle {
    id: artwork
    property string artUrl: ""
    property color backgroundColor: "#242424"
    property color foregroundColor: "#ffffff"
    readonly property bool hasArtwork: cover.status === Image.Ready
    readonly property int imageStatus: cover.status
    implicitWidth: 64
    implicitHeight: 64
    color: backgroundColor
    radius: 4

    Text {
        anchors.centerIn: parent
        visible: !artwork.hasArtwork
        text: "♫"
        color: artwork.foregroundColor
        font { family: "sans-serif"; pixelSize: Math.min(artwork.width, artwork.height) * 0.6 }
    }

    Image {
        id: cover
        anchors.fill: parent
        anchors.margins: 2
        source: artwork.artUrl
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        clip: true
        visible: artwork.hasArtwork
        sourceSize.width: Math.max(1, Math.round(width * Screen.devicePixelRatio))
        sourceSize.height: Math.max(1, Math.round(height * Screen.devicePixelRatio))
    }
}
