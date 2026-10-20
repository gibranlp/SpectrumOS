import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Item {
    width: 680
    height: 1000
    Shell.QuestlineCalendar {
        id: calendar
        width: 620
        theme: ({fontFamily: "monospace", fontSize: 14, colors: {
            surface: "#222222", surface_alt: "#333333", foreground: "#eeeeee", muted: "#aaaaaa",
            accent: "#66ccee", warning: "#e6bd57", error: "#ff6666"}})
    }
    SignalSpy { id: requested; target: calendar; signalName: "itemRequested" }
    TestCase {
        name: "QuestlineCalendar"
        when: windowShown
        function init() {
            calendar.today = new Date(2026, 9, 18, 12);
            calendar.month = new Date(2026, 9, 1);
            calendar.selectedDate = "2026-10-18";
            calendar.loaded = true;
            calendar.width = 620;
            calendar.questline = {available: true, tasks: [
                {id: "task", title: "Submit work", campaign: "Alpha", due_date: "2026-10-18"},
                {id: "later", title: "Later work", due_date: "2026-11-01"},
                {id: "done", title: "Completed", due_date: "2026-10-18", completed: true},
                {id: "bad", title: "Invalid date", due_date: "2026-02-30"}], steps: [
                {id: "step", parent_task_id: "task", title: "Draft", due_date: "2026-10-18"},
                {id: "done-step", parent_task_id: "task", due_date: "2026-10-18", completed: true},
                {id: "orphan", parent_task_id: "gone", due_date: "2026-10-18"},
                {id: "completed-parent", parent_task_id: "done", due_date: "2026-10-18"}]};
            requested.clear();
            wait(30);
        }
        function test_filters_completed_orphaned_and_invalid_due_dates() {
            compare(calendar.entries.map(item => item.stepId || item.taskId), ["step", "task", "later"]);
            compare(calendar.selectedEntries.length, 2);
            compare(findChild(calendar,"calendar-day-2026-10-18").count, 2);
        }
        function test_local_date_urgency_crosses_month_and_year() {
            compare(calendar.urgency("2026-10-17"), "due");
            compare(calendar.urgency("2026-10-18"), "due");
            compare(calendar.urgency("2026-10-19"), "soon");
            compare(calendar.urgency("2026-10-21"), "soon");
            compare(calendar.urgency("2026-10-22"), "later");
            calendar.today = new Date(2026, 11, 30, 23, 59);
            compare(calendar.urgency("2027-01-01"), "soon");
            compare(calendar.urgency("2027-01-03"), "later");
            compare(calendar.dueColor("2027-01-01"), calendar.theme.colors.warning);
        }
        function test_click_day_then_task_and_step() {
            calendar.selectedDate = "2026-10-01";
            mouseClick(findChild(calendar,"calendar-day-2026-10-18"));
            compare(calendar.selectedDate,"2026-10-18");
            const agenda = findChild(calendar,"calendar-agenda");
            tryCompare(agenda,"count",2);
            wait(40);
            mouseClick(agenda.itemAtIndex(0));
            compare(Array.from(requested.signalArguments[0]), ["task", "step"]);
            mouseClick(agenda.itemAtIndex(1));
            compare(Array.from(requested.signalArguments[1]), ["task", ""]);
        }
        function test_keyboard_day_activation_and_month_navigation() {
            const day = findChild(calendar,"calendar-day-2026-10-22");
            const action = day.children.find(item => item.hasOwnProperty("activated"));
            verify(action!==undefined);action.forceActiveFocus();keyClick(Qt.Key_Return);
            compare(calendar.selectedDate,"2026-10-22");
            mouseClick(findChild(calendar,"calendar-next"));
            compare(calendar.selectedDate,"2026-11-01");
            compare(calendar.selectedEntries[0].taskId,"later");
            mouseClick(findChild(calendar,"calendar-previous"));
            compare(calendar.selectedDate,"2026-10-01");
            calendar.month = new Date(2028, 1, 1);
            compare(calendar.daysInMonth,29);
            verify(findChild(calendar,"calendar-day-2028-02-29")!==null);
        }
        function test_catalog_refresh_and_unavailable_state_clear_markers() {
            calendar.questline = {available: true, tasks: [], steps: []};
            compare(calendar.selectedEntries.length,0);
            compare(findChild(calendar,"calendar-day-2026-10-18").count,0);
            calendar.questline = {available: false, error: "Database unavailable"};
            compare(calendar.entries.length,0);
        }
        function test_busy_day_scrolls_and_narrow_calendar_fits() {
            calendar.width = 440;
            calendar.questline = {available: true, tasks: Array.from({length: 30}, (_, i) => ({
                id: "task-" + i, title: "Task " + i, due_date: "2026-10-18"}))};
            const agenda = findChild(calendar,"calendar-agenda");
            tryCompare(agenda,"count",30);wait(50);
            verify(agenda.contentHeight > agenda.height);
            mouseWheel(agenda,100,60,0,-120);wait(60);
            verify(agenda.contentY > 0);
            const lastDay = findChild(calendar,"calendar-day-2026-10-31");
            const position = lastDay.mapToItem(calendar, lastDay.width,0);
            verify(position.x <= calendar.width);
        }
    }
}
