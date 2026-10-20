import QtQuick
import Quickshell.Io

Item {
    id: manager
    required property var theme
    visible: false
    property bool viewing: false
    property string query: ""
    property string source: "all"
    property string page: "discover"
    property var results: []
    property var jobs: []
    property var backends: ({})
    property var selected: null
    property string detail: ""
    property string error: ""
    property string warnings: ""
    property int revision: 0
    property int searchingRevision: -1
    property bool searchPending: false
    property bool busy: searchProcess.running
    property bool acting: actionProcess.running
    property var actionPayload: ({})
    property string actionName: ""
    property string searchOutput: ""
    property string actionOutput: ""
    property string detailKey: ""
    readonly property var activeJob: jobs.find(job => job.active) || jobs[0] || null
    readonly property bool authenticating: activeJob !== null && activeJob.active && activeJob.phase === "authentication"
    signal installationRequested()

    function search(): void {
        revision++;
        if (page === "activity") { searchPending = false; return; }
        searchPending = true; delay.restart();
    }
    function pump(): void {
        if (searchProcess.running || !searchPending || page === "activity") return;
        searchPending = false; searchingRevision = revision; searchOutput = "";
        searchProcess.exec([theme.backend("app-store-adapter"), "search"]);
    }
    function refresh(): void { search(); refreshJobs(); }
    function refreshJobs(): void {
        if (!jobsProcess.running) jobsProcess.exec([theme.backend("app-store-adapter"), "jobs"]);
    }
    function choose(item): void {
        if (acting) return;
        selected = item; detail = "Loading package details…";
        detailKey = item.key;
        action("details", {target:item});
    }
    function action(name, payload): void {
        if (acting) return;
        error = ""; actionName = name; actionPayload = payload; actionOutput = "";
        actionProcess.exec([theme.backend("app-store-adapter"), name]);
    }
    function install(): void {
        if (!selected || acting) return;
        action("start", {target:selected});
    }
    function answer(value): void {
        if (!activeJob || !activeJob.prompt) return;
        action("answer", {id:activeJob.id, token:activeJob.prompt.token, answer:value});
    }
    onQueryChanged: search()
    onSourceChanged: search()
    onPageChanged: { selected = null; if (page === "installed" && source === "aur") source = "all"; if (page === "activity") {searchPending=false;refreshJobs();} else search(); }
    Timer { id: delay; interval:450; onTriggered:manager.pump() }
    Timer { interval:900; repeat:true; running:manager.viewing; onTriggered:manager.refreshJobs() }
    Process {
        id: searchProcess
        stdinEnabled: true
        onStarted: write(JSON.stringify({query:manager.query, source:manager.source, installed:manager.page === "installed"})+"\n")
        stdout: StdioCollector { onStreamFinished:manager.searchOutput = text }
        onExited: (code,status) => {
            if (manager.searchingRevision === manager.revision) {
                try {
                    const result = JSON.parse(manager.searchOutput);
                    if (!result.ok) manager.error = result.error;
                    else { manager.results = result.results; manager.backends = result.backends; manager.warnings = result.warnings.join("\n"); }
                } catch (error) { manager.error = "Could not read the application search. Try again."; }
            }
            Qt.callLater(() => manager.pump());
        }
    }
    Process {
        id: actionProcess
        stdinEnabled: true
        onStarted: write(JSON.stringify(manager.actionPayload)+"\n")
        stdout: StdioCollector { onStreamFinished:manager.actionOutput = text }
        onExited: (code,status) => {
            try {
                const result = JSON.parse(manager.actionOutput);
                if (!result.ok) manager.error = result.error || "The action could not be completed.";
                else if (manager.actionName === "details" && manager.selected && manager.selected.key === manager.detailKey) manager.detail = result.detail;
                else if (manager.actionName === "start") { manager.page = "activity"; manager.installationRequested(); }
            } catch (error) { manager.error = "Could not read the App Store response."; }
            manager.refreshJobs();
        }
    }
    Process {
        id: jobsProcess
        stdinEnabled: true
        onStarted: write("{}\n")
        stdout: StdioCollector { onStreamFinished: {
            try { const result = JSON.parse(text); if (result.ok) manager.jobs = result.jobs; }
            catch(error) { manager.error = "Could not read installation activity."; }
        } }
    }
}
