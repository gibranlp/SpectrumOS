.pragma library

function envelope(text) {
    const result = JSON.parse(text);
    if (result.schema_version !== 1 || result.integration_version !== 1)
        throw new Error("Unsupported UKVM frontend contract. Update UKVM and SpectrumOS.");
    return result;
}
function slots() {
    return [{x:0,y:-2}, {x:0,y:-1}, {x:-2,y:0}, {x:-1,y:0}, {x:0,y:0},
            {x:1,y:0}, {x:2,y:0}, {x:0,y:1}, {x:0,y:2}];
}
function nodeAt(nodes, x, y) {
    return (nodes || []).find(n => n.x === x && n.y === y) || null;
}
function peerAt(peers, id) { return (peers || []).find(p => p.node_id === id) || null; }
function availability(peer) {
    const state = peer && peer.availability && peer.availability.state;
    return ["online", "offline", "unavailable"].indexOf(state) >= 0 ? state : "unknown";
}
function serviceLabel(status) {
    const service = status.service || {};
    if (!service.available) return qsTranslate("Spectrum", "Service unavailable");
    if (service.load_state === "not-found") return qsTranslate("Spectrum", "Service not installed");
    if (service.active_state === "active")
        return status.runtime && status.runtime.state === "running" ? qsTranslate("Spectrum", "Running") : qsTranslate("Spectrum", "Service active · runtime unavailable");
    if (service.unit_file_state === "disabled") return qsTranslate("Spectrum", "Service disabled");
    return qsTranslate("Spectrum", "Service ") + (service.active_state || qsTranslate("Spectrum", "unknown"));
}
function backendProblems(doctor) {
    if (!doctor || !doctor.portal) return [];
    const issues = [];
    if (!doctor.portal.available) issues.push(doctor.portal.error || qsTranslate("Spectrum", "Session portal unavailable."));
    ["input_capture", "remote_desktop"].forEach(key => {
        const value = doctor[key] || {};
        if (value.keyboard_advertised !== true || value.pointer_advertised !== true)
            issues.push((key === "input_capture" ? "InputCapture" : "RemoteDesktop") + ": " + (value.error || qsTranslate("Spectrum", "keyboard/pointer unavailable")));
    });
    if (!doctor.connect_to_eis_available) issues.push(qsTranslate("Spectrum", "ConnectToEIS unavailable. Check your Wayland desktop's portal backend."));
    return issues;
}
function offerValid(offer) {
    return offer && typeof offer.remote_node_id === "string" && /^[0-9a-f]{64}$/.test(offer.remote_node_id)
        && typeof offer.verification_code === "string" && offer.verification_code.length > 0;
}
function approval(offer, accept) {
    if (!offerValid(offer) || typeof accept !== "boolean") throw new Error("No current verification offer.");
    return {accept:accept, remote_node_id:offer.remote_node_id, verification_code:offer.verification_code};
}

function permissionLabel(value) { return value === true ? qsTranslate("Spectrum", "allowed") : value === false ? qsTranslate("Spectrum", "denied") : qsTranslate("Spectrum", "unknown"); }

function pairedControlOffer(data) {
    const peer = (data || {}).peer;
    if (!data || data.created !== true || !peer || !/^[0-9a-f]{64}$/.test(peer.id || "")
        || typeof peer.alias !== "string" || !peer.permissions || peer.permissions.connect !== true
        || peer.permissions.control_this_node !== false) return null;
    return {node_id:peer.id, name:peer.alias};
}

function permissionResult(status, data, peerId) {
    if (!data || data.node_id !== peerId || !data.permissions || typeof data.permissions !== "object")
        throw new Error("Invalid UKVM permission response. Refresh before retrying.");
    Object.keys(data.permissions).forEach(key => {
        if (typeof data.permissions[key] !== "boolean")
            throw new Error("Invalid UKVM permission state. Refresh before retrying.");
    });
    return Object.assign({}, status, {peers:(status.peers || []).map(peer => peer.node_id === peerId
        ? Object.assign({}, peer, {permissions:Object.assign({}, peer.permissions || {}, data.permissions)}) : peer)});
}

