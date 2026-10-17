import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: content
    required property var theme
    property bool active: false
    required property var manager
    readonly property bool busy: manager.busy
    spacing: 10
    onActiveChanged: if (active) manager.run(["status"])

    component Label: Text {
        Layout.fillWidth: true
        color: content.theme.colors.foreground
        wrapMode: Text.Wrap
        font { family: content.theme.fontFamily; pixelSize: content.theme.fontSize }
    }
    component Button: ShellButton {
        enabled: !content.manager.busy
        fontFamily: content.theme.fontFamily
        fontSize: content.theme.fontSize - 1
        backgroundColor: content.theme.colors.surface_alt
        foregroundColor: content.theme.colors.foreground
    }
    Label {
        text: "Keep your AppImages together and available in the application launcher."
        color: content.theme.colors.muted
    }
    RowLayout {
        Layout.fillWidth: true
        Button { objectName: "appimage-add"; label: "Add AppImage…"; Layout.fillWidth: true; onClicked: content.manager.run(["choose-add"]) }
        Button { objectName: "appimage-folder"; label: "Open folder"; onClicked: content.manager.run(["folder"]) }
    }
    Label {
        visible: content.manager.busy
        text: "Working…"
        color: content.theme.colors.muted
    }
    Label {
        objectName: "appimage-feedback"
        visible: text.length > 0
        text: content.manager.error || content.manager.message
        color: content.manager.error ? content.theme.colors.accent : content.theme.colors.muted
    }
    Label {
        objectName: "appimage-empty"
        visible: !content.manager.applications.length && !content.manager.busy
        text: "No managed AppImages yet. Choose a downloaded .AppImage to add it."
    }
    Repeater {
        model: content.manager.applications
        delegate: ColumnLayout {
            id: row
            required property var modelData
            Layout.fillWidth: true
            spacing: 6
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: content.theme.colors.surface_alt }
            RowLayout {
                Layout.fillWidth: true
                Image {
                    source: row.modelData.icon.startsWith("/") ? "file://" + row.modelData.icon : ""
                    visible: status === Image.Ready
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32
                    fillMode: Image.PreserveAspectFit
                }
                Label { text: row.modelData.name; font.bold: true }
                Label { text: (row.modelData.size / (1024 * 1024)).toFixed(1) + " MB"; Layout.fillWidth: false; color: content.theme.colors.muted }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Button { objectName: "appimage-launch-" + row.modelData.id; label: "Launch"; onClicked: content.manager.run(["launch", row.modelData.id]) }
                Button { objectName: "appimage-replace-" + row.modelData.id; label: "Replace…"; onClicked: content.manager.run(["choose-replace", row.modelData.id]) }
                Button { objectName: "appimage-remove-" + row.modelData.id; label: "Remove"; onClicked: content.manager.run(["remove", row.modelData.id]) }
            }
        }
    }
    Label {
        text: "Downloaded originals and application settings are kept. Replace lets you choose a newer version."
        color: content.theme.colors.muted
        font.pixelSize: content.theme.fontSize - 2
    }
}
