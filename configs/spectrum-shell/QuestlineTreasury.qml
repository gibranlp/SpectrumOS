import QtQuick

QtObject {
    property var campaigns: []
    property var entries: []
    property var accounts: []
    property string campaignId: ""

    readonly property var projects: {
        const byId = new Map();
        for (const campaign of campaigns)
            byId.set(campaign.id, { id: campaign.id, name: campaign.name, count: 0, hasAccounts: false });
        for (const item of accounts.concat(entries)) {
            const id = item.campaign_id || "";
            if (!byId.has(id))
                byId.set(id, { id: id, name: item.campaign || "Unfiled", count: 0, hasAccounts: false });
        }
        for (const entry of entries)
            byId.get(entry.campaign_id || "").count += 1;
        for (const account of accounts)
            byId.get(account.campaign_id || "").hasAccounts = true;
        return Array.from(byId.values()).sort((a, b) => a.name.localeCompare(b.name));
    }
    readonly property var items: entries.filter(entry => (entry.campaign_id || "") === campaignId)
    readonly property var currentAccounts: accounts.filter(account => (account.campaign_id || "") === campaignId && account.balance_minor !== 0)

    function resolveCampaign(id): string {
        if (projects.some(project => project.id === id))
            return id;
        return (projects.find(project => project.count > 0 || project.hasAccounts) || projects[0] || { id: "" }).id;
    }
}
