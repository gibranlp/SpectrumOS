import QtQuick
import QtQuick.Controls as Controls

Item {
    id:bar
    required property var theme
    property var campaigns: []
    property string selectedId: ""
    signal chosen(string campaignId)
    implicitHeight:40
    function revealSelection(): void {
        if (list.currentIndex>=0) list.positionViewAtIndex(list.currentIndex,ListView.Contain);
    }
    ListView {
        id:list
        objectName:"questline-campaign-buttons"
        anchors.fill:parent
        anchors.bottomMargin:4
        orientation:ListView.Horizontal
        spacing:6
        clip:true
        boundsBehavior:Flickable.StopAtBounds
        model:bar.campaigns
        currentIndex:bar.campaigns.findIndex(c=>c.id===bar.selectedId)
        onCurrentIndexChanged:Qt.callLater(bar.revealSelection)
        onWidthChanged:Qt.callLater(bar.revealSelection)
        onCountChanged:Qt.callLater(bar.revealSelection)
        delegate:ShellButton {
            required property var modelData
            objectName:"questline-campaign-"+modelData.id
            label:modelData.name
            fontFamily:bar.theme.fontFamily
            fontSize:bar.theme.fontSize
            backgroundColor:bar.selectedId===modelData.id?bar.theme.colors.accent:bar.theme.colors.surface_alt
            foregroundColor:bar.selectedId===modelData.id?bar.theme.colors.background:bar.theme.colors.foreground
            onClicked:bar.chosen(modelData.id)
        }
        Controls.ScrollBar.horizontal:Controls.ScrollBar {
            objectName:"questline-campaign-scroll"
            policy:Controls.ScrollBar.AlwaysOff
        }
        WheelHandler {
            onWheel:event=> {
                const delta=event.angleDelta.x || event.angleDelta.y;
                list.contentX=Math.max(0,Math.min(list.contentWidth-list.width,list.contentX-delta));
                event.accepted=true;
            }
        }
    }
}
