import QtQuick

Item {
    id: store
    property bool ready: false
    property string profileKey: ""
    signal profileChanged()
    property string activeTab: "Overview"
    property string selectedProjectId: ""
    property var views: ({})
    property var drafts: ({})
    property var inFlight: null
    property string storageError: ""
    property bool blocked: false
    onBlockedChanged: if (!blocked) debounce.restart()
    property int debounceInterval: 900
    readonly property bool busy: inFlight !== null
    signal changed()
    signal saveRequested(var job)
    signal saved(string key, string id)

    function copy(value) { return JSON.parse(JSON.stringify(value)); }
    function snapshot() { return {version:1,profile_key:profileKey,activeTab:activeTab,selectedProjectId:selectedProjectId,views:views,drafts:drafts,inFlight:inFlight}; }
    function restore(data): void {
        if (data && data.version === 1) {
            profileKey=data.profile_key || "";
            views = data.views || {};
            drafts = data.drafts || {};
            activeTab = data.activeTab || "Overview";
            selectedProjectId = data.selectedProjectId === undefined ? projectForView(activeTab,views[activeTab] || {}) || "" : data.selectedProjectId;
            if (data.inFlight && drafts[data.inFlight.key] && data.inFlight.payload.action.indexOf("create_") === 0 && !data.inFlight.payload.autosave_id) {
                const next = copy(drafts);
                next[data.inFlight.key].error = qsTranslate("Spectrum", "A save was interrupted. Check the full app before retrying to avoid a duplicate.");
                drafts = next;
            }
        }
        inFlight = null;
        ready = true;
        debounce.restart();
    }
    function bindProfile(key): void {applyProfileKey(key);}
    function applyProfileKey(key): void {
        if(!ready || !key || key===profileKey)return;
        const replaced=!!profileKey || key.split(":").slice(1).join(":").length>0;
        if(replaced) {drafts={};views={};selectedProjectId="";inFlight=null;activeTab="Sync";}
        else {
            const next=copy(drafts);
            for(const id of Object.keys(next)) {
                const row=next[id];const saved=row.saved===JSON.stringify(row.payload);
                row.payload.profile_key=key;
                if(saved)row.saved=JSON.stringify(row.payload);
            }
            drafts=next;
        }
        profileKey=key;changed();
        if(replaced)profileChanged();
    }
    function projectForView(tab, view) {
        if (view.quickScrollPicker) return "";
        if (view.editing && ["Tasks","Scrolls","Treasury","Chronicles"].includes(tab) && view.editCampaignId) return view.editCampaignId;
        if (tab === "Tasks" || tab === "Chronicles") return view.campaignId;
        if (tab === "Scrolls") return view.scrollProjectId;
        if (tab === "Treasury") return view.treasuryCampaignId;
        if (tab === "Focus" && view.focus) return view.focus.projectId;
        return undefined;
    }
    function remember(tab, view): void {
        if (!ready) return;
        const next = copy(views);
        next[tab] = copy(view);
        views = next;
        activeTab = tab;
        const project = projectForView(tab,view);
        if (project !== undefined) selectedProjectId = project || "";
        changed();
    }
    function update(key, payload, valid, reason, initial): void {
        if (!ready || !key) return;
        const next = copy(drafts);
        const previous = next[key];
        payload = copy(payload);
        if(profileKey)payload.profile_key=profileKey;
        if (previous && previous.payload.id) {
            payload.id = previous.payload.id;
            payload.action = payload.action.replace("create_", "update_");
        }
        if (previous && previous.payload.autosave_id) payload.autosave_id = previous.payload.autosave_id;
        if (payload.action.indexOf("create_") === 0 && !payload.autosave_id)
            payload.autosave_id = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, c => {
                const r = Math.floor(Math.random() * 16);
                return (c === "x" ? r : (r & 3) | 8).toString(16);
            });
        payload.autosave = true;
        const fingerprint = JSON.stringify(payload);
        if (previous && JSON.stringify(previous.payload) === fingerprint && previous.valid === valid) return;
        next[key] = {payload:payload,valid:valid,reason:reason || "",error:"",
            saved:previous ? previous.saved : initial ? fingerprint : "",
            revision:previous ? previous.revision + 1 : 1,view:previous ? previous.view : null,tab:previous ? previous.tab : ""};
        drafts = next;
        changed();
        debounce.restart();
    }
    function keepDraftView(key, tab, view): void {
        if (!drafts[key]) return;
        const next = copy(drafts);
        next[key].view = copy(view);
        next[key].tab = tab;
        drafts = next;
        changed();
    }
    function status(key): string {
        const draft = drafts[key];
        if (storageError) return storageError;
        if (!draft) return qsTranslate("Spectrum", "Changes save automatically.");
        if (draft.error) return draft.error;
        if (inFlight && inFlight.key === key) return qsTranslate("Spectrum", "Saving…");
        if (!draft.valid) return qsTranslate("Spectrum", "Draft kept on this device. ") + draft.reason;
        return draft.saved === JSON.stringify(draft.payload) ? qsTranslate("Spectrum", "Autosaved") : qsTranslate("Spectrum", "Saving…");
    }
    function flush(): void {
        debounce.stop();
        if (!ready || busy || blocked || storageError) return;
        for (const key of Object.keys(drafts)) {
            const draft = drafts[key];
            if (!draft.valid || draft.error || draft.saved === JSON.stringify(draft.payload)) continue;
            inFlight = {key:key,payload:copy(draft.payload),revision:draft.revision};
            changed();
            saveRequested(copy(inFlight));
            return;
        }
    }
    function finish(result): void {
        if (!inFlight) return;
        const job = inFlight;
        const next = copy(drafts);
        const draft = next[job.key];
        if (draft) {
            if (result.error) draft.error = result.error;
            else {
                const committed = copy(job.payload);
                if (result.id) {
                    committed.id = result.id;
                    committed.action = committed.action.replace("create_", "update_");
                    draft.payload.id = result.id;
                    draft.payload.action = draft.payload.action.replace("create_", "update_");
                }
                draft.saved = JSON.stringify(committed);
            }
            drafts = next;
        }
        inFlight = null;
        changed();
        if (!result.error) saved(job.key,result.id || "");
        debounce.restart();
    }
    function retry(key): void {
        if (!drafts[key] || busy) return;
        const next = copy(drafts);
        next[key].error = "";
        drafts = next;
        storageError = "";
        changed();
        flush();
    }
    function forget(id): void {
        const next = copy(drafts);
        for (const key of Object.keys(next)) if (next[key].payload.id === id) delete next[key];
        drafts = next;
        changed();
    }
    Timer { id: debounce; interval: store.debounceInterval; onTriggered: store.flush() }
}
