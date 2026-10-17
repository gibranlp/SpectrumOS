import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

TestCase {
    id: tests
    name: "SpectrumDrop"
    visible: true
    width: 640; height: 600
    when: windowShown
    QtObject {
        id: theme
        property var colors: ({foreground:"#eeeeee",surface_alt:"#333333",accent:"#66ccee",muted:"#aaaaaa"})
        property string fontFamily: "monospace"
        property int fontSize: 12
    }
    QtObject {
        id: backend
        property bool busy: false
        property bool scanning: false
        property var peers: []
        property var state: ({available:true,receiving:false,visible:false,transfer:{}})
        property string error: ""
        property var calls: []
        function command(args) { calls = calls.concat([args]); }
        function scan() { calls = calls.concat([["scan"]]); }
    }
    Shell.SpectrumDrop { id: editor; anchors.fill: parent; theme: theme; backend: backend }
    function init() {
        backend.busy=false; backend.scanning=false; backend.peers=[]; backend.error="";
        backend.state={available:true,receiving:false,visible:false,transfer:{}}; backend.calls=[];
    }
    function test_receive_window_is_direct() {
        const button=findChild(editor,"drop-receive-5");
        mouseClick(button,button.width/2,button.height/2);
        compare(backend.calls.length,1); compare(backend.calls[0][0],"receive"); compare(backend.calls[0][1],"5");
    }
    function test_search_disabled_until_visible() {
        const button=findChild(editor,"drop-scan");
        verify(!button.enabled);
        backend.state={available:true,receiving:true,visible:true,transfer:{}};
        verify(button.enabled); button.clicked(); compare(backend.calls[0][0],"scan");
    }
    function test_peer_sends_to_exact_address() {
        backend.state={available:true,receiving:true,visible:true,transfer:{}};
        backend.peers=[{name:"Mac",mac:"02:11:22:33:44:55"}];
        tryVerify(() => findChild(editor,"drop-send-02:11:22:33:44:55") !== null);
        findChild(editor,"drop-send-02:11:22:33:44:55").clicked();
        compare(backend.calls[0][0],"send"); compare(backend.calls[0][1],"02:11:22:33:44:55");
    }
    function test_active_transfer_keeps_cancel_and_blocks_stop() {
        backend.state={available:true,receiving:true,visible:true,transfer:{active:true,message:"Sending…"}};
        verify(!findChild(editor,"drop-stop").enabled);
        verify(!findChild(editor,"drop-receive-5").enabled);
        findChild(editor,"drop-cancel").clicked(); compare(backend.calls[0][0],"cancel");
    }
    function test_expired_window_can_restore_wifi() {
        backend.state={available:true,receiving:false,visible:false,radio_owned:true,transfer:{}};
        const stop=findChild(editor,"drop-stop");
        verify(stop.enabled); stop.clicked(); compare(backend.calls[0][0],"stop");
    }
    function test_failed_transfer_is_explicit_and_visible_above_devices() {
        backend.state={transfer:{active:false,phase:"failed",message:"Recipient unavailable"}};
        const status=findChild(editor,"drop-transfer-status");
        verify(status.visible);
        compare(status.text,"Send failed: Recipient unavailable");
    }
    function test_error_and_progress_are_plain_text() {
        backend.error="<b>Failure</b>";
        backend.state={transfer:{message:"<img>"}};
        compare(findChild(editor,"drop-error").textFormat,Text.PlainText);
        compare(findChild(editor,"drop-transfer-status").textFormat,Text.PlainText);
    }
}
