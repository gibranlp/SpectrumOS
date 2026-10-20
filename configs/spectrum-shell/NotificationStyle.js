.pragma library

function kind(notification) {
    if (String(notification.appName || "").toLowerCase() !== "questline") return "";
    const hint=notification.questlineKind || (notification.hints || {})["x-questline-kind"] || "";
    if (["swarm","hydration","hydration-progress"].includes(hint)) return hint;
    const icon=String(notification.iconSource || notification.appIcon || "");
    if (icon.includes("notification_swarm.png")) return "swarm";
    if (icon.includes("hydration.png")) return /reminder/i.test(notification.summary || "") ? "hydration" : "hydration-progress";
    if (/^hydration reminder$/i.test(notification.summary || "")) return "hydration";
    return "";
}
function token(notification) {
    return String(notification.reminderToken || (notification.hints || {})["x-questline-reminder-token"] || "");
}
function palette(notification,colors) {
    const type=kind(notification);
    if (type==="swarm") return {kind:type,background:"#180a26",alternate:"#301345",accent:"#a855f7",foreground:"#f3e8ff",muted:"#e9d5ff",persistent:false};
    if (type.startsWith("hydration")) return {kind:type,background:"#071930",alternate:"#0b3152",accent:"#38bdf8",foreground:"#e0f2fe",muted:"#bae6fd",persistent:type==="hydration"};
    return {kind:"",background:colors.surface,alternate:colors.surface_alt,accent:colors.accent,foreground:colors.foreground,muted:colors.muted,persistent:false};
}
function isStableUpdate(notification) {
    return notification.appName === "SpectrumOS Updates" && (notification.hints || {})["x-spectrumos-kind"] === "stable-updates";
}
function actions(notification) {
    if (isStableUpdate(notification)) return [{identifier:"spectrum-open-updates",text:"Open Updates"}];
    if (kind(notification)==="hydration") return [{identifier:"questline-drink",text:"Drink"}];
    return Array.from(notification.actions || []).filter(action=>action.identifier!=="default").map(action=>({identifier:action.identifier,text:action.text}));
}
