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
        animationDuration: 0
        pawsFirstProbability: 0
    }
    TestCase {
        name: "IgorStage"
        when: windowShown
        function init() { stage.visiting = false; stage.pawsFirstProbability = 0; stage.celebrationMessage = ""; wait(10); }
        function test_pawsAppearBeforeHead_data() {
            return ["top", "bottom", "left", "right"].map(edge => ({tag: edge, edge: edge}));
        }
        function test_pawsAppearBeforeHead(data) {
            stage.edge = data.edge;
            stage.pawsFirstProbability = 1;
            stage.visiting = true;
            wait(60);
            compare(stage.headReveal, 0);
            verify(!findChild(stage, "igorHead").visible);
            const image = grabImage(scene);
            let darkPixels = 0;
            for (let x = 0; x < scene.width; x += 2)
                for (let y = 0; y < scene.height; y += 2)
                    if (image.red(x,y) < 100) darkPixels++;
            verify(darkPixels > 20, "Paws must be visible before the head");
            tryCompare(stage, "headReveal", 1, 1000);
            verify(findChild(stage, "igorHead").visible);
        }
        function test_cancelPawsFirstArrival() {
            stage.pawsFirstProbability = 1;
            stage.visiting = true;
            wait(60);
            stage.visiting = false;
            wait(800);
            verify(!stage.motionActive);
            compare(stage.headReveal, 1);
        }
        function test_speechStaysUprightAndInsideEveryEdge_data() {
            return ["top", "left", "right", "bottom"].map(edge => ({tag: edge, edge: edge}));
        }
        function test_speechStaysUprightAndInsideEveryEdge(data) {
            stage.edge = data.edge;
            stage.position = 0.02;
            stage.celebrationMessage = "That deserves a paw-five!";
            stage.visiting = true;
            wait(30);
            const bubble = findChild(stage, "igorSpeechBubble");
            verify(bubble.visible);
            compare(bubble.rotation, 0);
            verify(bubble.x >= 0 && bubble.y >= 0);
            verify(bubble.x + bubble.width <= bubble.parent.width);
            verify(bubble.y + bubble.height <= bubble.parent.height);
            stage.celebrationMessage = "";
            verify(!bubble.visible);
        }
        function test_revealsBehindEachShellEdge_data() {
            return [{tag:"top-bar-top",edge:"top",left:8,top:34},
                    {tag:"top-bar-left",edge:"left",left:8,top:34},
                    {tag:"top-bar-right",edge:"right",left:8,top:34},
                    {tag:"top-bar-bottom",edge:"bottom",left:8,top:34},
                    {tag:"left-bar-top",edge:"top",left:52,top:8},
                    {tag:"left-bar-left",edge:"left",left:52,top:8},
                    {tag:"left-bar-right",edge:"right",left:52,top:8},
                    {tag:"left-bar-bottom",edge:"bottom",left:52,top:8}];
        }
        function test_revealsBehindEachShellEdge(data) {
            stage.leftInset = data.left;
            stage.topInset = data.top;
            stage.edge = data.edge;
            stage.position = 0.02;
            stage.visiting = true;
            wait(30);
            const motion = findChild(stage, "igorRevealMotion");
            motion.progress = 0.9;
            wait(30);
            const image = grabImage(scene);
            let visiblePixels = 0;
            for (let x = 0; x < scene.width; x += 2) {
                for (let y = 0; y < scene.height; y += 2) {
                    const dark = image.red(x,y) < 100 && image.green(x,y) < 100 && image.blue(x,y) < 100;
                    if (x < data.left || y < data.top || x >= scene.width - 8 || y >= scene.height - 8)
                        verify(!dark, "Igor crossed the shell or bar at " + x + "," + y);
                    else if (dark) visiblePixels++;
                }
            }
            verify(visiblePixels > 50, "Igor must be partially visible while emerging");
            stage.visiting = false;
            wait(30);
            const hidden = grabImage(scene);
            for (let x = 0; x < scene.width; x += 8)
                for (let y = 0; y < scene.height; y += 8)
                    compare(hidden.red(x,y), 255);
        }
    }
}
