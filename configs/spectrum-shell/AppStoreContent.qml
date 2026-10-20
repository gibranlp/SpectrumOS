pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell

ColumnLayout {
    id: content
    required property var theme
    required property var manager
    property string selection: ""
    signal routeRequested(string route)
    readonly property var job: manager.activeJob
    readonly property var prompt: job ? job.prompt : null
    spacing:12
    function focusInitial(): void { searchField.forceActiveFocus(); }
    component Label: Text {
        Layout.minimumWidth:0; Layout.fillWidth:true
        color:content.theme.colors.foreground
        font { family:content.theme.fontFamily; pixelSize:content.theme.fontSize }
        textFormat:Text.PlainText
        wrapMode:Text.Wrap
    }
    component Button: ShellButton {
        fontFamily:content.theme.fontFamily; fontSize:content.theme.fontSize
        backgroundColor:content.theme.colors.surface_alt; foregroundColor:content.theme.colors.foreground
    }
    component Field: Controls.TextField {
        color:content.theme.colors.foreground
        placeholderTextColor:content.theme.colors.muted
        font { family:content.theme.fontFamily; pixelSize:content.theme.fontSize }
        padding:12
        background:Rectangle { radius:10; color:content.theme.colors.surface_alt; border.color:parent.activeFocus ? content.theme.colors.accent : "transparent" }
    }
    RowLayout {
        Layout.minimumWidth:0; Layout.fillWidth:true
        Repeater {
            model:[{id:"discover",label:"Discover"},{id:"installed",label:"Installed"},{id:"activity",label:"Activity"}]
            Button {
                required property var modelData
                label:modelData.label+(modelData.id === "activity" && content.job && content.job.active ? " ●" : "")
                backgroundColor:content.manager.page === modelData.id ? content.theme.colors.accent : content.theme.colors.surface_alt
                foregroundColor:content.manager.page === modelData.id ? content.theme.colors.background : content.theme.colors.foreground
                onClicked:content.manager.page=modelData.id
            }
        }
        Item { Layout.minimumWidth:0; Layout.fillWidth:true }
        Button { label:"↻"; Accessible.name:"Refresh App Store"; onClicked:content.manager.refresh() }
    }
    Label { visible:content.manager.error !== ""; text:content.manager.error; color:content.theme.colors.error || content.theme.colors.foreground }
    ColumnLayout {
        visible:content.manager.page !== "activity" && !content.manager.selected
        Layout.minimumWidth:0; Layout.fillWidth:true; Layout.fillHeight:true; spacing:10
        Field {
            id:searchField
            objectName:"app-store-search"
            Layout.minimumWidth:0; Layout.fillWidth:true; placeholderText:"Search applications and packages…"
            text:content.manager.query
            onTextEdited:content.manager.query=text
            onAccepted:content.manager.search()
        }
        Flow {
            Layout.minimumWidth:0; Layout.fillWidth:true; spacing:6
            Repeater {
                model:content.manager.page === "installed" ? [{id:"all",label:"All"},{id:"pacman",label:"System packages"},{id:"flatpak",label:"Flatpak"}] : [{id:"all",label:"All sources"},{id:"pacman",label:"System packages"},{id:"aur",label:"AUR · community"},{id:"flatpak",label:"Flatpak"}]
                Button {
                    required property var modelData
                    label:modelData.label
                    backgroundColor:content.manager.source === modelData.id ? content.theme.colors.accent : content.theme.colors.surface_alt
                    foregroundColor:content.manager.source === modelData.id ? content.theme.colors.background : content.theme.colors.foreground
                    onClicked:content.manager.source=modelData.id
                }
            }
        }
        Label {
            text:content.manager.busy ? "Searching sources…" : content.manager.results.length+" results · Choose a source before installing."
            color:content.theme.colors.muted
        }
        Label { visible:content.manager.warnings !== ""; text:content.manager.warnings; color:content.theme.colors.warning || content.theme.colors.foreground }
        ListView {
            id:results
            objectName:"app-store-results"
            Layout.minimumWidth:0; Layout.fillWidth:true; Layout.fillHeight:true; clip:true; spacing:7
            model:content.manager.results
            delegate:Rectangle {
                id:resultRow
                required property var modelData
                required property int index
                width:results.width; height:row.implicitHeight+24; radius:12
                color:action.activeFocus ? content.theme.colors.accent : content.theme.colors.surface_alt
                Rectangle {
                    anchors { left:parent.left; top:parent.top; margins:14 }
                    width:36; height:36; radius:9
                    color:content.theme.colors.surface
                    visible:!appIcon.visible
                    Text { anchors.centerIn:parent; text:resultRow.modelData.source === "flatpak" ? "▦" : "▣"; color:content.theme.colors.accent; font.pixelSize:24 }
                }
                Image {
                    id:appIcon
                    anchors { left:parent.left; top:parent.top; margins:14 }
                    width:36; height:36; fillMode:Image.PreserveAspectFit
                    visible:resultRow.modelData.icon !== undefined && Quickshell.hasThemeIcon(resultRow.modelData.icon)
                    source:visible ? Quickshell.iconPath(resultRow.modelData.icon) : ""
                }
                ColumnLayout {
                    id:row; anchors { left:parent.left; leftMargin:62; right:parent.right; rightMargin:12; top:parent.top; topMargin:12 }
                    spacing:4
                    Label { text:resultRow.modelData.title; font.bold:true; color:action.activeFocus ? content.theme.colors.background : content.theme.colors.foreground }
                    Label { text:resultRow.modelData.description || resultRow.modelData.name; maximumLineCount:2; elide:Text.ElideRight; color:action.activeFocus ? content.theme.colors.background : content.theme.colors.muted }
                    Label { text:(resultRow.modelData.source === "aur" ? "AUR · community" : resultRow.modelData.source === "flatpak" ? "Flatpak" : "System")+" · "+resultRow.modelData.label+(resultRow.modelData.installed ? " · Installed" : ""); font.pixelSize:Math.max(10,content.theme.fontSize-1); color:action.activeFocus ? content.theme.colors.background : content.theme.colors.accent }
                }
                KeyboardAction { id:action; anchors.fill:parent; Accessible.name:resultRow.modelData.title+" · "+resultRow.modelData.label; onActivated:content.manager.choose(resultRow.modelData) }
            }
            Controls.ScrollBar.vertical:Controls.ScrollBar {}
        }
    }
    ColumnLayout {
        visible:content.manager.page !== "activity" && content.manager.selected !== null
        Layout.minimumWidth:0; Layout.fillWidth:true; Layout.fillHeight:true; spacing:12
        Button { label:"← Results"; onClicked:content.manager.selected=null }
        Label { text:content.manager.selected ? content.manager.selected.title : ""; font.pixelSize:content.theme.fontSize+7; font.bold:true }
        Label { text:content.manager.selected ? content.manager.selected.label+" · "+content.manager.selected.version : ""; color:content.theme.colors.accent }
        Controls.ScrollView {
            Layout.minimumWidth:0; Layout.fillWidth:true; Layout.fillHeight:true; clip:true; contentWidth:availableWidth
            Controls.TextArea {
                readOnly:true; text:content.manager.detail; textFormat:TextEdit.PlainText; wrapMode:TextEdit.Wrap
                color:content.theme.colors.foreground; font { family:content.theme.fontFamily; pixelSize:content.theme.fontSize }
                background:Rectangle { color:content.theme.colors.surface_alt; radius:12 }
                padding:14
            }
        }
        Label {
            text:content.manager.selected && content.manager.selected.source === "flatpak" ? "Installation opens in a separate terminal. Review permissions and dependencies there."
                : "Installation opens in a separate terminal and includes a full system upgrade. Review packages, passwords and AUR build files there."
            color:content.theme.colors.muted
        }
        RowLayout {
            Layout.minimumWidth:0; Layout.fillWidth:true
            Button {
                objectName:"app-store-install"
                Layout.minimumWidth:0; Layout.fillWidth:true
                label:content.manager.selected && content.manager.selected.installed ? content.manager.selected.launchable ? "Open application" : "Installed" : "Install in terminal"
                enabled:!content.manager.acting && (!content.manager.selected || !content.manager.selected.installed || content.manager.selected.launchable === true) && (!content.job || !content.job.active || (content.manager.selected && content.manager.selected.installed))
                onClicked: {
                    if (content.manager.selected.installed) content.manager.action("launch",{target:content.manager.selected});
                    else content.manager.install();
                }
            }
        }
    }
    ColumnLayout {
        visible:content.manager.page === "activity"
        Layout.minimumWidth:0; Layout.fillWidth:true; Layout.fillHeight:true; spacing:10
        Label { text:content.job ? content.job.target.title || content.job.target.name : "No installations yet."; font.bold:true }
        Label { text:content.job ? content.job.message : "Choose an application in Discover to start."; color:content.theme.colors.accent }
        Label { visible:content.job !== null && content.job.active; text:content.job && content.job.mode === "terminal" ? "Passwords and confirmations stay in the installation terminal. This is a read-only copy of its recent output." : "An earlier graphical installation is still active. Answer its questions here."; color:content.theme.colors.muted }
        Controls.ScrollView {
            id:activityScroll
            Layout.minimumWidth:0; Layout.fillWidth:true; Layout.fillHeight:true; clip:true; contentWidth:availableWidth
            Flickable {
                id:activityLog
                objectName:"app-store-log-scroll"
                clip:true; boundsBehavior:Flickable.StopAtBounds
                contentWidth:width; contentHeight:activityText.height+24
                property bool followOutput:true
                property bool adjusting:false
                function restorePosition(previous,follow): void {
                    adjusting=true;
                    contentY=follow ? Math.max(0,contentHeight-height) : Math.min(previous,Math.max(0,contentHeight-height));
                    adjusting=false;
                }
                onContentYChanged:if(!adjusting)followOutput=contentY+height>=contentHeight-40
                onHeightChanged:if(followOutput)Qt.callLater(()=>restorePosition(0,true))
                onContentHeightChanged:if(followOutput)Qt.callLater(()=>restorePosition(0,true))
                TextEdit {
                    id:activityText
                    objectName:"app-store-activity"
                    x:12; y:12; width:Math.max(1,activityLog.width-24); height:implicitHeight
                    readOnly:true; selectByMouse:true; textFormat:TextEdit.PlainText; wrapMode:TextEdit.Wrap
                    text:content.prompt && content.prompt.kind === "review" ? content.prompt.body : content.job ? content.job.log : ""
                    color:content.theme.colors.foreground; font { family:content.theme.fontFamily; pixelSize:content.theme.fontSize }
                    onTextChanged: {
                        const previous=activityLog.contentY;
                        const follow=activityLog.followOutput;
                        Qt.callLater(()=>activityLog.restorePosition(previous,follow));
                    }
                }
            }
        }
        Label { visible:content.prompt !== null; text:content.prompt ? content.prompt.text : ""; font.bold:true }
        RowLayout {
            visible:content.prompt !== null && content.prompt.kind !== "selection"
            Layout.minimumWidth:0; Layout.fillWidth:true
            Button { objectName:"app-store-yes"; Layout.minimumWidth:0; Layout.fillWidth:true; label:content.prompt && content.prompt.kind === "review" ? "Approve reviewed files" : "Yes"; enabled:!content.manager.acting; onClicked:content.manager.answer("y") }
            Button { objectName:"app-store-no"; Layout.minimumWidth:0; Layout.fillWidth:true; label:content.prompt && content.prompt.kind === "review" ? "Decline review" : "No"; enabled:!content.manager.acting; onClicked:content.manager.answer("n") }
        }
        RowLayout {
            visible:content.prompt !== null && content.prompt.kind === "selection"
            Layout.minimumWidth:0; Layout.fillWidth:true
            Field { id:choice; Layout.minimumWidth:0; Layout.fillWidth:true; placeholderText:"Selection number (blank uses the displayed default)"; validator:RegularExpressionValidator { regularExpression:/[0-9 ,\-]{0,80}/ } }
            Button { label:"Continue"; enabled:!content.manager.acting; onClicked:{ content.manager.answer(choice.text);choice.text=""; } }
        }
        Button { visible:content.job !== null && !content.job.active; label:"Refresh installed applications"; onClicked:{content.manager.source="all";content.manager.page="installed";content.manager.refresh();} }
    }
    RowLayout {
        Layout.minimumWidth:0; Layout.fillWidth:true
        Button { label:"AppImages"; onClicked:content.routeRequested("appimages") }
        Button { label:"System updates"; onClicked:content.routeRequested("updates") }
        Item { Layout.minimumWidth:0; Layout.fillWidth:true }
    }
}
