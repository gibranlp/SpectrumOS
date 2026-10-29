import QtQuick
import "IgorOutfits.js" as Outfits

Image {
    id: outfit
    objectName: "igorSeasonalOutfit"
    property date currentDate: new Date()
    property bool visitActive: false
    property var randomSource: Math.random
    property real visitRoll: randomSource()
    readonly property var selection: Outfits.forDate(currentDate, visitRoll)
    readonly property string outfitId: selection ? selection.id : ""
    source: selection ? Qt.resolvedUrl("igor/" + selection.asset) : ""
    sourceSize.width: Math.ceil(width * 2)

    function refreshDate(): void { currentDate = new Date(); }
    onVisitActiveChanged: {
        if (visitActive) {
            refreshDate();
            visitRoll = randomSource();
        }
    }
    onVisibleChanged: { if (visible) refreshDate(); }

    Timer {
        objectName: "igorOutfitClock"
        // El límite de un minuto también detecta cambios de zona horaria y reanudaciones.
        interval: Math.max(1, Math.min(60000, new Date(outfit.currentDate.getFullYear(),
            outfit.currentDate.getMonth(), outfit.currentDate.getDate() + 1).getTime()
            - outfit.currentDate.getTime()))
        running: true
        repeat: true
        onTriggered: outfit.refreshDate()
    }
}
