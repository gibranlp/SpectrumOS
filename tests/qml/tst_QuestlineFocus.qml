import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Item {
    width: 1500
    height: 900
    QtObject {
        id: theme
        property string fontFamily: "Sans"
        property int fontSize: 14
        property QtObject colors: QtObject {
            property color background: "#101820"
            property color surface_alt: "#203040"
            property color foreground: "#eeeeee"
            property color muted: "#aaaaaa"
            property color accent: "#60bfff"
            property color error: "#ff6060"
        }
    }
    Shell.QuestlineFocus { id: focus; anchors.fill: parent; theme: theme; focusState: ({ phase: "idle" }) }
    SignalSpy { id: start; target: focus; signalName: "focusStart" }
    SignalSpy { id: action; target: focus; signalName: "focusAction" }
    TestCase {
        name: "QuestlineFocus"
        when: windowShown
        function init() {
            focus.focusState = { phase: "idle" };
            focus.questline = { available: true, campaigns: [{ id: "a", name: "Alpha" }, { id: "b", name: "Beta" }],
                tasks: [{ id: "one", project_id: "a", title: "First task", priority: "High" },
                        { id: "two", project_id: "b", title: "Second task", priority: "Medium" }] };
            focus.projectId = "a";
            focus.taskId = "";
            focus.duration = 25;
            focus.soundscape = "Silent";
            wait(0);
            start.clear();
            action.clear();
        }
        function test_campaignSwitchFiltersTasksAndClearsSelection() {
            focus.selectTask("one");
            compare(focus.tasks.map(task => task.id), ["", "one"]);
            focus.selectCampaign("b");
            compare(focus.taskId, "");
            compare(focus.tasks.map(task => task.id), ["", "two"]);
            focus.selectCampaign("");
            compare(focus.tasks.length, 1);
        }
        function test_startUsesSelectedCampaignTaskSoundAndDuration() {
            focus.selectTask("one");
            focus.selectSoundscape("Rain Sounds");
            focus.duration = 45;
            focus.startOrToggle();
            compare(start.count, 1);
            compare(start.signalArguments[0][0], { duration: 45, project_id: "a", task_id: "one",
                campaign: "Alpha", task: "First task", soundscape: "Rain Sounds" });
        }
        function test_runningSessionSynchronizesTimerAndLocksSelections() {
            focus.focusState = { phase: "work", remaining: 89, project_id: "b", task_id: "two", duration: 30, soundscape: "Forest Sounds" };
            compare(focus.remaining, 89);
            focus.selectCampaign("a");
            focus.selectTask("one");
            focus.selectSoundscape("Silent");
            compare(focus.projectId, "b");
            compare(focus.taskId, "two");
            compare(focus.soundscape, "Forest Sounds");
            focus.startOrToggle();
            compare(action.signalArguments[0][0], "toggle");
            compare(start.count, 0);
            focus.focusState = { phase: "paused", remaining: 89, project_id: "b", task_id: "two", duration: 30, soundscape: "Forest Sounds" };
            focus.startOrToggle();
            compare(action.count, 2);
            focus.focusState = { phase: "starting" };
            focus.startOrToggle();
            compare(action.count, 2);
        }
        function test_catalogRefreshClearsRemovedTaskAndKeepsCampaign() {
            focus.selectTask("one");
            focus.questline = { available: true, campaigns: focus.questline.campaigns, tasks: [] };
            tryCompare(focus, "taskId", "");
            compare(focus.projectId, "a");
            focus.questline = { available: true, campaigns: [], tasks: [] };
            tryCompare(focus, "projectId", "");
        }
        function test_unavailableProfileCannotStart() {
            focus.questline = { available: false };
            focus.startOrToggle();
            compare(start.count, 0);
        }
    }
}
