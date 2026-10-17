import QtQuick
import QtTest
import Quickshell
import "." as Ukvm

Scope {
    FloatingWindow {
        visible: true
        implicitWidth: 500
        implicitHeight: 300
        Ukvm.UkvmState { id: backend; active: false; adapter: "/nonexistent-ukvm-test-adapter" }
        TestCase {
            name: "UkvmPermissionResponses"
            when: true
            onCompletedChanged: if (completed) {
                console.log("UKVM state checks:", qtest_results.passCount, "passed,", qtest_results.failCount, "failed");
                Qt.quit();
            }
            function init() {
                backend.status = {peers:[{node_id:"a".repeat(64), permissions:{control_this_node:true,share_clipboard:true}}]};
                backend.requested = ["peer", "deny", "a".repeat(64), "share-clipboard"];
                backend.error = "";
                backend.notice = "";
                backend.applyPending = true;
                backend.controlOffer = null;
                backend.controlApplyPeer = "";
                backend.controlApplyReady = false;
                backend.compatible = true;
                backend.adapter = Quickshell.env("SPECTRUM_UKVM_TEST_ADAPTER");
            }
            SignalSpy { id: remoteSpy; target: backend; signalName: "remoteOpened" }
            function test_view_permission_response_updates_live_without_control() {
                backend.requested = ["peer", "allow", "a".repeat(64), "view-screen"];
                backend.acceptResponse(JSON.stringify({schema_version:1,integration_version:1,installed:true,ok:true,apply_pending:false,
                    data:{node_id:"a".repeat(64),permissions:{view_screen:true,control_this_node:false,share_clipboard:true}}}));
                verify(backend.status.peers[0].permissions.view_screen);
                verify(!backend.status.peers[0].permissions.control_this_node);
                verify(!backend.controlApplyReady);
                verify(!backend.applyPending);
                verify(!backend.busy);
                backend.requested = ["peer", "deny", "a".repeat(64), "view-screen"];
                backend.acceptResponse(JSON.stringify({schema_version:1,integration_version:1,installed:true,ok:true,apply_pending:false,
                    data:{node_id:"a".repeat(64),permissions:{view_screen:false,control_this_node:false}}}));
                verify(!backend.status.peers[0].permissions.view_screen);
            }
            function test_remote_launch_closes_management_only_after_success() {
                remoteSpy.clear();
                backend.requested = ["remote", "a".repeat(64)];
                backend.acceptResponse(JSON.stringify({schema_version:1,integration_version:1,installed:true,ok:false,apply_pending:false,
                    error:{message:"Launch refused"}}));
                compare(remoteSpy.count, 0);
                backend.acceptResponse(JSON.stringify({schema_version:1,integration_version:1,installed:true,ok:true,apply_pending:false,data:{launched:true}}));
                compare(remoteSpy.count, 1);
            }
            function test_pair_success_offers_control_without_granting() {
                backend.acceptPairResponse(JSON.stringify({schema_version:1,integration_version:1,event:"result",ok:true,apply_pending:true,
                    data:{created:true,peer:{id:"a".repeat(64),alias:"io",permissions:{connect:true,control_this_node:false,share_clipboard:true,receive_files:true}}}}));
                compare(backend.controlOffer.name, "io");
                verify(!backend.busy);
                backend.decideControl(false);
                compare(backend.controlOffer, null);
                verify(!backend.busy);
            }
            function test_explicit_control_grant_runs_apply_and_preserves_other_permissions() {
                backend.status = {peers:[{node_id:"a".repeat(64),permissions:{connect:true,control_this_node:false,share_clipboard:true,receive_files:true}}]};
                backend.controlOffer = {node_id:"a".repeat(64),name:"io"};
                backend.decideControl(true);
                tryCompare(backend,"notice","Applied.",3000);
                verify(backend.status.peers[0].permissions.control_this_node);
                verify(backend.status.peers[0].permissions.share_clipboard);
                verify(backend.status.peers[0].permissions.receive_files);
                verify(!backend.applyPending);
                tryCompare(backend,"busy",false);
            }
            function test_failed_control_grant_never_runs_apply() {
                backend.authorizeControl("c".repeat(64));
                tryCompare(backend,"error","Permission refused",3000);
                tryCompare(backend,"busy",false);
                compare(backend.requested[0],"peer");
                verify(backend.applyPending);
            }
            function test_mismatched_control_response_never_runs_apply() {
                backend.authorizeControl("d".repeat(64));
                tryVerify(() => backend.error.indexOf("Invalid UKVM permission response") >= 0, 3000);
                tryCompare(backend,"busy",false);
                compare(backend.requested[0],"peer");
            }
            function test_apply_failure_keeps_saved_permission_and_pending_state() {
                backend.authorizeControl("f".repeat(64));
                tryCompare(backend,"error","Apply refused",3000);
                tryCompare(backend,"busy",false);
                verify(backend.applyPending);
            }
            function response(ok, data, error) {
                return JSON.stringify({schema_version:1,integration_version:1,installed:true,apply_pending:true,command:"peer",ok:ok,data:data,error:error});
            }
            function test_send_result_clears_progress_and_expires_success_message() {
                backend.transfer = {id:"b".repeat(32),state:"transferring",name:"sample.txt"};
                backend.acceptTransfer(JSON.stringify({schema_version:1,integration_version:1,command:"send",event:"result",ok:true,data:{id:"b".repeat(32),destination:"sample.txt"},error:null}));
                compare(backend.transfer.state,"completed");
                compare(backend.notice,"File sent: sample.txt");
                tryCompare(backend,"notice","",3500);
            }
            function test_failed_send_keeps_error_visible() {
                backend.transfer = {id:"b".repeat(32),state:"transferring"};
                backend.acceptTransfer(JSON.stringify({schema_version:1,integration_version:1,command:"send",event:"result",ok:false,data:null,error:{message:"Receiving denied"}}));
                compare(backend.transfer.state,"failed");
                compare(backend.error,"Receiving denied");
            }
            function test_confirmed_permission_updates_immediately_and_preserves_control() {
                backend.acceptResponse(response(true, {node_id:"a".repeat(64),permissions:{control_this_node:true,share_clipboard:false}}, null));
                compare(backend.status.peers[0].permissions.share_clipboard, false);
                verify(backend.status.peers[0].permissions.control_this_node);
                verify(backend.applyPending);
                backend.requested = ["peer", "allow", "a".repeat(64), "share-clipboard"];
                backend.acceptResponse(response(true, {node_id:"a".repeat(64),permissions:{control_this_node:true,share_clipboard:true}}, null));
                verify(backend.status.peers[0].permissions.share_clipboard);
                verify(backend.status.peers[0].permissions.control_this_node);
            }
            function test_failed_command_keeps_real_permission_and_surfaces_error() {
                backend.acceptResponse(response(false, null, {code:"operation_failed",message:"Permission update refused"}));
                verify(backend.status.peers[0].permissions.share_clipboard);
                verify(backend.status.peers[0].permissions.control_this_node);
                compare(backend.error, "Permission update refused");
                compare(backend.notice, "");
            }
            function test_invalid_success_response_does_not_change_permission() {
                let rejected = false;
                try { backend.acceptResponse(response(true, {node_id:"c".repeat(64),permissions:{share_clipboard:false}}, null)); }
                catch (e) { rejected = true; }
                verify(rejected);
                verify(backend.status.peers[0].permissions.share_clipboard);
            }
        }
    }
}
