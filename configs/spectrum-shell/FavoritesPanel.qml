import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id:panel
    required property var theme
    required property var manager
    property bool expanded:false
    property int topInset:8
    property int sideInset:8
    signal closeRequested()
    WlrLayershell.layer:WlrLayer.Top
    WlrLayershell.namespace:"spectrum-widget-favorites"
    anchors {top:true;bottom:true;left:true;right:true}
    exclusionMode:ExclusionMode.Ignore
    color:"transparent"
    visible:motion.active
    focusable:expanded && !manager.choosing
    EscapeDismissal {active:panel.expanded && !panel.manager.choosing;onDismissed:panel.closeRequested()}
    Connections {target:panel.manager;function onFavoriteOpened(){if(panel.expanded)panel.closeRequested();}}
    onExpandedChanged: {
        manager.active=expanded;
        if (expanded) { manager.refresh();Qt.callLater(()=>contentArea.focusInitial()); }
        else manager.persist();
    }
    MouseArea {anchors.fill:parent;visible:panel.expanded;onClicked:panel.closeRequested()}
    ShellSurface {
        id:frame
        objectName:"favorites-frame"
        width:Math.min(780,panel.width-panel.sideInset-8)
        height:panel.height-panel.topInset-8
        x:panel.sideInset;y:panel.topInset
        color:panel.theme.colors.surface;radius:32
        attachTop:true;attachBottom:true;attachLeft:true
        topAttachmentHeight:panel.theme.barStyle==="islands" && panel.theme.barPosition==="top"?Math.max(0,y-8):0
        leftAttachmentWidth:panel.theme.barStyle==="islands" && panel.theme.barPosition==="left"?Math.max(0,x-leftFrameThickness):0
        transform:ShellMotion {id:motion;surface:frame;expanded:panel.expanded;edge:"left";animationsEnabled:panel.theme.animationsEnabled!==false;bounceEnabled:panel.theme.widgetBounceEnabled!==false;viewportWidth:panel.screen.width;viewportHeight:panel.screen.height}
        MouseArea {anchors.fill:parent;onClicked:{}}
        ColumnLayout {
            anchors.fill:parent;anchors.margins:22;spacing:12
            RowLayout {
                Layout.fillWidth:true
                Text {text:"FAVORITES";color:panel.theme.colors.foreground;font {family:panel.theme.fontFamily;pixelSize:panel.theme.fontSize+8;bold:true}}
                Item {Layout.fillWidth:true}
                ShellButton {label:"✕";fontFamily:panel.theme.fontFamily;fontSize:panel.theme.fontSize;backgroundColor:panel.theme.colors.surface_alt;foregroundColor:panel.theme.colors.foreground;onClicked:panel.closeRequested()}
            }
            FavoritesContent {id:contentArea;Layout.fillWidth:true;Layout.fillHeight:true;theme:panel.theme;manager:panel.manager}
        }
    }
}
