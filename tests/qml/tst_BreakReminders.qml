import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

TestCase {
    name: "BreakReminderCycle"
    Shell.BreakReminderState {
        id: state
        backendDir: "/nonexistent"
        property var sent: []
        function notify(kind) { sent.push(kind); }
    }
    function init() {
        state.ready = true;
        state.settings = {enabled:true,eye_minutes:20,movement_minutes:50,pause_focus:true};
        state.reset();
        state.startupUntil = 0;
        state.breakUntil = 0;
        state.pendingNotification = "";
        state.inhibited = false;
        state.sent = [];
    }
    function test_login_delay() {
        const now = Date.now();
        state.startupUntil = now + 90000;
        state.pendingNotification = "started";
        state.tick(now + 89000);
        compare(state.sent.length, 0);
        compare(state.eyeElapsed, 0);
        state.tick(now + 90000);
        compare(state.sent[0], "started");
        state.tick(now + 91000);
        compare(state.eyeElapsed, 1);
    }
    function test_break_and_restart_preserve_movement_progress() {
        const now = Date.now();
        state.previousTick = now - 1000;
        state.eyeElapsed = 1199;
        state.movementElapsed = 1199;
        state.tick(now);
        compare(state.sent[0], "eyes");
        compare(state.breakUntil, now + 180000);
        state.tick(now + 179000);
        compare(state.eyeElapsed, 0);
        state.tick(now + 180000);
        compare(state.sent[1], "resumed");
        compare(state.movementElapsed, 1200);
        state.tick(now + 181000);
        compare(state.eyeElapsed, 1);
    }
    function test_disabled_and_inhibited_do_not_notify() {
        const now = Date.now();
        state.startupUntil = now - 1;
        state.pendingNotification = "started";
        state.inhibited = true;
        state.tick(now);
        compare(state.sent.length, 0);
        state.inhibited = false;
        state.settings = {enabled:false};
        state.tick(now + 1000);
        compare(state.sent.length, 0);
    }
    function test_movement_break_resets_both_timers() {
        const now = Date.now();
        state.previousTick = now - 1000;
        state.movementElapsed = 2999;
        state.tick(now);
        compare(state.sent[0], "movement");
        compare(state.eyeElapsed, 0);
        compare(state.movementElapsed, 0);
    }
}
