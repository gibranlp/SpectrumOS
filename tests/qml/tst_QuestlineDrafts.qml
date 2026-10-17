import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Item {
    Shell.QuestlineDrafts { id: store; debounceInterval: 60000 }
    SignalSpy { id: requests; target: store; signalName: "saveRequested" }
    TestCase {
        name: "QuestlineDrafts"
        function init() {
            store.ready = false;
            store.views = ({}); store.drafts = ({}); store.inFlight = null; store.storageError = "";
            store.restore({version:1}); requests.clear();
        }
        function test_selected_project_persists_across_tabs_and_restart() {
            store.remember("Tasks",{campaignId:"project-b"});
            compare(store.selectedProjectId,"project-b");
            store.remember("Overview",{});
            compare(store.selectedProjectId,"project-b");
            const data=store.copy(store.snapshot());store.selectedProjectId="";store.restore(data);
            compare(store.selectedProjectId,"project-b");
            store.remember("Scrolls",{scrollProjectId:"project-a",quickScrollPicker:true});
            compare(store.selectedProjectId,"");
        }
        function test_resume_tab_selected_item_and_editor_positions() {
            const view = {selected:{id:"scroll-1"},editing:true,key:"Scrolls:scroll-1",body:"unfinished\ntext",bodyCursor:9,editorScroll:125};
            store.remember("Scrolls",view);
            const data = store.copy(store.snapshot());
            store.remember("Tasks",{selected:{id:"task-2"}});
            store.restore(data);
            compare(store.activeTab,"Scrolls");
            compare(store.views.Scrolls.body,view.body);
            compare(store.views.Scrolls.selected.id,"scroll-1");
            compare(store.views.Scrolls.bodyCursor,9);
            compare(store.views.Scrolls.editorScroll,125);
        }
        function test_incomplete_treasury_is_kept_without_creating_entry() {
            store.update("entry",{action:"create_entry",title:"Travel",amount_minor:0},false,"Enter an amount.",false);
            store.keepDraftView("entry","Treasury",{amount:"12.",editing:true,key:"entry"});
            store.flush();
            compare(requests.count,0);
            compare(store.drafts.entry.view.amount,"12.");
            verify(store.status("entry").indexOf("Draft kept") === 0);
            store.restore(store.copy(store.snapshot()));
            compare(store.drafts.entry.view.amount,"12.");
        }
        function test_initial_edit_does_not_write_or_award_xp() {
            store.update("scroll",{action:"update_scroll",id:"a",title:"Hello",content:"Body"},true,"",true);
            store.flush();
            compare(requests.count,0);
            compare(store.status("scroll"),"Autosaved");
        }
        function test_typing_during_save_keeps_latest_content_and_one_creation() {
            store.update("new",{action:"create_scroll",project_id:"p",title:"Hello",content:"one"},true,"",false);
            const token = store.drafts.new.payload.autosave_id;
            verify(/^[a-f0-9-]{36}$/.test(token));
            store.flush(); compare(requests.count,1);
            store.update("new",{action:"create_scroll",project_id:"p",title:"Hello",content:"two"},true,"",false);
            store.flush(); compare(requests.count,1);
            store.finish({id:"created"});
            compare(store.drafts.new.payload.content,"two");
            compare(store.drafts.new.payload.id,"created");
            compare(store.drafts.new.payload.action,"update_scroll");
            compare(store.drafts.new.payload.autosave_id,token);
            store.flush(); compare(requests.count,2);
            compare(requests.signalArguments[1][0].payload.content,"two");
            store.finish({id:"created"});
            compare(store.status("new"),"Autosaved");
            store.flush(); compare(requests.count,2);
        }
        function test_errors_keep_draft_and_retry_only_when_requested() {
            store.update("task",{action:"update_task",id:"a",title:"New"},true,"",false);
            store.flush(); store.finish({error:"Database busy"});
            compare(store.status("task"),"Database busy");
            store.flush(); compare(requests.count,1);
            store.retry("task"); compare(requests.count,2);
            compare(requests.signalArguments[1][0].payload.title,"New");
        }
        function test_switching_tabs_keeps_independent_pending_drafts() {
            for (const tab of ["Tasks","Scrolls","Treasury","Sidequests"]) {
                store.update(tab,{action:"update_task",id:tab,title:tab},true,"",false);
                store.remember(tab,{key:tab,editing:true});
            }
            store.flush(); compare(requests.count,1);
            for (let i=0; i<4; i++) {
                store.finish({id:requests.signalArguments[i][0].payload.id});
                store.flush();
            }
            compare(requests.count,4);
            compare(Object.keys(store.views).length,4);
            verify(!store.busy);
        }
        function test_interrupted_create_reuses_original_idempotency_key() {
            store.update("new",{action:"create_scroll",title:"Hello",content:"Body"},true,"",false);
            store.flush();
            const saved = store.copy(store.snapshot());
            const token = store.inFlight.payload.autosave_id;
            store.restore(saved); requests.clear(); store.flush();
            compare(requests.count,1);
            compare(store.inFlight.payload.autosave_id,token);
            compare(store.drafts.new.error,"");
        }
        function test_local_storage_failure_prevents_database_write() {
            store.update("step",{action:"create_step",parent_id:"a",title:"Step"},true,"",false);
            store.storageError = "Disk full";
            store.flush(); compare(requests.count,0);
            compare(store.status("step"),"Disk full");
        }
    }
}
