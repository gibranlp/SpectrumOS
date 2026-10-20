pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: calendar
    required property var theme
    property var questline: ({available: false})
    property bool loaded: false
    property date today: new Date()
    property date month: new Date(today.getFullYear(), today.getMonth(), 1)
    property string selectedDate: dateKey(today)
    readonly property int offset: (month.getDay() + 6) % 7
    readonly property int daysInMonth: new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate()
    readonly property var entries: dueEntries()
    readonly property var selectedEntries: entries.filter(item => item.date === selectedDate)
    signal itemRequested(string taskId, string stepId)
    spacing: 12

    function dateKey(value): string { return Qt.formatDate(value, "yyyy-MM-dd"); }
    function validDate(value): bool {
        if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
        const parts = value.split("-").map(Number);
        return dateKey(new Date(parts[0], parts[1] - 1, parts[2], 12)) === value;
    }
    function dueEntries() {
        if (!questline.available) return [];
        const tasks = (questline.tasks || []).filter(task => !task.completed);
        const parents = new Map(tasks.map(task => [task.id, task]));
        const result = tasks.filter(task => validDate(task.due_date)).map(task => ({
            taskId: task.id, stepId: "", title: task.title, context: task.campaign || "Unfiled", date: task.due_date
        }));
        for (const step of questline.steps || []) {
            const parent = parents.get(step.parent_task_id);
            if (parent && !step.completed && validDate(step.due_date)) result.push({
                taskId: parent.id, stepId: step.id, title: step.title,
                context: (parent.campaign || "Unfiled") + " · " + parent.title, date: step.due_date
            });
        }
        return result.sort((a, b) => a.date.localeCompare(b.date) || a.title.localeCompare(b.title));
    }
    function urgency(value): string {
        const parts = value.split("-").map(Number);
        const days = (Date.UTC(parts[0], parts[1] - 1, parts[2])
            - Date.UTC(today.getFullYear(), today.getMonth(), today.getDate())) / 86400000;
        return days <= 0 ? "due" : days <= 3 ? "soon" : "later";
    }
    function dueColor(value): color {
        const level = urgency(value);
        return level === "due" ? (theme.colors.error || "#ff8c9a") : level === "soon" ? (theme.colors.warning || "#e6bd57") : theme.colors.accent;
    }
    function showToday(): void {
        today = new Date();
        month = new Date(today.getFullYear(), today.getMonth(), 1);
        selectedDate = dateKey(today);
    }
    function changeMonth(delta): void {
        month = new Date(month.getFullYear(), month.getMonth() + delta, 1);
        selectedDate = dateKey(month);
    }
    onSelectedDateChanged: agenda.contentY = 0

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: monthContent.implicitHeight + 32
        radius: 18
        color: calendar.theme.colors.surface_alt
        ColumnLayout {
            id: monthContent
            anchors { fill: parent; margins: 16 }
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: Qt.formatDate(calendar.month, "MMMM yyyy")
                    color: calendar.theme.colors.foreground
                    font { family: calendar.theme.fontFamily; pixelSize: calendar.theme.fontSize + 3; bold: true }
                }
                ShellButton {
                    objectName: "calendar-today"
                    label: "Today"
                    fontFamily: calendar.theme.fontFamily
                    fontSize: calendar.theme.fontSize - 1
                    backgroundColor: calendar.theme.colors.surface
                    foregroundColor: calendar.theme.colors.foreground
                    onClicked: calendar.showToday()
                }
                Repeater {
                    model: [-1, 1]
                    ShellButton {
                        required property int modelData
                        objectName: modelData < 0 ? "calendar-previous" : "calendar-next"
                        label: modelData < 0 ? "‹" : "›"
                        fontFamily: calendar.theme.fontFamily
                        fontSize: calendar.theme.fontSize + 2
                        backgroundColor: calendar.theme.colors.surface
                        foregroundColor: calendar.theme.colors.foreground
                        onClicked: calendar.changeMonth(modelData)
                    }
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 7
                rowSpacing: 5
                columnSpacing: 5
                Repeater {
                    model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                    Text {
                        required property string modelData
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: calendar.theme.colors.muted
                        font { family: calendar.theme.fontFamily; pixelSize: calendar.theme.fontSize - 2 }
                    }
                }
                Repeater {
                    model: 42
                    Rectangle {
                        id: cell
                        required property int index
                        readonly property int day: index - calendar.offset + 1
                        readonly property bool valid: day > 0 && day <= calendar.daysInMonth
                        readonly property string key: valid ? calendar.dateKey(new Date(calendar.month.getFullYear(), calendar.month.getMonth(), day, 12)) : ""
                        readonly property int count: calendar.entries.filter(item => item.date === key).length
                        readonly property bool selected: valid && key === calendar.selectedDate
                        readonly property bool isToday: valid && key === calendar.dateKey(calendar.today)
                        readonly property color markerColor: count ? calendar.dueColor(key) : calendar.theme.colors.accent
                        objectName: "calendar-day-" + key
                        Layout.fillWidth: true
                        implicitHeight: Math.max(40, calendar.theme.fontSize + 26)
                        radius: 9
                        color: selected ? Qt.alpha(markerColor, 0.3) : count ? Qt.alpha(markerColor, 0.12) : "transparent"
                        border.width: selected || isToday ? 1 : 0
                        border.color: selected ? markerColor : calendar.theme.colors.accent
                        Accessible.role: Accessible.Button
                        Accessible.name: key + (count ? ", " + count + " due" : "")
                        Accessible.onPressAction: if (valid) calendar.selectedDate = key
                        Text {
                            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 5 }
                            text: cell.valid ? String(cell.day) : ""
                            color: cell.count ? cell.markerColor : calendar.theme.colors.foreground
                            font { family: calendar.theme.fontFamily; pixelSize: calendar.theme.fontSize + 1; bold: cell.isToday || cell.count > 0 }
                        }
                        Rectangle {
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 5 }
                            width: cell.count > 1 ? 15 : 5
                            height: 4
                            radius: 2
                            visible: cell.count > 0
                            color: cell.markerColor
                        }
                        KeyboardAction {
                            anchors.fill: parent
                            enabled: cell.valid
                            cursorShape: Qt.PointingHandCursor
                            onActivated: calendar.selectedDate = cell.key
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Repeater {
                    model: [{label: "Later", color: calendar.theme.colors.accent},
                        {label: "Within 3 days", color: calendar.theme.colors.warning || "#e6bd57"},
                        {label: "Today / overdue", color: calendar.theme.colors.error || "#ff8c9a"}]
                    RowLayout {
                        required property var modelData
                        spacing: 5
                        Rectangle { width: 5; height: 5; radius: 3; color: modelData.color }
                        Text {
                            text: modelData.label
                            color: calendar.theme.colors.muted
                            font { family: calendar.theme.fontFamily; pixelSize: calendar.theme.fontSize - 3 }
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: Qt.formatDate(new Date(Number(calendar.selectedDate.slice(0, 4)), Number(calendar.selectedDate.slice(5, 7)) - 1, Number(calendar.selectedDate.slice(8, 10)), 12), "dddd, d MMMM")
            + (calendar.selectedEntries.length ? " · " + calendar.selectedEntries.length + " due" : "")
        color: calendar.theme.colors.foreground
        wrapMode: Text.WordWrap
        font { family: calendar.theme.fontFamily; pixelSize: calendar.theme.fontSize; bold: true }
    }
    Text {
        Layout.fillWidth: true
        visible: calendar.selectedEntries.length === 0
        text: !calendar.loaded ? "Loading due dates…" : !calendar.questline.available
            ? (calendar.questline.error ? "Could not load Questline due dates." : "Questline due dates are unavailable.")
            : "No tasks or steps due on this day."
        color: calendar.theme.colors.muted
        wrapMode: Text.WordWrap
        font { family: calendar.theme.fontFamily; pixelSize: calendar.theme.fontSize - 1 }
    }
    ListView {
        id: agenda
        objectName: "calendar-agenda"
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 180)
        visible: count > 0
        clip: true
        spacing: 5
        boundsBehavior: Flickable.StopAtBounds
        model: calendar.selectedEntries
        delegate: Rectangle {
            required property var modelData
            width: agenda.width
            implicitHeight: agendaText.implicitHeight + 18
            radius: 10
            color: calendar.theme.colors.surface_alt
            RowLayout {
                anchors { fill: parent; margins: 9 }
                spacing: 10
                Rectangle { width: 4; Layout.fillHeight: true; radius: 2; color: calendar.dueColor(modelData.date) }
                ColumnLayout {
                    id: agendaText
                    Layout.fillWidth: true
                    spacing: 3
                    Text {
                        Layout.fillWidth: true
                        text: (modelData.stepId ? "Step · " : "Task · ") + modelData.title
                        elide: Text.ElideRight
                        color: calendar.theme.colors.foreground
                        font { family: calendar.theme.fontFamily; pixelSize: calendar.theme.fontSize; bold: true }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.context
                        elide: Text.ElideRight
                        color: calendar.theme.colors.muted
                        font { family: calendar.theme.fontFamily; pixelSize: calendar.theme.fontSize - 2 }
                    }
                }
                Text { text: "›"; color: calendar.theme.colors.muted; font.pixelSize: calendar.theme.fontSize + 4 }
            }
            KeyboardAction {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onActivated: calendar.itemRequested(modelData.taskId, modelData.stepId)
            }
        }
    }
}
