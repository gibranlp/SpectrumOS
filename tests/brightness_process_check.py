from pathlib import Path
import os
import subprocess
import tempfile

root=Path(__file__).resolve().parents[1]
s=(root/'configs/spectrum-shell/shell.qml').read_text()
functions=s[s.index('    function refreshBrightness()'):s.index('    function runAction(')]
processes=s[s.index('    Process {\n        id: brightnessProcess'):s.index('    Process {\n        id: overviewProcess')]
with tempfile.TemporaryDirectory(prefix='spectrum-brightness-process-') as temp:
    path=Path(temp)
    helper=path/'helper'
    helper.write_text('''#!/usr/bin/env python3
import json,sys,time
from pathlib import Path
p=Path(__file__).with_name('value')
value=int(p.read_text()) if p.exists() else 50
if sys.argv[1]=='status':
    time.sleep(.25)
    print(json.dumps({'devices':[{'id':'mock','available':True,'percent':value}],'error':''}))
else:
    if sys.argv[3]=='denied':
        print(json.dumps({'ok':False,'error':'Permission denied'}))
        sys.exit(1)
    p.write_text('55')
    print(json.dumps({'ok':True,'device':{'id':'mock','available':True,'percent':55}}))
''')
    helper.chmod(0o755)
    qml='''import QtQuick
import Quickshell
import Quickshell.Io
Scope {
 id: shell
 property var brightness: ({devices:[],error:""})
 readonly property bool brightnessBusy: brightnessActionProcess.running
 property bool brightnessRefreshPending: false
 property int brightnessRevision: 0
 property string brightnessActionError: ""
 property string actionError: ""
 property bool controlsVisible: false
 property var bars: ({instances: []})
 property string helper: HELPER
 function backend(name) { return helper; }
'''.replace('HELPER', '"'+str(helper)+'"')+functions+processes+'''
 property int step: 0
 function assertThat(value, message) { if (!value) { console.error("FAIL:",message); Qt.exit(1); } }
 Component.onCompleted: refreshBrightness()
 Timer {
  interval: 20; repeat: true; running: true
  onTriggered: {
   if (shell.step === 0 && shell.brightness.devices.length && !brightnessProcess.running) {
    shell.assertThat(shell.brightness.devices[0].percent === 50, "initial state reaches widget");
    shell.refreshBrightness(); shell.step=1;
   } else if (shell.step === 1 && brightnessProcess.running) {
    shell.changeBrightness("up","mock"); shell.step=2;
   } else if (shell.step === 2 && !shell.brightnessBusy && shell.brightness.devices[0].percent === 55 && !brightnessProcess.running) {
    shell.assertThat(shell.brightness.devices[0].percent === 55, "stale poll cannot overwrite action readback");
    shell.refreshBrightness(); shell.step=3;
   } else if (shell.step === 3 && !brightnessProcess.running) {
    shell.assertThat(shell.brightness.devices[0].percent === 55, "subsequent state readback");
    shell.changeBrightness("up","denied"); shell.step=4;
   } else if (shell.step === 4 && !shell.brightnessBusy && shell.brightnessActionError) {
    shell.assertThat(shell.brightnessActionError === "Permission denied", "specific error preserved");
    shell.refreshBrightness(); shell.step=5;
   } else if (shell.step === 5 && !brightnessProcess.running) {
    shell.assertThat(shell.brightnessActionError === "Permission denied", "refresh does not erase error");
    console.log("Brightness process checks: 5 passed, 0 failed"); Qt.quit();
   }
  }
 }
 Timer { interval: 5000; running: true; onTriggered: { console.error("FAIL: timed out at step",shell.step); Qt.exit(1); } }
}
'''
    (path/'shell.qml').write_text(qml)
    result=subprocess.run(['qs','--path',str(path/'shell.qml'),'--no-color'],env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=temp),capture_output=True,text=True,timeout=10)
    print(result.stdout+result.stderr)
    if result.returncode or '5 passed, 0 failed' not in result.stdout+result.stderr:
        raise SystemExit('Brightness process validation failed')
