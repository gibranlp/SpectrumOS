import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Item {
    id: scene
    width: 500
    height: 360
    Rectangle { anchors.fill: parent; color: "white" }
    Shell.IgorStage {
        id: stage
        anchors.fill: parent
        catSize: 180
        position: 0.5
        animationDuration: 0
    }
    TestCase {
        name: "IgorChin"
        when: windowShown
        function test_headStaysConnected_data() {
            const rows = [];
            for (const edge of ["top", "bottom", "left", "right"])
                for (const tilt of [-7, 0, 7])
                    rows.push({tag:edge+"-"+tilt,edge:edge,tilt:tilt});
            return rows;
        }
        function test_headStaysConnected(data) {
            stage.visiting = false;
            stage.edge = data.edge;
            wait(30);
            const perch = findChild(stage, "igorPerch");
            const cat = perch.children[0];
            cat.headTilt = data.tilt;
            cat.headLift = -7;
            wait(350);
            const motion = findChild(stage, "igorRevealMotion");
            motion.progress = 1;
            wait(30);
            const image = grabImage(scene);
            for (let offset = -35; offset <= 35; offset++) {
                const x = data.edge === "left" ? 8 : data.edge === "right" ? scene.width - 9 : scene.width / 2 + offset;
                const y = data.edge === "top" ? 8 : data.edge === "bottom" ? scene.height - 9 : scene.height / 2 + offset;
                verify(image.red(x,y) < 60 && image.green(x,y) < 60 && image.blue(x,y) < 60,
                       "Gap between chin and shell at " + data.edge + " " + offset);
            }
        }
    }
}
