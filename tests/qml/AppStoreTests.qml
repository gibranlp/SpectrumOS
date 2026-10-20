import QtQuick
import QtTest
import Quickshell
import "../../configs/spectrum-shell" as Shell

Scope {
    QtObject {
        id:theme
        property string fontFamily:"sans-serif"
        property int fontSize:13
        property bool animationsEnabled:false
        property bool widgetBounceEnabled:false
        property string barStyle:"full"
        property string barPosition:"top"
        property var colors:({background:"#111111",surface:"#222222",surface_alt:"#333333",foreground:"#eeeeee",muted:"#aaaaaa",accent:"#66ccee",error:"#ee7777",warning:"#eebb66"})
        function backend(name) { return Quickshell.env("SPECTRUM_APP_STORE_TEST")+"/"+name; }
    }
    Shell.AppStoreManager { id:manager; theme:theme; viewing:panel.expanded }
    Shell.AppStorePanel { id:panel; theme:theme; manager:manager; onCloseRequested:expanded=false }
    TestCase {
        id:tests
        parent:panel.contentItem
        name:"AppStore"
        when:true
        onCompletedChanged:if(completed){console.log("App Store checks:",qtest_results.passCount,"passed",qtest_results.failCount,"failed");Qt.quit();}
        function eq(a,b){if(a!==b)console.warn("Mismatch",a,b);compare(a,b);}
        function field(name){return findChild(panel,"app-store-"+name);}
        function settled(){tryVerify(()=>!manager.busy && !manager.acting && !manager.searchPending,7000);wait(50);}
        function init(){manager.page="discover";manager.source="pacman";manager.selected=null;manager.error="";manager.query="fixture";panel.expanded=true;manager.refresh();settled();}
        function cleanup(){console.log("App Store case",qtest_results.functionName,"failures",qtest_results.failCount);panel.expanded=false;manager.selected=null;theme.fontSize=13;settled();}
        function test_click_result_loads_details_without_installing(){
            const list=field("results");list.forceLayout();wait(50);
            verify(list.count>0);mouseClick(list.itemAtIndex(0),30,25);
            tryVerify(()=>manager.selected!==null,2000);settled();
            compare(manager.detail,"Fixture description and dependencies");
            eq(manager.page,"discover");
        }
        function test_typing_search_and_enter_refreshes_results(){
            const search=field("search");search.forceActiveFocus();search.selectAll();
            for (const letter of "editor") keyClick(letter);keyClick(Qt.Key_Return);settled();
            compare(manager.query,"editor");compare(manager.results[0].name,"editor");
        }
        function test_late_search_response_does_not_replace_new_query(){
            manager.query="slow";wait(500);verify(manager.busy);
            manager.query="newest";settled();compare(manager.results[0].name,"newest");
        }
        function test_details_close_does_not_start_job(){
            manager.choose(manager.results[0]);settled();
            eq(manager.page,"discover");
            panel.expanded=false;panel.expanded=true;settled();eq(manager.page,"discover");
        }
        function test_confirm_install_closes_widget_and_keeps_terminal_activity(){
            manager.choose(manager.results[0]);settled();
            mouseClick(field("install"));
            tryCompare(panel,"expanded",false,4000);settled();manager.refreshJobs();
            tryVerify(()=>manager.activeJob && manager.activeJob.mode==="terminal",4000);
            compare(manager.activeJob.prompt,null);
            panel.expanded=true;wait(100);verify(manager.activeJob.active);
            manager.action("test-complete",{});
            tryVerify(()=>manager.activeJob && manager.activeJob.phase==="complete",4000);
        }
        function test_activity_scroll_preserves_reading_position_and_follows_bottom(){
            manager.page="activity";manager.action("test-log",{});settled();
            const scroll=field("log-scroll");
            tryVerify(()=>scroll.contentHeight>scroll.height+500,3000);
            tryVerify(()=>Math.abs(scroll.contentY-(scroll.contentHeight-scroll.height))<2,3000);
            scroll.contentY=200;wait(50);
            mouseWheel(scroll,100,100,0,-120);tryVerify(()=>!scroll.moving,3000);verify(scroll.contentY>200);
            const previous=scroll.contentY;
            manager.action("test-append",{});settled();verify(Math.abs(scroll.contentY-previous)<2);
            scroll.contentY=scroll.contentHeight-scroll.height;wait(50);
            manager.action("test-append",{});settled();
            verify(Math.abs(scroll.contentY-(scroll.contentHeight-scroll.height))<2);
        }
        function test_installed_source_cannot_stay_on_aur_filter(){
            manager.source="aur";manager.page="installed";settled();compare(manager.source,"all");
        }
        function test_large_font_keeps_search_and_list_usable(){
            for(const size of [13,20]){
                theme.fontSize=size;wait(80);
                verify(field("search").width>200);verify(field("results").height>80);
                verify(field("results").width<=panel.width);
            }
        }
    }
}
