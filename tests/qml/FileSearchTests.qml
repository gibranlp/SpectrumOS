import QtQuick
import QtTest
import Quickshell
import "../../configs/spectrum-shell" as Shell
Scope {
TestCase {
    name: "FileSearch"
    visible: true
    width: 640
    height: 480
    when: true
    onCompletedChanged: if (completed) { console.log("File search UI:",qtest_results.passCount,"passed",qtest_results.failCount,"failed"); Qt.quit(); }
    Shell.FileSearch {
        id: editor
        anchors.fill: parent
        backendDir: Quickshell.env("SPECTRUM_SEARCH_FIXTURE")
        theme: ({fontFamily:"monospace",fontSize:12,colors:{background:"#111111",surface:"#222222",surface_alt:"#333333",foreground:"#eeeeee",muted:"#aaaaaa",accent:"#66ccee"}})
    }
    function init() {
        editor.backendDir=Quickshell.env("SPECTRUM_SEARCH_FIXTURE");
        editor.active=false;
        tryVerify(()=>!editor.inFlight && !editor.locationBusy,5000);
        editor.active=true;
        editor.activate();
        tryCompare(editor,"locationBusy",false,5000);
        editor.loadLocation("/home/test");
        tryCompare(editor,"locationBusy",false,5000);
        verify(editor.scopeValid);
    }
    function query(value) { findChild(editor,"search-query").text=value; }
    function test_custom_path_reruns_current_query() {
        query("track");
        tryCompare(editor,"matches",["/home/test/track.txt"],5000);
        findChild(editor,"search-folder").text="/media/Music";
        findChild(editor,"search-use-folder").clicked();
        tryCompare(editor,"matches",["/media/Music/track.txt"],5000);
        compare(editor.root,"/media/Music");
    }
    function test_changed_location_never_receives_old_results() {
        query("slow");
        tryCompare(editor,"inFlight",true,5000);
        editor.loadLocation("/media/other");
        query("new");
        tryCompare(editor,"matches",["/media/other/new.txt"],5000);
        wait(700);
        compare(editor.matches,["/media/other/new.txt"]);
    }
    function test_closing_cancels_search_and_drops_results() {
        query("slow");
        tryCompare(editor,"inFlight",true,5000);
        editor.active=false;
        tryCompare(editor,"inFlight",false,5000);
        wait(700);
        compare(editor.matches.length,0);
    }
    function test_invalid_location_does_not_search_previous_folder() {
        query("track");
        tryCompare(editor,"matches",["/home/test/track.txt"],5000);
        editor.loadLocation("/missing");
        tryCompare(editor,"locationBusy",false,5000);
        verify(!editor.scopeValid);
        compare(editor.error,"Folder unavailable");
        query("another");
        wait(400);
        compare(editor.matches.length,0);
        verify(!editor.inFlight);
    }
    function test_location_is_reloaded_on_reopening() {
        editor.loadLocation("/media/Music");
        tryCompare(editor,"locationBusy",false,5000);
        editor.active=false;
        editor.active=true;
        editor.activate();
        tryCompare(editor,"locationBusy",false,5000);
        compare(editor.root,"/media/Music");
    }
    function test_short_query_clears_existing_matches() {
        query("track");
        tryCompare(editor,"matches",["/home/test/track.txt"],5000);
        query("t");
        wait(400);
        compare(editor.matches.length,0);
        verify(!editor.inFlight);
    }
    function test_missing_helper_releases_location_controls() {
        editor.backendDir=Quickshell.env("SPECTRUM_SEARCH_FIXTURE") + "/missing";
        editor.loadLocation();
        tryCompare(editor,"locationBusy",false,5000);
        compare(editor.error,"Could not start the search location helper.");
    }
}
}
