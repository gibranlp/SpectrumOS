import QtQuick
import Spectrum.I18n 1.0
import QtTest
import Qt.labs.folderlistmodel
import "../../configs/spectrum-ukvm" as Ukvm
import "../../configs/spectrum-ukvm/UkvmModel.js" as Model

TestCase {
    id: test
    readonly property var languageController: Translator
    name: "SpectrumUkvm"
    visible: true
    width: 1050; height: 900
    when: windowShown
    QtObject {
        id: theme
        property var colors: ({background:"#15131a", surface:"#232029", surface_alt:"#2e2c34", foreground:"#eff3fa", muted:"#a6afbe", accent:"#b293e6"})
        property string fontFamily: "monospace"
        property int fontSize: 12
    }
    QtObject {
        id: backend
        property var status: ({node:{name:"Local"}, peers:[{name:"<b>Peer</b>",node_id:"a".repeat(64),trusted:true,permissions:{connect:true,control_this_node:false},position:null,availability:{state:"offline"}}],layout:{nodes:[{name:"Local",local:true,x:0,y:0,node_id:"b".repeat(64)}],valid:true},service:{available:true,active_state:"inactive",unit_file_state:"disabled",load_state:"loaded"},runtime:{state:"stopped"}})
        property var doctor: ({})
        property var machines: []
        property var recovery: []
        property bool installed: true
        property bool compatible: true
        property bool applyPending: false
        property bool busy: false
        property bool sending: false
        property var transfer: null
        property bool pairing: false
        property bool discovering: false
        property string error: ""
        property string notice: ""
        property string pairingPhase: ""
        property var offer: null
        property var controlOffer: null
        signal remoteOpened()
        property var actions: []
        property var decisions: []
        property var sends: []
        function sendFiles(paths, peer) { sends = sends.concat([{paths:paths,peer:peer}]); }
        function action(args) { actions = actions.concat([args]); }
        function authorizeControl(peerId) { action(["peer", "allow", peerId, "control-this-node"]); }
        function decideControl(allow) {
            const peerId = controlOffer.node_id;
            controlOffer = null;
            if (allow) authorizeControl(peerId);
        }
        function refresh() {}
        function run(args) { action(args); }
        function startPair(endpoint, expected) { pairing = true; }
        function approve(accept) { decisions = decisions.concat([Model.approval(offer, accept)]); offer = null; }
        function cancelPair() { pairing = false; offer = null; }
    }
    Ukvm.UkvmPage { id: page; anchors.fill: parent; theme: theme; backend: backend }
    function test_background_runtime_changes_keep_peer_delegates_and_focus() {
        const originalStatus=backend.status;
        wait(30);
        const row=findChild(page,"peer-" + "a".repeat(64));
        verify(row !== null);
        const previousPeers=page.peers;
        const next=JSON.parse(JSON.stringify(backend.status));
        next.runtime={state:"running",counter:42};
        backend.status=next;
        wait(30);
        compare(page.peers,previousPeers);
        verify(findChild(page,"peer-" + "a".repeat(64)) === row);
        next.peers[0].permissions.control_this_node=true;
        backend.status=JSON.parse(JSON.stringify(next));
        verify(page.peers[0].permissions.control_this_node);
        backend.status=originalStatus;
    }
    function init() {
        backend.actions = [];
        backend.sends = [];
        page.pickerMode = "";
        backend.decisions = [];
        backend.busy = false;
        backend.offer = null;
        backend.controlOffer = null;
        backend.pairing = false;
        page.selectedId = "";
        page.showDetails = false;
        page.showHealthDetails = false;
        backend.machines = [];
        backend.error = "";
        backend.notice = "";
        page.healthPage = 0;
        page.peerPage = 0;
        page.discoveryPage = 0;
        test.width = 1050; test.height = 900;
        theme.fontSize = 12;
    }
    function test_fresh_pairing_requires_separate_named_control_choice() {
        backend.controlOffer = Model.pairedControlOffer({created:true,peer:{id:"a".repeat(64),alias:"<b>io</b>",permissions:{connect:true,control_this_node:false}}});
        wait(20);
        verify(findChild(page, "control-onboarding").visible);
        compare(findChild(page, "control-onboarding-title").text, "Allow <b>io</b> to control this computer");
        compare(findChild(page, "control-onboarding-title").textFormat, Text.PlainText);
        compare(backend.actions.length, 0);
        findChild(page, "decline-paired-control").clicked();
        compare(backend.actions.length, 0);
        verify(!findChild(page, "control-onboarding").visible);
        backend.controlOffer = {node_id:"a".repeat(64),name:"io"};
        findChild(page, "allow-paired-control").clicked();
        compare(JSON.stringify(backend.actions[0]), JSON.stringify(["peer", "allow", "a".repeat(64), "control-this-node"]));
        verify(!findChild(page, "control-onboarding").visible);
    }
    function test_existing_or_invalid_pairing_never_offers_automatic_changes() {
        const peer = {id:"a".repeat(64),alias:"io",permissions:{connect:true,control_this_node:false}};
        compare(Model.pairedControlOffer({created:false,peer:peer}), null);
        compare(Model.pairedControlOffer({created:true,peer:Object.assign({},peer,{id:"bad"})}), null);
        compare(Model.pairedControlOffer({created:true,peer:Object.assign({},peer,{permissions:{connect:true,control_this_node:true}})}), null);
        compare(backend.actions.length, 0);
    }
    function test_actions_execute_on_first_click() {
        verify(findChild(page, "ukvm-scroll") === null);
        findChild(page, "action-service-restart").clicked();
        compare(JSON.stringify(backend.actions[0]), JSON.stringify(["service", "restart"]));
        findChild(page, "action-apply").clicked();
        compare(JSON.stringify(backend.actions[1]), JSON.stringify(["apply"]));
        verify(findChild(page, "confirm-service-restart") === null);
    }
    function test_remote_view_permission_is_separate_from_launch() {
        const original = backend.status;
        backend.status = Object.assign({}, original, {peers:[{node_id:"a".repeat(64),name:"io",permissions:{connect:true,view_screen:false,control_this_node:false}}]});
        page.selectedId = "a".repeat(64);
        wait(20);
        const toggle = findChild(page, "view-screen-toggle");
        verify(toggle.enabled);
        verify(!toggle.checked);
        toggle.clicked();
        compare(JSON.stringify(backend.actions[0]), JSON.stringify(["peer","allow","a".repeat(64),"view-screen"]));
        verify(!toggle.checked);
        const launch = findChild(page, "open-remote");
        verify(launch.enabled);
        launch.clicked();
        compare(JSON.stringify(backend.actions[1]), JSON.stringify(["remote","a".repeat(64)]));
        backend.status = original;
    }
    function test_clipboard_permission_is_separate_and_explicit() {
        const original = backend.status;
        backend.status = Object.assign({}, original, {clipboard:{enabled:false,state:"disabled",connected_peers:0},
            peers:[Object.assign({}, original.peers[0], {permissions:{connect:true,control_this_node:false,share_clipboard:false}})]});
        page.selectedId = "a".repeat(64);
        wait(20);
        compare(Model.clipboardLabel(backend.status.clipboard), "Off");
        compare(Model.clipboardLabel({enabled:true,supported:true,connected_peers:2,state:"sharing"}), "Sharing text · 2 computers");
        compare(Model.clipboardLabel({enabled:true,supported:false,state:"unavailable"}), "Backend unavailable");
        const toggle = findChild(page, "share-clipboard-toggle");
        verify(toggle !== null);
        verify(!toggle.checked);
        verify(!toggle.checkable);
        compare(backend.actions.length, 0);
        mouseClick(toggle, toggle.width / 2, toggle.height / 2);
        compare(JSON.stringify(backend.actions[0]), JSON.stringify(["peer", "allow", "a".repeat(64), "share-clipboard"]));
        verify(!toggle.checked);
        backend.error = "Permission update failed";
        verify(!toggle.checked);
        compare(findChild(page, "operation-message").text, backend.error);
        backend.error = "";
        backend.status = Model.permissionResult(backend.status, {node_id:page.selectedId,permissions:{share_clipboard:true}}, page.selectedId);
        verify(toggle.checked);
        compare(backend.status.peers[0].permissions.control_this_node, false);
        mouseClick(toggle, toggle.width / 2, toggle.height / 2);
        verify(toggle.checked);
        compare(JSON.stringify(backend.actions[1]), JSON.stringify(["peer", "deny", "a".repeat(64), "share-clipboard"]));
        backend.status = Model.permissionResult(backend.status, {node_id:page.selectedId,permissions:{share_clipboard:false}}, page.selectedId);
        verify(!toggle.checked);
        backend.busy = true;
        verify(!toggle.enabled);
        backend.busy = false;
        backend.status = original;
    }
    function test_file_permission_is_live_and_separate_with_no_optimistic_grant() {
        const original = backend.status;
        backend.status = Object.assign({}, original, {files:{supported:true,state:"available",transfers:[]},
            peers:[Object.assign({}, original.peers[0], {permissions:{connect:true,control_this_node:true,share_clipboard:true,receive_files:false}})]});
        page.selectedId = "a".repeat(64);
        wait(20);
        const toggle = findChild(page, "receive-files-toggle");
        verify(toggle.enabled);
        verify(!toggle.checked);
        mouseClick(toggle, toggle.width / 2, toggle.height / 2);
        compare(JSON.stringify(backend.actions[0]), JSON.stringify(["peer", "allow", page.selectedId, "receive-files"]));
        verify(!toggle.checked);
        backend.error = "Permission denied";
        verify(!toggle.checked);
        backend.status = Model.permissionResult(backend.status, {node_id:page.selectedId,permissions:{receive_files:true,control_this_node:true,share_clipboard:true}}, page.selectedId);
        verify(toggle.checked);
        verify(backend.status.peers[0].permissions.control_this_node);
        verify(backend.status.peers[0].permissions.share_clipboard);
        backend.sending = true;
        verify(toggle.enabled);
        toggle.clicked();
        compare(JSON.stringify(backend.actions[1]), JSON.stringify(["peer", "deny", page.selectedId, "receive-files"]));
        verify(toggle.checked);
        backend.sending = false;
        backend.status = original;
    }
    function test_desktop_authorization_reset_is_direct_and_independent_of_peer_permissions() {
        const original = backend.status;
        backend.status = Object.assign({}, original, {desktop_authorization: {
            remote_desktop: {state:"persistent",active:true,remembered:true},
            input_capture: {state:"unsupported"}
        }});
        page.showHealthDetails = true;
        page.healthPage = 1;
        wait(20);
        compare(Model.authorizationLabel(backend.status), "Persistent");
        compare(Model.authorizationLabel(backend.status, "input_capture"), "Persistence unavailable");
        const reset = findChild(page, "action-authorization-reset");
        verify(reset.visible);
        reset.clicked();
        compare(JSON.stringify(backend.actions[0]), JSON.stringify(["authorization", "reset", "--yes"]));
        compare(backend.status.peers[0].permissions.control_this_node, false);
        backend.status = original;
    }
    function test_picker_home_and_local_url_encoding() {
        const picker = findChild(page,"ukvm-file-picker");
        verify(picker.homeFolder.toString().startsWith("file:///"));
        compare(picker.localUrl("/tmp/a #你好.txt"),"file:///tmp/a%20%23%E4%BD%A0%E5%A5%BD.txt");
        compare(picker.localUrl(Qt.resolvedUrl("../fixtures/ukvm-picker/")),Qt.resolvedUrl("../fixtures/ukvm-picker/").toString());
    }
    function test_inline_picker_selection_cancel_escape_and_palette() {
        page.selectedId = "a".repeat(64);
        page.openPicker("files");
        const picker = findChild(page,"ukvm-file-picker");
        const folder = Qt.resolvedUrl("../fixtures/ukvm-picker/");
        picker.open(folder);
        tryCompare(picker,"folderStatus",FolderListModel.Ready);
        tryCompare(picker,"entryCount",1);
        verify(picker.visible);
        compare(picker.color.toString(),theme.colors.surface);
        tryVerify(() => findChild(picker,"file-picker-entry-0") !== null);
        const entry = findChild(picker,"file-picker-entry-0");
        mouseClick(entry,entry.width/2,entry.height/2);
        compare(picker.selectedUrls.length,1);
        compare(entry.background.border.color.toString(),theme.colors.accent);
        const up = findChild(picker,"file-picker-up");
        verify(up.enabled);
        up.clicked();
        tryCompare(picker,"currentFolder",Qt.resolvedUrl("../fixtures/").toString().replace(/\/$/,""));
        picker.open(folder);
        tryCompare(picker,"folderStatus",FolderListModel.Ready);
        tryCompare(picker,"entryCount",1);
        picker.chooseEntry(0);
        verify(picker.selectedUrls[0].endsWith("pacman-multilib.conf"));
        const send = findChild(picker,"file-picker-send");
        verify(send.enabled);
        send.clicked();
        compare(page.pickerMode,"");
        compare(backend.sends.length,1);
        compare(backend.sends[0].peer,page.selectedId);
        page.openPicker("files");
        findChild(picker,"file-picker-cancel").clicked();
        compare(page.pickerMode,"");
        compare(backend.sends.length,1);
        page.openPicker("folder");
        picker.open(folder);
        tryCompare(picker,"folderStatus",FolderListModel.Ready);
        findChild(picker,"file-picker-filter").forceActiveFocus();
        keyClick(Qt.Key_Escape);
        tryCompare(page,"pickerMode","");
        compare(backend.sends.length,1);
    }
    function test_folder_picker_sends_current_folder() {
        page.selectedId = "a".repeat(64);
        page.openPicker("folder");
        const picker = findChild(page,"ukvm-file-picker");
        const folder = Qt.resolvedUrl("../fixtures/ukvm-picker/");
        picker.open(folder);
        tryCompare(picker,"folderStatus",FolderListModel.Ready);
        const send = findChild(picker,"file-picker-send");
        verify(send.enabled);
        send.clicked();
        compare(backend.sends.length,1);
        compare(backend.sends[0].paths[0],folder.toString());
    }
    function test_discovery_combines_runtime_pairing_and_excludes_local_without_name_matching() {
        const id = "a".repeat(64), local = "b".repeat(64);
        const runtime = {name:"Peer",advertised_node_id:id,pairing_available:false,addresses:["10.0.0.2:24800"]};
        const pairing = {name:"Peer",advertised_node_id:id,pairing_available:true,addresses:["10.0.0.2:25000"]};
        const other = {name:"Peer",advertised_node_id:"c".repeat(64),pairing_available:true,addresses:["10.0.0.3:25000"]};
        const rows = Model.discoveryMachines([runtime,pairing,other,{advertised_node_id:local}],local);
        compare(rows.length,2);
        compare(rows[0].addresses[0],"10.0.0.2:25000");
        verify(rows[0].pairing_available);
        compare(Model.discoveryMachines([pairing,runtime],local)[0].addresses[0],"10.0.0.2:25000");
    }
    function test_completed_transfers_disappear_even_with_stale_status() {
        const own = {id:"1",state:"completed"};
        compare(Model.activeTransfer(false,own,[{id:"1",state:"transferring"},{id:"2",state:"completed"}]),null);
        compare(Model.activeTransfer(true,own,[{id:"1",state:"transferring"}]),null);
        compare(Model.activeTransfer(false,own,[{id:"3",state:"receiving"}]),null);
        compare(Model.activeTransfer(false,own,[{id:"3",state:"verifying"}]).id,"3");
    }
    function test_send_buttons_are_visible_in_topology_when_details_open() {
        const original = backend.status;
        backend.status = Object.assign({},original,{files:{state:"available"}});
        page.selectedId = "a".repeat(64);
        page.showDetails = true;
        wait(20);
        try {
            const files = findChild(page,"send-files"), folder = findChild(page,"send-folder");
            verify(files.visible && files.enabled);
            verify(folder.visible && folder.enabled);
            page.selectedId = "";
            verify(files.visible && !files.enabled);
        } finally { backend.status = original; }
    }
    function test_discovery_shows_only_name_and_details_are_opt_in() {
        backend.machines = [{name:"Laptop", addresses:["192.168.1.40"], advertised_node_id:"c".repeat(64), pairing_available:true, matches_trusted_id:true}];
        wait(20);
        const label = findChild(page, "discovery-name-0");
        verify(label !== null);
        compare(label.text, "Laptop");
        compare(label.textFormat, Text.PlainText);
        verify(!page.showHealthDetails);
        verify(!page.showDetails);
    }
    function test_topology_model() {
        compare(Model.slots().length, 9);
        compare(Model.nodeAt(backend.status.layout.nodes, 0, 0).name, "Local");
        compare(Model.nodeAt([], 1, 0), null);
        compare(Model.availability({availability:{state:"future"}}), "unknown");
        compare(Model.availability({availability:{state:"unavailable"}}), "unavailable");
        compare(Model.serviceLabel(backend.status), "Service disabled");
    }
    function test_place_uses_identity_and_no_direct_config() {
        page.selectedId = "a".repeat(64);
        page.place(-1,0);
        compare(backend.actions.length, 1);
        compare(JSON.stringify(backend.actions[0]), JSON.stringify(["layout","place","-1","0","a".repeat(64)]));
    }
    function test_unpair_executes_once_on_click() {
        page.selectedId = "a".repeat(64);
        findChild(page, "action-unpair-" + "a".repeat(64)).clicked();
        compare(backend.actions.length, 1);
        compare(JSON.stringify(backend.actions[0]), JSON.stringify(["unpair","a".repeat(64),"--yes"]));
    }
    function test_busy_blocks_mutation() {
        backend.busy = true;
        page.selectedId = "a".repeat(64);
        page.place(1,0);
        page.perform(["layout","remove","a".repeat(64),"--yes"]);
        compare(backend.actions.length, 0);
    }
    function test_pairing_never_automatically_approves() {
        backend.pairing = true;
        backend.offer = {remote_name:"<b>Untrusted label</b>",remote_node_id:"a".repeat(64),verification_code:"1234-5678"};
        wait(30);
        compare(backend.decisions.length, 0);
        const approve = findChild(page, "approvePairing");
        verify(approve.enabled);
        approve.forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(backend.decisions.length, 1);
        compare(backend.decisions[0].remote_node_id, "a".repeat(64));
        compare(backend.decisions[0].verification_code, "1234-5678");
        verify(backend.decisions[0].accept);
        verify(!approve.enabled);
    }
    function test_approval_fails_without_offer() {
        verify(!findChild(page, "approvePairing").enabled);
        verify(!Model.offerValid({remote_node_id:"a".repeat(64)}));
        verify(!Model.offerValid(null));
    }
    function test_backend_classification_uses_versions_and_structured_state() {
        compare(Model.backendState({portal:{available:false}}), "backend_missing");
        compare(Model.backendState({portal:{available:true},input_capture:{version:1},remote_desktop:{version:1}}), "incompatible_backend");
        const ready = {portal:{available:true},backend_state:"backend_ready"};
        compare(Model.backendState(ready), "backend_ready");
        verify(Model.healthLabel({service:{available:true},runtime:{state:"stopped"}},ready).includes("consent"));
        compare(Model.healthLabel({service:{available:true,active_state:"failed"}},ready), "Service needs attention");
    }
    function test_first_run_initialization_requires_user_action() {
        const original = backend.status;
        backend.status = {node:{name:"Fresh computer"},health:{identity_initialized:false},service:{available:true},layout:{nodes:[],valid:true}};
        wait(20);
        const button = findChild(page, "initializeNode");
        try {
            verify(button.enabled);
            compare(backend.actions.length, 0);
            button.clicked();
            compare(JSON.stringify(backend.actions[0]),JSON.stringify(["setup","--local","--name","Fresh computer"]));
        } finally {
            backend.status = original;
        }
    }
    function test_backend_errors() {
        verify(Model.backendProblems({portal:{available:false,error:"No session bus"},remote_desktop:{error:"Backend missing"}}).join(" ").includes("Backend missing"));
        compare(Model.backendProblems({}).length, 0);
    }
    function test_theme_binding_and_plain_text() {
        page.selectedId = "a".repeat(64);
        const chip = findChild(page, "peer-" + page.selectedId);
        verify(chip !== null);
        compare(chip.contentItem.textFormat, Text.PlainText);
        verify(chip.contentItem.text.indexOf("<b>Peer</b>") >= 0);
        const previous = theme.colors;
        theme.colors = Object.assign({}, theme.colors, {accent:"#123456"});
        compare(chip.background.color.toString(), "#123456");
        theme.colors = previous;
        compare(Model.permissionLabel(null), "unknown");
        compare(Model.permissionLabel(false), "denied");
        compare(Model.permissionLabel(true), "allowed");
    }
    function test_permission_result_rejects_wrong_peer_or_invalid_state() {
        const original = backend.status;
        for (const data of [{node_id:"c".repeat(64),permissions:{share_clipboard:true}}, {node_id:"a".repeat(64),permissions:{share_clipboard:"true"}}, {}]) {
            let rejected = false;
            try { Model.permissionResult(original, data, "a".repeat(64)); } catch (e) { rejected = true; }
            verify(rejected);
        }
        compare(backend.status, original);
    }
    function test_active_transfer_and_permissions_fit_without_scrolling() {
        const original = backend.status;
        test.width = 760; test.height = 630;
        backend.status = Object.assign({}, original, {files:{supported:true,state:"available",transfers:[]},
            peers:[Object.assign({}, original.peers[0], {position:{x:1,y:0},permissions:{connect:true,control_this_node:true,share_clipboard:true,receive_files:true}})]});
        backend.transfer = {id:"b".repeat(32),name:"binary.bin",peer_name:"Peer",direction:"send",state:"transferring",bytes:4,total_bytes:10};
        backend.sending = true;
        page.selectedId = "a".repeat(64);
        wait(30);
        try {
            const panel = findChild(page, "peer-panel");
            for (const name of ["open-remote", "view-screen-toggle", "receive-files-toggle", "share-clipboard-toggle", "action-peer-deny", "action-unpair-" + "a".repeat(64)]) {
                const child = findChild(page, name);
                const position = child.mapToItem(panel, 0, 0);
                verify(position.y >= 0 && position.y + child.height <= panel.height, name + " fits inside peer panel");
            }
            const actions = findChild(page, "files-actions");
            const actionPosition = actions.mapToItem(page, 0, 0);
            verify(actionPosition.x >= 0 && actionPosition.y >= 0);
            verify(actionPosition.x + actions.width <= page.width);
            verify(actionPosition.y + actions.height <= page.height);
            const bar = findChild(page, "file-progress");
            compare(bar.visualPosition, 0.4);
            compare(bar.contentItem.children[0].color.toString(), theme.colors.accent);
            verify(findChild(page, "ukvm-scroll") === null);
            backend.status = Object.assign({}, backend.status, {files:{state:"unavailable",error:"Transfer history unreadable"}});
            compare(findChild(page, "operation-message").text, "Transfer history unreadable");
        } finally {
            backend.sending = false;
            backend.transfer = null;
            backend.status = original;
        }
    }
    function test_bounded_layout_at_laptop_sizes_data() {
        return [{tag:"normal",w:920,h:780,font:12}, {tag:"laptop",w:760,h:630,font:12}, {tag:"large-font",w:760,h:630,font:24}];
    }
    function test_bounded_layout_at_laptop_sizes(data) {
        test.width = data.w; test.height = data.h;
        theme.fontSize = data.font;
        page.selectedId = "a".repeat(64);
        backend.machines = Array.from({length:12}, (_,i) => ({name:"Laptop " + i,pairing_available:true,addresses:["192.168.1.40"]}));
        wait(30);
        verify(findChild(page, "ukvm-scroll") === null);
        const content = findChild(page, "ukvm-content");
        compare(content.height, page.height);
        for (const name of ["topology", "peer-panel", "discovery-panel"]) {
            const item = findChild(page, name);
            const point = item.mapToItem(page, 0, 0);
            verify(point.x >= -1 && point.y >= -1, name);
            verify(point.x + item.width <= page.width + 1, name + " width");
            verify(point.y + item.height <= page.height + 1, name + " height");
        }
        const toggle = findChild(page, "share-clipboard-toggle");
        const point = toggle.mapToItem(page, 0, 0);
        verify(point.y + toggle.height <= page.height, "toggle fits");
        compare(page.listedMachines.length, 2);
        page.discoveryPage = 1;
        compare(page.listedMachines[0].name, "Laptop 2");
    }
    function test_schema_rejection() {
        let rejected = false;
        try { Model.envelope('{"schema_version":2,"integration_version":1}'); } catch (e) { rejected = true; }
        verify(rejected);
    }
}
