import QtQuick
import Quickshell.Io

QuestlineDrafts {
    id: workspace
    required property string backendDir
    property int externalActions: 0
    property string incomingProfileKey:""
    property string archiveSnapshot:""
    property bool archiveFailed:false
    blocked: externalActions > 0 || incomingProfileKey.length>0 || archiveFailed
    function bindProfile(key):void {
        if(!ready || !key || key===profileKey)return;
        if(incomingProfileKey){incomingProfileKey=key;return;}
        const replaces=!!profileKey || key.split(":").slice(1).join(":").length>0;
        if(replaces && Object.keys(drafts).length>0){
            incomingProfileKey=key;archiveSnapshot=JSON.stringify(snapshot());archiveFailed=false;
            archiveProcess.exec([backendDir+"/questline-widget-state","archive"]);
        }else applyProfileKey(key);
    }
    Process {
        id:archiveProcess
        stdinEnabled:true
        onStarted:write(workspace.archiveSnapshot+"\n")
        onExited:(code,status)=>{
            if(code!==0 && workspace.incomingProfileKey){
                workspace.incomingProfileKey="";workspace.archiveFailed=true;
                workspace.storageError="Could not preserve the old profile's drafts. Your drafts are kept; refresh to retry.";
            }
        }
        stdout:StdioCollector {onStreamFinished:{
            try{
                const result=JSON.parse(text);
                if(!result.ok)throw new Error(result.error||"Archive failed");
                const key=workspace.incomingProfileKey;
                workspace.incomingProfileKey="";workspace.archiveSnapshot="";workspace.archiveFailed=false;
                if(workspace.storageError.startsWith("Could not preserve"))workspace.storageError="";
                workspace.applyProfileKey(key);
            }catch(error){
                workspace.incomingProfileKey="";workspace.archiveFailed=true;
                workspace.storageError="Could not preserve the old profile's drafts. Your drafts are kept; refresh to retry.";
            }
        }}
    }
    property bool loading: true
    property bool persistencePending: false
    property string writingSnapshot: ""
    property var awaitingSave: null
    property string actionResponse: ""
    onChanged: { persistencePending = true; persistDelay.restart(); }
    onSaveRequested: job => {
        awaitingSave = job;
        persistDelay.stop();
        persist();
    }
    function persist(): void {
        if (loading || stateProcess.running || !persistencePending || storageError) return;
        persistencePending = false;
        writingSnapshot = JSON.stringify(snapshot());
        stateProcess.exec([backendDir + "/questline-widget-state", "write"]);
    }
    Component.onCompleted: stateProcess.exec([backendDir + "/questline-widget-state", "read"])
    Timer { id: persistDelay; interval: 120; onTriggered: workspace.persist() }
    Process {
        id: stateProcess
        stdinEnabled: true
        onStarted: if (!workspace.loading) write(workspace.writingSnapshot + "\n")
        stdout: StdioCollector { onStreamFinished: {
            try {
                const result = JSON.parse(text);
                if (workspace.loading) {
                    workspace.loading = false;
                    workspace.restore(result.state);
                }
                if (result.error) {
                    workspace.storageError = "Could not keep your draft: " + result.error;
                    workspace.awaitingSave = null;
                    workspace.inFlight = null;
                } else {
                    workspace.storageError = "";
                    if (workspace.awaitingSave && !actionProcess.running
                        && JSON.parse(workspace.writingSnapshot).inFlight
                        && JSON.parse(workspace.writingSnapshot).inFlight.key === workspace.awaitingSave.key
                        && JSON.parse(workspace.writingSnapshot).inFlight.revision === workspace.awaitingSave.revision) {
                        workspace.actionResponse = "";
                        actionProcess.exec([workspace.backendDir + "/questline-action", JSON.stringify(workspace.awaitingSave.payload)]);
                        workspace.awaitingSave = null;
                    }
                }
            } catch (error) {
                workspace.loading = false;
                workspace.ready = true;
                workspace.storageError = "Could not read the Questline draft store.";
            }
        } }
        onExited: { if (workspace.persistencePending) persistDelay.restart(); }
    }
    Process {
        id: actionProcess
        stdout: StdioCollector { onStreamFinished: workspace.actionResponse = text }
        onExited: (code, status) => {
            let result;
            try { result = JSON.parse(workspace.actionResponse); }
            catch (error) { result = {error:"Autosave failed. Your draft is kept on this device."}; }
            if (code !== 0 && !result.error) result.error = "Autosave failed. Your draft is kept on this device.";
            workspace.finish(result);
        }
    }
}
