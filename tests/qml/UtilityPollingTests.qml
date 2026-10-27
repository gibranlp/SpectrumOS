import QtQuick
import QtTest
import Quickshell
import "../../configs/spectrum-shell" as Shell
Scope {
    Shell.QuestlineDrafts { id: workspace; property int externalActions: 0; Component.onCompleted: restore({version:1}) }
    Shell.UtilityPanel {
        id: panel
        questlineWorkspace: workspace
        breakState: ({settings:{enabled:false,eye_minutes:20,movement_minutes:50,pause_focus:true},ready:true,busy:false,status:"Off",error:"",eyeElapsed:0,movementElapsed:0,minutesLeft:function(){return "";}})
        backendDir: Quickshell.env("SPECTRUM_POLLING_DIR")
        focusState: ({})
        theme: ({panelLeftInset:52,barPosition:"top",barStyle:"full",animationsEnabled:false,widgetBounceEnabled:false,gamingActive:false,fontSize:12,fontFamily:"monospace",colors:{background:"#111111",surface:"#222222",surface_alt:"#333333",foreground:"#eeeeee",muted:"#aaaaaa",accent:"#66ccee"}})
    }
    TestCase {
        name: "UtilityPolling"
        when: true
        onCompletedChanged: if (completed) { console.log("Utility polling:",qtest_results.passCount,"passed",qtest_results.failCount,"failed"); Qt.quit(); }
        SignalSpy { id: returned; target: panel; signalName: "spectrumDropReturnRequested" }
        function test_drop_returns_after_chooser_even_while_closed() {
            const backend=findChild(panel,"spectrumdrop-state");
            panel.page="spectrumdrop";
            backend.state={visible:true,transfer:{}};
            backend.scan();
            wait(30);
            backend.command(["send","02:11:22:33:44:55"]);
            verify(backend.busy);
            compare(backend.pendingAfterScan[0],"send");
            tryCompare(backend,"awaitingChooser",true,1000);
            verify(!panel.expanded);
            tryCompare(returned,"count",1,4000);
            verify(!backend.awaitingChooser);
            compare(backend.state.transfer.phase,"failed");
            verify(backend.state.transfer.message.indexOf("Send failed:") === 0);
        }
        function test_hotkey_poll_preserves_rows_and_queues_action() {
            const backend=findChild(panel,"hotkey-state");
            verify(backend !== null);
            backend.command(["status"]);
            wait(30); verify(!backend.busy);
            tryCompare(backend,"rules",[{id:"test",keys:"2",interval_ms:50,shortcut:"Control+Shift+2",active:false}],1000);
            const previous=backend.rules;
            backend.command(["status"]);
            wait(30); verify(!backend.busy);
            backend.command(["stop-all"]);
            verify(backend.busy); compare(backend.pending[0],"stop-all");
            wait(400);
            verify(!backend.busy);
            compare(backend.requested[0],"stop-all");
            verify(backend.rules === previous);
        }
    }
}
