import QtQuick 2.11
import QtQuick.Layouts 1.11
import SddmComponents 2.0 as SDDM

ColumnLayout {
    id: formContainer
    spacing: root.font.pointSize

    SDDM.TextConstants { id: textConstants }

    property alias systemButtonVisibility: systemButtons.visible
    property alias clockVisibility: systemButtons.visible
    property bool virtualKeyboardActive: false
    property alias username: input.username

    Input {
        id: input
        Layout.fillWidth: true
        Layout.preferredHeight: root.font.pointSize * 21
    }

    SystemButtons {
        id: systemButtons
        Layout.alignment: Qt.AlignHCenter
        exposedLogin: input.exposeLogin
    }
}
