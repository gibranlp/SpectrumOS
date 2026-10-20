import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: manager
    property string program: "pactl"
    property var pending: []
    property bool launching: false
    property string error: ""
    readonly property bool busy: launching || writer.running || pending.length > 0 || settle.running
    signal failed(string message)

    function setVolume(kind, target, percent): void {
        const level = Math.round(percent);
        if (!["sink", "source"].includes(kind) || typeof target !== "string" || !target.length || !Number.isFinite(level) || level < 0 || level > 100) return;
        // Conserva sólo el valor más reciente de cada dispositivo mientras termina el envío anterior.
        pending = pending.filter(item => item.kind !== kind || item.target !== target).concat([{kind:kind,target:target,percent:level}]);
        if (!writer.running && !launching && !dispatch.running) dispatch.start();
    }
    Timer {
        id: dispatch
        interval: 25
        onTriggered: {
            if (writer.running || manager.launching || !manager.pending.length) return;
            const next = manager.pending[0];
            manager.pending = manager.pending.slice(1);
            manager.error = "";
            manager.launching = true;
            writer.exec([manager.program, "set-" + next.kind + "-volume", next.target, next.percent + "%"]);
        }
    }
    Timer { id: settle; interval: 40 }
    Process {
        id: writer
        onStarted: manager.launching = false
        stderr: StdioCollector { onStreamFinished: manager.error = text.trim() }
        onExited: code => {
            manager.launching = false;
            if (code !== 0) manager.failed(manager.error || "Could not change audio volume");
            if (manager.pending.length) dispatch.restart();
            else settle.restart();
        }
    }
}
