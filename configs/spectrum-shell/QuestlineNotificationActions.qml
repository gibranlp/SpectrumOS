import QtQuick
import Quickshell.Io

Item {
    id:bridge
    required property string backendDir
    property var queue:[]
    property var job:null
    property string response:""
    signal finished(var request,var result)
    function enqueue(action,id,token): void {
        if (!["drink_water","dismiss_hydration_reminder"].includes(action)) return;
        if ((job && job.action===action && job.notificationId===id) || queue.some(item=>item.action===action && item.notificationId===id)) return;
        queue=queue.concat([{action:action,notificationId:id,reminder_token:token}]);pump();
    }
    function pump(): void {
        if (job || !queue.length) return;
        job=queue[0];queue=queue.slice(1);response="";
        process.exec([backendDir+"/questline-action",JSON.stringify({action:job.action,reminder_token:job.reminder_token})]);
    }
    Process {
        id:process
        stdout:StdioCollector {onStreamFinished:bridge.response=text}
        onExited:(code,status)=> {
            let result;
            try {result=JSON.parse(bridge.response);}catch(error){result={error:qsTranslate("Spectrum", "Could not record your drink. Please try again.")};}
            if (code!==0 && !result.error) result.error=qsTranslate("Spectrum", "Could not record your drink. Please try again.");
            const request=bridge.job;bridge.job=null;bridge.finished(request,result);Qt.callLater(bridge.pump);
        }
    }
}
