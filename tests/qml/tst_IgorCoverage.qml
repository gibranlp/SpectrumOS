import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Item {
    width: 1600
    height: 328
    Rectangle { anchors.fill: parent; color: "white" }
    Shell.IgorIllustration { id: cat; width: 800; height: 328 }
    Image {
        id: reference
        x: 800
        width: 800
        height: 328
        source: "../../configs/spectrum-shell/igor/head.svg"
        sourceSize.width: 1600
    }
    TestCase {
        name: "IgorCoverage"
        when: windowShown
        function test_earJoints_data() {
            return [{tag:"outward", tilt:-4}, {tag:"rest", tilt:0}, {tag:"inward", tilt:2}];
        }
        function test_earJoints(data) {
            cat.earTilt = 0;
            wait(350);
            tryCompare(reference, "status", Image.Ready);
            const rest = grabImage(reference);
            cat.earTilt = data.tilt;
            wait(350);
            const posed = grabImage(cat);
            let checked = 0;
            for (let x = 110; x < 290; x++) {
                for (let y = 80; y < 108; y++) {
                    if (rest.red(x * 2, y * 2) < 60 && rest.green(x * 2, y * 2) < 60 && rest.blue(x * 2, y * 2) < 60) {
                        checked++;
                        verify(posed.red(x * 2, y * 2) < 100 && posed.green(x * 2, y * 2) < 100 && posed.blue(x * 2, y * 2) < 100, "Transparent head joint at " + x + "," + y);
                    }
                }
            }
            verify(checked > 2500);
        }
    }
}
