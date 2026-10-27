import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: monitor
    required property string backendDir
    property var status: ({packages: [], checked_at: 0, eligible: false, error: ""})
    readonly property bool checking: checker.running
    function refresh(): void {
        if (!checker.running) checker.exec([backendDir + "/spectrum-update-check", "--check"]);
    }
    Process {
        id: cached
        command: [monitor.backendDir + "/spectrum-update-check", "--status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { monitor.status = JSON.parse(text); } catch (error) {} }
        }
    }
    Process {
        id: checker
        stdout: StdioCollector {
            onStreamFinished: {
                try { monitor.status = JSON.parse(text); }
                catch (error) { monitor.status = Object.assign({}, monitor.status, {error: qsTranslate("Spectrum", "Could not check Stable updates.")}); }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) monitor.status = Object.assign({}, monitor.status, {error: qsTranslate("Spectrum", "Could not check Stable updates.")});
        }
    }
    Timer { interval: 60000; running: true; onTriggered: monitor.refresh() }
    Timer { interval: 1800000; running: true; repeat: true; onTriggered: monitor.refresh() }
}
