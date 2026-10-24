import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

ColumnLayout {
    id: editor
    required property var theme
    required property var account
    property bool expanded: false
    property bool busy: false
    property var viewport: null
    property string status: account.savings_status || "Available"
    property string period: account.interest_period || "Annual"
    property string rate: ((account.interest_rate_bps || 0) / 100).toFixed(2)
    readonly property bool valid: /^\d+(\.\d{1,2})?$/.test(rate) && Number(rate) <= 10000
    function reveal(item): void {
        if (!viewport) return;
        const position = item.mapToItem(viewport.contentItem,0,0);
        if (position.y < viewport.contentY) viewport.contentY = position.y;
        else if (position.y + item.height > viewport.contentY + viewport.height)
            viewport.contentY = position.y + item.height - viewport.height;
    }
    signal saveRequested(var payload)
    spacing: 5
    ShellButton {
        id: settingsButton
        onActiveFocusChanged: if (activeFocus) editor.reveal(settingsButton)
        objectName: "questline-savings-settings-" + editor.account.id
        Layout.fillWidth: true
        label: editor.expanded ? "Close settings" : "Savings settings"
        fontFamily: editor.theme.fontFamily; fontSize: editor.theme.fontSize - 2
        backgroundColor: editor.theme.colors.background; foregroundColor: editor.theme.colors.foreground
        onClicked: editor.expanded = !editor.expanded
    }
    ColumnLayout {
        visible: editor.expanded
        Layout.fillWidth: true
        spacing: 6
        Text {
            text: "Savings availability"
            color: editor.theme.colors.foreground
            font { family: editor.theme.fontFamily; pixelSize: editor.theme.fontSize - 2 }
        }
        FocusChoice {
            id: statusChoice
            onActiveFocusChanged: if (activeFocus) editor.reveal(statusChoice)
            objectName: "questline-savings-status-" + editor.account.id
            Layout.fillWidth: true
            theme: editor.theme
            model: ["Available", "Invested"]
            currentIndex: editor.status === "Invested" ? 1 : 0
            onActivated: editor.status = model[currentIndex]
        }
        Text {
            text: "Interest rate (%)"
            color: editor.theme.colors.foreground
            font { family: editor.theme.fontFamily; pixelSize: editor.theme.fontSize - 2 }
        }
        Controls.TextField {
            id: rateField
            onActiveFocusChanged: if (activeFocus) editor.reveal(rateField)
            objectName: "questline-savings-rate-" + editor.account.id
            Layout.fillWidth: true
            text: editor.rate
            selectByMouse: true
            color: editor.theme.colors.foreground
            font { family: editor.theme.fontFamily; pixelSize: editor.theme.fontSize - 1 }
            background: Rectangle { radius: 6; color: editor.theme.colors.background }
            onTextEdited: editor.rate = text
        }
        FocusChoice {
            id: periodChoice
            onActiveFocusChanged: if (activeFocus) editor.reveal(periodChoice)
            objectName: "questline-savings-period-" + editor.account.id
            Layout.fillWidth: true
            theme: editor.theme
            model: ["Monthly", "Annual"]
            currentIndex: editor.period === "Monthly" ? 0 : 1
            onActivated: editor.period = model[currentIndex]
        }
        Text {
            Layout.fillWidth: true
            text: "Estimates only. No automatic interest entries."
            wrapMode: Text.Wrap
            color: editor.theme.colors.muted
            font { family: editor.theme.fontFamily; pixelSize: editor.theme.fontSize - 3 }
        }
        ShellButton {
            id: saveButton
            onActiveFocusChanged: if (activeFocus) editor.reveal(saveButton)
            objectName: "questline-savings-save-" + editor.account.id
            Layout.fillWidth: true
            label: "Save savings settings"
            enabled: editor.valid && !editor.busy
            fontFamily: editor.theme.fontFamily; fontSize: editor.theme.fontSize - 2
            backgroundColor: editor.theme.colors.accent; foregroundColor: editor.theme.colors.background
            onClicked: editor.saveRequested({action:"configure_savings",id:editor.account.id,version:editor.account.version,
                savings_status:editor.status,interest_rate:editor.rate,interest_period:editor.period})
        }
    }
}
