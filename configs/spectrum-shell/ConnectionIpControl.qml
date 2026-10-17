import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: control
    required property var theme
    required property var profile
    spacing: 4
    Text {
        Layout.fillWidth: true
        text: control.profile.name + " · " + (control.profile.type === "wifi" ? "Wi-Fi" : "Ethernet")
        elide: Text.ElideRight
        color: control.theme.colors.foreground
        font { family: control.theme.fontFamily; pixelSize: control.theme.fontSize - 1 }
    }
    RowLayout {
        ShellCheckBox {
            objectName: "connection-ipv4"
            theme: control.theme; label: "IPv4"
            known: typeof control.profile.ipv4_enabled === "boolean"
            value: control.profile.ipv4_enabled === true
            enabled: known && !control.theme.actionBusy && (!value || control.profile.ipv6_enabled === true)
            onChangeRequested: value => control.theme.runAction([control.theme.backend("network-adapter"), "ip-family", control.profile.uuid, "ipv4", value ? "on" : "off"])
        }
        ShellCheckBox {
            objectName: "connection-ipv6"
            theme: control.theme; label: "IPv6"
            known: typeof control.profile.ipv6_enabled === "boolean"
            value: control.profile.ipv6_enabled === true
            enabled: known && !control.theme.actionBusy && (!value || control.profile.ipv4_enabled === true)
            onChangeRequested: value => control.theme.runAction([control.theme.backend("network-adapter"), "ip-family", control.profile.uuid, "ipv6", value ? "on" : "off"])
        }
    }
    Text {
        Layout.fillWidth: true
        visible: text.length > 0
        text: control.profile.error || ""
        wrapMode: Text.WordWrap
        color: control.theme.colors.foreground
        font { family: control.theme.fontFamily; pixelSize: control.theme.fontSize - 1 }
    }
}
