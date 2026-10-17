import QtQuick
import QtTest
import Quickshell
import "../../configs/spectrum-ukvm" as Ukvm

Scope {
    FloatingWindow {
        visible: true
        implicitWidth: 240; implicitHeight: 100
        Ukvm.UkvmState { id: backend; active: false; compatible: true; adapter: Quickshell.env("SPECTRUM_UKVM_TEST_ADAPTER") }
        TestCase {
            name: "UkvmPolling"
            when: true
            onCompletedChanged: if (completed) { console.log("Polling checks:",qtest_results.passCount,"passed",qtest_results.failCount,"failed"); Qt.quit(); }
            SignalSpy { id: changed; target: backend; signalName: "statusChanged" }
            function test_a_identical_status_preserves_model() {
                backend.status={peers:[{node_id:"a".repeat(64)}]};
                const previous=backend.status;
                changed.clear(); backend.requested=["status"];
                backend.acceptResponse(JSON.stringify({schema_version:1,integration_version:1,installed:true,ok:true,apply_pending:false,data:JSON.parse(JSON.stringify(previous))}));
                compare(changed.count,0);
                verify(backend.status === previous);
            }
            function test_b_poll_is_quiet_and_action_is_queued_once() {
                backend.run(["status"]);
                wait(30);
                verify(!backend.busy);
                backend.action(["service","restart"]);
                compare(backend.pendingRequest[0],"service");
                verify(backend.busy);
                backend.action(["service","stop"]);
                compare(backend.pendingRequest[1],"restart");
                tryCompare(backend,"notice","Service restart completed.",2000);
                tryCompare(backend,"busy",false);
                compare(backend.requested[1],"restart");
                compare(backend.pendingRequest.length,0);
            }
        }
    }
}
