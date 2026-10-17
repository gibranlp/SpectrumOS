pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "UkvmModel.js" as Model

Item {
    id: state
    property bool active: false
    property string adapter: "/usr/lib/spectrumos/ukvm-adapter"
    property var status: ({})
    property var doctor: ({})
    property var machines: []
    property var recovery: []
    property bool installed: true
    property bool compatible: false
    property bool applyPending: false
    property string error: ""
    property string notice: ""
    property string pairingPhase: ""
    property var offer: null
    property bool pairingResult: false
    property var controlOffer: null
    property string controlApplyPeer: ""
    property bool controlApplyReady: false
    property var requested: []
    property var queued: []
    property bool requestReceived: false
    property var transfer: null
    property bool transferResult: false
    property string completionNotice: ""
    readonly property bool sending: upload.running
    property var pendingRequest: []
    readonly property bool busy: pair.running || pendingRequest.length > 0 || (request.running && !Model.isStatusRequest(requested))
    readonly property bool pairing: pair.running
    readonly property bool discovering: request.running && requested[0] === "discover"

    signal remoteOpened()

    function refresh() {
        if (request.running || pair.running || pendingRequest.length) return;
        queued = [["doctor"], ["pair", "status"]];
        run(["status"]);
    }
    function run(args) {
        if (pair.running) return;
        if (request.running) {
            if (!Model.isStatusRequest(args)) pendingRequest = args;
            return;
        }
        requested = args;
        requestReceived = false;
        request.command = [adapter, "request", JSON.stringify(args)];
        request.running = true;
    }
    function action(args) {
        if (busy || !compatible) return;
        error = "";
        notice = "";
        queued = [["status"], ["doctor"], ["pair", "status"]];
        run(args);
    }
    function authorizeControl(peerId) {
        if (busy || !compatible || !/^[0-9a-f]{64}$/.test(peerId)) return;
        controlApplyPeer = peerId;
        controlApplyReady = false;
        action(["peer", "allow", peerId, "control-this-node"]);
    }
    function decideControl(allow) {
        if (!controlOffer || busy) return;
        const peerId = controlOffer.node_id;
        controlOffer = null;
        if (allow) authorizeControl(peerId);
        else notice = "Pairing retained. Control remains denied. You can allow it from the selected computer later.";
    }
    function acceptPairResponse(text) {
        const response = Model.envelope(text);
        if (response.event === "confirmation_required") {
            if (!Model.offerValid(response.data)) throw new Error("Invalid verification offer");
            offer = response.data;
            pairingPhase = "Compare the verification code on BOTH machines.";
        } else if (response.event === "result") {
            pairingResult = true;
            offer = null;
            applyPending = response.apply_pending;
            if (response.ok) {
                controlOffer = Model.pairedControlOffer(response.data);
                notice = "Pairing complete. Control, clipboard sharing and file receiving are separate permissions.";
            } else error = response.error.message;
        } else if (response.event === "listening") {
            pairingPhase = "Ready for another machine to pair · " + response.data.endpoint;
            if (!response.data.discovery_available) notice = "Discovery unavailable. Use the displayed address directly.";
        } else if (response.event === "discovery_unavailable") notice = response.data.message;
        else if (response.event === "connecting") pairingPhase = "Connecting to " + response.data.endpoint;
    }
    function acceptResponse(text) {
        const response = Model.envelope(text);
        requestReceived = true;
        installed = response.installed;
        applyPending = response.apply_pending;
        if (!response.ok) {
            error = response.error.message;
            if (requested[0] === "status") compatible = false;
            return;
        }
        if (requested[0] === "status") { if (!Model.sameData(status, response.data)) status = response.data; compatible = true; }
        else if (requested[0] === "doctor") { if (!Model.sameData(doctor, response.data)) doctor = response.data; }
        else if (requested[0] === "discover") { const next = response.data.machines || []; if (!Model.sameData(machines, next)) machines = next; }
        else if (requested[0] === "pair") { const next = response.data.records || []; if (!Model.sameData(recovery, next)) recovery = next; }
        else if (requested[0] === "remote") {
            if (response.data.launched !== true) throw new Error("Remote window was not launched.");
            notice = "Remote window launched. Connection and permission status appear in that window.";
            remoteOpened();
        }
        else {
            if (requested[0] === "peer" && (requested[1] === "allow" || requested[1] === "deny")) {
                if (typeof (response.data.permissions || {})[requested[3].replace(/-/g, "_")] !== "boolean")
                    throw new Error("UKVM did not return the changed permission. Refresh before retrying.");
                status = Model.permissionResult(status, response.data, requested[2]);
                if (controlApplyPeer === requested[2] && requested[1] === "allow" && requested[3] === "control-this-node") {
                    if (response.data.permissions.control_this_node !== true)
                        throw new Error("Control permission was not granted. Refresh before retrying.");
                    controlApplyReady = true;
                }
            }
            const messages = {setup:"Ready. Enable login startup and start UKVM.", layout:"Position saved. Apply to use it.", peer:"Permission saved. Apply to use it.", unpair:"Computer removed.", apply:"Applied.", authorization:"Desktop authorization forgotten. Start UKVM and approve the portal again. Peer permissions are unchanged."};
            notice = requested[0] === "peer" && requested[3] === "share-clipboard"
                ? (requested[1] === "allow" ? "Clipboard permission enabled. Enable sharing on both computers." : "Clipboard sharing stopped for this computer.")
                : requested[0] === "peer" && requested[3] === "receive-files"
                    ? (requested[1] === "allow" ? "File receiving enabled for this computer." : "File receiving stopped for this computer.")
                    : requested[0] === "peer" && requested[3] === "view-screen"
                        ? (requested[1] === "allow" ? "This peer may view this screen. Portal consent and control remain separate." : "Screen viewing stopped for this peer.")
                    : requested[0] === "files" ? "Cancellation requested."
                    : messages[requested[0]] || "Service " + requested[1] + " completed.";
        }
    }
    function sendFiles(paths, peer) {
        if (sending || !compatible || !paths.length) return;
        error = "";
        completionMessage.stop();
        notice = "";
        transfer = null;
        transferResult = false;
        upload.command = [adapter, "send", JSON.stringify({peer:peer, paths:paths})];
        upload.running = true;
    }
    function acceptTransfer(text) {
        const response = Model.envelope(text);
        if (response.command !== "send") throw new Error("Wrong transfer response");
        if (response.event === "result") {
            transferResult = true;
            transfer = Object.assign({}, transfer || {}, {id:response.ok ? response.data.id : (transfer || {}).id,
                state:response.ok ? "completed" : "failed"});
            if (response.ok) {
                completionNotice = "File sent: " + response.data.destination;
                notice = completionNotice;
                completionMessage.restart();
            } else error = response.error.message;
        } else if (response.event === "started" || response.event === "progress") transfer = response.data;
        else throw new Error("Unknown transfer event");
    }
    function startPair(endpoint, expected) {
        if (busy || !compatible) return;
        error = "";
        notice = "";
        offer = null;
        controlOffer = null;
        pairingResult = false;
        pairingPhase = "Starting pairing…";
        let args = [adapter, "pair"];
        if (endpoint) {
            args.push(endpoint);
            if (expected) args.push("--expected-node-id", expected);
        }
        pair.command = args;
        pair.running = true;
    }
    function approve(accept) {
        if (!pair.running || !Model.offerValid(offer)) return;
        const reply = Model.approval(offer, accept);
        pair.write(JSON.stringify(reply) + "\n");
        offer = null;
        pairingPhase = accept ? "Waiting for the other machine's approval…" : "Rejecting pairing…";
    }
    function cancelPair() {
        if (!pair.running) return;
        offer = null;
        pairingPhase = "Cancelling pairing…";
        pair.signal(15);
    }
    onActiveChanged: {
        if (active) refresh();
        else cancelPair();
    }
    Timer { interval: 4000; repeat: true; running: state.active; onTriggered: {
        if (!state.busy) state.run(["status"]);
    } }
    Process {
        id: request
        stdout: StdioCollector { onStreamFinished: {
            try { state.acceptResponse(text); }
            catch (e) { state.error = "Invalid UKVM response: " + e.message; }
        } }
        onExited: (code) => {
            if (!state.requestReceived) state.error = "UKVM command interrupted or integration unavailable. Refresh before retrying.";
            if (state.controlApplyPeer && state.requested[0] === "peer") {
                const apply = code === 0 && state.controlApplyReady;
                state.controlApplyPeer = "";
                state.controlApplyReady = false;
                if (apply) {
                    Qt.callLater(() => state.run(["apply"]));
                    return;
                }
            }
            if (state.pendingRequest.length) {
                Qt.callLater(() => { const next = state.pendingRequest; state.pendingRequest = []; state.run(next); });
                return;
            }
            const next = state.queued.slice();
            state.queued = next.slice(1);
            if (next.length && state.installed && state.compatible && state.active)
                Qt.callLater(() => state.run(next[0]));
        }
    }
    Timer {
        id: completionMessage
        interval: 2500
        onTriggered: { if (state.notice === state.completionNotice) state.notice = ""; }
    }
    Process {
        id: upload
        stdout: SplitParser { onRead: line => {
            try { state.acceptTransfer(line); }
            catch (e) { state.error = "Invalid transfer status: " + e.message; upload.signal(15); }
        } }
        onExited: (code) => {
            if (!state.transferResult) state.error = "Transfer interrupted. Check receiver history before retrying.";
            Qt.callLater(() => state.refresh());
        }
    }
    Process {
        id: pair
        stdinEnabled: true
        stdout: SplitParser { onRead: line => {
            try {
                state.acceptPairResponse(line);
            } catch (e) {
                state.error = "Pairing protocol error: " + e.message;
                state.cancelPair();
            }
        } }
        onExited: (code) => {
            state.offer = null;
            state.pairingPhase = "";
            if (!state.pairingResult) state.error = "Pairing interrupted. Inspect refreshed peers and recovery state before retrying.";
            Qt.callLater(() => state.refresh());
        }
    }
}
