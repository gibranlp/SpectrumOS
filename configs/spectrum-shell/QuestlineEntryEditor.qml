import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

Controls.ScrollView {
    id: editor
    required property var theme
    property var fields: ({})
    property var accounts: []
    property var categories: []
    property var tasks: []
    property string campaignId: ""
    property string entryType: "Expense"
    property var legacyAccountIds: []
    signal edited(var value)
    clip: true
    contentWidth: availableWidth
    contentHeight: fieldsColumn.implicitHeight
    Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AsNeeded

    function reveal(item): void {
        const position = item.mapToItem(fieldsColumn,0,0);
        const viewport = contentItem;
        if (position.y < viewport.contentY) viewport.contentY = position.y;
        else if (position.y + item.height > viewport.contentY + viewport.height)
            viewport.contentY = position.y + item.height - viewport.height;
    }

    function update(name, value): void {
        const next = Object.assign({}, fields);
        next[name] = value;
        edited(next);
    }
    function choices(key) {
        let options = [];
        if (key === "account_id" || key === "transfer_account_id")
            options = accounts.filter(item => item.campaign_id === campaignId && (!item.is_default || legacyAccountIds.includes(item.id))
                && (key !== "transfer_account_id" || item.id !== fields.account_id));
        else if (key === "category_id")
            options = categories.filter(item => item.campaign_id === campaignId && item.entry_type === entryType);
        else if (key === "related_task_id")
            options = tasks.filter(item => item.project_id === campaignId).map(item => ({id:item.id,name:item.title}));
        else options = ["None","Weekly","Monthly","Yearly","Custom"].map(item => ({id:item,name:item}));
        if (key !== "recurrence") options = [{id:"",name:key === "category_id" ? qsTranslate("Spectrum", "Default category") : key === "account_id" || key === "transfer_account_id" ? qsTranslate("Spectrum", "Choose account") : qsTranslate("Spectrum", "None")}].concat(options);
        const selected = fields[key] || "";
        if (selected && !options.some(item => item.id === selected))
            options.push({id:selected,name:qsTranslate("Spectrum", "Unavailable selection")});
        return options;
    }

    ColumnLayout {
        id: fieldsColumn
        width: editor.availableWidth
        spacing: 12
        GridLayout {
            Layout.fillWidth: true
            columns: width >= 560 ? 2 : 1
            columnSpacing: 16
            rowSpacing: 12
            Repeater {
                model: [
                    {key:"account_id",label:editor.entryType === "Transfer" ? qsTranslate("Spectrum", "From account") : qsTranslate("Spectrum", "Account")},
                    {key:"category_id",label:qsTranslate("Spectrum", "Category")},
                    {key:"transfer_account_id",label:qsTranslate("Spectrum", "To account")},
                    {key:"related_task_id",label:qsTranslate("Spectrum", "Related task")},
                    {key:"recurrence",label:qsTranslate("Spectrum", "Recurrence")}
                ]
                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    visible: modelData.key !== "transfer_account_id" || editor.entryType === "Transfer"
                    Text {
                        text: modelData.label
                        color: editor.theme.colors.foreground
                        font { family: editor.theme.fontFamily; pixelSize: editor.theme.fontSize }
                    }
                    FocusChoice {
                        id: optionChoice
                        onActiveFocusChanged: if (activeFocus) editor.reveal(optionChoice)
                        objectName: "questline-entry-" + modelData.key
                        Layout.fillWidth: true
                        theme: editor.theme
                        translateModel: modelData.key === "recurrence"
                        model: editor.choices(modelData.key)
                        textRole: "name"
                        currentIndex: Math.max(0, model.findIndex(item => item.id === (editor.fields[modelData.key] || (modelData.key === "recurrence" ? "None" : ""))))
                        onActivated: editor.update(modelData.key, model[currentIndex].id)
                    }
                }
            }
            Repeater {
                model: [
                    {key:"entry_date",label:qsTranslate("Spectrum", "Entry date"),hint:qsTranslate("Spectrum", "YYYY-MM-DD")},
                    {key:"due_date",label:qsTranslate("Spectrum", "Due date"),hint:qsTranslate("Spectrum", "Optional · YYYY-MM-DD")},
                    {key:"payment_date",label:qsTranslate("Spectrum", "Payment date"),hint:qsTranslate("Spectrum", "Optional · YYYY-MM-DD")},
                    {key:"vendor_source",label:qsTranslate("Spectrum", "Vendor / source"),hint:qsTranslate("Spectrum", "Optional")},
                    {key:"custom_recurrence",label:qsTranslate("Spectrum", "Custom recurrence"),hint:qsTranslate("Spectrum", "Describe the schedule")},
                    {key:"description",label:qsTranslate("Spectrum", "Description"),hint:qsTranslate("Spectrum", "Optional")},
                    {key:"notes",label:qsTranslate("Spectrum", "Notes"),hint:qsTranslate("Spectrum", "Optional")},
                    {key:"attachment_ref",label:qsTranslate("Spectrum", "Attachment reference"),hint:qsTranslate("Spectrum", "Optional path or reference")}
                ]
                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    visible: modelData.key !== "custom_recurrence" || editor.fields.recurrence === "Custom"
                    Text {
                        text: modelData.label
                        color: editor.theme.colors.foreground
                        font { family: editor.theme.fontFamily; pixelSize: editor.theme.fontSize }
                    }
                    Controls.TextField {
                        id: inputField
                        onActiveFocusChanged: if (activeFocus) editor.reveal(inputField)
                        objectName: "questline-entry-" + modelData.key
                        Layout.fillWidth: true
                        implicitHeight: 40
                        text: editor.fields[modelData.key] || ""
                        placeholderText: modelData.hint
                        selectByMouse: true
                        color: editor.theme.colors.foreground
                        placeholderTextColor: editor.theme.colors.muted
                        font { family: editor.theme.fontFamily; pixelSize: editor.theme.fontSize }
                        background: Rectangle { radius: 8; color: editor.theme.colors.background }
                        onTextEdited: editor.update(modelData.key, text)
                    }
                }
            }
        }
    }
}
