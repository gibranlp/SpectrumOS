import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Item {
    width: 900
    height: 600
    Rectangle { anchors.fill: parent; color: "black" }
    Shell.BarIslands {
        id: backdrop
        width: 900
        height: 34
        groups: [{ start: 20, length: 180 }, { start: 420, length: 100 }, { start: 730, length: 140 }]
    }
    TestCase {
        name: "BarIslands"
        when: windowShown
        function init() {
            backdrop.horizontal = true;
            backdrop.width = 900;
            backdrop.height = 34;
            backdrop.groups = [{ start: 20, length: 180 }, { start: 420, length: 100 }, { start: 730, length: 140 }];
        }
        function islandItems() {
            return Array.from(backdrop.children).filter(item => item.objectName === "barIsland")
                .sort((a, b) => backdrop.horizontal ? a.x - b.x : a.y - b.y);
        }
        function test_title_resize_keeps_existing_curves_data() {
            return [{tag: "top", horizontal: true}, {tag: "left", horizontal: false}];
        }
        function test_title_resize_keeps_existing_curves(data) {
            backdrop.horizontal = data.horizontal;
            backdrop.width = data.horizontal ? 900 : 52;
            backdrop.height = data.horizontal ? 34 : 900;
            wait(30);
            const original = islandItems();
            compare(original.length, 3);
            for (const length of [140, 180, 120, 190, 180]) {
                backdrop.groups = [{ start: 20, length: length }, { start: 420, length: 100 }, { start: 730, length: 140 }];
                const current = islandItems();
                compare(current.length, 3);
                for (let index = 0; index < current.length; index++)
                    compare(current[index], original[index], "A title resize must preserve every existing island and its painted corners");
                compare(backdrop.segments[0].end, 30 + length);
                compare(data.horizontal ? current[0].width : current[0].height,
                    length + 20 + (data.horizontal ? 0 : 2 * backdrop.joinRadius));
            }
        }
        function test_merging_groups_keeps_surviving_curves() {
            wait(30);
            const original = islandItems();
            backdrop.groups = [{ start: 20, length: 440 }, { start: 730, length: 140 }];
            const merged = islandItems();
            compare(merged.length, 2);
            compare(merged[0], original[0]);
            compare(merged[1], original[1]);
            compare(merged[0].width, 460);
            compare(merged[1].x, 720);
        }
        function test_visible_islands_repaint_after_palette_change_data() {
            return [{tag: "top", horizontal: true}, {tag: "left", horizontal: false}];
        }
        function test_visible_islands_repaint_after_palette_change(data) {
            backdrop.horizontal = data.horizontal;
            backdrop.width = data.horizontal ? 900 : 52;
            backdrop.height = data.horizontal ? 34 : 600;
            backdrop.groups = [{start: 100, length: 200}];
            backdrop.surfaceColor = "#123456";
            wait(60);
            const originalItems = islandItems();
            const x = data.horizontal ? 180 : 25;
            const y = data.horizontal ? 15 : 180;
            compare(grabImage(backdrop).pixel(x, y), Qt.rgba(0x12 / 255, 0x34 / 255, 0x56 / 255, 1));
            backdrop.surfaceColor = "#abcdef";
            wait(60);
            compare(grabImage(backdrop).pixel(x, y), Qt.rgba(0xab / 255, 0xcd / 255, 0xef / 255, 1));
            compare(islandItems(), originalItems);
        }
        function test_separate_groups_leave_clear_gaps() {
            compare(backdrop.segments.length, 3);
            compare(backdrop.segments[0].start, 10);
            compare(backdrop.segments[0].end, 210);
            const first = backdrop.maskRect(0);
            const second = backdrop.maskRect(1);
            verify(first.x + first.width < second.x);
            compare(backdrop.maskRect(3).width, 0);
        }
        function test_nearby_groups_merge_their_shoulders() {
            backdrop.groups = [{ start: 20, length: 180 }, { start: 220, length: 80 }];
            compare(backdrop.segments.length, 1);
            compare(backdrop.segments[0].end, 310);
        }
        function test_hidden_and_empty_groups_release_their_islands() {
            backdrop.groups = [{ start: 20, length: 180 }, { start: 420, length: 100, visible: false }, { start: 730, length: 0 }];
            compare(backdrop.segments.length, 1);
        }
        function test_ranges_stay_inside_the_display() {
            backdrop.groups = [{ start: -20, length: 80 }, { start: 870, length: 200 }];
            compare(backdrop.segments[0].start, 0);
            compare(backdrop.segments[1].end, 900);
            verify(backdrop.maskRect(1).x + backdrop.maskRect(1).width <= 900);
        }
        function test_left_bar_uses_the_same_group_geometry() {
            backdrop.horizontal = false;
            backdrop.width = 52;
            backdrop.height = 900;
            const rect = backdrop.maskRect(1);
            compare(rect.x, 0);
            compare(rect.width, 52);
            compare(rect.y, 388);
            compare(rect.height, 164);
        }
        function test_left_island_has_a_continuous_curved_end() {
            backdrop.horizontal = false;
            backdrop.width = 52;
            backdrop.height = 600;
            backdrop.surfaceColor = "#ffffff";
            backdrop.groups = [{ start: 200, length: 200 }];
            wait(60);
            const image = grabImage(backdrop);
            let previous = 8;
            for (let y = 170; y <= 214; y += 2) {
                let edge = 0;
                for (let x = 0; x < 52; x++)
                    if (image.red(x, y) > 200) edge = x + 1;
                verify(edge >= previous, "The curve must widen smoothly");
                verify(edge - previous <= 14, "The curve must not have a squared step");
                previous = edge;
            }
            verify(image.red(48, 198) < 50, "The outer tip must remain rounded");
            verify(image.red(48, 212) > 200, "The curve must reach the body gradually");
            verify(image.red(25, 300) > 200);
            verify(image.red(20, 150) < 50, "The gap stays transparent");
        }
        function test_revealed_content_merges_without_overlapping_islands() {
            backdrop.groups = [{ start: 20, length: 180 }, { start: 420, length: 100 }, { start: 200, length: 230 }];
            compare(backdrop.segments.length, 1);
            compare(backdrop.segments[0].start, 10);
            compare(backdrop.segments[0].end, 530);
        }
    }
}
