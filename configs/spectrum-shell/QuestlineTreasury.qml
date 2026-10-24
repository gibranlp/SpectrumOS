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
    readonly property var currentAccounts: accounts.filter(account => (account.campaign_id || "") === campaignId && (!account.is_default || account.balance_minor !== 0))

    readonly property var currencyTotals: {
        const totals = {};
        const ensure = currency => {
            if (!totals[currency]) totals[currency] = {currency:currency,income:0,paid:0,committed:0,saved:0,invested:0,liquidSavings:0,available:0};
            return totals[currency];
        };
        for (const account of accounts.filter(item => item.campaign_id === campaignId)) {
            const total = ensure(account.currency_code || "USD");
            if (account.kind === "Savings") {
                total.saved += account.balance_minor || 0;
                if (account.savings_status === "Invested") total.invested += account.balance_minor || 0;
                else total.liquidSavings += account.balance_minor || 0;
            }
        }
        for (const entry of items) {
            const total = ensure(entry.currency_code || "USD");
            if (entry.entry_type === "Income" && ["Approved","Paid"].includes(entry.status)) total.income += entry.amount_minor;
            if (entry.entry_type === "Expense" && entry.status === "Paid") total.paid += entry.amount_minor;
            if (entry.entry_type === "Expense" && entry.status === "Approved") total.committed += entry.amount_minor;
        }
        return Object.values(totals).map(total => Object.assign(total,{available:total.income-total.paid-total.committed-total.saved}));
    }
    function estimate(account): string {
        const rate = account.interest_rate_bps || 0;
        const base = Math.max(0,account.balance_minor || 0);
        const estimate = Math.floor(base * rate / 10000);
        if (!Number.isSafeInteger(estimate) || !Number.isSafeInteger(base * rate)) return "Estimate unavailable";
        return "Estimated interest: " + account.currency_code + " " + (estimate / 100).toLocaleString(Qt.locale(),'f',2)
            + (account.interest_period === "Monthly" ? " / month" : " / year");
    }

    function resolveCampaign(id): string {
        if (projects.some(project => project.id === id))
            return id;
        return (projects.find(project => project.count > 0 || project.hasAccounts) || projects[0] || { id: "" }).id;
    }
}
