import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell.Io

Flickable {
    id: sync
    required property var theme
    required property var workspace
    required property string backendDir
    property bool active:false
    property var state:({})
    property var request:({})
    property string action:""
    property string message:""
    property string error:""
    property string transferCode:""
    property var preview:null
    property bool launchPending:false
    property bool finished:false
    property bool holdsWorkspace:false
    readonly property bool busy:runner.running || launchPending
    readonly property bool canAct:state.account!==undefined && workspace.ready && !workspace.storageError && !workspace.blocked && !busy && !workspace.busy && workspace.externalActions===0
    signal refreshRequested()
    signal profileRestored()
    contentWidth:width
    contentHeight:body.implicitHeight
    clip:true
    boundsBehavior:Flickable.StopAtBounds
    function run(name,extra):void {
        if(busy || (name!=="status" && !canAct))return;
        action=name;error="";preview=null;finished=false;
        request=Object.assign({action:name,account:state.account===undefined?null:state.account},extra||{});
        if(name!=="status") {workspace.externalActions++;holdsWorkspace=true;message=qsTranslate("Spectrum", "Working…");}
        launchPending=true;
        runner.exec([backendDir+"/questline-sync-control"]);
    }
    function decide(confirmed):void {
        if(!preview)return;
        runner.write(JSON.stringify(confirmed?{confirm:preview.token}:{cancel:true})+"\n");preview=null;
        message=confirmed?"Applying…":"Canceling…";
    }
    function receive(line):void {
        try {
            const result=JSON.parse(line);
            if(result.status) {
                state=result.status;
                if(state.profile_key && workspace.ready && typeof workspace.bindProfile==="function")workspace.bindProfile(state.profile_key);
            }
            if(result.phase==="preview") {
                if(!active){runner.write(JSON.stringify({cancel:true})+"\n");return;}
                preview=result;message=qsTranslate("Spectrum", "Review before continuing.");
                Qt.callLater(()=>sync.contentY=Math.max(0,Math.min(sync.contentHeight-sync.height,confirmationCard.y)));
                return;
            }
            finished=true;
            if(!result.ok){error=result.error||"Questline could not complete that operation.";message="";return;}
            if(action!=="status") {
                message=result.message||"Done.";
                if(result.path)message+="\n"+result.path;
                if(result.backup)message+="\nBackup: "+result.backup;
                if(result.warning)error=result.warning;
                if(result.transfer_code && active)transferCode=result.transfer_code;
                if(result.profile_replaced){transferCode="";profileRestored();}
                refreshRequested();
            }
        }catch(exception){error=qsTranslate("Spectrum", "Could not read the Sync response.");}
    }
    onActiveChanged:{
        if(active)run("status");
        else {if(preview)decide(false);transferCode="";identityInput.text="";}
    }
    Timer {interval:3000;repeat:true;running:sync.active;onTriggered:sync.run("status")}
    Process {
        id:runner
        stdinEnabled:true
        onStarted:{sync.launchPending=false;write(JSON.stringify(sync.request)+"\n");sync.request={};identityInput.text="";}
        stdout:SplitParser {onRead:data=>sync.receive(data)}
        onExited:(code,status)=>{
            sync.launchPending=false;
            if(sync.holdsWorkspace){sync.workspace.externalActions=Math.max(0,sync.workspace.externalActions-1);sync.holdsWorkspace=false;}
            if(!sync.finished && !sync.error)sync.error=qsTranslate("Spectrum", "The operation stopped. Your existing saved data has been preserved.");
            sync.preview=null;
        }
    }
    component Label:Text {
        Layout.fillWidth:true
        wrapMode:Text.Wrap
        color:sync.theme.colors.foreground
        font.family:sync.theme.fontFamily
        font.pixelSize:sync.theme.fontSize
    }
    component Field:Controls.TextField {
        color:sync.theme.colors.foreground
        placeholderTextColor:sync.theme.colors.muted
        selectionColor:sync.theme.colors.accent
        font.family:sync.theme.fontFamily
        padding:10
        background:Rectangle {radius:8;color:sync.theme.colors.background;border.width:1;border.color:parent.activeFocus?sync.theme.colors.accent:sync.theme.colors.surface_alt}
    }
    component Button:ShellButton {
        fontFamily:sync.theme.fontFamily;fontSize:sync.theme.fontSize
        backgroundColor:sync.theme.colors.surface_alt;foregroundColor:sync.theme.colors.foreground
        enabled:sync.canAct
    }
    ColumnLayout {
        id:body
        width:sync.width
        spacing:12
        Label {text:qsTranslate("Spectrum", "Sync & profile");font.bold:true;font.pixelSize:sync.theme.fontSize+4}
        Label {objectName:"questline-sync-status";text:sync.busy?(sync.preview?qsTranslate("Spectrum", "Waiting for confirmation"):qsTranslate("Spectrum", "Operation in progress…")):sync.state.account===undefined?qsTranslate("Spectrum", "Sync status is unavailable"):!sync.state.available?qsTranslate("Spectrum", "No local profile — restore one below."):sync.state.recovery_hold?qsTranslate("Spectrum", "Recovery hold — restore before enabling sync."):!sync.state.cloud_enabled?qsTranslate("Spectrum", "Local only"):!sync.state.auto_sync?qsTranslate("Spectrum", "Automatic sync paused"):sync.state.error?qsTranslate("Spectrum", "Sync needs attention"):qsTranslate("Spectrum", "Automatic sync enabled")}
        Flow {
            Layout.fillWidth:true;spacing:8
            Button {objectName:"questline-sync-cloud";label:sync.state.cloud_enabled?qsTranslate("Spectrum", "Cloud Sync: On"):qsTranslate("Spectrum", "Cloud Sync: Off");onClicked:sync.run("set_cloud_sync",{enabled:!sync.state.cloud_enabled})}
            Button {objectName:"questline-sync-auto";label:sync.state.auto_sync?qsTranslate("Spectrum", "Auto Sync: On"):qsTranslate("Spectrum", "Auto Sync: Off");enabled:sync.canAct && !!sync.state.available && !sync.state.recovery_hold;onClicked:sync.run("set_auto_sync",{enabled:!sync.state.auto_sync})}
            Button {objectName:"questline-sync-now";label:qsTranslate("Spectrum", "Sync Now");enabled:sync.canAct && !!sync.state.available && !!sync.state.cloud_enabled && !sync.state.recovery_hold;onClicked:sync.run("sync_now")}
            Button {label:qsTranslate("Spectrum", "Refresh");enabled:!sync.busy;onClicked:sync.run("status")}
        }
        Label {text:(sync.state.queued||0)+qsTranslate("Spectrum", " pending · ")+(sync.state.deferred||0)+qsTranslate("Spectrum", " waiting · ")+(sync.state.quarantined||0)+qsTranslate("Spectrum", " quarantined")}
        Label {text:qsTranslate("Spectrum", "Last successful sync: ")+(sync.state.last_success?new Date(sync.state.last_success).toLocaleString():qsTranslate("Spectrum", "Not recorded"))}
        Label {text:qsTranslate("Spectrum", "Background service: ")+((sync.state.service||{}).active||qsTranslate("Spectrum", "Checking…"))+" · "+((sync.state.service||{}).enabled||"")}
        Label {visible:!!sync.state.error;text:qsTranslate("Spectrum", sync.state.error)||"";color:sync.theme.colors.accent}
        Label {text:qsTranslate("Spectrum", "Disabling Auto Sync keeps changes saved locally. Sync Now still works when Cloud Sync is enabled.");color:sync.theme.colors.muted}
        Label {text:qsTranslate("Spectrum", "Backups and export");font.bold:true}
        Flow {
            Layout.fillWidth:true;spacing:8
            Button {objectName:"questline-sync-export";label:qsTranslate("Spectrum", "Export profile");enabled:sync.canAct && !!sync.state.available;onClicked:{sync.transferCode="";sync.run("export_profile");}}
            Button {objectName:"questline-sync-backup";label:qsTranslate("Spectrum", "Create backup");enabled:sync.canAct && !!sync.state.available;onClicked:sync.run("backup")}
            Button {objectName:"questline-sync-restore-backup";label:qsTranslate("Spectrum", "Restore file…");onClicked:sync.run("restore_backup")}
            Button {objectName:"questline-sync-restore-cloud";label:qsTranslate("Spectrum", "Restore cloud backup…");enabled:sync.canAct && !!sync.state.available && !!sync.state.cloud_enabled;onClicked:sync.run("restore_cloud")}
            Button {objectName:"questline-sync-prune";label:qsTranslate("Spectrum", "Prune tasks…");enabled:sync.canAct && !!sync.state.available;onClicked:sync.run("prune_tasks",{days:30})}
        }
        Label {text:qsTranslate("Spectrum", "Exports save directly to your Downloads folder. Backups save locally and also upload an encrypted cloud copy when Cloud Sync is on. Pruning previews private completed quests older than 30 days.");color:sync.theme.colors.muted}
        ColumnLayout {
            visible:sync.transferCode.length>0;Layout.fillWidth:true
            Label {text:qsTranslate("Spectrum", "Private Transfer Code — grants access to your profile. Copy it only to a trusted PC.");color:sync.theme.colors.accent}
            Field {Layout.fillWidth:true;readOnly:true;text:sync.transferCode;selectByMouse:true;font.family:sync.theme.fontFamily}
            Button {objectName:"questline-sync-copy-transfer";label:qsTranslate("Spectrum", "Copy Transfer Code");onClicked:sync.run("copy_transfer",{transfer_code:sync.transferCode})}
        }
        Label {text:qsTranslate("Spectrum", "Restore identity");font.bold:true}
        Field {
            id:identityInput
            objectName:"questline-sync-transfer-input"
            Layout.fillWidth:true
            placeholderText:qsTranslate("Spectrum", "Paste a private Transfer Code")
            echoMode:TextInput.Password
            selectByMouse:true
            enabled:!sync.busy
            font.family:sync.theme.fontFamily
        }
        Button {objectName:"questline-sync-restore-identity";label:qsTranslate("Spectrum", "Preview identity restore");enabled:sync.canAct && identityInput.text.trim().length>0 && !!sync.state.cloud_enabled;onClicked:sync.run("restore_identity",{transfer_code:identityInput.text})}
        Label {text:qsTranslate("Spectrum", "Restore operations replace this PC's local profile after a preview and confirmation. Close the Questline terminal first. The current profile and widget drafts are backed up; Auto Sync remains off after restoring.");color:sync.theme.colors.muted}
        Rectangle {
            id:confirmationCard
            visible:sync.preview!==null
            Layout.fillWidth:true
            implicitHeight:confirmation.implicitHeight+24
            radius:12;color:sync.theme.colors.surface_alt
            ColumnLayout {
                id:confirmation
                anchors{left:parent.left;right:parent.right;top:parent.top;margins:12}
                Label {objectName:"questline-sync-preview";text:sync.preview?(sync.preview.kind==="prune_tasks"?qsTranslate("Spectrum", "Prune ")+sync.preview.count+qsTranslate("Spectrum", " quests and steps older than ")+sync.preview.days+qsTranslate("Spectrum", " days?"):qsTranslate("Spectrum", "Restore ")+(sync.preview.incoming.name||qsTranslate("Spectrum", "profile"))+": "+sync.preview.incoming.tasks+qsTranslate("Spectrum", " quests/steps, ")+sync.preview.incoming.notes+qsTranslate("Spectrum", " scrolls, ")+sync.preview.incoming.favorites+qsTranslate("Spectrum", " favorites?")):"";font.bold:true}
                Label {text:sync.preview?sync.preview.message:""}
                RowLayout {
                    ShellButton {objectName:"questline-sync-confirm";label:qsTranslate("Spectrum", "Confirm");fontFamily:sync.theme.fontFamily;fontSize:sync.theme.fontSize;backgroundColor:sync.theme.colors.accent;foregroundColor:sync.theme.colors.background;onClicked:sync.decide(true)}
                    ShellButton {objectName:"questline-sync-cancel";label:qsTranslate("Spectrum", "Cancel");fontFamily:sync.theme.fontFamily;fontSize:sync.theme.fontSize;onClicked:sync.decide(false)}
                }
            }
        }
        Label {objectName:"questline-sync-message";visible:sync.message.length>0;text:qsTranslate("Spectrum", sync.message)}
        Label {objectName:"questline-sync-error";visible:sync.error.length>0;text:qsTranslate("Spectrum", sync.error);color:sync.theme.colors.accent}
        Label {text:qsTranslate("Spectrum", "Devices");font.bold:true}
        Repeater {model:sync.state.devices||[];delegate:Label {required property var modelData;text:modelData.name+" · "+(modelData.last_sync?new Date(modelData.last_sync).toLocaleString():qsTranslate("Spectrum", "No sync recorded"))}}
    }
}
