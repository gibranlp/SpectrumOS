pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: content
    required property var theme
    required property var manager
    readonly property bool selectedCategoryHasFavorites: manager.favorites.some(f=>f.category===manager.view.category)
    function cancelDrag(): void { dragGhost.Drag.cancel();dragGhost.sourceArea=null; }
    onVisibleChanged:if(!visible)cancelDrag()
    spacing: 12
    property string editorKey: ""
    FontMetrics {
        id:actionMetrics
        font.family:content.theme.fontFamily
        font.pixelSize:Math.max(10,content.theme.fontSize-2)
        font.bold:true
    }
    readonly property real countWidth:Math.max(16,actionMetrics.advanceWidth(String(Math.max(0,...manager.favorites.map(f=>f.clickCount)))))
    function actionRows(width): int {
        const widths=[countWidth].concat(manager.browsers.map(()=>30),[Math.max(36,actionMetrics.advanceWidth("Edit")+24),36]);
        let rows=1,used=0;
        for(const size of widths) {
            if(used>0 && used+4+size>width) {rows++;used=0;}
            used+=(used>0?4:0)+size;
        }
        return rows;
    }
    function focusInitial(): void { if (manager.view.editor) titleField.forceActiveFocus(); else search.forceActiveFocus(); }
    Connections { target:content.manager; function onViewChanged() {
        const key=content.manager.view.editor+":"+(content.manager.view.draft.id||"");
        if (key!==content.editorKey) { content.editorKey=key; if (content.visible) Qt.callLater(()=>content.focusInitial()); }
    } }
    component Label: Text {
        color:content.theme.colors.foreground
        font.family:content.theme.fontFamily
        font.pixelSize:content.theme.fontSize
        textFormat:Text.PlainText
        wrapMode:Text.WordWrap
    }
    component Button: ShellButton {
        fontFamily:content.theme.fontFamily
        fontSize:content.theme.fontSize
        backgroundColor:content.theme.colors.surface_alt
        foregroundColor:content.theme.colors.foreground
        enabled:content.manager.ready && !content.manager.choosing
    }
    component Field: Controls.TextField {
        Layout.fillWidth:true
        Layout.minimumWidth:0
        implicitHeight:40
        color:content.theme.colors.foreground
        placeholderTextColor:content.theme.colors.muted
        font.family:content.theme.fontFamily
        font.pixelSize:content.theme.fontSize
        selectByMouse:true
        background:Rectangle { radius:8; color:content.theme.colors.surface_alt; border.width:parent.activeFocus?1:0; border.color:content.theme.colors.accent }
    }
    component Choice: Controls.ComboBox {
        id:choice
        Layout.minimumWidth:0
        implicitHeight:38
        popup.width:choice.width
        textRole:"name"
        font.family:content.theme.fontFamily
        font.pixelSize:content.theme.fontSize
        background:Rectangle { radius:8; color:content.theme.colors.surface_alt; border.width:choice.activeFocus?1:0; border.color:content.theme.colors.accent }
        contentItem:Text { text:choice.displayText; font:choice.font; color:content.theme.colors.foreground; verticalAlignment:Text.AlignVCenter; leftPadding:10; rightPadding:28; elide:Text.ElideRight }
        delegate:Controls.ItemDelegate {
            id:option
            required property var modelData
            required property int index
            width:choice.width
            contentItem:Text { text:option.modelData.name; color:content.theme.colors.foreground; font:choice.font; elide:Text.ElideRight }
            background:Rectangle { color:option.highlighted?content.theme.colors.accent:content.theme.colors.surface_alt }
            highlighted:choice.highlightedIndex===index
        }
        indicator:Text { x:choice.width-width-10; y:(choice.height-height)/2; text:"⌄"; color:content.theme.colors.foreground; font:choice.font }
        popup.background:Rectangle { color:content.theme.colors.surface_alt; radius:8; border.color:content.theme.colors.muted }
    }
    Flow {
        Layout.fillWidth:true; spacing:8
        Button { objectName:"favorites-new"; label:"+ Favorite"; onClicked:content.manager.editFavorite(null) }
        Button { objectName:"favorites-category-new"; label:"+ Category"; onClicked:content.manager.editCategory(null) }
        Button { objectName:"favorites-import"; label:"Import"; onClicked: { content.manager.persist(); content.manager.run("choose-import"); } }
        Button { objectName:"favorites-export"; label:"Export"; onClicked: { content.manager.persist(); content.manager.run("choose-export"); } }
    }
    Label { visible:content.manager.error.length>0; Layout.fillWidth:true; text:content.manager.error; color:content.theme.colors.accent }
    RowLayout {
        visible:content.manager.preview!==null
        Layout.fillWidth:true
        Label { Layout.fillWidth:true; text:content.manager.preview ? content.manager.preview.added+" new · "+content.manager.preview.existing+" duplicates · "+content.manager.preview.invalid+" skipped" : "" }
        Button { objectName:"favorites-import-confirm"; label:"Import"; enabled:!content.manager.busy; onClicked:content.manager.run("import-apply",{path:content.manager.preview.path}) }
        Button { label:"Cancel"; onClicked:content.manager.preview=null }
    }
    Field {
        id:search;objectName:"favorites-search"
        visible:!content.manager.view.editor
        placeholderText:"Search…"
        maximumLength:200
        text:content.manager.view.search
        onTextEdited:content.manager.change({search:text})
    }
    RowLayout {
        Layout.fillWidth:true;Layout.fillHeight:true;spacing:14
        Controls.ScrollView {
            id:categoryScroll
            Layout.preferredWidth:Math.min(240,content.width*0.32)
            Layout.minimumWidth:0
            Layout.fillHeight:true
            clip:true
            contentWidth:availableWidth
            rightPadding:12
            Controls.ScrollBar.horizontal.policy:Controls.ScrollBar.AlwaysOff
            ColumnLayout {
                width:categoryScroll.availableWidth;spacing:6
                Repeater {
                    objectName:"favorites-categories"
                    model:content.manager.categoryList
                    Button {
                        id:categoryButton
                        required property var modelData
                        objectName:"favorites-category-"+modelData.id
                        Layout.fillWidth:true
                        property string categoryText:modelData.name+" ("+(modelData.id==="top" ? Math.min(24,content.manager.favorites.length) : content.manager.favorites.filter(f=>f.category===modelData.id).length)+")"
                        label:""
                        implicitHeight:Math.max(34,categoryLabel.implicitHeight+14)
                        Accessible.name:categoryText
                        backgroundColor:categoryDrop.containsDrag || content.manager.view.category===modelData.id?content.theme.colors.accent:content.theme.colors.surface_alt
                        foregroundColor:categoryDrop.containsDrag || content.manager.view.category===modelData.id?content.theme.colors.background:content.theme.colors.foreground
                        onClicked:content.manager.selectCategory(modelData.id)
                        Text {
                            id:categoryLabel
                            anchors.centerIn:parent
                            width:Math.max(0,parent.width-24)
                            text:categoryButton.categoryText
                            textFormat:Text.PlainText
                            wrapMode:Text.Wrap
                            color:categoryButton.foregroundColor
                            font {family:content.theme.fontFamily;pixelSize:content.theme.fontSize;bold:true}
                        }
                        DropArea {
                            id:categoryDrop
                            objectName:"favorites-drop-"+categoryButton.modelData.id
                            anchors.fill:parent
                            keys:["spectrum-favorite"]
                            enabled:categoryButton.modelData.id!=="top" && content.manager.ready && !content.manager.choosing
                            onEntered:event=> { if(!event.source || !event.source.favoriteId)event.accepted=false; }
                            onDropped:event=> {
                                if(event.source && event.source.favoriteId) {
                                    content.manager.moveFavorite(event.source.favoriteId,categoryButton.modelData.id);
                                    event.acceptProposedAction();
                                }
                            }
                        }
                    }
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth:true;Layout.fillHeight:true;Layout.minimumWidth:0;spacing:10
            RowLayout {
                visible:!content.manager.view.editor
                Layout.fillWidth:true
                Label { Layout.fillWidth:true; text:content.manager.view.search?"Search results":content.manager.view.category==="top"?"TOP":content.manager.categoryName(content.manager.view.category);font.bold:true;color:content.theme.colors.accent }
                Button { objectName:"favorites-category-edit";visible:!["top","uncategorized"].includes(content.manager.view.category);label:"Edit";onClicked:content.manager.editCategory(content.manager.categories.find(c=>c.id===content.manager.view.category)) }
                Button { objectName:"favorites-category-delete";visible:!["top","uncategorized"].includes(content.manager.view.category);label:"Delete";enabled:content.manager.ready && !content.manager.choosing && !content.selectedCategoryHasFavorites;onClicked:{content.manager.persist();content.manager.run("category-delete",{id:content.manager.view.category});} }
            }
            GridView {
                id:grid;objectName:"favorites-grid"
                visible:!content.manager.view.editor
                Layout.fillWidth:true;Layout.fillHeight:true
                clip:true
                cellWidth:Math.floor((width-12)/(width>=440?2:1))
                cellHeight:100+content.actionRows(cellWidth-28)*38
                model:content.manager.visibleFavorites
                boundsBehavior:Flickable.StopAtBounds
                flickableDirection:Flickable.VerticalFlick
                Controls.ScrollBar.vertical:Controls.ScrollBar {
                    id:linksScroll
                    objectName:"favorites-links-scroll"
                    policy:grid.contentHeight>grid.height ? Controls.ScrollBar.AlwaysOn : Controls.ScrollBar.AlwaysOff
                    minimumSize:0.08
                    contentItem:Rectangle {implicitWidth:8;radius:4;color:content.theme.colors.accent;opacity:linksScroll.pressed?1:0.65}
                }
                delegate:Rectangle {
                    id:card
                    required property var modelData
                    required property int index
                    width:grid.cellWidth-8;height:grid.cellHeight-8;radius:12;color:content.theme.colors.surface_alt
                    ColumnLayout {
                        anchors.fill:parent;anchors.margins:10;spacing:5
                        Item {
                            Layout.fillWidth:true;Layout.fillHeight:true
                            RowLayout {
                                anchors.fill:parent;spacing:8
                                Item {
                                    Layout.preferredWidth:24;Layout.preferredHeight:24
                                    Image { id:favicon;anchors.fill:parent;source:card.modelData.icon||"";asynchronous:true;fillMode:Image.PreserveAspectFit;visible:status===Image.Ready }
                                    Label { anchors.centerIn:parent;visible:favicon.status!==Image.Ready;text:"★";color:content.theme.colors.accent }
                                }
                                ColumnLayout {
                                    Layout.fillWidth:true;spacing:3
                                    Label { Layout.fillWidth:true;text:card.modelData.title;maximumLineCount:2;elide:Text.ElideRight;font.bold:true }
                                    Label { Layout.fillWidth:true;text:card.modelData.host||"";elide:Text.ElideRight;maximumLineCount:1;color:content.theme.colors.muted;font.pixelSize:Math.max(10,content.theme.fontSize-2) }
                                }
                            }
                            KeyboardAction {
                                id:openAction
                                objectName:"favorites-open-"+card.modelData.id
                                anchors.fill:parent
                                enabled:content.manager.ready && !content.manager.choosing
                                property bool dragged:false
                                Keys.onPressed:event=> { if(activationKey(event.key)){dragged=false;event.accepted=true;} }
                                preventStealing:true
                                drag.target:dragGhost
                                cursorShape:drag.active?Qt.ClosedHandCursor:Qt.OpenHandCursor
                                onPressed:mouse=> {
                                    dragged=false;
                                    const point=mapToItem(dragGhost.parent,mouse.x,mouse.y);
                                    dragGhost.x=point.x-12;dragGhost.y=point.y-12;
                                    dragGhost.favoriteId=card.modelData.id;dragGhost.title=card.modelData.title;dragGhost.sourceArea=openAction;
                                }
                                onPositionChanged:if(drag.active)dragged=true
                                onReleased: { if(dragged)dragGhost.Drag.drop();else dragGhost.Drag.cancel();dragGhost.sourceArea=null; }
                                onCanceled:content.cancelDrag()
                                onActivated:if(!dragged)content.manager.run("open",{id:card.modelData.id})
                            }
                        }
                        Flow {
                            Layout.fillWidth:true
                            spacing:4
                            Label {width:content.countWidth;height:34;verticalAlignment:Text.AlignVCenter;text:card.modelData.clickCount;color:content.theme.colors.muted;font.pixelSize:Math.max(10,content.theme.fontSize-2)}
                            Repeater {
                                model:content.manager.browsers
                                Button {
                                    id:browserButton
                                    required property var modelData
                                    objectName:"favorites-browser-"+card.modelData.id+"-"+modelData.id
                                    implicitWidth:30
                                    label:browserIcon.status===Image.Ready?"":modelData.name.slice(0,1)
                                    Accessible.name:"Open in "+modelData.name
                                    Controls.ToolTip.visible:browserHover.hovered
                                    Controls.ToolTip.text:"Open in "+modelData.name
                                    Controls.ToolTip.delay:400
                                    HoverHandler {id:browserHover}
                                    Image {
                                        id:browserIcon
                                        anchors.centerIn:parent
                                        width:20;height:20
                                        source:Quickshell.iconPath(browserButton.modelData.icon||"web-browser",true)
                                        fillMode:Image.PreserveAspectFit
                                        visible:status===Image.Ready
                                    }
                                    onClicked:content.manager.run("open",{id:card.modelData.id,browser:modelData.id})
                                }
                            }
                            Button { objectName:"favorites-edit-"+card.modelData.id;label:"Edit";fontSize:Math.max(10,content.theme.fontSize-2);onClicked:content.manager.editFavorite(card.modelData) }
                            Button { objectName:"favorites-remove-"+card.modelData.id;label:"×";onClicked:{content.manager.persist();content.manager.run("favorite-delete",{id:card.modelData.id});} }
                        }
                    }
                }
            }
            Controls.ScrollView {
                id:editorScroll
                objectName:"favorites-editor-scroll"
                visible:content.manager.view.editor!==""
                Layout.fillWidth:true;Layout.fillHeight:true;Layout.minimumWidth:0;clip:true
                contentWidth:availableWidth
                Controls.ScrollBar.horizontal.policy:Controls.ScrollBar.AlwaysOff
                ColumnLayout {
                    width:editorScroll.availableWidth;spacing:12
                    Field { id:titleField;objectName:"favorites-title";placeholderText:content.manager.view.editor==="favorite"?"Favorite title":"Category name";maximumLength:content.manager.view.editor==="favorite"?200:80;text:content.manager.view.editor==="favorite"?(content.manager.view.draft.title||""):(content.manager.view.draft.name||"");onTextEdited:content.manager.draft(content.manager.view.editor==="favorite"?{title:text}:{name:text}) }
                    Field { objectName:"favorites-url";visible:content.manager.view.editor==="favorite";placeholderText:"https://example.com/";maximumLength:4096;text:content.manager.view.draft.url||"";onTextEdited:content.manager.draft({url:text}) }
                    Label { visible:content.manager.view.editor==="favorite";text:"Category" }
                    Choice {
                        objectName:"favorites-category-choice"
                        visible:content.manager.view.editor==="favorite"
                        Layout.fillWidth:true
                        model:content.manager.categories
                        currentIndex:content.manager.categories.findIndex(c=>c.id===content.manager.view.draft.category)
                        onActivated:index=>content.manager.draft({category:content.manager.categories[index].id})
                    }
                    Label {visible:content.manager.draftError.length>0;Layout.fillWidth:true;text:content.manager.draftError;color:content.theme.colors.accent}
                    RowLayout {
                        Layout.fillWidth:true
                        Button {objectName:"favorites-save";label:"Save";enabled:content.manager.ready && !content.manager.busy && !content.manager.choosing;onClicked:content.manager.save()}
                        Button { objectName:"favorites-back";label:"Back";onClicked:content.manager.back() }
                    }
                }
            }
        }
    }
    Rectangle { Layout.fillWidth:true;implicitHeight:1;color:content.theme.colors.surface_alt }
    RowLayout {
        Layout.fillWidth:true;spacing:10
        Label { text:"Default browser";font.bold:true }
        Choice {
            objectName:"favorites-browser"
            Layout.fillWidth:true
            model:content.manager.browsers
            currentIndex:content.manager.browsers.findIndex(b=>b.id===content.manager.defaultBrowser)
            displayText:currentIndex<0?"Select browser…":currentText
            enabled:!content.manager.busy
            onActivated:index=>content.manager.run("browser-set",{id:content.manager.browsers[index].id})
        }
        Button { objectName:"favorites-browser-refresh";label:"↻";onClicked:content.manager.run("browsers") }
    }
    Rectangle {
        id:dragGhost
        objectName:"favorites-drag-ghost"
        parent:content.Window.window?content.Window.window.contentItem:content
        property var sourceArea:null
        property string favoriteId:""
        property string title:""
        width:Math.min(260,ghostLabel.implicitWidth+28);height:42;radius:10
        z:10000
        visible:Drag.active
        color:content.theme.colors.accent
        Drag.active:sourceArea!==null && sourceArea.drag.active
        Drag.source:dragGhost
        Drag.keys:["spectrum-favorite"]
        Drag.supportedActions:Qt.MoveAction
        Drag.proposedAction:Qt.MoveAction
        Drag.hotSpot.x:12;Drag.hotSpot.y:12
        Label {id:ghostLabel;anchors.centerIn:parent;width:parent.width-24;text:dragGhost.title;elide:Text.ElideRight;maximumLineCount:1;color:content.theme.colors.background;font.bold:true}
    }

}
