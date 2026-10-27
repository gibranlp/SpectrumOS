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
        property var colors:({background:"#111111",surface:"#222222",surface_alt:"#333333",foreground:"#eeeeee",muted:"#aaaaaa",accent:"#66ccee"})
        function backend(name) {return Quickshell.env("SPECTRUM_FAVORITES_TEST_DIR")+"/"+name;}
    }
    Shell.FavoritesManager {id:manager;theme:theme}
    Shell.FavoritesPanel {id:panel;theme:theme;manager:manager;topInset:8;sideInset:8;onCloseRequested:expanded=false}
    TestCase {
        id:tests
        parent:panel.contentItem
        name:"Favorites"
        when:true
        onCompletedChanged:if(completed){console.log("Favorites checks:",qtest_results.passCount,"passed",qtest_results.failCount,"failed");Qt.quit();}
        function assertEqual(actual,expected){if(JSON.stringify(actual)!==JSON.stringify(expected))console.warn("Mismatch",JSON.stringify(actual),JSON.stringify(expected));compare(actual,expected);}
        function typeText(text){for(let i=0;i<text.length;i++)keyClick(text[i]);}
        function field(name){return findChild(panel,"favorites-"+name);}
        function settle(){manager.persist();wait(30);tryVerify(()=>!manager.busy && manager.queue.length===0,8000,"Favorites request queue did not drain: "+manager.error);wait(30);}
        function init(){
            try {
            tryCompare(manager,"ready",true,5000);settle();
            manager.run("test-reset");settle();
            manager.view=({category:"top",search:"",editor:"",draft:{}});manager.draftError="";manager.error="";manager.message="";manager.preview=null;
            panel.expanded=true;wait(100);settle();
            } catch(e) {console.warn("INIT exception",e.message,String(e.stack).split("\n").slice(0,5).join("\n"));throw e;}
        }
        function cleanup(){panel.expanded=false;settle();}
        function test_new_favorite_autosaves_and_reopens_editor(){
            try {
            mouseClick(field("new"));wait(20);
            const title=field("title");title.forceActiveFocus();typeText("Defeat the backlog");
            const url=field("url");url.forceActiveFocus();typeText("https://example.com/");
            settle();assertEqual(manager.favorites.length,1);assertEqual(manager.favorites[0].title,"Defeat the backlog");
            panel.expanded=false;settle();panel.expanded=true;wait(50);settle();
            assertEqual(manager.view.editor,"favorite");assertEqual(field("url").text,"https://example.com/");
            mouseClick(field("back"));settle();assertEqual(manager.view.editor,"");
            } catch(e) {console.warn("test_new_favorite_autosaves_and_reopens_editor",e.message,String(e.stack).split("\n").slice(0,5).join("\n"));throw e;}
        }
        function test_incomplete_draft_is_retained_without_a_link(){
            try {
            manager.editFavorite(null);manager.draft({title:"Half written",url:"https://"});settle();
            assertEqual(manager.favorites.length,0);verify(manager.draftError.length>0);
            panel.expanded=false;settle();panel.expanded=true;wait(30);settle();
            assertEqual(field("title").text,"Half written");assertEqual(field("url").text,"https://");
            } catch(e) {console.warn("test_incomplete_draft_is_retained_without_a_link",e.message,String(e.stack).split("\n").slice(0,5).join("\n"));throw e;}
        }
        function test_category_create_rename_and_delete_immediately(){
            try {
            mouseClick(field("category-new"));wait(20);manager.draft({name:"Campaigns"});settle();
            const category=manager.categories.find(c=>c.name==="Campaigns");verify(category!==undefined);
            manager.back();manager.selectCategory(category.id);settle();
            mouseClick(field("category-edit"));wait(20);manager.draft({name:"Adventures"});settle();
            assertEqual(manager.categoryName(category.id),"Adventures");manager.back();settle();
            mouseClick(field("category-delete"));settle();assertEqual(manager.categories.length,1);assertEqual(manager.view.category,"uncategorized");
            } catch(e) {console.warn("test_category_create_rename_and_delete_immediately",e.message,String(e.stack).split("\n").slice(0,5).join("\n"));throw e;}
        }
        function test_nonempty_category_blocks_delete_until_last_favorite_removed() {
            try {
            manager.editCategory(null);manager.draft({name:"Temporary"});settle();
            const category=manager.categories.find(c=>c.name==="Temporary").id;
            manager.back();manager.selectCategory(category);settle();
            manager.editFavorite(null);manager.draft({title:"Delete me",url:"https://delete.example"});settle();
            const id=manager.favorites[0].id;manager.back();settle();
            verify(!field("category-delete").enabled);
            manager.change({search:"nothing matches"});settle();verify(!field("category-delete").enabled);
            manager.change({search:""});settle();field("grid").forceLayout();wait(50);
            const card=field("grid").itemAtIndex(0);verify(card!==null);
            mouseClick(findChild(card,"favorites-remove-"+id));settle();
            assertEqual(manager.favorites.length,0);verify(field("category-delete").enabled);
            mouseClick(field("category-delete"));settle();
            verify(!manager.categories.some(c=>c.id===category));assertEqual(manager.error,"");
            } catch(e) {console.warn("test_nonempty_category_blocks_delete_until_last_favorite_removed",e.message,String(e.stack));throw e;}
        }
        function test_long_lists_scroll_in_top_and_regular_categories() {
            try {
            manager.categories=[{id:"uncategorized",name:"Uncategorized"},{id:"many",name:"Many"}];
            manager.favorites=Array.from({length:60},(_,i)=>({id:"link"+i,title:"Portal "+i,url:"https://example.com/"+i,category:"many",clickCount:60-i}));
            const grid=field("grid");
            for (const category of ["top","many"]) {
                manager.view=({category:category,search:"",editor:"",draft:{}});wait(100);grid.forceLayout();wait(30);
                assertEqual(grid.count,category==="top"?24:60);
                verify(grid.contentHeight>grid.height);verify(field("links-scroll").visible);
                grid.positionViewAtBeginning();wait(50);const start=grid.contentY;
                if (category==="top") {
                    mouseWheel(grid,grid.width/2,grid.height/2,0,-360);wait(200);
                    verify(grid.contentY>start,"Mouse wheel did not scroll TOP");
                    tryCompare(grid,"moving",false,2000);
                }
                const scroll=field("links-scroll");const thumb=scroll.contentItem;
                const handleCenter=thumb.y+thumb.height/2;
                mouseDrag(scroll,scroll.width/2,handleCenter,0,scroll.height-1-handleCenter,Qt.LeftButton,Qt.NoModifier,100);
                wait(100);
                verify(grid.contentY>start,"Scrollbar did not scroll "+category);
                tryVerify(()=>grid.itemAtIndex(grid.count-1)!==null,1000,"Last favorite is unreachable in "+category);
                verify(grid.contentY+grid.height>=grid.contentHeight-2);
            }
            } catch(e) {console.warn("test_long_lists_scroll_in_top_and_regular_categories",e.message,String(e.stack));throw e;}
        }
        function test_y_editor_fields_stay_inside_panel_with_long_values() {
            const originalWidth=panel.implicitWidth;
            try {
                manager.editCategory(null);manager.draft({name:"Category".repeat(10)});settle();
                const category=manager.categories.find(c=>c.name==="Category".repeat(10));
                manager.back();manager.selectCategory(category.id);settle();
                manager.editFavorite(null);manager.draft({title:"T".repeat(200),url:"https://example.com/"+"a".repeat(1500)});settle();
                for (const width of [800,620]) {
                    panel.implicitWidth=width;wait(100);
                    const frame=findChild(panel,"favorites-frame");
                    const scroll=field("editor-scroll");
                    verify(scroll.contentWidth<=scroll.availableWidth+1,"Editor content exceeds viewport");
                    for (const name of ["title","url","category-choice","back","browser"]) {
                        const control=field(name);const point=control.mapToItem(frame,0,0);
                        verify(control.width>0 && point.x>=0 && point.x+control.width<=frame.width+1,name+" exceeds panel at width "+width);
                    }
                }
            } catch(e) {console.warn("test_y_editor_fields_stay_inside_panel_with_long_values",e.message,String(e.stack));throw e;}
            finally {panel.implicitWidth=originalWidth;wait(100);}
        }
        function test_top_ranking_category_and_global_search(){
            try {
            manager.categories=[{id:"uncategorized",name:"Uncategorized"},{id:"work",name:"Work"}];
            manager.favorites=[{id:"z",title:"Zulu",url:"https://z.example",category:"work",clickCount:3},{id:"a",title:"Alpha",url:"https://a.example",category:"uncategorized",clickCount:3},{id:"b",title:"Beta",url:"https://b.example",category:"work",clickCount:9}];
            assertEqual(manager.visibleFavorites[0].title,"Beta");assertEqual(manager.visibleFavorites[1].title,"Alpha");
            manager.view=({category:"work",search:"",editor:"",draft:{}});assertEqual(manager.visibleFavorites.length,2);
            manager.view=({category:"work",search:"alpha",editor:"",draft:{}});assertEqual(manager.visibleFavorites.length,1);assertEqual(manager.visibleFavorites[0].title,"Alpha");
            } catch(e) {console.warn("test_top_ranking_category_and_global_search",e.message,String(e.stack).split("\n").slice(0,5).join("\n"));throw e;}
        }
        function test_browser_selector_and_refresh(){
            try {
            assertEqual(manager.browsers.length,2);assertEqual(manager.defaultBrowser,"browser.desktop");
            manager.run("browser-set",{id:"second.desktop"});settle();assertEqual(manager.defaultBrowser,"second.desktop");
            verify(field("browser").visible);mouseClick(field("browser-refresh"));settle();assertEqual(manager.error,"");
            } catch(e) {console.warn("test_browser_selector_and_refresh",e.message,String(e.stack).split("\n").slice(0,5).join("\n"));throw e;}
        }
        function test_import_preview_requires_confirmation(){
            try {
            manager.run("import-preview",{path:Quickshell.env("SPECTRUM_FAVORITES_TEST_DIR")+"/fixture.json"});settle();
            assertEqual(manager.favorites.length,0);assertEqual(manager.preview.added,2);verify(field("import-confirm").visible);
            mouseClick(field("import-confirm"));settle();assertEqual(manager.favorites.length,2);assertEqual(manager.visibleFavorites[0].title,"Most used");assertEqual(manager.visibleFavorites[0].clickCount,12);
            } catch(e) {console.warn("test_import_preview_requires_confirmation",e.message,String(e.stack).split("\n").slice(0,5).join("\n"));throw e;}
        }
        function test_mouse_click_opens_once_and_closes_panel() {
            manager.editFavorite(null);manager.draft({title:"Portal",url:"https://example.com/"});settle();manager.back();settle();
            field("grid").forceLayout();wait(100);
            const id=manager.favorites[0].id;
            const action=findChild(field("grid").itemAtIndex(0),"favorites-open-"+id);
            verify(action!==null);mouseClick(action,12,12);settle();
            assertEqual(manager.favorites.find(f=>f.id===id).clickCount,1);
            verify(!panel.expanded);
        }
        function test_each_browser_icon_routes_mouse_and_keyboard_open() {
            manager.editFavorite(null);manager.draft({title:"Portal",url:"https://example.com/"});settle();manager.back();settle();
            const id=manager.favorites[0].id;
            for(let index=0;index<manager.browsers.length;index++) {
                panel.expanded=true;settle();field("grid").forceLayout();wait(100);
                const browser=manager.browsers[index];
                const button=findChild(field("grid").itemAtIndex(0),"favorites-browser-"+id+"-"+browser.id);
                verify(button!==null);verify(button.visible);
                if(index===0)mouseClick(button);else {
                    const action=button.children.find(child=>child.activeFocusOnTab===true);
                    verify(action!==undefined);action.forceActiveFocus();keyClick(Qt.Key_Return);
                }
                settle();assertEqual(manager.error,"");
                assertEqual(manager.job.action,"open");assertEqual(manager.job.payload.browser,browser.id);
                assertEqual(manager.favorites[0].clickCount,index+1);
                assertEqual(manager.defaultBrowser,"browser.desktop");verify(!panel.expanded);
            }
        }
        function test_many_browser_icons_wrap_inside_favorite() {
            manager.editFavorite(null);manager.draft({title:"Portal",url:"https://example.com/"});settle();manager.back();settle();
            manager.browsers=Array.from({length:12},(_,i)=>({id:"test-"+i+".desktop",name:"Browser "+i,icon:""}));
            field("grid").forceLayout();wait(100);
            const card=field("grid").itemAtIndex(0);
            for(const browser of manager.browsers) {
                const button=findChild(card,"favorites-browser-"+manager.favorites[0].id+"-"+browser.id);
                const point=button.mapToItem(card,0,0);
                verify(point.x>=0 && point.x+button.width<=card.width);
                verify(point.y>=0 && point.y+button.height<=card.height);
            }
            const edit=findChild(card,"favorites-edit-"+manager.favorites[0].id);
            verify(edit.mapToItem(card,0,edit.height).y<=card.height);
        }
        function test_keyboard_open_increments_once(){
            try {
            manager.editFavorite(null);manager.draft({title:"Portal",url:"https://example.com/"});settle();manager.back();settle();
            field("grid").forceLayout();wait(100);const card=field("grid").itemAtIndex(0);verify(card!==null);const action=findChild(card,"favorites-open-"+manager.favorites[0].id);verify(action!==null);action.forceActiveFocus();keyClick(Qt.Key_Return);settle();
            assertEqual(manager.favorites[0].clickCount,1);
            } catch(e) {console.warn("test_keyboard_open_increments_once",e.message,String(e.stack).split("\n").slice(0,5).join("\n"));throw e;}
        }
        function test_import_button_accepts_browser_html() {
            assertEqual(field("import").label,"Import");assertEqual(field("export").label,"Export");
            manager.run("import-preview",{path:Quickshell.env("SPECTRUM_FAVORITES_TEST_DIR")+"/browser.html"});settle();
            assertEqual(manager.preview.added,1);assertEqual(manager.preview.invalid,1);assertEqual(manager.favorites.length,0);
            mouseClick(field("import-confirm"));settle();
            assertEqual(manager.favorites.length,1);assertEqual(manager.favorites[0].title,"Browser portal");assertEqual(manager.favorites[0].clickCount,0);
            assertEqual(manager.categoryName(manager.favorites[0].category),"Bookmarks bar");
        }
        function dragFavoriteToCategory(category) {
            field("grid").forceLayout();wait(50);
            const card=field("grid").itemAtIndex(0);verify(card!==null);
            const action=findChild(card,"favorites-open-"+manager.visibleFavorites[0].id);
            const categoryButton=field("categories").itemAt(manager.categoryList.findIndex(c=>c.id===category));
            const target=findChild(categoryButton,"favorites-drop-"+category);verify(action!==null);verify(target!==null);
            const point=target.mapToItem(action,target.width/2,target.height/2);
            mousePress(action,12,12,Qt.LeftButton);
            mouseMove(action,50,12,30,Qt.LeftButton);wait(40);
            mouseMove(action,point.x,point.y,40,Qt.LeftButton);wait(80);
            const accepted=target.containsDrag;
            mouseRelease(action,point.x,point.y,Qt.LeftButton);settle();
            if(category!=="top")verify(accepted,"Destination category did not accept the drag");
        }
        function test_drag_to_another_category_moves_without_opening() {
            try {
            manager.run("import-apply",{path:Quickshell.env("SPECTRUM_FAVORITES_TEST_DIR")+"/fixture.json"});settle();
            manager.editCategory(null);manager.draft({name:"Destination"});settle();const destination=manager.categories.find(c=>c.name==="Destination");
            manager.back();manager.selectCategory(manager.categories.find(c=>c.name==="Work").id);settle();
            const id=manager.visibleFavorites[0].id;const count=manager.visibleFavorites[0].clickCount;
            dragFavoriteToCategory(destination.id);
            assertEqual(manager.favorites.find(f=>f.id===id).category,destination.id);
            assertEqual(manager.favorites.find(f=>f.id===id).clickCount,count);
            assertEqual(manager.visibleFavorites.length,1);verify(panel.expanded);
            manager.selectCategory(destination.id);settle();assertEqual(manager.visibleFavorites[0].id,id);
            } catch(e) {console.warn("test_drag_to_another_category_moves_without_opening",e.message,String(e.stack));throw e;}
        }
        function test_drag_to_top_is_rejected_without_opening() {
            try {
            manager.run("import-apply",{path:Quickshell.env("SPECTRUM_FAVORITES_TEST_DIR")+"/fixture.json"});settle();
            const work=manager.categories.find(c=>c.name==="Work").id;manager.selectCategory(work);settle();
            const id=manager.visibleFavorites[0].id;const count=manager.visibleFavorites[0].clickCount;
            dragFavoriteToCategory("top");
            assertEqual(manager.favorites.find(f=>f.id===id).category,work);assertEqual(manager.favorites.find(f=>f.id===id).clickCount,count);verify(panel.expanded);
            const action=findChild(field("grid").itemAtIndex(0),"favorites-open-"+id);action.forceActiveFocus();keyClick(Qt.Key_Return);settle();
            assertEqual(manager.favorites.find(f=>f.id===id).clickCount,count+1);
            } catch(e) {console.warn("test_drag_to_top_is_rejected_without_opening",e.message,String(e.stack));throw e;}
        }
        function test_icons_worker_receives_input_and_finishes() {
            const previous=manager.iconRevision;manager.iconsWanted=true;
            tryVerify(()=>manager.iconRevision>previous,5000,"Favicon worker did not return a result");
        }
        function test_z_preview() {
            manager.browsers=[{id:"brave-browser.desktop",name:"Brave",icon:"brave-desktop"},{id:"firefox.desktop",name:"Firefox",icon:"firefox"},{id:"google-chrome.desktop",name:"Google Chrome",icon:"google-chrome"},{id:"zen.desktop",name:"Zen Browser",icon:"zen-browser"}];
            manager.defaultBrowser="zen.desktop";
            manager.categories=[{id:"uncategorized",name:"Uncategorized"},{id:"work",name:"Work"},{id:"music",name:"Music"},{id:"linux",name:"Linux"}];
            manager.favorites=[{id:"1",title:"SpectrumOS",url:"https://gibranlp.dev/en/spectrum/",host:"gibranlp.dev",icon:"",category:"linux",clickCount:48},{id:"2",title:"Questline",url:"https://questlinecli.com/",host:"questlinecli.com",icon:"",category:"work",clickCount:31},{id:"3",title:"Arch Linux",url:"https://archlinux.org/",host:"archlinux.org",icon:"",category:"linux",clickCount:24},{id:"4",title:"Your next soundtrack",url:"https://example.com/music",host:"example.com",icon:"",category:"music",clickCount:12}];
            manager.view=({category:"top",search:"",editor:"",draft:{}});wait(200);
            const file=Quickshell.env("SPECTRUM_FAVORITES_SCREENSHOT");
            if (file) {
                let captured=false;
                findChild(panel,"favorites-frame").grabToImage(result=>{result.saveToFile(file);captured=true;});
                tryVerify(()=>captured,5000);
            }
        }
    }
}
