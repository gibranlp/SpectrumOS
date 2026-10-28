import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: monitor
    required property string backendDir
    property var status: ({packages: [], installed_packages: [], inventory_error: "", checked_at: 0, eligible: false, error: ""})
    property bool statusLoaded: false
    readonly property bool checking: checker.running
    function refresh(): void {
        if (!cached.running) cached.exec([backendDir + "/spectrum-update-check", "--status"]);
        if (!checker.running) checker.exec([backendDir + "/spectrum-update-check", "--check"]);
    }
    Process {
        id: cached
        command: [monitor.backendDir + "/spectrum-update-check", "--status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const status = JSON.parse(text);
                    monitor.status = monitor.statusLoaded ? Object.assign({}, monitor.status, {
                        installed_packages: status.installed_packages || [], inventory_error: status.inventory_error || ""
                    }) : status;
                    monitor.statusLoaded = true;
                } catch (error) {}
            }
        }
    }
    Process {
        id: checker
        stdout: StdioCollector {
            onStreamFinished: {
                try { monitor.status = JSON.parse(text); monitor.statusLoaded = true; }
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
