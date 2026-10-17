import QtQuick

QtObject {
    id: state
    property bool enabled: true
    property bool blocked: false
    property bool idle: false
    property bool sessionAllowed: false
    property bool active: false
    property bool previewing: false
    property bool armed: true
    onBlockedChanged: if (blocked) dismiss()
    onEnabledChanged: if (!enabled && !previewing) dismiss()
    onSessionAllowedChanged: if (!sessionAllowed) dismiss()
    onIdleChanged: {
        if (!idle) {
            armed = true;
            if (!previewing) dismiss();
        }
    }
    function start(preview): bool {
        if (blocked || !sessionAllowed || (!preview && (!enabled || !idle || !armed))) return false;
        previewing = preview;
        active = true;
        return true;
    }
    function dismiss(): void {
        active = false;
        previewing = false;
        armed = !idle;
    }
}
