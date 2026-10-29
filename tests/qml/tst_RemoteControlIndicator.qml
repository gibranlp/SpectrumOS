import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell
import "../../configs/spectrum-shell/UkvmControlModel.js" as Model

TestCase {
    name: "RemoteControlIndicator"
    visible: true
    when: windowShown
    width: 120; height: 80
    QtObject {
        id: theme
        property string fontFamily: "monospace"
        property int fontSize: 14
        property var colors: ({foreground:"#ffffff", background:"#000000", surface:"#222222", accent:"#aaaaaa"})
    }
    Shell.RemoteControlIndicator { id: indicator; theme: theme; animationsEnabled: false }
    Row {
        id: activities
        y: 40
        spacing: 8
        Shell.FocusCountdown { id: focus; theme: theme; focusState: ({phase:"work", remaining:120}) }
        Shell.RecordingStatus { id: recording; screenRecording: true; audioRecording: true; animationsEnabled: false }
        Shell.RemoteControlIndicator { id: incoming; theme: theme; active: true; animationsEnabled: false }
    }
    function test_focus_recordings_and_remote_control_coexist() {
        wait(20);
        verify(focus.visible && recording.visible && incoming.visible);
        verify(recording.x >= focus.x + focus.width);
        verify(incoming.x >= recording.x + recording.width);
        compare(activities.width, focus.width + recording.width + incoming.width + 16);
        incoming.active = false;
        wait(20);
        verify(focus.visible && recording.visible);
        compare(activities.width, focus.width + recording.width + 8);
        incoming.active = true;
    }
    SignalSpy { id: activated; target: indicator; signalName: "activated" }
    function snapshot(focus, state, updated) {
        return {schema_version:1,ok:true,data:{runtime:{state:state,snapshot:{state:"running",focus:focus,updated:updated,active_peer:"peer"}},peers:[{node_id:"peer",name:"Other PC"}]}};
    }
    function test_only_active_incoming_control() {
        compare(Model.incoming(snapshot("Controlled","running",100),101).active,true);
        compare(Model.incoming(snapshot("Controlled","running",100),101).peerName,"Other PC");
        for (const focus of ["Local","Armed","Controlling","Window","Reserved","Yielding"])
            compare(Model.incoming(snapshot(focus,"running",100),101).active,false,focus);
        compare(Model.incoming(snapshot("Controlled","stopped",100),101).active,false);
        compare(Model.incoming(snapshot("Controlled","running",100),106).active,false);
        compare(Model.incoming(snapshot("Controlled","running",110),100).active,false);
        compare(Model.incoming(null,100).active,false);
        compare(Model.incoming({schema_version:2,ok:true},100).active,false);
    }
    function test_indicator_visibility_click_and_pulse() {
        indicator.active=false;
        verify(!indicator.visible);
        indicator.peerName="Other PC";
        indicator.active=true;
        verify(indicator.visible);
        verify(indicator.description.includes("Other PC"));
        activated.clear();
        mouseClick(indicator,15,15);
        compare(activated.count,1);
        indicator.animationsEnabled=true;
        tryCompare(indicator,"lit",false,1000);
        indicator.animationsEnabled=false;
        compare(indicator.lit,true);
        indicator.active=false;
    }
}
