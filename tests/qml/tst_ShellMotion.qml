import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Item {
    width: 640
    height: 480
    Rectangle {
        id: panel
        width: 220
        height: 180
        transform: Shell.ShellMotion {
            id: motion
            surface: panel
            expanded: false
            edge: "top"
            viewportWidth: 640
            viewportHeight: 480
        }
    }
    TestCase {
        name: "ShellMotion"
        when: windowShown
        function init() {
            motion.animationsEnabled = true;
            motion.bounceEnabled = false;
            motion.expanded = false;
            wait(350);
            panel.width = 220;
            panel.height = 180;
            motion.bounceEnabled = true;
        }
        function offset() {
            return motion.edge === "left" ? motion.x : motion.edge === "right" ? -motion.x
                : motion.edge === "top" ? motion.y : -motion.y;
        }
        function test_gaming_opens_and_closes_without_animation() {
            motion.animationsEnabled = false;
            motion.expanded = true;
            tryCompare(motion, "progress", 1);
            verify(!motion.animation.running);
            motion.expanded = false;
            tryCompare(motion, "progress", 0);
            verify(!motion.active);
        }
        function test_gaming_stops_an_animation_in_progress() {
            motion.expanded = true;
            wait(50);
            verify(motion.animation.running);
            motion.animationsEnabled = false;
            compare(motion.progress, 1);
            verify(!motion.animation.running);
        }
        function test_subtle_opening_from_every_edge_data() {
            return ["top", "left", "right", "bottom"].map(edge => ({tag: edge, edge: edge}));
        }
        function test_subtle_opening_from_every_edge(data) {
            motion.edge = data.edge;
            panel.x = data.edge === "right" ? 420 : 0;
            panel.y = data.edge === "bottom" ? 300 : 0;
            motion.expanded = true;
            let peak = 0;
            for (let i = 0; i < 45; i++) {
                wait(10);
                peak = Math.max(peak, offset());
            }
            verify(peak > 0.5, "Opening should bounce slightly: peak=" + peak + " travel=" + motion.travelDistance + " overshoot=" + motion.openingOvershoot(motion.travelDistance) + " progress=" + motion.progress);
            verify(peak <= 3.1, "Opening bounce must stay within three pixels");
            fuzzyCompare(offset(), 0, 0.01);
            verify(motion.active);
            motion.expanded = false;
            for (let i = 0; i < 35; i++) {
                wait(10);
                verify(offset() <= 0.01, "Closing must not bounce");
            }
            verify(!motion.active);
        }
        function test_disabled_and_reversed_animation() {
            motion.bounceEnabled = false;
            motion.expanded = true;
            for (let i = 0; i < 35; i++) {
                wait(10);
                verify(offset() <= 0.01, "Disabled bounce must use the original slide");
            }
            motion.expanded = false;
            wait(60);
            motion.expanded = true;
            wait(350);
            fuzzyCompare(motion.progress, 1, 0.001);
            verify(motion.active);
        }
        function test_final_geometry_used_for_each_opening_data() {
            return [
                {tag: "control-center", edge: "left", width: 660, height: 450},
                {tag: "notification-history", edge: "right", width: 352, height: 450},
                {tag: "notification-toast", edge: "right", width: 320, height: 100},
                {tag: "dashboard", edge: "top", width: 500, height: 400}
            ];
        }
        function test_final_geometry_used_for_each_opening(data) {
            motion.edge = data.edge;
            panel.width = 0;
            panel.height = 0;
            wait(20);
            motion.expanded = true;
            wait(30);
            panel.width = data.width;
            panel.height = data.height;
            panel.x = data.edge === "right" ? 640 - panel.width : 52;
            panel.y = 8;
            let peak = 0;
            for (let i = 0; i < 45; i++) {
                wait(10);
                peak = Math.max(peak, offset());
            }
            verify(peak > 2.5, "Every widget should visibly rebound: " + peak);
            verify(peak <= 3.1, "Resolved geometry must keep the rebound within the attachment overlap: " + peak);
        }
    }
}
