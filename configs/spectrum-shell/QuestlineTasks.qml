import QtQuick

QtObject {
    property var campaigns: []
    property var tasks: []
    property string campaignId: ""
    readonly property var projects: {
        const byId = new Map();
        for (const campaign of campaigns)
            byId.set(campaign.id, { id: campaign.id, name: campaign.name, count: 0 });
        for (const task of tasks) {
            const id = task.project_id || "";
            if (!byId.has(id))
                byId.set(id, { id: id, name: task.campaign || "Unfiled", count: 0 });
            byId.get(id).count += 1;
        }
        return Array.from(byId.values()).sort((a, b) => a.name.localeCompare(b.name));
    }
    readonly property var items: tasks.filter(task => (task.project_id || "") === campaignId)

    function resolveCampaign(id): string {
        if (projects.some(project => project.id === id))
            return id;
        return (projects.find(project => project.count > 0) || projects[0] || { id: "" }).id;
    }
}
