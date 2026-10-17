import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Item {
    Shell.QuestlineTreasury { id: treasury }
    TestCase {
        name: "QuestlineTreasury"
        function init() {
            treasury.campaigns = [{ id: "a", name: "Alpha" }, { id: "b", name: "Beta" }, { id: "c", name: "Empty" }];
            treasury.entries = [{ id: "one", campaign_id: "a", campaign: "Alpha" },
                                { id: "two", campaign_id: "b", campaign: "Beta" }];
            treasury.accounts = [{ id: "cash-a", campaign_id: "a", balance_minor: 100 },
                                 { id: "zero-a", campaign_id: "a", balance_minor: 0 },
                                 { id: "cash-b", campaign_id: "b", balance_minor: -200 }];
            treasury.campaignId = "a";
        }
        function test_selectionFiltersEntriesAndAccounts() {
            compare(treasury.items.map(entry => entry.id), ["one"]);
            compare(treasury.currentAccounts.map(account => account.id), ["cash-a"]);
            compare(treasury.projects.map(project => project.count), [1, 1, 0]);
            treasury.campaignId = "b";
            compare(treasury.items.map(entry => entry.id), ["two"]);
            compare(treasury.currentAccounts.map(account => account.id), ["cash-b"]);
            treasury.campaignId = "c";
            compare(treasury.items.length, 0);
            compare(treasury.currentAccounts.length, 0);
            compare(treasury.resolveCampaign("c"), "c");
        }
        function test_refreshPreservesSelectionAndUpdatesBalances() {
            treasury.accounts = [{ id: "cash-a", campaign_id: "a", balance_minor: 0 }];
            treasury.entries = [];
            compare(treasury.currentAccounts.length, 0);
            compare(treasury.resolveCampaign("a"), "a");
            treasury.campaigns = [{ id: "b", name: "Beta" }];
            treasury.accounts = [];
            compare(treasury.resolveCampaign("a"), "b");
        }
        function test_olderCampaignsAndAccountsWithoutEntriesRemainAccessible() {
            treasury.entries = [{ id: "old", campaign_id: "old", campaign: "Older campaign" }];
            treasury.accounts = [{ id: "cash", campaign_id: "bank", campaign: "Bank", balance_minor: 500 }];
            compare(treasury.projects.length, 5);
            treasury.campaignId = "old";
            compare(treasury.items[0].id, "old");
            treasury.campaignId = "bank";
            compare(treasury.currentAccounts[0].id, "cash");
            compare(treasury.resolveCampaign("missing"), "bank");
            treasury.entries = [];
            treasury.accounts = [];
            treasury.campaigns = [];
            compare(treasury.resolveCampaign("missing"), "");
        }
    }
}
