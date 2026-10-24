import QtQuick
import Quickshell.Io

Item {
    id: manager
    required property var theme
    visible: false
    property var favorites: []
    property var categories: []
    property var versions: ({})
    property string account: ""
    property bool active: false
    property var view: ({category:"top", search:"", editor:"", draft:{}})
    property var browsers: []
    property string defaultBrowser: ""
    property string httpBrowser: ""
    property var preview: null
    property string error: ""
    property string draftError: ""
    property string message: ""
    signal favoriteOpened()
    property bool ready: false
    property bool busy: process.running
    property bool choosing: busy && job && ["choose-import","choose-export"].includes(job.action)
    property var queue: []
    property var job: null
    property string response: ""
    property int revision: 0
    property bool pendingView: false
    property bool iconsWanted: false
    property int iconRevision:0
    function run(action, payload): void {
        const request = {action:action,payload:payload || {},revision:revision};
        queue = queue.filter(item => action !== "view-save" || item.action !== "view-save").concat([request]);
        pump();
    }
    function pump(): void {
        if (process.running || !queue.length) return;
        job = queue[0]; queue = queue.slice(1); response = "";
        if (job.action==="view-save" && job.payload.view.editor===view.editor && job.payload.view.draft.id===view.draft.id && view.baseVersion!==undefined) job.payload.view.baseVersion=view.baseVersion;
        process.exec([theme.backend("favorites-adapter"),job.action]);
    }
    function persist(): void {
        if (!ready || !pendingView) return;
        saveDelay.stop(); pendingView = false;
        run("view-save",{view:JSON.parse(JSON.stringify(view))});
    }
    function change(patch): void {
        view=Object.assign({},view,patch); revision++; pendingView=true; saveDelay.restart();
    }
    function draft(patch): void { change({draft:Object.assign({},view.draft,patch)}); }
    function newId(): string { return Date.now().toString(36)+Math.random().toString(36).slice(2,12); }
    function editFavorite(item): void {
        persist(); change({editor:"favorite",draft:item ? {id:item.id,title:item.title,url:item.url,category:categories.some(c=>c.id===item.category) ? item.category : "uncategorized"} : {id:newId(),title:"",url:"",category:view.category === "top" ? "uncategorized" : view.category},baseVersion:item ? (versions["favorite:"+item.id] || null) : null});
        draftError="";
    }
    function editCategory(item): void {
        persist(); change({editor:"category",draft:item ? {id:item.id,name:item.name} : {id:newId(),name:""},baseVersion:item ? (versions["favorite_category:"+item.id] || null) : null}); draftError="";
    }
    function back(): void {
        persist(); change({editor:"",draft:{}}); persist(); draftError="";
    }
    function save(): void {
        if (!ready || busy || choosing || !view.editor) return;
        saveDelay.stop(); pendingView=false;
        run("view-save",{view:JSON.parse(JSON.stringify(view)),finishEditing:true});
    }
    function moveFavorite(id,category): void {
        persist();
        if (view.editor === "favorite" && view.draft.id === id) change({draft:Object.assign({},view.draft,{category:category})});
        run("favorite-move",{id:id,category:category});
    }
    function selectCategory(id): void {
        if (view.editor) back(); change({category:id,search:""});
    }
    function refresh(): void { persist(); run("status"); run("browsers"); iconsWanted=true; }
    function categoryName(id): string {
        const found=categories.find(c=>c.id===id); return found ? found.name : "Uncategorized";
    }
    readonly property var ranked: favorites.slice().sort((a,b) => b.clickCount-a.clickCount || a.title.toLocaleLowerCase().localeCompare(b.title.toLocaleLowerCase()) || a.id.localeCompare(b.id))
    readonly property var visibleFavorites: {
        const query=view.search.trim().toLocaleLowerCase();
        if (query) return ranked.filter(f => [f.title,f.url,categoryName(f.category)].join(" ").toLocaleLowerCase().includes(query));
        const selected=view.category;
        return selected === "top" ? ranked.slice(0,24) : ranked.filter(f=>f.category===selected || (selected==="uncategorized" && !categories.some(c=>c.id===f.category)));
    }
    readonly property var categoryList: [{id:"top",name:"TOP"}].concat(categories.slice().sort((a,b)=>a.name.localeCompare(b.name)))
    Timer {
        interval:2500; repeat:true; running:manager.active
        onTriggered:if (!manager.busy && !manager.pendingView && !manager.queue.length) manager.run("status")
    }
    Timer { id:saveDelay; interval:650; onTriggered:manager.persist() }
    Timer {
        interval:700; running:manager.iconsWanted && !process.running && !icons.running; repeat:false
        onTriggered: { manager.iconsWanted=false; icons.exec([manager.theme.backend("favorites-adapter"),"icons"]); }
    }
    Process {
        id:process
        stdinEnabled:true
        onStarted: { write(JSON.stringify(manager.job.payload)+"\n"); }
        stdout: StdioCollector { onStreamFinished:manager.response=text }
        onExited:(code,status)=> {
            let changedAccount=false;
            try {
                const result=JSON.parse(manager.response);
                if (!result.ok) manager.error=result.error || "Favorites could not complete that action.";
                else {
                    manager.error="";
                    if (result.state) {
                        manager.favorites=result.state.favorites;
                        manager.categories=result.state.categories;
                        changedAccount=!!(manager.account && result.state.questlineAccount && manager.account!==result.state.questlineAccount);
                        manager.account=result.state.questlineAccount || "";
                        manager.versions=result.state._versions || {};
                        if (!manager.ready || changedAccount) { manager.view=result.state.view; manager.ready=true; }
                        if (changedAccount) { manager.queue=[];manager.pendingView=false;saveDelay.stop();manager.draftError=""; }
                        if (["view-save","favorite-move"].includes(manager.job.action) && result.state.view && result.state.view.editor===manager.view.editor && result.state.view.draft.id===manager.view.draft.id && result.state.view.baseVersion!==undefined) manager.view=Object.assign({},manager.view,{baseVersion:result.state.view.baseVersion});
                        if (manager.job.action === "category-delete" && manager.revision===manager.job.revision) manager.view=result.state.view;
                    }
                    if (result.draftError !== undefined && manager.job.revision===manager.revision) manager.draftError=result.draftError;
                    if (result.message) manager.message=result.message;
                    if (result.browsers) { manager.browsers=result.browsers; manager.defaultBrowser=result.defaultBrowser; manager.httpBrowser=result.httpBrowser; }
                    if (result.preview) manager.preview=result.preview;
                    if (manager.job.action==="import-apply") { manager.preview=null;manager.iconsWanted=true; }
                    if (manager.job.action==="view-save") manager.iconsWanted=true;
                    if (manager.job.action==="open") manager.favoriteOpened();
                    if (manager.job.action==="view-save" && manager.job.payload.finishEditing && !result.draftError
                        && !changedAccount && manager.job.revision===manager.revision
                        && manager.job.payload.view.editor===manager.view.editor
                        && manager.job.payload.view.draft.id===manager.view.draft.id) manager.back();
                }
            } catch(error) { manager.error="Could not read the Favorites response. Your saved data has been preserved."; }
            Qt.callLater(()=>manager.pump());
        }
    }
    Process {
        id:icons
        stdinEnabled:true
        onStarted:write("{}\n")
        stdout: StdioCollector { onStreamFinished: {
            try {
                const result=JSON.parse(text);
                if (result.ok && result.icons) { manager.favorites=manager.favorites.map(f=>Object.assign({},f,{icon:result.icons[f.id] || f.icon}));manager.iconRevision++; }
            } catch(error) {}
        } }
    }
    Component.onCompleted:run("status")
}
