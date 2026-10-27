import QtQuick
import Quickshell.Io

Item {
    id: controller
    required property var theme
    visible: false
    property var applications: []
    property bool busy: action.running
    property string error: ""
    property string message: ""
    property string operation: ""
    function run(args): void {
        if (busy) return;
        operation = args[0];
        error = "";
        message = "";
        action.exec([theme.backend("appimage-adapter")].concat(args));
    }
    Process {
        id: action
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    if (!result.ok) {
                        controller.error = result.error || "AppImage operation failed.";
                        return;
                    }
                    if (result.applications) controller.applications = result.applications;
                    if (result.cancelled) return;
                    if (controller.operation === "choose-add") controller.message = qsTranslate("Spectrum", "AppImage added to the launcher.");
                    if (controller.operation === "choose-replace") controller.message = qsTranslate("Spectrum", "AppImage replaced.");
                    if (controller.operation === "remove") controller.message = qsTranslate("Spectrum", "Managed AppImage removed. Application settings were preserved.");
                } catch (error) { controller.error = qsTranslate("Spectrum", "Could not read the AppImage manager response."); }
            }
        }
        onExited: (code) => { if (code !== 0 && !controller.error) controller.error = qsTranslate("Spectrum", "AppImage operation failed."); }
    }
}
