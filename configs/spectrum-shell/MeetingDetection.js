.pragma library

function isCallingApp(properties) {
    const p = properties || {};
    const identity = [p["application.name"], p["application.process.binary"],
        p["application.id"], p["node.name"]].join(" ").toLowerCase();
    return /\b(brave|chromium|chrome|google-chrome|firefox|zen|zen-browser|zenbrowser|vivaldi|microsoft-edge|msedge|opera|teams|ms-teams|teams-for-linux|zoom|discord|vesktop|skype|webex|jitsi)\b/.test(identity);
}

function isActiveMicrophoneLink(link, activeState) {
    if (!link || !link.source || !link.target || link.state !== activeState) return false;
    const source = link.source;
    const target = link.target;
    return !!(source.audio && !source.isStream && !source.isSink
        && target.audio && target.isStream && !target.isSink && target.ready
        && isCallingApp(target.properties));
}
