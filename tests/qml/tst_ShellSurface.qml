import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Rectangle {
    id: scene
    width: 400
    height: 300
    color: "black"
    Shell.ShellSurface {
        id: panel
        x: 80
        y: 60
        width: 200
        height: 140
        radius: 24
        color: "white"
    }
    TestCase {
        name: "ShellSurface"
        when: windowShown
        function init() {
            panel.color = "white";
            panel.leftAttachmentWidth = 0;
            panel.topAttachmentHeight = 0;
        }
        function test_left_island_gaps_are_filled_data() {
            return ["center", "bottom", "floating"].map(layout => ({tag: layout, layout: layout}));
        }
        function test_left_island_gaps_are_filled(data) {
            panel.attachLeft = true;
            panel.attachRight = false;
            panel.attachTop = data.layout === "center";
            panel.attachBottom = data.layout !== "floating";
            panel.leftAttachmentWidth = 44;
            panel.x = 83;
            panel.y = 60;
            waitForRendering(panel);
            const image = grabImage(scene);
            for (const x of [36, 40, 52, 68, 80, 84]) {
                for (const y of [60, 90, 130, 190, 199])
                    compare(image.pixel(x, y), Qt.rgba(1, 1, 1, 1));
            }
            if (!panel.attachTop) {
                compare(image.pixel(36, 48), Qt.rgba(1, 1, 1, 1));
                compare(image.pixel(68, 48), Qt.rgba(0, 0, 0, 1));
            }
            compare(panel.width, 200);
            compare(panel.height, 140);
        }
        function test_attachment_stays_filled_during_bounce_data() {
            return ["top", "bottom", "left", "right"].map(edge => ({tag: edge, edge: edge}));
        }
        function test_attachment_stays_filled_during_bounce(data) {
            panel.attachTop = data.edge === "top";
            panel.attachBottom = data.edge === "bottom";
            panel.attachLeft = data.edge === "left";
            panel.attachRight = data.edge === "right";
            panel.x = 80 + (panel.attachLeft ? 3 : panel.attachRight ? -3 : 0);
            panel.y = 60 + (panel.attachTop ? 3 : panel.attachBottom ? -3 : 0);
            waitForRendering(panel);
            const image = grabImage(scene);
            const samples = panel.attachTop ? [[180, 60], [68, 60], [292, 60]]
                : panel.attachBottom ? [[180, 200], [68, 200], [292, 200]]
                : panel.attachLeft ? [[80, 130], [80, 48], [80, 212]]
                : [[280, 130], [280, 48], [280, 212]];
            for (const point of samples)
                compare(image.pixel(point[0], point[1]), Qt.rgba(1, 1, 1, 1));
            compare(panel.width, 200);
            compare(panel.height, 140);
        }
        function test_top_island_gap_is_filled_without_moving_contents_data() {
            return [{tag:"right-widget",right:true},{tag:"center-ukvm",right:false}];
        }
        function test_top_island_gap_is_filled_without_moving_contents(data) {
            panel.attachTop = true;
            panel.attachRight = data.right;
            panel.attachLeft = panel.attachBottom = false;
            panel.x = 80;
            panel.y = 60;
            panel.topAttachmentHeight = 52;
            waitForRendering(panel);
            const image = grabImage(scene);
            for (const x of [82, 120, 220, 278]) {
                for (const y of [8, 16, 34, 59, 70])
                    compare(image.pixel(x, y), Qt.rgba(1, 1, 1, 1));
            }
            compare(panel.y, 60);
            compare(panel.width, 200);
            compare(panel.height, 140);
        }
        function test_open_surface_and_curves_repaint_after_palette_change() {
            panel.attachTop = true;
            panel.attachLeft = panel.attachRight = panel.attachBottom = false;
            panel.x = 80;
            panel.y = 60;
            for (const color of ["#123456", "#abcdef", "#554433"]) {
                panel.color = color;
                wait(60);
                const image = grabImage(scene);
                compare(image.pixel(180, 130), color);
                compare(image.pixel(180, 59), color);
                for (const point of [[68, 60], [292, 60]]) {
                    verify(Math.abs(image.red(point[0], point[1]) - panel.color.r * 255) < 20);
                    verify(Math.abs(image.green(point[0], point[1]) - panel.color.g * 255) < 20);
                    verify(Math.abs(image.blue(point[0], point[1]) - panel.color.b * 255) < 20);
                }
            }
        }
        function test_floating_surface_has_no_overlap() {
            panel.attachTop = panel.attachBottom = panel.attachLeft = panel.attachRight = false;
            panel.x = 80;
            panel.y = 60;
            waitForRendering(panel);
            const image = grabImage(scene);
            for (const point of [[180, 59], [180, 200], [79, 130], [280, 130]])
                compare(image.pixel(point[0], point[1]), Qt.rgba(0, 0, 0, 1));
        }
    }
}
