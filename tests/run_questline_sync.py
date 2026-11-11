#!/usr/bin/env python3
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='spectrum-sync-progress-') as temporary:
    directory = Path(temporary)
    shutil.copytree(ROOT / 'configs/spectrum-shell', directory / 'shell')
    backend = directory / 'questline-sync-control'
    backend.write_text('#!/bin/sh\nread request\nprintf \'%s\\n\' \'{"ok":true,"status":{"account":"test","available":true}}\'\n')
    backend.chmod(0o755)
    (directory / 'Test.qml').write_text('''import QtQuick
import QtTest
import Quickshell
import "shell" as Shell
Scope {
    QtObject {
        id: workspace
        property bool ready:true
        property bool storageError:false
        property bool blocked:false
        property bool busy:false
        property int externalActions:0
    }
    Shell.QuestlineSync {
        id: panel
        width:600;height:800
        workspace:workspace
        backendDir:Quickshell.env("SYNC_TEST_DIR")
        theme:({fontSize:12,fontFamily:"monospace",colors:{background:"#111111",surface_alt:"#333333",foreground:"#eeeeee",muted:"#aaaaaa",accent:"#66ccee"}})
    }
    TestCase {
        name:"QuestlineSyncProgress"
        when:true
        function test_progress() {
            panel.active=true;
            tryVerify(()=>!panel.busy && panel.state.account==="test");
            panel.finished=false;panel.action="restore_cloud";panel.launchPending=true;
            panel.receive(JSON.stringify({phase:"progress",message:"Downloading profile…"}));
            compare(panel.finished,false);
            compare(panel.error,"");
            compare(panel.progressMessage,"Downloading profile…");
            verify(panel.operationVisible);
            tryVerify(()=>panel.elapsedSeconds>=1,2500);
            panel.receive(JSON.stringify({phase:"preview",token:"test",message:"Review profile",incoming:{name:"Hero",tasks:1,notes:0,favorites:0}}));
            verify(panel.preview!==null);
            const paused=panel.elapsedSeconds;
            wait(1200);
            compare(panel.elapsedSeconds,paused);
            compare(findChild(panel,"questline-sync-progress").visible,false);
            panel.preview=null;
            panel.receive(JSON.stringify({phase:"progress",message:"Applying restore…"}));
            verify(findChild(panel,"questline-sync-progress").indeterminate);
            panel.receive(JSON.stringify({ok:false,error:"Download failed"}));
            compare(panel.finished,true);
            compare(panel.error,"Download failed");
            const stopped=panel.elapsedSeconds;
            wait(1200);
            compare(panel.elapsedSeconds,stopped);
            panel.launchPending=false;
            verify(!panel.operationVisible);
            compare(panel.duration(125),"2:05");
            console.log("Questline sync progress checks passed");
            Qt.quit();
        }
    }
    Timer {interval:10000;running:true;onTriggered:Qt.quit()}
}
''')
    runtime = directory / 'runtime'
    runtime.mkdir(mode=0o700)
    environment = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                       XDG_RUNTIME_DIR=str(runtime), SYNC_TEST_DIR=str(directory))
    result = subprocess.run(['qs', '--path', str(directory / 'Test.qml'), '--no-color'],
                            env=environment, capture_output=True, text=True, timeout=15)
    output = result.stdout + result.stderr
    print(output, end='')
    if result.returncode or 'Questline sync progress checks passed' not in output or 'FAIL!' in output:
        raise SystemExit(1)
