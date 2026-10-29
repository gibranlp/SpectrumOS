import QtQuick
import Quickshell.Io
import "UkvmControlModel.js" as Model

Item {
    id: state
    property var record: null
    property double now: Date.now() / 1000
    readonly property var incoming: Model.incoming(record, now)
    readonly property bool active: incoming.active
    readonly property string peerName: incoming.peerName
    visible: false
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            state.now = Date.now() / 1000;
            if (!poll.running) poll.running = true;
        }
    }
    Process {
        id: poll
        command: ["/usr/bin/ukvm", "status", "--json"]
        property string response: ""
        onStarted: response = ""
        stdout: StdioCollector { onStreamFinished: poll.response = text }
        onExited: (code, status) => {
            state.now = Date.now() / 1000;
            try { state.record = code === 0 ? JSON.parse(response) : null; }
            catch (error) { state.record = null; }
        }
    }
}
