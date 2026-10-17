import QtQuick
import QtQuick.Window
import QtTest
import Quickshell.Io

Item {
    id: scene
    property string fixture: "/tmp/spectrum-watch-" + Date.now() + "/focus/state.json"
    property string value: ""
    Process { id: writer }
    FileView {
        id: watcher
        path: scene.fixture
        watchChanges: true
        onFileChanged: reload()
        onTextChanged: scene.value = text()
    }
    TestCase {
        name: "FileWatch"
        when: windowShown || (scene.Window.window !== null && scene.Window.window.visible)
        onCompletedChanged: if (completed) console.log("File watcher checks:", qtest_results.passCount, "passed,", qtest_results.failCount, "failed")
        function test_createAndAtomicReplace() {
            writer.exec(["python3", "-c", "from pathlib import Path; import sys; Path(sys.argv[1]).parent.mkdir(parents=True)", scene.fixture]);
            tryCompare(writer, "running", false);
            watcher.reload();
            writer.exec(["python3", "-c", "from pathlib import Path; import sys; p=Path(sys.argv[1]); p.write_text('first')", scene.fixture]);
            tryCompare(scene, "value", "first", 3000);
            tryCompare(writer, "running", false);
            writer.exec(["python3", "-c", "from pathlib import Path; import sys; p=Path(sys.argv[1]); t=p.with_suffix('.tmp'); t.write_text('second'); t.replace(p)", scene.fixture]);
            tryCompare(scene, "value", "second", 3000);
            tryCompare(writer, "running", false);
            writer.exec(["python3", "-c", "from pathlib import Path; import sys; p=Path(sys.argv[1]); p.unlink(missing_ok=True); p.parent.rmdir(); p.parent.parent.rmdir()", scene.fixture]);
        }
    }
}