function clipboardLabel(value) {
    if (!value) return qsTranslate("Spectrum", "Update UKVM for text sharing");
    if (value.state === "restart_required") return qsTranslate("Spectrum", "Restart UKVM to enable text sharing");
    if (!value.enabled) return qsTranslate("Spectrum", "Off");
    if (value.supported === false || value.state === "unavailable") return qsTranslate("Spectrum", "Backend unavailable");
    if (value.state === "stopped") return qsTranslate("Spectrum", "Enabled · start UKVM");
    if (value.state === "starting") return qsTranslate("Spectrum", "Starting…");
    const count = value.connected_peers || 0;
    return count ? qsTranslate("Spectrum", "Sharing text · %n computer", "", count) : qsTranslate("Spectrum", "Enabled · waiting for another computer");
}

function authorizationLabel(status, kind, doctor) {
    const key = kind || "remote_desktop";
    const sampled = ((status || {}).desktop_authorization || {})[key];
    const probed = ((doctor || {}).desktop_authorization || {})[key];
    const value = probed && probed.persistence_api_supported === false ? probed : sampled || probed || {};
    const labels = {persistent: qsTranslate("Spectrum", "Persistent"), active: qsTranslate("Spectrum", "Active"), needs_approval: qsTranslate("Spectrum", "Needs approval"),
        unsupported: qsTranslate("Spectrum", "Persistence unavailable"), unavailable: qsTranslate("Spectrum", "Authorization needs attention")};
    return labels[value.state] || qsTranslate("Spectrum", "Authorization status unavailable");
}

function backendState(doctor) {
    if (!doctor || !doctor.portal) return "unknown";
    if (["backend_ready", "backend_missing", "incompatible_backend"].indexOf(doctor.backend_state) >= 0)
        return doctor.backend_state;
    if (!doctor.portal.available || !(doctor.input_capture || {}).version || !(doctor.remote_desktop || {}).version)
        return "backend_missing";
    return backendProblems(doctor).length ? "incompatible_backend" : "backend_ready";
}
function healthLabel(status, doctor) {
    const service = status.service || {};
    if (!service.available || service.active_state === "failed") return qsTranslate("Spectrum", "Service needs attention");
    const backend = backendState(doctor);
    if (backend === "backend_missing") return qsTranslate("Spectrum", "Required Wayland backend missing");
    if (backend === "incompatible_backend") return qsTranslate("Spectrum", "Incompatible Wayland backend");
    if (backend === "unknown") return qsTranslate("Spectrum", "Checking Wayland backend…");
    if ((status.runtime || {}).state === "running") return qsTranslate("Spectrum", "Running · backend ready");
    return qsTranslate("Spectrum", "Backend ready · portal consent may be needed when starting");
}

function discoveryMachines(machines, localId) {
    const result = [];
    const indices = {};
    (machines || []).forEach((machine, index) => {
        const id = machine.advertised_node_id;
        const hasId = typeof id === "string" && /^[0-9a-f]{64}$/.test(id);
        if (hasId && id === localId) return;
        const key = hasId ? "node:" + id : machine.service_instance ? "instance:" + machine.service_instance : "entry:" + index;
        if (indices[key] === undefined) {
            indices[key] = result.length;
            result.push(machine);
        } else if (machine.pairing_available === true && result[indices[key]].pairing_available !== true) {
            result[indices[key]] = machine;
        }
    });
    return result;
}
function activeTransfer(sending, own, transfers) {
    const active = transfer => transfer && ["preparing", "connecting", "transferring", "verifying"].indexOf(transfer.state) >= 0;
    if (sending && active(own)) return own;
    return (transfers || []).slice().reverse().find(transfer => active(transfer)
        && !(own && !active(own) && transfer.id === own.id)) || null;
}

function isStatusRequest(args) {
    return args[0] === "status" || args[0] === "doctor" || (args[0] === "pair" && args[1] === "status");
}
function sameData(current, next) { return JSON.stringify(current) === JSON.stringify(next); }
