import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Item {
    Shell.QuestlineTasks { id: tasks }
    TestCase {
        name: "QuestlineTasks"
        function init() {
            tasks.campaigns = [{ id: "a", name: "Alpha" }, { id: "b", name: "Beta" }, { id: "c", name: "Empty" }];
            tasks.tasks = [{ id: "one", project_id: "a", campaign: "Alpha" },
                           { id: "two", project_id: "b", campaign: "Beta" },
                           { id: "three", project_id: "a", campaign: "Alpha" }];
            tasks.campaignId = "a";
        }
        function test_selectionFiltersTasksAndKeepsEmptyCampaigns() {
            compare(tasks.items.map(task => task.id), ["one", "three"]);
            compare(tasks.projects.map(project => project.count), [2, 1, 0]);
            tasks.campaignId = "b";
            compare(tasks.items.map(task => task.id), ["two"]);
            tasks.campaignId = "c";
            compare(tasks.items.length, 0);
            compare(tasks.resolveCampaign("c"), "c");
        }
        function test_refreshPreservesCampaignAndUpdatesCounts() {
            tasks.tasks = tasks.tasks.filter(task => task.id !== "one");
            compare(tasks.items.map(task => task.id), ["three"]);
            compare(tasks.projects[0].count, 1);
            compare(tasks.resolveCampaign("a"), "a");
            tasks.campaigns = [{ id: "b", name: "Beta" }];
            tasks.tasks = tasks.tasks.filter(task => task.project_id === "b");
            compare(tasks.resolveCampaign("a"), "b");
        }
        function test_unfiledAndOlderCampaignTasksRemainAccessible() {
            tasks.tasks = [{ id: "old", project_id: "archived", campaign: "Older campaign" },
                           { id: "loose", project_id: null, campaign: "Unfiled" }];
            compare(tasks.projects.length, 5);
            tasks.campaignId = "archived";
            compare(tasks.items[0].id, "old");
            tasks.campaignId = "";
            compare(tasks.items[0].id, "loose");
        }
        function test_invalidSelectionPrefersCampaignWithTasks() {
            tasks.tasks = [{ id: "two", project_id: "b", campaign: "Beta" }];
            compare(tasks.resolveCampaign("missing"), "b");
            tasks.campaigns = [];
            tasks.tasks = [];
            compare(tasks.resolveCampaign("missing"), "");
        }
    }
}
