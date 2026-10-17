import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Item {
    width: 1400
    height: 400
    Shell.DetailedBarStats {
        id: stats
        font { family: "monospace"; pixelSize: 18; bold: true }
        text: "CPU 25%   RAM 12.5 GiB / 32 GiB   GPU AMD Radeon RX 7900 XT   65°C"
    }
    TestCase {
        name: "DetailedBarStats"
        when: windowShown
        function test_content_fits_monitor_data() {
            return [
                {tag: "wide", available: 1200, pixels: 18},
                {tag: "small-monitor", available: 320, pixels: 18},
                {tag: "large-font", available: 320, pixels: 26},
                {tag: "narrow", available: 140, pixels: 22}
            ];
        }
        function test_content_fits_monitor(data) {
            stats.availableWidth = data.available;
            stats.font.pixelSize = data.pixels;
            waitForRendering(stats);
            verify(stats.width <= data.available);
            verify(stats.contentWidth <= stats.width + 1);
            compare(stats.truncated, false);
            if (stats.naturalWidth <= data.available) {
                compare(stats.width, stats.naturalWidth);
                compare(stats.lineCount, 1);
                verify(stats.width > 600);
            } else {
                compare(stats.width, data.available);
                verify(stats.lineCount > 1);
                verify(stats.implicitHeight > stats.font.pixelSize * 1.5);
            }
        }
        function test_font_and_content_changes_resize_island() {
            stats.availableWidth = 1400;
            stats.font.pixelSize = 14;
            stats.text = "CPU 3%   RAM 4 GiB";
            waitForRendering(stats);
            const initial = stats.width;
            stats.font.pixelSize = 22;
            waitForRendering(stats);
            verify(stats.width > initial);
            const largerFont = stats.width;
            stats.text += "   GPU AMD Radeon RX 7900 XT   65°C";
            waitForRendering(stats);
            verify(stats.width > largerFont);
            compare(stats.truncated, false);
        }
    }
}
