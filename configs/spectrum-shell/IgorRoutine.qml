import QtQuick

Item {
    id: routine
    property bool visitsEnabled: false
    property bool available: false
    property var random: Math.random
    property var monitorNames: []
    property var blockedMonitors: []
    property string selectedMonitor: ""
    property bool suppressed: false
    property bool playing: false
    property string mediaKind: "music"
    property bool meeting: false
    readonly property bool musicPlaying: playing && !meeting && mediaKind === "music"
    readonly property bool watching: playing && !meeting && mediaKind === "video"
    property bool visiting: false
    property bool waving: false
    property bool greeted: false
    property string gesture: "curious"
    property int visitCount: 0
    property string edge: "bottom"
    property real position: 0.5
    property int greetingDelay: 6000
    property int minimumPause: 60000
    property int maximumPause: 150000
    property int minimumStay: 16000
    property int maximumStay: 26000
    property real quietVisitProbability: 0.25
    property int minimumQuietStay: 35000
    property int maximumQuietStay: 60000
    property int visitDuration: 0
    property bool celebrationsAllowed: true
    property string celebrationMessage: ""
    property int celebrationDuration: 6500
    property int celebrationIndex: -1
    readonly property var celebrationPhrases: [
        "Was that so hard? Don't answer.",
        "Procrastination has filed an appeal.",
        "Progress. Without a meeting. Imagine.",
        "Fine. That was annoyingly impressive.",
        "A task done. Alert the historians.",
        "All that drama. One little checkmark.",
        "Your excuses are suddenly unemployed.",
        "You finished it? There goes my argument.",
        "Competence? On this desktop?",
        "Quest complete. Ego update pending.",
        "You earned XP. I earned a nap.",
        "Task slain. The tabs remain undefeated.",
        "Finally. The checkbox was getting lonely.",
        "Well done. I'm as surprised as you are.",
        "A completed task? In this economy?",
        "Did you just do the thing? Suspicious.",
        "One less task. Still no extra lives.",
        "Look at you, making the TODO list nervous.",
        "Done. Only three imaginary deadlines late.",
        "I would clap, but these are paws.",
        "Actual progress. There goes my nap.",
        "An achievement without a subscription. Wild.",
        "Shall I notify your abandoned browser tabs?",
        "You did the thing. I'll allow the smugness."
    ]
    property bool napping: false
    property real napProbability: 0.3
    property bool manualGreeting: false
    readonly property bool eligible: visitsEnabled && available && (!suppressed || manualGreeting)
    readonly property var edges: ["top", "bottom", "left", "right"]
    visible: false

    function schedule(): void {
        arrival.interval = playing ? 0
            : greeted ? minimumPause + Math.round(random() * (maximumPause - minimumPause)) : greetingDelay;
        arrival.restart();
    }

    function greet(): bool {
        if (!visitsEnabled || !available)
            return false;
        manualGreeting = true;
        return appear("");
    }

    function nap(): bool {
        if (playing || !appear("")) return false;
        napping = true;
        gesture = "nap";
        waving = false;
        visitDuration = 0;
        stay.stop();
        return true;
    }

    function celebrate(): bool {
        if (!visitsEnabled || !available || !celebrationsAllowed)
            return false;
        if (napping && visiting) retreat();
        manualGreeting = true;
        if (!visiting && !appear("bottom")) {
            manualGreeting = false;
            return false;
        }
        const offset = 1 + Math.floor(random() * (celebrationPhrases.length - 1));
        celebrationIndex = (celebrationIndex + offset) % celebrationPhrases.length;
        celebrationMessage = celebrationPhrases[celebrationIndex];
        gesture = "wave";
        waving = !playing;
        if (playing) stay.stop();
        else {
            stay.interval = Math.max(visitDuration, celebrationDuration + 1000);
            stay.restart();
        }
        celebration.restart();
        return true;
    }

    function appear(requestedEdge, requestedMonitor = ""): bool {
        if (!eligible)
            return false;
        const candidates = monitorNames.filter(name => manualGreeting || !blockedMonitors.includes(name));
        if (monitorNames.length && (!candidates.length || (requestedMonitor && !candidates.includes(requestedMonitor))))
            return false;
        selectedMonitor = requestedMonitor || (candidates.length ? candidates[Math.floor(random() * candidates.length)] : "");
        arrival.stop();
        if (edges.includes(requestedEdge)) {
            edge = requestedEdge;
        } else {
            const alternatives = edges.filter(value => value !== edge);
            edge = playing && edge !== "bottom" && random() < 0.5 ? "bottom" : alternatives[Math.floor(random() * alternatives.length)];
        }
        napping = !manualGreeting && !playing && !requestedEdge && visitCount > 0 && random() < napProbability;
        const quiet = !napping && !playing && !requestedEdge && visitCount > 0 && random() < quietVisitProbability;
        const cornerPosition = 0.02 + random() * 0.06;
        position = quiet ? (random() < 0.5 ? cornerPosition : 1 - cornerPosition) : 0.28 + random() * 0.44;
        gesture = napping ? "nap" : quiet ? "quiet" : ["wave", "curious", "stretch", "sleepy"][visitCount % 4];
        visitCount += 1;
        waving = !napping && !playing && (requestedEdge || gesture === "wave") ? true : false;
        greeted = true;
        visiting = true;
        visitDuration = playing || napping ? 0
            : quiet
            ? minimumQuietStay + Math.round(random() * (maximumQuietStay - minimumQuietStay))
            : minimumStay + Math.round(random() * (maximumStay - minimumStay));
        if (playing || napping) stay.stop();
        else { stay.interval = visitDuration; stay.restart(); }
        return true;
    }

    function retreat(): void {
        stay.stop();
        celebration.stop();
        celebrationMessage = "";
        visiting = false;
        waving = false;
        manualGreeting = false;
        if (eligible)
            schedule();
    }

    Component.onCompleted: { if (eligible) schedule(); }
    onBlockedMonitorsChanged: {
        if (visiting && !manualGreeting && blockedMonitors.includes(selectedMonitor))
            retreat();
    }
    onMonitorNamesChanged: {
        if (visiting && !monitorNames.includes(selectedMonitor))
            retreat();
    }
    onCelebrationsAllowedChanged: {
        if (!celebrationsAllowed && celebrationMessage)
            retreat();
    }
    onVisitsEnabledChanged: { if (!visitsEnabled) greeted = false; }
    onEligibleChanged: {
        if (eligible) {
            if (!visiting)
                schedule();
        } else {
            arrival.stop();
            retreat();
        }
    }
    onPlayingChanged: {
        if (playing && eligible) {
            if (visiting) {
                napping = false;
                visitDuration = 0;
                stay.stop();
                waving = false;
                if (gesture === "quiet" || gesture === "nap")
                    gesture = "curious";
            } else {
                schedule();
            }
        } else if (!playing && visiting) {
            if (napping) return;
            if (!celebrationMessage) retreat();
        } else if (eligible) {
            schedule();
        }
    }

    Timer {
        id: celebration
        interval: routine.celebrationDuration
        onTriggered: {
            routine.celebrationMessage = "";
            routine.manualGreeting = false;
            if (routine.blockedMonitors.includes(routine.selectedMonitor))
                routine.retreat();
        }
    }
    Timer { id: arrival; onTriggered: routine.appear("") }
    Timer { id: stay; onTriggered: if (!routine.playing) routine.retreat() }
}
