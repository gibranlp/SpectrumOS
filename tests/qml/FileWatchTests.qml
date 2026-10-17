import QtQuick
import Quickshell

Scope {
    FloatingWindow {
        visible: true
        implicitWidth: 200
        implicitHeight: 100
        Loader { anchors.fill: parent; source: "file://" + Quickshell.shellDir + "/tst_FileWatch.qml" }
    }
}
