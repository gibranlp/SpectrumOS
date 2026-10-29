import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

TestCase {
    id: test
    name: "BarControls"
    width: 1100
    height: 1100
    visible: true
    when: windowShown
    property int trayActivations: 0
    property var theme: ({fontFamily:"monospace", fontSize:13,
        colors:{foreground:"white", muted:"gray", accent:"cyan", surface_alt:"#222222"},
        performance:{available:false, mode:"balanced"}, idle:{active:false},
        weather:{icon:"☀",temperature:"23°"}, network:{connection_type:"ethernet"},
        volumePercent:36, volumeMuted:false, volumeAvailable:true})
    Shell.BarControls { id: controls; theme: test.theme }
    SignalSpy { id: chosen; target: controls; signalName:"chosen" }
    function init() {
        chosen.clear();
        controls.trayItems = [];
        controls.batteryDevice = null;
        controls.charging = false;
        controls.externalPower = false;
        test.trayActivations = 0;
    }
    function test_battery_level_precedes_power_mode_data() { return test_order_and_actions_data(); }
    function test_battery_level_precedes_power_mode(data) {
        controls.profile = data.profile;
        controls.vertical = data.vertical;
        controls.batteryDevice = {ready:true, isLaptopBattery:true, percentage:0.73};
        waitForRendering(controls);
        const battery = findChild(controls, "bar-control-battery-level");
        const mode = findChild(controls, "bar-control-battery");
        verify(battery && battery.visible && mode && mode.visible);
        verify((data.vertical ? battery.y < mode.y : battery.x < mode.x), "Battery charge must precede the power-mode icon");
        compare(controls.actions.indexOf("battery-level") + 1, controls.actions.indexOf("battery"));
        const indicator = findChild(battery, "bar-battery-indicator");
        const percentage = findChild(indicator, "battery-percentage");
        compare(indicator.level, 73);
        compare(percentage.text, "73%");
        controls.batteryDevice = {ready:true, isLaptopBattery:true, percentage:0.18};
        tryCompare(indicator, "level", 18);
        const fill = findChild(indicator, "battery-level-fill");
        const body = findChild(indicator, "battery-body");
        fuzzyCompare(fill.width / (body.width - 4), 0.18, 0.001);
        controls.charging = true;
        controls.externalPower = true;
        const status = findChild(indicator, "battery-power-status");
        verify((data.vertical ? percentage : status).text.includes("⚡"));
        if (!data.vertical) {
            waitForRendering(controls);
            compare(percentage.text, "18%");
            verify(status.x < body.parent.x);
            verify(body.parent.x < percentage.x);
        }
        compare(indicator.stateLabel, qsTranslate("Spectrum", "Charging"));
        controls.charging = false;
        controls.batteryDevice = {ready:true, isLaptopBattery:true, percentage:1};
        tryCompare(indicator, "level", 100);
        verify((data.vertical ? percentage : status).text.includes("🔌"));
        compare(indicator.stateLabel, qsTranslate("Spectrum", "Fully charged"));
        const button = findChild(battery, "bar-action-battery-level");
        mouseClick(button, button.width / 2, button.height / 2);
        compare(chosen.signalArguments[chosen.count - 1][0], "battery");
    }
    function test_peripheral_battery_does_not_add_laptop_controls() {
        controls.batteryDevice = {ready:true, isLaptopBattery:false, percentage:0.5};
        verify(!controls.hasBattery);
        verify(!controls.actions.includes("battery-level"));
    }
    function test_order_and_actions_data() {
        const rows = [];
        for (const profile of ["standard", "detailed", "multimedia"])
            for (const vertical of [false, true]) rows.push({tag:profile + (vertical ? "-left" : "-top"), profile:profile, vertical:vertical});
        return rows;
    }
    function test_order_and_actions(data) {
        controls.profile = data.profile;
        controls.vertical = data.vertical;
        const expected = data.profile === "detailed"
            ? ["favorites", "breaks", "battery", "keep-awake", "brightness", "weather", "displays", "typography", "network", "bluetooth", "audio", "notifications", "extras"]
            : ["battery", "keep-awake", "weather", "network", "bluetooth", "audio", "notifications", "extras"];
        waitForRendering(controls);
        let previous = -1;
        for (const action of expected) {
            const item = findChild(controls, "bar-control-" + action);
            verify(item && item.visible, action + " must be visible even without a laptop battery");
            const position = data.vertical ? item.y : item.x;
            verify(position > previous, action + " must follow the specified order");
            previous = position;
            if (action !== "audio") {
                const button = findChild(item, "bar-action-" + action);
                mouseClick(button, button.width / 2, button.height / 2);
                compare(chosen.signalArguments[chosen.count - 1][0], action);
            }
        }
        compare(controls.actions.length, expected.length);
        controls.trayItems = [{title:"Example app",icon:"",onlyMenu:false,activate:()=>test.trayActivations++}];
        waitForRendering(controls);
        const tray = findChild(controls, "bar-tray-application");
        verify((data.vertical ? tray.y : tray.x) > previous, "System tray must come after More");
        mouseClick(tray, tray.width / 2, tray.height / 2);
        compare(test.trayActivations, 1);
    }
}
