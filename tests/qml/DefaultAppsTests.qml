import QtQuick
import QtTest
import Quickshell
import "../../configs/spectrum-shell" as Shell

Scope {
TestCase {
    name: "DefaultApps"
    visible: true
    width: 640
    height: 600
    when: true
    onCompletedChanged: if (completed) { console.log("Default apps UI:",qtest_results.passCount,"passed",qtest_results.failCount,"failed"); Qt.quit(); }
    Shell.DefaultApps {
        id: editor
        anchors.fill: parent
        backendDir: Quickshell.env("SPECTRUM_DEFAULT_APPS_FIXTURE")
        theme: ({fontFamily:"monospace",fontSize:12,colors:{background:"#111111",surface:"#222222",surface_alt:"#333333",foreground:"#eeeeee",muted:"#aaaaaa",accent:"#66ccee"}})
    }
    function equal(actual, expected) { if (!qtest_compareInternal(actual,expected)) console.warn("Comparison:",JSON.stringify(actual),JSON.stringify(expected)); compare(actual,expected); }
    function init() {
        editor.backendDir=Quickshell.env("SPECTRUM_DEFAULT_APPS_FIXTURE");
        tryCompare(editor,"busy",false,5000);
        editor.byType=false;
        editor.group="video";
        findChild(editor,"default-apps-search").text="";
        editor.command("status",{group:"video",catalogue:true});
        tryCompare(editor,"busy",false,5000);
        equal(editor.error,"");
    }
    function test_mixed_defaults_wait_for_explicit_choice_and_apply() {
        console.log("Running mixed_defaults_wait_for_explicit_choice_and_apply");
        const choice=findChild(editor,"default-apps-application");
        const button=findChild(editor,"default-apps-apply");
        equal(editor.defaults.length,2);
        equal(choice.currentIndex,-1);
        verify(!button.enabled);
        choice.currentIndex=0;
        tryCompare(button,"enabled",true);
        equal(editor.message,"");
        button.clicked();
        tryCompare(editor,"message","Saved explicitly",5000);
        equal(editor.defaults[0].desktop,"test-player.desktop");
        equal(editor.defaults[1].desktop,"test-player.desktop");
        verify(!button.enabled);
    }
    function test_extension_search_selects_canonical_mkv_type() {
        console.log("Running extension_search_selects_canonical_mkv_type");
        editor.byType=true;
        findChild(editor,"default-apps-search").text=".mkv";
        tryVerify(()=>!editor.busy && editor.selected.mime==="video/x-matroska",5000);
        equal(editor.defaults.length,1);
        equal(editor.defaults[0].mime,"video/x-matroska");
    }
    function test_error_is_visible_without_replacing_the_current_choices() {
        console.log("Running error_is_visible_without_replacing_the_current_choices");
        const before=editor.defaults;
        editor.command("set",{group:"video",desktop:"fail.desktop"});
        tryCompare(editor,"error","Unable to update associations",5000);
        equal(editor.defaults,before);
        verify(!editor.busy);
    }
    function test_no_matching_file_type_cannot_apply_old_choices() {
        editor.byType=true;
        findChild(editor,"default-apps-search").text="no-such-extension-xyz";
        tryCompare(editor,"busy",false,5000);
        compare(editor.filteredTypes.length,0);
        verify(!editor.selectionMatches);
        verify(!findChild(editor,"default-apps-apply").enabled);
    }
    function test_missing_helper_does_not_leave_controls_busy() {
        editor.backendDir=Quickshell.env("SPECTRUM_DEFAULT_APPS_FIXTURE") + "/missing";
        editor.refresh();
        tryCompare(editor,"busy",false,5000);
        compare(editor.error,"Could not start the default applications helper.");
    }

}
}
