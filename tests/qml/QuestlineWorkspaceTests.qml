import QtQuick
import QtTest
import Quickshell
import "../../configs/spectrum-shell" as Shell
Scope {
    Shell.QuestlineWorkspace { id: workspace; backendDir: Quickshell.env("SPECTRUM_QUESTLINE_TEST_DIR") }
    Shell.UtilityPanel {
        id: panel
        questlineWorkspace: workspace
        backendDir: Quickshell.env("SPECTRUM_QUESTLINE_TEST_DIR")
        focusState: ({phase:"idle"})
        theme: ({panelLeftInset:52,barPosition:"top",barStyle:"full",animationsEnabled:false,widgetBounceEnabled:false,gamingActive:false,fontSize:12,fontFamily:"monospace",colors:{background:"#111111",surface:"#222222",surface_alt:"#333333",foreground:"#eeeeee",muted:"#aaaaaa",accent:"#66ccee",accent_alt:"#eecc66",error:"#ff6666"}})
    }
    TestCase {
        name: "QuestlineWorkspace"
        when: true
        onCompletedChanged: if (completed) { console.log("Questline workspace:",qtest_results.passCount,"passed",qtest_results.failCount,"failed"); Qt.quit(); }
        function field(name) { return findChild(panel,"questline-"+name); }
        function init() {
            tryCompare(workspace,"ready",true,3000);
            tryCompare(workspace,"busy",false,3000);
            panel.expanded=false;
            panel.page="search";
            panel.questlineCampaignId="";panel.questlineTreasuryCampaignId="";panel.questlineScrollProjectId="";
            workspace.views=({});workspace.drafts=({});workspace.activeTab="Overview";workspace.selectedProjectId="";
            panel.open("questline");
            tryCompare(panel,"questlineLoaded",true,3000);
            wait(80);
        }
        function test_quick_note_in_current_task_project_focuses_body() {
            panel.switchQuestlineTab("Tasks");
            panel.selectQuestlineTaskProject("campaign-b");
            panel.openQuestlineNewScroll();wait(100);
            verify(panel.questlineEditing);
            verify(!panel.questlineQuickScrollPicker);
            compare(panel.questlineTab,"Scrolls");
            compare(panel.questlineEditCampaignId,"campaign-b");
            verify(field("title").text.indexOf("Quick note · ")===0);
            verify(field("body").activeFocus);
            verify(!workspace.drafts[panel.questlineDraftKey].valid);
        }
        function test_quick_note_without_project_picks_then_writes_and_resumes() {
            workspace.selectedProjectId="";
            panel.openQuestlineNewScroll();wait(100);
            verify(panel.questlineQuickScrollPicker);
            verify(!panel.questlineEditing);
            const picker=findChild(panel,"questline-quick-scroll-projects");
            compare(picker.count,2);
            verify(picker.activeFocus);
            keyClick(Qt.Key_Down);keyClick(Qt.Key_Return);wait(100);
            verify(!panel.questlineQuickScrollPicker);
            verify(panel.questlineEditing);
            compare(panel.questlineEditCampaignId,"campaign-b");
            verify(field("body").activeFocus);
            field("body").text="Captured quickly in Beta";
            panel.expanded=false;panel.open("questline");wait(100);
            compare(field("body").text,"Captured quickly in Beta");
            compare(panel.questlineEditCampaignId,"campaign-b");
            tryVerify(()=>workspace.status(panel.questlineDraftKey)==="Autosaved",3000);
        }
        function test_quick_note_preserves_an_unfinished_scroll() {
            panel.switchQuestlineTab("Scrolls");panel.beginQuestlineEdit(null);
            field("body").text="An unfinished note without a title";
            panel.rememberQuestline();
            const previous=panel.questlineDraftKey;
            panel.openQuestlineNewScroll();wait(100);
            verify(panel.questlineDraftKey!==previous);
            compare(workspace.drafts[previous].view.body,"An unfinished note without a title");
            verify(!workspace.drafts[previous].valid);
        }
        function test_quick_note_stale_project_asks_instead_of_silently_choosing() {
            workspace.selectedProjectId="deleted-project";
            panel.openQuestlineNewScroll();wait(100);
            verify(panel.questlineQuickScrollPicker);
            verify(!panel.questlineEditing);
            panel.beginQuestlineQuickScroll("shared");
            verify(panel.questlineQuickScrollPicker);
            verify(!panel.questlineEditing);
        }
        function test_quick_note_waits_for_workspace_and_catalog() {
            workspace.ready=false;workspace.selectedProjectId="campaign-b";
            panel.questlineLoaded=false;
            panel.openQuestlineNewScroll();
            verify(panel.questlinePendingNewScroll);
            tryCompare(panel,"questlineLoaded",true,3000);
            verify(panel.questlinePendingNewScroll);
            workspace.ready=true;wait(100);
            verify(!panel.questlinePendingNewScroll);
            verify(panel.questlineEditing);
            compare(panel.questlineEditCampaignId,"campaign-b");
        }
        function test_scroll_reopens_in_editor_with_cursor_and_latest_text() {
            panel.switchQuestlineTab("Scrolls");
            panel.beginQuestlineEdit(panel.questline.scrolls[0]);
            field("body").text="Still writing\nsecond paragraph";
            field("body").cursorPosition=8;
            panel.expanded=false;
            panel.open("questline");
            wait(100);
            compare(panel.questlineTab,"Scrolls");
            verify(panel.questlineEditing);
            compare(panel.questlineSelected.id,"scroll-a");
            compare(field("body").text,"Still writing\nsecond paragraph");
            compare(field("body").cursorPosition,8);
            tryVerify(()=>workspace.status(panel.questlineDraftKey)==="Autosaved",3000);
            verify(panel.questlineEditing);
        }
        function test_new_scroll_keeps_typing_during_create_and_reopens_without_duplicates() {
            panel.switchQuestlineTab("Scrolls");panel.beginQuestlineEdit(null);
            field("title").text="New scroll";field("body").text="First paragraph";
            panel.rememberQuestline();workspace.flush();
            verify(workspace.busy);
            field("body").text="First and second paragraphs";
            panel.expanded=false;panel.open("questline");wait(100);
            compare(field("body").text,"First and second paragraphs");
            tryVerify(()=>workspace.status(panel.questlineDraftKey)==="Autosaved",4000);
            verify(panel.questlineSelected !== null);
            compare(workspace.drafts[panel.questlineDraftKey].payload.action,"update_scroll");
            compare(workspace.drafts[panel.questlineDraftKey].payload.content,"First and second paragraphs");
        }
        function test_tabs_restore_task_step_and_incomplete_treasury() {
            panel.switchQuestlineTab("Tasks");
            panel.beginQuestlineEdit(panel.questline.tasks[0]);
            field("body").text="Task work in progress";
            panel.switchQuestlineTab("Treasury");panel.beginQuestlineEdit(null);
            field("title").text="Hotel";field("amount").text="12.";
            panel.expanded=false;panel.open("questline");wait(100);
            compare(panel.questlineTab,"Treasury");
            compare(field("amount").text,"12.");
            verify(panel.questlineEditing);
            verify(workspace.status(panel.questlineDraftKey).indexOf("Draft kept")===0);
            verify(!workspace.drafts[panel.questlineDraftKey].valid);
            panel.switchQuestlineTab("Tasks");wait(30);
            compare(field("body").text,"Task work in progress");
            compare(panel.questlineSelected.id,"task-a");
            panel.leaveQuestlineEditor();
            panel.beginQuestlineStepEdit(panel.questline.steps[0]);
            field("title").text="Step work in progress";
            panel.expanded=false;panel.open("questline");wait(100);
            compare(panel.questlineStepParent.id,"task-a");
            compare(panel.questlineStepSelected.id,"step-a");
            compare(field("title").text,"Step work in progress");
        }
        function test_sidequest_options_and_focus_preferences_resume() {
            panel.switchQuestlineTab("Sidequests");panel.beginQuestlineEdit(panel.questline.sidequests[0]);
            panel.questlineSidequestFrequency="Weekly";panel.questlineSidequestReward=35;
            panel.switchQuestlineTab("Focus");
            const focus = findChild(panel,"questline-focus");
            focus.projectId="campaign-a";focus.taskId="task-a";focus.duration=45;focus.soundscape="Rain Sounds";
            panel.expanded=false;panel.open("questline");wait(80);
            compare(panel.questlineTab,"Focus");
            compare(focus.duration,45);compare(focus.soundscape,"Rain Sounds");compare(focus.taskId,"task-a");
            panel.switchQuestlineTab("Sidequests");wait(30);
            verify(panel.questlineEditing);
            compare(panel.questlineSidequestFrequency,"Weekly");
            compare(panel.questlineSidequestReward,35);
        }
        function cleanup() {if (qtest_results.failed) console.log("Failed test:",qtest_results.functionName);panel.expanded=false;tryCompare(workspace,"busy",false,3000);wait(300);}
    }
}
