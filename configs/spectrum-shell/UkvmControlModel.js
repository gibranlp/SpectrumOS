function incoming(record, now) {
    const data = record && record.schema_version === 1 && record.ok === true ? record.data : null;
    const runtime = data && data.runtime;
    const snapshot = runtime && runtime.snapshot;
    if (!runtime || runtime.state !== "running" || !snapshot || snapshot.state !== "running"
            || snapshot.focus !== "Controlled" || typeof snapshot.updated !== "number"
            || now - snapshot.updated > 5 || snapshot.updated > now + 1)
        return {active: false, peerName: ""};
    const peers = Array.isArray(data.peers) ? data.peers : [];
    const peer = peers.find(item => item.node_id === snapshot.active_peer);
    return {active: true, peerName: peer && typeof peer.name === "string" ? peer.name : ""};
}
