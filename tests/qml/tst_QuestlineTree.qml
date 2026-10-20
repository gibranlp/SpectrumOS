import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Item {
    width: 640
    height: 480
    Shell.QuestlineTree {
        id: tree
        width: 640
        height: 480
        Rectangle { anchors.fill: parent; color: "black"; z: -1 }
    }
    TestCase {
        name: "QuestlineTree"
        when: windowShown

        function paintedPixels() {
            wait(60);
            const image = grabImage(tree);
            let count = 0, red = 0, green = 0;
            for (let y = 0; y < image.height; y++) {
                for (let x = 0; x < image.width; x++) {
                    const color = image.pixel(x, y);
                    if (color.a > 0.1 && (color.r > color.g * 1.5 || color.g > color.r * 1.5)) {
                        verify(x >= 7 && y >= 7 && x < image.width - 7 && y < image.height - 7);
                        count++;
                        if (color.r > color.g * 2) red++;
                        if (color.g > color.r * 2) green++;
                    }
                }
            }
            return {count: count, red: red, green: green};
        }

        function init() { tree.width = 640; tree.height = 480; tree.visible = true; tree.rows = []; }

        function test_colored_tree_is_visible_and_centered_without_padding() {
            tree.rows = [[{text: "     *", color: "#ff0000"}, {text: "*     ", color: "#00ff00"}]];
            compare(tree.drawing.columns, 2);
            compare(tree.drawing.lines, 1);
            const pixels = paintedPixels();
            verify(pixels.red > 0); verify(pixels.green > 0);
        }

        function test_large_tree_fits_small_viewport() {
            tree.width = 160; tree.height = 100;
            tree.rows = Array.from({length:25}, () => [{text:"*".repeat(60), color:"#00ff00"}]);
            const pixels = paintedPixels();
            verify(pixels.count > 50); verify(pixels.green > 50);
        }

        function test_refresh_and_reopen_repaint_current_tree() {
            tree.rows = [[{text: "*", color: "#ff0000"}]];
            verify(paintedPixels().red > 0);
            tree.visible = false;
            tree.rows = [[{text: "*", color: "#00ff00"}]];
            tree.visible = true;
            const pixels = paintedPixels();
            compare(pixels.red, 0); verify(pixels.green > 0);
            tree.rows = [];
            compare(paintedPixels().count, 0);
        }

        function test_repeated_growth_refresh_resize_and_reopen() {
            for (let cycle = 0; cycle < 36; cycle++) {
                tree.visible = false;
                tree.width = cycle % 2 ? 320 : 640;
                tree.height = cycle % 2 ? 180 : 480;
                tree.rows = Array.from({length:25}, (_, row) => [
                    {text: " ".repeat(10) + "*".repeat(1 + cycle), color: row % 2 ? "#00ff00" : "#ff0000"}
                ]);
                tree.visible = true;
                wait(20);
            }
            verify(paintedPixels().count > 0);
        }
    }
}
