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
        property var colors: ({surface:"#222222",background:"#111111",foreground:"#eeeeee",surface_alt:"#333333",accent:"#66ccee",muted:"#aaaaaa"})
        property string fontFamily: "monospace"
        property int fontSize: 12
    }
    QtObject {
        id: backend
        property string transport: "airdrop"
        property var lastPayload: ({})
        property bool busy: false
        property bool scanning: false
        property var peers: []
        property var state: ({available:true,receiving:false,visible:false,transfer:{}})
        property string error: ""
        property var calls: []
        function command(args, payload) { calls = calls.concat([args]); lastPayload = payload || {}; }
        function selectTransport(value) { transport = value; }
        function scan() { calls = calls.concat([["scan"]]); }
    }
    Shell.SpectrumDrop { id: editor; anchors.fill: parent; theme: theme; backend: backend }
    function init() {
        backend.transport="airdrop";backend.lastPayload={};
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
    function test_network_discovery_does_not_require_receiving() {
        backend.transport="pc";
        backend.state={available:true,receiving:false,visible:false,transfer:{},lan:{receiving:false,incoming:[]}};
        const search=findChild(editor,"drop-scan");
        verify(search.enabled);search.clicked();compare(backend.calls[0][0],"scan");
        findChild(editor,"drop-receive-5").clicked();compare(backend.calls[1][0],"receive-lan");
    }
    function test_network_send_uses_private_payload_and_clears_code() {
        backend.transport="pc";
        backend.peers=[{name:"Other Spectrum",mac:"lan:0123456789abcdef0123456789abcdef",transport:"lan"}];
        const id="lan:0123456789abcdef0123456789abcdef";
        tryVerify(()=>findChild(editor,"drop-code-"+id)!==null);
        const code=findChild(editor,"drop-code-"+id),send=findChild(editor,"drop-send-"+id);
        verify(!send.enabled);code.text="ABCD-EFGH-JKLM-NPQR";verify(send.enabled);send.clicked();
        compare(backend.calls[0][0],"send-lan");compare(backend.lastPayload.code,"ABCD-EFGH-JKLM-NPQR");compare(code.text,"");
    }
    function test_incoming_transfer_requires_explicit_acceptance() {
        backend.transport="pc";
        backend.state={transfer:{},lan:{receiving:true,code:"ABCDEFGHIJKLMNOP",incoming:[{id:"abc",sender:"Other Spectrum",phase:"pending",files:[{name:"photo.png",size:128}],total:128,bytes:0}]}};
        tryVerify(()=>findChild(editor,"drop-accept-abc")!==null);
        compare(backend.calls.length,0);
        findChild(editor,"drop-accept-abc").clicked();compare(backend.calls[0][0],"accept-lan");compare(backend.calls[0][1],"abc");
    }

    function test_pair_request_uses_code_once_and_clears_it() {
        backend.transport="pc";
        const id="lan:0123456789abcdef0123456789abcdef";
        backend.peers=[{id:id.slice(4),name:"Other PC",mac:id,fingerprint:"b".repeat(64)}];
        tryVerify(()=>findChild(editor,"drop-pair-"+id)!==null);
        const code=findChild(editor,"drop-code-"+id),pair=findChild(editor,"drop-pair-"+id);
        verify(!pair.enabled);code.text="ABCD-EFGH-JKLM-NPQR";verify(pair.enabled);pair.clicked();
        compare(backend.calls[0],["pair-lan",id]);compare(backend.lastPayload.code,"ABCD-EFGH-JKLM-NPQR");compare(code.text,"");
    }

    function test_paired_pc_sends_without_code_and_can_be_forgotten() {
        backend.transport="pc";
        const id="0123456789abcdef0123456789abcdef",fingerprint="b".repeat(64);
        backend.state={transfer:{},lan:{paired:[{id:id,name:"Saved PC",fingerprint:fingerprint}]}};
        backend.peers=[{id:id,name:"Saved PC",mac:"lan:"+id,fingerprint:fingerprint}];
        tryVerify(()=>findChild(editor,"drop-send-lan:"+id)!==null);
        verify(!findChild(editor,"drop-code-lan:"+id).visible);
        const send=findChild(editor,"drop-send-lan:"+id);verify(send.enabled);send.clicked();
        compare(backend.calls[0],["send-lan","lan:"+id]);compare(backend.lastPayload.code,"");
        findChild(editor,"drop-forget-"+id).clicked();compare(backend.calls[1],["forget-lan",id]);
    }

    function test_saved_pc_can_send_without_discovery() {
        backend.transport="pc";
        const id="0123456789abcdef0123456789abcdef";
        backend.state={transfer:{},lan:{paired:[{id:id,name:"Saved PC",fingerprint:"b".repeat(64)}]}};
        tryVerify(()=>findChild(editor,"drop-saved-send-"+id)!==null);
        findChild(editor,"drop-saved-send-"+id).clicked();
        compare(backend.calls[0],["send-lan","lan:"+id]);compare(backend.lastPayload.code,"");
    }

    function test_changed_identity_blocks_nearby_send() {
        backend.transport="pc";
        const id="0123456789abcdef0123456789abcdef";
        backend.state={transfer:{},lan:{paired:[{id:id,name:"Saved PC",fingerprint:"b".repeat(64)}]}};
        backend.peers=[{id:id,name:"Saved PC",mac:"lan:"+id,fingerprint:"c".repeat(64)}];
        tryVerify(()=>findChild(editor,"drop-send-lan:"+id)!==null);
        verify(!findChild(editor,"drop-send-lan:"+id).enabled);
    }

    function test_pairing_needs_explicit_local_consent() {
        backend.transport="pc";
        backend.state={transfer:{},lan:{pair_requests:[{id:"abc",name:"Other PC"}]}};
        tryVerify(()=>findChild(editor,"drop-accept-pair-abc")!==null);
        compare(backend.calls.length,0);
        findChild(editor,"drop-accept-pair-abc").clicked();compare(backend.calls[0],["accept-pair-lan","abc"]);
        findChild(editor,"drop-decline-pair-abc").clicked();compare(backend.calls[1],["decline-pair-lan","abc"]);
    }

    function test_thunar_selection_is_visible_and_clears_in_the_current_transport() {
        backend.transport="pc";
        backend.state={selection:{count:2,names:["code <test>.py","notes.txt"]},transfer:{}};
        verify(findChild(editor,"drop-selected-files").visible);
        compare(findChild(editor,"drop-selection-summary").text,"2 files selected in Thunar");
        compare(backend.calls.length,0);
        findChild(editor,"drop-clear-selection").clicked();
        compare(backend.calls[0],["clear-selection","pc"]);
        backend.state={selection:{count:0,names:[]},transfer:{}};
        verify(!findChild(editor,"drop-selected-files").visible);
    }

    function test_thunar_selection_reveals_recipient_view_at_top() {
        backend.transport="pc";
        backend.state={selection:{count:1,names:["photo.png"]},transfer:{},lan:{receiving:false,incoming:[{id:"old",phase:"cancelled",files:[]}]}};
        tryVerify(()=>editor.choosingRecipient);
        editor.contentItem.contentY=120;
        editor.revealSelection();
        compare(editor.contentItem.contentY,0);
        verify(findChild(editor,"drop-choose-recipient").visible);
        verify(!findChild(editor,"drop-receive-5").visible);
        verify(findChild(editor,"drop-accept-old")===null);
        backend.state={selection:{count:1,names:["another.png"]},transfer:{},lan:{}};
        tryCompare(editor.contentItem,"contentY",0);
    }

}
