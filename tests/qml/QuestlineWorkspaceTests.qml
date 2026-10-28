import QtQuick
import QtTest
import Quickshell
import "../../configs/spectrum-shell" as Shell
Scope {
    Shell.QuestlineWorkspace { id: workspace; backendDir: Quickshell.env("SPECTRUM_QUESTLINE_TEST_DIR") }
    Shell.UtilityPanel {
        id: panel
        questlineWorkspace: workspace
        breakState: ({settings:{enabled:false,eye_minutes:20,movement_minutes:50,pause_focus:true},ready:true,busy:false,status:"Off",error:"",eyeElapsed:0,movementElapsed:0,minutesLeft:function(){return "";}})
        backendDir: Quickshell.env("SPECTRUM_QUESTLINE_TEST_DIR")
        focusState: ({phase:"idle"})
        theme: ({panelLeftInset:52,barPosition:"top",barStyle:"full",animationsEnabled:false,widgetBounceEnabled:false,gamingActive:false,fontSize:12,fontFamily:"monospace",colors:{background:"#111111",surface:"#222222",surface_alt:"#333333",foreground:"#eeeeee",muted:"#aaaaaa",accent:"#66ccee",accent_alt:"#eecc66",error:"#ff6666"}})
    }
    Shell.Dashboard {
        id: dashboard
        targetScreen: Quickshell.screens[0]
        theme: panel.theme
        weather: ({icon:"☀",temperature:"28°",location:"Cancun"})
        media: ({available:false})
        questline: panel.questline
        questlineLoaded: panel.questlineLoaded
        onRefreshDueDates: panel.refreshQuestline()
        onDueItemRequested: (taskId,stepId) => { dashboard.expanded=false;panel.openQuestlineDueItem(taskId,stepId); }
    }
    TestCase {
        name: "QuestlineWorkspace"
        when: true
        onCompletedChanged: if (completed) { console.log("Questline workspace:",qtest_results.passCount,"passed",qtest_results.failCount,"failed"); Qt.quit(); }
        function field(name) {
            const direct=findChild(panel,"questline-"+name);
            if(direct) return direct;
            function visual(item) {
                if(!item) return null;
                if(item.objectName==="questline-"+name) return item;
                for(const child of item.children || []) {const found=visual(child);if(found)return found;}
                return null;
            }
            return visual(panel.contentItem);
        }
        function init() {
            tryCompare(workspace,"ready",true,3000);
            tryCompare(workspace,"busy",false,3000);
            dashboard.expanded=false;
            panel.expanded=false;
            panel.page="search";
            panel.questlineCampaignId="";panel.questlineTreasuryCampaignId="";panel.questlineScrollProjectId="";
            workspace.views=({});workspace.drafts=({});workspace.activeTab="Overview";workspace.selectedProjectId="";
            panel.open("questline");
            tryCompare(panel,"questlineLoaded",true,3000);
            wait(80);
        }
        function assertCampaign(id) {
            compare(panel.questlineCampaignId,id);compare(panel.questlineScrollProjectId,id);compare(panel.questlineTreasuryCampaignId,id);
            compare(workspace.selectedProjectId,id);
        }
        function campaignButton(id) {
            const list=field("campaign-buttons");
            const index=list.model.findIndex(c=>c.id===id);
            list.positionViewAtIndex(index,ListView.Contain);wait(40);
            return list.itemAtIndex(index);
        }
        function test_campaign_selector_stays_visible_on_every_tab() {
            try {
            for (const tab of field("tabs").model) {
                panel.switchQuestlineTab(tab);wait(30);
                verify(field("campaign-bar").visible,tab);
                mouseClick(campaignButton("campaign-b"));wait(30);assertCampaign("campaign-b");
                mouseClick(campaignButton("campaign-a"));wait(30);assertCampaign("campaign-a");
            }
            panel.switchQuestlineTab("Overview");
            mouseClick(campaignButton("campaign-b"));wait(30);
            panel.expanded=false;panel.open("questline");wait(100);
            assertCampaign("campaign-b");verify(field("campaign-bar").visible);
            } catch(error) {console.warn("test_campaign_selector_stays_visible_on_every_tab",error.message,String(error.stack));throw error;}
        }
        function test_campaign_switch_from_scroll_editor_keeps_draft() {
            try {
            panel.switchQuestlineTab("Scrolls");panel.selectQuestlineProject("campaign-a");
            panel.beginQuestlineEdit(panel.questlineSelected);
            field("body").text="# Preserved draft\n\n[Example](https://example.com)";
            panel.rememberQuestline();
            const key=panel.questlineDraftKey;
            const body=field("body").text;
            verify(field("campaign-bar").visible);
            mouseClick(campaignButton("campaign-b"));wait(50);
            assertCampaign("campaign-b");verify(!panel.questlineEditing);
            compare(workspace.drafts[key].view.body,body);
            compare(workspace.drafts[key].view.campaignId,"campaign-a");
            panel.restoreQuestline("Scrolls",workspace.drafts[key].view);wait(50);
            assertCampaign("campaign-a");compare(field("body").text,body);
            } catch(error) {console.warn("test_campaign_switch_from_scroll_editor_keeps_draft",error.message,String(error.stack));throw error;}
        }
        function test_scroll_markdown_renders_and_edit_preserves_source() {
            const markdown = "# Heading\n\n**Bold** and *italic* with [Example](https://example.com).\n\n- First\n- Second\n\n> Quote\n\n```text\ncode <literal>\n```\n\n| Name | Value |\n| --- | --- |\n| Item | 42 |\n";
            panel.questline=Object.assign({},panel.questline,{
                scrolls:panel.questline.scrolls.map(item=>item.id==="scroll-a" ? Object.assign({},item,{markdown_content:markdown}) : item)
            });
            panel.switchQuestlineTab("Scrolls");
            panel.selectQuestlineScrollProject("campaign-a");
            wait(50);
            const detail=field("detail-text");
            compare(detail.textFormat,TextEdit.MarkdownText);
            verify(detail.readOnly);
            const rendered=detail.getText(0,detail.length);
            verify(rendered.includes("Heading"));
            verify(rendered.includes("Bold and italic"));
            verify(rendered.includes("code <literal>"));
            verify(rendered.includes("Item"));verify(rendered.includes("42"));
            verify(!rendered.includes("# Heading"));
            verify(!rendered.includes("**Bold**"));
            verify(!rendered.includes("[Example]"));
            let linkFound=false;
            for(let i=0;i<detail.length;i++) {
                const rect=detail.positionToRectangle(i);
                if(detail.linkAt(rect.x+1,rect.y+rect.height/2)==="https://example.com") {linkFound=true;break;}
            }
            verify(linkFound);
            panel.beginQuestlineEdit(panel.questlineSelected);wait(30);
            compare(field("body").textFormat,TextEdit.PlainText);
            compare(field("body").text,markdown);
            compare(panel.questlineDraftPayload().payload.content,markdown);
            panel.leaveQuestlineEditor();wait(30);
            compare(field("detail-text").textFormat,TextEdit.MarkdownText);
            panel.switchQuestlineTab("Tasks");wait(30);
            compare(field("detail-text").textFormat,TextEdit.PlainText);
        }
        function test_dashboard_calendar_click_opens_the_exact_step() {
            dashboard.expanded=true;
            wait(150);
            const calendar=findChild(dashboard.contentItem,"dashboard-calendar");
            verify(calendar!==null);
            calendar.today=new Date(2026,9,18,12);calendar.month=new Date(2026,9,1);
            calendar.selectedDate="2026-10-18";
            panel.questline=Object.assign({},panel.questline,{
                tasks:panel.questline.tasks.map(item=>Object.assign({},item,{due_date:"2026-10-18"})),
                steps:panel.questline.steps.map(item=>Object.assign({},item,{due_date:"2026-10-18"}))
            });
            wait(80);
            compare(calendar.selectedEntries.length,2);
            const agenda=findChild(calendar,"calendar-agenda");
            const index=calendar.selectedEntries.findIndex(item=>item.stepId==="step-a");
            verify(index>=0);verify(agenda.itemAtIndex(index)!==null);
            mouseClick(agenda.itemAtIndex(index));
            tryCompare(panel,"questlineDueTarget",null,3000);
            compare(dashboard.expanded,false);
            compare(panel.questlineStepSelected.id,"step-a");
            compare(panel.questlineStepParent.id,"task-a");
        }
        function test_calendar_task_opens_its_campaign_and_detail() {
            panel.switchQuestlineTab("Scrolls");
            panel.selectQuestlineScrollProject("campaign-b");
            panel.openQuestlineDueItem("task-a", "");
            tryCompare(panel,"questlineDueTarget",null,3000);
            compare(panel.questlineTab,"Tasks");
            assertCampaign("campaign-a");
            compare(panel.questlineSelected.id,"task-a");
            verify(!panel.questlineEditing);
        }
        function test_calendar_step_waits_for_workspace_and_opens_exact_step() {
            workspace.ready=false;
            panel.openQuestlineDueItem("task-a","step-a");
            tryCompare(panel,"questlineDueReady",true,3000);
            verify(panel.questlineDueTarget!==null);
            workspace.ready=true;
            tryCompare(panel,"questlineDueTarget",null,3000);
            compare(panel.questlineTab,"Tasks");assertCampaign("campaign-a");
            compare(panel.questlineSelected.id,"task-a");
            compare(panel.questlineStepParent.id,"task-a");
            compare(panel.questlineStepSelected.id,"step-a");
            compare(field("title").text,"Step");verify(panel.questlineEditing);
        }
        function test_calendar_step_restores_unfinished_draft() {
            panel.switchQuestlineTab("Tasks");panel.selectQuestlineTaskProject("campaign-a");
            panel.beginQuestlineStepEdit(panel.questline.steps[0]);
            field("title").text="";field("body").text="Unfinished step from the calendar";
            panel.rememberQuestline();
            panel.openQuestlineDueItem("task-a","step-a");
            tryCompare(panel,"questlineDueTarget",null,3000);
            compare(field("title").text,"");
            compare(field("body").text,"Unfinished step from the calendar");
            compare(panel.questlineStepSelected.id,"step-a");
            verify(panel.questlineEditing);
        }
        function test_calendar_missing_item_reports_error_without_opening_another_task() {
            panel.openQuestlineDueItem("missing-task","step-a");
            tryCompare(panel,"questlineDueTarget",null,3000);
            verify(panel.questlineError.indexOf("no longer available")>=0);
            verify(!panel.questlineStepSelected || panel.questlineStepSelected.id!=="missing-task");
        }
        function test_campaign_buttons_share_selection_and_filter_all_three_tabs() {
            try {
            panel.questline=Object.assign({},panel.questline,{
                tasks:panel.questline.tasks.concat([{id:"task-b",project_id:"campaign-b",title:"Beta task",campaign:"Beta"}]),
                scrolls:panel.questline.scrolls.concat([{id:"scroll-b",project_id:"campaign-b",title:"Beta scroll",campaign:"Beta",markdown_content:"Beta notes"}]),
                entries:[{id:"entry-b",campaign_id:"campaign-b",title:"Beta entry",campaign:"Beta",amount_minor:100,currency_code:"USD",entry_type:"Expense",status:"Planned"}]
            });
            panel.switchQuestlineTab("Tasks");wait(50);
            const beta=campaignButton("campaign-b");verify(beta!==null);mouseClick(beta);wait(50);
            assertCampaign("campaign-b");compare(beta.backgroundColor,panel.theme.colors.accent);
            compare(campaignButton("campaign-a").backgroundColor,panel.theme.colors.surface_alt);
            compare(panel.questlineItems()[0].id,"task-b");
            mouseClick(field("tabs").itemAt(field("tabs").model.indexOf("Treasury")));wait(50);assertCampaign("campaign-b");compare(panel.questlineItems()[0].id,"entry-b");
            mouseClick(field("tabs").itemAt(field("tabs").model.indexOf("Scrolls")));wait(50);assertCampaign("campaign-b");compare(panel.questlineItems()[0].id,"scroll-b");
            mouseClick(campaignButton("campaign-a"));wait(50);assertCampaign("campaign-a");compare(panel.questlineItems()[0].id,"scroll-a");
            mouseClick(field("tabs").itemAt(field("tabs").model.indexOf("Tasks")));wait(50);assertCampaign("campaign-a");compare(panel.questlineItems()[0].id,"task-a");
            panel.switchQuestlineTab("Treasury");wait(30);mouseClick(campaignButton("campaign-b"));wait(30);assertCampaign("campaign-b");
            panel.switchQuestlineTab("Scrolls");wait(30);assertCampaign("campaign-b");compare(panel.questlineItems()[0].id,"scroll-b");
            panel.switchQuestlineTab("Tasks");wait(30);assertCampaign("campaign-b");compare(panel.questlineItems()[0].id,"task-b");
            } catch(e) {console.warn("campaign_buttons",e.message,String(e.stack));throw e;}
        }
        function test_campaign_empty_projects_remain_selected_and_reopen() {
            try {
            panel.switchQuestlineTab("Tasks");panel.selectQuestlineTaskProject("campaign-b");
            for(const tab of ["Scrolls","Treasury","Chronicles","Tasks"]) {
                panel.switchQuestlineTab(tab);wait(30);assertCampaign("campaign-b");compare(panel.questlineItems().length,0);
                verify(panel.questlineProjects().some(c=>c.id==="campaign-b"));
            }
            panel.expanded=false;panel.open("questline");wait(100);assertCampaign("campaign-b");
            } catch(e) {console.warn("campaign_empty",e.message,String(e.stack));throw e;}
        }
        function test_campaign_switch_preserves_other_campaign_draft() {
            try {
            panel.switchQuestlineTab("Scrolls");panel.selectQuestlineScrollProject("campaign-a");panel.beginQuestlineEdit(null);
            field("body").text="A private unfinished Alpha draft";panel.rememberQuestline();const key=panel.questlineDraftKey;
            panel.switchQuestlineTab("Tasks");panel.selectQuestlineTaskProject("campaign-b");
            panel.switchQuestlineTab("Scrolls");wait(50);assertCampaign("campaign-b");verify(!panel.questlineEditing);
            compare(workspace.drafts[key].view.body,"A private unfinished Alpha draft");verify(!workspace.drafts[key].valid);
            panel.restoreQuestline("Scrolls",workspace.drafts[key].view);wait(50);assertCampaign("campaign-a");verify(panel.questlineEditing);
            compare(field("body").text,"A private unfinished Alpha draft");
            } catch(e) {console.warn("campaign_draft",e.message,String(e.stack));throw e;}
        }
        function test_campaign_overflow_scrolls_and_reveals_selection() {
            try {
            panel.questline=Object.assign({},panel.questline,{campaigns:panel.questline.campaigns.concat(Array.from({length:35},(_,i)=>({id:"extra-"+i,name:"Project "+String(i).padStart(2,"0"),is_shared:false})))});
            panel.switchQuestlineTab("Tasks");panel.selectQuestlineTaskProject("extra-34");wait(100);
            const list=field("campaign-buttons");verify(list.contentWidth>list.width);verify(list.contentX>0);verify(!field("campaign-scroll").visible);
            const button=campaignButton("extra-34");verify(button!==null);compare(button.backgroundColor,panel.theme.colors.accent);
            const previous=list.contentX;mouseWheel(list,list.width/2,list.height/2,0,120);wait(100);verify(list.contentX<previous);
            } catch(e) {console.warn("campaign_overflow",e.message,String(e.stack));throw e;}
        }
        function test_campaign_tab_order_places_sidequests_after_hero() {
            compare(field("tabs").model,["Overview","Tasks","Scrolls","Treasury","Chronicles","Tree","Focus","Hero","Sidequests","Sync"]);
        }
        function test_campaign_scrolls_without_visible_scrollbar_across_tabs() {
            panel.questline=Object.assign({},panel.questline,{campaigns:panel.questline.campaigns.concat(Array.from({length:35},(_,i)=>({id:"extra-"+i,name:"Project "+String(i).padStart(2,"0"),is_shared:false})))});
            for (const tab of ["Tasks","Treasury","Scrolls","Chronicles"]) {
                panel.switchQuestlineTab(tab);wait(30);
                const scroll=field("campaign-scroll");verify(!scroll.visible);
                const campaigns=field("campaign-bar");
                const tabs=field("tabs").itemAt(0).parent;
                verify(campaigns.y+campaigns.height<=tabs.y);
                const list=field("campaign-buttons");
                list.contentX=0;mouseWheel(list,list.width/2,list.height/2,0,-120);wait(30);
                verify(list.contentX>0);
            }
        }
        function test_character_header_shows_live_profile_and_xp_across_tabs() {
            try {
            const hero={username:"Igor",class:"Task Paladin",level:5,xp:125,xp_next_level:500};
            panel.questline=Object.assign({},panel.questline,{hero:hero});
            for (const tab of ["Tasks","Treasury","Scrolls","Chronicles"]) {
                panel.switchQuestlineTab(tab);wait(30);
                verify(field("character-header").visible);
                compare(field("character-name").text,"Igor");
                compare(field("character-class").text,"Task Paladin · Level 5");
                compare(field("character-xp-label").text,"125 / 500 XP");
                compare(field("character-header").progress,0.25);
                compare(field("character-xp-fill").width,field("character-xp-track").width*0.25);
            }
            const preview=Quickshell.env("SPECTRUM_QUESTLINE_PREVIEW");
            if (preview) grabImage(panel.contentItem).save(preview);
            panel.questline=Object.assign({},panel.questline,{hero:Object.assign({},hero,{xp:250})});wait(30);
            compare(field("character-header").progress,0.5);
            panel.questline=Object.assign({},panel.questline,{hero:{username:"Igor",class:"Task Paladin",level:100,xp:0,xp_next_level:0}});wait(30);
            compare(field("character-header").progress,1);
            panel.questline=Object.assign({},panel.questline,{hero:Object.assign({},hero,{xp_next_level:undefined})});wait(30);
            compare(field("character-header").progress,0);compare(field("character-xp-label").text,"125 XP");
            panel.questline=Object.assign({},panel.questline,{hero:null});wait(30);
            verify(!field("character-header").visible);
            } catch(error) {console.warn("character_header",error.message,String(error.stack));throw error;}
        }
        function test_new_task_shortcut_campaign_buttons_preserve_the_draft() {
            panel.switchQuestlineTab("Chronicles");panel.selectQuestlineProject("campaign-b");
            panel.expanded=false;panel.openQuestlineNewTask();wait(100);
            compare(panel.questlineTab,"Tasks");verify(panel.questlineEditing);
            compare(panel.questlineEditCampaignId,"campaign-b");
            verify(field("campaign-bar").visible);
            compare(campaignButton("campaign-b").backgroundColor,panel.theme.colors.accent);
            compare(field("campaign-buttons").model.map(c=>c.id),["campaign-a","campaign-b"]);
            field("body").text="Work in progress";
            const key=panel.questlineDraftKey;
            mouseClick(campaignButton("campaign-a"));wait(50);
            verify(panel.questlineEditing);compare(panel.questlineDraftKey,key);
            compare(field("body").text,"Work in progress");
            compare(panel.questlineEditCampaignId,"campaign-a");assertCampaign("campaign-a");
            compare(workspace.drafts[key].payload.project_id,"campaign-a");
            compare(campaignButton("campaign-a").backgroundColor,panel.theme.colors.accent);
            panel.expanded=false;panel.open("questline");wait(100);
            verify(panel.questlineEditing);compare(panel.questlineDraftKey,key);
            compare(panel.questlineEditCampaignId,"campaign-a");compare(field("body").text,"Work in progress");
        }
        function test_new_task_campaign_buttons_scroll_to_selected_campaign() {
            panel.openQuestlineNewTask();wait(100);
            panel.questline=Object.assign({},panel.questline,{campaigns:panel.questline.campaigns.concat(Array.from({length:35},(_,i)=>({id:"extra-"+i,name:"Project "+String(i).padStart(2,"0"),is_shared:false})))});
            panel.selectQuestlineCampaign("extra-34");wait(100);
            verify(panel.questlineEditing);compare(panel.questlineEditCampaignId,"extra-34");
            const list=field("campaign-buttons");verify(list.contentWidth>list.width);verify(list.contentX>0);
            compare(campaignButton("extra-34").backgroundColor,panel.theme.colors.accent);
        }
        function test_chronicles_follow_campaign_and_reopen_without_stale_selection() {
            panel.questline=Object.assign({},panel.questline,{chronicles:[
                {id:"journal-a",project_id:"campaign-a",title:"2026-10-18",description:"Alpha daily log",campaign:"Alpha",author_username:"Igor"},
                {id:"journal-b",project_id:"campaign-b",title:"2026-10-19",description:"Beta daily log",campaign:"Beta",author_username:""}
            ]});
            panel.switchQuestlineTab("Tasks");panel.selectQuestlineProject("campaign-b");
            mouseClick(field("tabs").itemAt(field("tabs").model.indexOf("Chronicles")));wait(50);
            assertCampaign("campaign-b");compare(panel.questlineSelected.id,"journal-b");
            compare(panel.questlineItems().length,1);
            compare(field("detail-text").text,"Beta daily log");
            mouseClick(campaignButton("campaign-a"));wait(50);
            assertCampaign("campaign-a");compare(panel.questlineSelected.id,"journal-a");
            panel.switchQuestlineTab("Treasury");panel.selectQuestlineProject("campaign-b");
            panel.switchQuestlineTab("Chronicles");wait(50);
            assertCampaign("campaign-b");compare(panel.questlineSelected.id,"journal-b");
            panel.expanded=false;panel.open("questline");wait(100);
            compare(panel.questlineTab,"Chronicles");assertCampaign("campaign-b");
            compare(panel.questlineItems().length,0);compare(panel.questlineSelected,null);
            const saved=workspace.snapshot();
            workspace.views=({});workspace.activeTab="Tasks";workspace.selectedProjectId="campaign-a";
            workspace.restore(saved);panel.restoreQuestline(workspace.activeTab);wait(50);
            compare(panel.questlineTab,"Chronicles");assertCampaign("campaign-b");
        }
        function test_chronicle_new_button_preserves_campaign_draft_and_autosaves() {
            panel.switchQuestlineTab("Treasury");panel.selectQuestlineProject("campaign-b");
            panel.switchQuestlineTab("Chronicles");wait(50);
            const button=field("new-item");verify(button.visible);verify(button.enabled);
            compare(button.label,"+ New chronicle");mouseClick(button);wait(50);
            verify(panel.questlineEditing);compare(panel.questlineEditCampaignId,"campaign-b");
            verify(field("body").activeFocus);
            const key=panel.questlineDraftKey;
            panel.rememberQuestline();verify(!workspace.drafts[key].valid);
            field("body").text="x".repeat(256);panel.rememberQuestline();
            verify(!workspace.drafts[key].valid);
            panel.switchQuestlineTab("Tasks");panel.selectQuestlineProject("campaign-a");
            panel.restoreQuestline("Chronicles",workspace.drafts[key].view);wait(50);
            assertCampaign("campaign-b");compare(field("body").text.length,256);
            field("body").text="Progress on the Beta campaign.";panel.rememberQuestline();
            verify(workspace.drafts[key].valid);
            compare(workspace.drafts[key].payload.action,"create_chronicle");
            compare(workspace.drafts[key].payload.project_id,"campaign-b");
            workspace.flush();tryVerify(()=>!workspace.busy,3000);
            verify(!!workspace.drafts[key].payload.id);
            compare(workspace.drafts[key].payload.action,"update_chronicle");
        }
        function test_chronicle_edit_and_older_binary_controls() {
            panel.questline=Object.assign({},panel.questline,{chronicles:[
                {id:"journal-a",project_id:"campaign-a",title:"2026-10-18",description:"An existing chronicle",campaign:"Alpha",author_username:"Igor"}
            ]});
            panel.switchQuestlineTab("Chronicles");panel.selectQuestlineProject("campaign-a");wait(50);
            const edit=field("edit-item");verify(edit.visible);verify(edit.enabled);
            mouseClick(edit);wait(50);compare(field("body").text,"An existing chronicle");
            compare(panel.questlineDraftPayload().payload.action,"update_chronicle");
            panel.leaveQuestlineEditor();
            panel.questline=Object.assign({},panel.questline,{chronicles_available:false});wait(50);
            verify(!field("new-item").enabled);verify(!field("edit-item").enabled);
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
        function test_entry_savings_settings_and_separate_currency_totals() {
            try {
            panel.questline=Object.assign({},panel.questline,{
                savings_accounts_available:true,
                accounts:[{id:"checking",campaign_id:"campaign-a",name:"My bank",kind:"Spending",is_default:false,balance_minor:60000,currency_code:"MXN",version:1},
                          {id:"investment",campaign_id:"campaign-a",name:"My investment",kind:"Savings",is_default:false,balance_minor:30000,currency_code:"MXN",version:1,savings_status:"Invested",interest_rate_bps:1200,interest_period:"Annual"},
                          {id:"reserve",campaign_id:"campaign-a",name:"Emergency fund",kind:"Savings",is_default:false,balance_minor:10000,currency_code:"MXN",version:1,savings_status:"Available",interest_rate_bps:100,interest_period:"Monthly"},
                          {id:"empty-custom",campaign_id:"campaign-a",name:"New bank",kind:"Spending",is_default:false,balance_minor:0,currency_code:"MXN",version:1}],
                entries:[{id:"income",title:"Income",campaign:"Alpha",campaign_id:"campaign-a",currency_code:"MXN",entry_type:"Income",status:"Paid",amount_minor:100000},
                         {id:"commitment",title:"Commitment",campaign:"Alpha",campaign_id:"campaign-a",currency_code:"MXN",entry_type:"Expense",status:"Approved",amount_minor:5000}]
            });
            panel.switchQuestlineTab("Treasury");panel.selectQuestlineProject("campaign-a");wait(100);
            const summary=field("treasury-summary");verify(summary!==null);
            const totals=summary.model[0];
            compare(totals.available,55000);compare(totals.saved,40000);compare(totals.invested,30000);compare(totals.liquidSavings,10000);
            const preview=Quickshell.env("SPECTRUM_QUESTLINE_SAVINGS_PREVIEW");
            if(preview) grabImage(panel.contentItem).save(preview);
            const settings=field("savings-settings-investment");verify(settings!==null);
            settings.forceActiveFocus();wait(40);mouseClick(settings);wait(40);
            const status=field("savings-status-investment");status.forceActiveFocus();keyClick(Qt.Key_Home);
            const rate=field("savings-rate-investment");rate.forceActiveFocus();keyClick(Qt.Key_A,Qt.ControlModifier);keyClick(Qt.Key_1);keyClick(Qt.Key_Period);keyClick(Qt.Key_5);keyClick(Qt.Key_0);
            const period=field("savings-period-investment");period.forceActiveFocus();keyClick(Qt.Key_Home);
            const save=field("savings-save-investment");verify(save.enabled);
            save.forceActiveFocus();wait(40);
            if(preview) grabImage(panel.contentItem).save(preview.replace(".png","-settings.png"));
            mouseClick(save);
            tryCompare(workspace,"externalActions",1,1000);
            tryCompare(workspace,"externalActions",0,3000);
            wait(150);
            panel.questline=Object.assign({},panel.questline,{accounts:[],entries:[]});
            } catch(e) {console.warn("Savings test",e.message,String(e.stack));throw e;}
        }
        function test_entry_treasury_full_form_payload_and_draft_restoration() {
            workspace.blocked=true;
            try {
                panel.questline=Object.assign({},panel.questline,{
                    treasury_fields_available:true,
                    accounts:[{id:"default-spending",campaign_id:"campaign-a",name:"Spending",is_default:true,balance_minor:0},
                              {id:"default-savings",campaign_id:"campaign-a",name:"Savings",is_default:true,balance_minor:0},
                              {id:"cash-a",campaign_id:"campaign-a",name:"Cash",is_default:false,balance_minor:0},
                              {id:"savings-a",campaign_id:"campaign-a",name:"Savings",balance_minor:0}],
                    categories:[{id:"transfer-a",campaign_id:"campaign-a",entry_type:"Transfer",name:"Internal Transfer"}]
                });
                panel.switchQuestlineTab("Treasury");panel.selectQuestlineProject("campaign-a");panel.beginQuestlineEdit(null);
                panel.questlineEntryType="Transfer";
                panel.questlineEntryFields={account_id:"cash-a",category_id:"transfer-a",transfer_account_id:"savings-a",
                    related_task_id:"task-a",entry_date:"2026-10-21",due_date:"2026-10-22",payment_date:"2026-10-21",
                    vendor_source:"Bank",notes:"Transfer notes",description:"Reserve",attachment_ref:"receipt.pdf",
                    recurrence:"Custom",custom_recurrence:"Every six weeks"};
                field("title").text="Treasury transfer";field("amount").text="45.50";
                panel.rememberQuestline();wait(60);
                verify(panel.questlineDraftPayload().valid);
                const payload=panel.questlineDraftPayload().payload;
                panel.questlineSelected={id:"saved-transfer"};
                verify(panel.questlineDraftPayload().valid);
                panel.questlineSelected=null;
                compare(payload.amount_minor,4550);compare(payload.transfer_account_id,"savings-a");
                compare(payload.account_id,"cash-a");compare(payload.category_id,"transfer-a");
                compare(payload.notes,"Transfer notes");compare(payload.recurrence,"Custom");
                const source=field("entry-account_id");const destination=field("entry-transfer_account_id");
                verify(source!==null,"Account selector missing");verify(destination!==null,"Destination selector missing");verify(destination.visible,"Destination selector hidden");
                verify(source.model.some(item=>item.id==="cash-a"));
                verify(!destination.model.some(item=>item.id==="cash-a"));
                compare(source.model.length,3);
                source.forceActiveFocus();keyClick(Qt.Key_End);wait(40);
                compare(panel.questlineEntryFields.account_id,"savings-a");
                source.forceActiveFocus();keyClick(Qt.Key_Home);keyClick(Qt.Key_Down);wait(40);
                compare(panel.questlineEntryFields.account_id,"cash-a");
                panel.rememberQuestline();
                const preview=Quickshell.env("SPECTRUM_QUESTLINE_TREASURY_PREVIEW");
                if(preview) grabImage(panel.contentItem).save(preview);
                const editor=field("entry-editor");
                verify(editor.contentHeight>editor.height);
                const notes=field("entry-notes");
                notes.forceActiveFocus();wait(40);
                verify(notes.mapToItem(editor,0,0).y>=0);
                verify(notes.mapToItem(editor,0,notes.height).y<=editor.height+1);
                if(preview) grabImage(panel.contentItem).save(preview.replace(".png","-scrolled.png"));
                panel.expanded=false;panel.open("questline");wait(100);
                compare(panel.questlineEntryFields,payloadToFields(payload));
                compare(panel.questlineDraftPayload().payload.transfer_account_id,"savings-a");
                panel.questlineEntryFields=Object.assign({},panel.questlineEntryFields,{transfer_account_id:"cash-a"});
                verify(!panel.questlineDraftPayload().valid);
                panel.questlineEntryFields=Object.assign({},panel.questlineEntryFields,{transfer_account_id:"savings-a",due_date:"2026-02-31"});
                verify(!panel.questlineDraftPayload().valid);
            } catch(e) {console.warn("Treasury test",e.message,String(e.stack));throw e;}
            finally {workspace.drafts=({});workspace.blocked=false;panel.questline=Object.assign({},panel.questline,{treasury_fields_available:true});}
        }
        function payloadToFields(payload) {
            const fields={};
            for(const key of Object.keys(panel.questlineEntryFields)) fields[key]=payload[key];
            return fields;
        }
        function test_entry_treasury_edit_keeps_fields_and_type_change_resets_category() {
            workspace.blocked=true;
            try {
                panel.switchQuestlineTab("Treasury");panel.selectQuestlineProject("campaign-a");
                panel.beginQuestlineEdit({id:"entry-full",campaign_id:"campaign-a",title:"Existing",amount_minor:100,
                    entry_type:"Income",status:"Approved",account_id:"cash-a",category_id:"salary-a",
                    notes:"Original note",description:"Original description",created_at:"2026-09-10T12:00:00Z",recurrence:"Monthly"});
                compare(panel.questlineEntryFields.account_id,"cash-a");
                compare(panel.questlineEntryFields.category_id,"salary-a");
                compare(panel.questlineEntryFields.notes,"Original note");
                compare(panel.questlineEntryFields.entry_date,"2026-09-10");
                panel.questlineEntryType="Expense";
                compare(panel.questlineEntryFields.category_id,"");
                compare(panel.questlineEntryFields.account_id,"cash-a");
                panel.questline.treasury_fields_available=false;
                verify(!panel.questlineDraftPayload().valid);
            } catch(e) {console.warn("Treasury test",e.message,String(e.stack));throw e;}
            finally {workspace.drafts=({});workspace.blocked=false;panel.questline=Object.assign({},panel.questline,{treasury_fields_available:true});}
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
