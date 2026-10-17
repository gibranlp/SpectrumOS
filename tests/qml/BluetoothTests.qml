import QtQuick
import Quickshell

Scope {
    FloatingWindow {
        visible: true
        implicitWidth: 600
        implicitHeight: 850
        Loader { anchors.fill: parent; source: "file://" + Quickshell.shellDir + "/tst_Bluetooth.qml" }
    }
}
