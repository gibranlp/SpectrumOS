import QtQuick
import Quickshell
import "../../configs/spectrum-shell" as Shell

ShellRoot {
    id: root
    property int step: 0
    property int ticks: 0
    property int passed: 0
    property int failed: 0
    function check(value, label): void {
        if (value) passed++;
        else { failed++; console.error("FAIL: " + label); }
    }
    function find(item, name): var {
        if (item.objectName === name) return item;
        const children = item.children || [];
        for (let index = 0; index < children.length; index++) {
            const found = find(children[index], name);
            if (found) return found;
        }
        return null;
    }
    Shell.MagnetDownloads {
        id: widget
        width: 636
        height: 550
        active: true
        backendDir: Quickshell.env("SPECTRUM_MAGNET_TEST_DIR")
        theme: QtObject {
            property string fontFamily: "Sans"
            property int fontSize: 14
            property var colors: ({background:"#111111",surface_alt:"#222222",foreground:"#eeeeee",accent:"#aabbff",muted:"#aaaaaa"})
        }
    }
    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            root.ticks++;
            if (root.ticks > 140) { root.check(false, "widget flow timed out at step " + root.step); finish(); return; }
            const query = root.find(widget, "magnet-query");
            if (root.step === 0 && query && !widget.busy) {
                root.check(widget.tab === "search", "search is the default tab");
                root.find(widget, "magnet-top100").activate();

                root.step = 1;
            } else if (root.step === 1 && widget.searching) {
                root.check(widget.results.length === 0, "new search clears old results");
                root.step = 2;
            } else if (root.step === 2 && !widget.searching && widget.searched) {
                root.check(widget.results.length === 1, "search results reach widget");
                root.check(widget.sources.length === 2 && !widget.sources[1].ok, "partial source failure remains visible");
                root.check(widget.submittedQuery === "top100", "search query retained");
                root.step = 3;
            } else if (root.step === 3 && !widget.busy) {
                const result = root.find(widget, "magnet-result-download");
                if (!result) return;
                root.check(result.enabled, "result can be downloaded");
                result.activate();
                root.step = 4;
            } else if (root.step === 4 && widget.tab === "downloads" && (widget.state.rows || []).length === 1 && !widget.busy) {
                root.check(widget.state.rows[0].state === "Starting", "queued download status appears without terminal");
                root.check(widget.queuedMagnets.length === 1, "download success tracked");
                root.check(widget.message.length > 0, "download confirmation shown");
                const deletion = root.find(widget, "magnet-delete-files");
                deletion.activate();
                root.check(widget.pendingRemoval === "delete:" + widget.state.rows[0].info_hash, "file deletion requires confirmation");
                root.check(deletion.label === "Confirm file deletion", "destructive action is explicit");
                deletion.activate();
                root.step = 5;
            } else if (root.step === 5 && !widget.busy && !widget.state.rows.length) {
                widget.tab = "search";
                query.text = "fail";
                widget.search();
                root.step = 6;
            } else if (root.step === 6 && !widget.searching && widget.searchError) {
                root.check(widget.results.length === 0, "failed search clears stale results");
                root.check(widget.searchError === "fixture search failed", "search error displayed");
                query.text = "magnet:?xt=urn:btih:" + "b".repeat(40);
                root.check(root.find(widget, "magnet-search-submit").label === "Download", "magnet paste changes action");
                if (widget.busy) return;
                root.find(widget, "magnet-search-submit").activate();
                root.step = 7;
            } else if (root.step === 7 && widget.tab === "downloads" && (widget.state.rows || []).length === 1) {
                root.check(true, "pasted magnet queues directly");
                finish();
            }
        }
        function finish(): void {
            console.log("Magnet widget: " + root.passed + " passed " + root.failed + " failed");
            Qt.quit();
        }
    }
}
