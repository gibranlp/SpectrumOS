#!/usr/bin/env python3
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='spectrum-audio-widget-') as temporary:
    directory=Path(temporary)
    shutil.copytree(root/'configs/spectrum-shell',directory/'configs/spectrum-shell')
    panel=directory/'configs/spectrum-shell/BarWidget.qml'
    source=panel.read_text().replace('PanelWindow {','FloatingWindow {\n    implicitWidth:800;implicitHeight:420',1)
    for line in ['    anchors { top: true; bottom: true; left: true; right: true }\n',
                 '    exclusionMode: ExclusionMode.Ignore\n',
                 '    WlrLayershell.layer: WlrLayer.Top\n',
                 '    WlrLayershell.namespace: "spectrum-widget-barwidget"\n',
                 '    WlrLayershell.keyboardFocus: panelFocus.mode\n']:
        source=source.replace(line,'',1)
    panel.write_text(source)
    runtime=directory/'runtime'
    runtime.mkdir(mode=0o700)
    command=directory/'pactl-test'
    command.write_text('#!/usr/bin/env python3\nimport json,os,sys,time\nwith open(os.environ["SPECTRUM_AUDIO_TEST_LOG"],"a") as f:f.write(json.dumps(sys.argv[1:])+"\\n")\ntime.sleep(.08)\n')
    command.chmod(0o755)
    environment=dict(os.environ,XDG_RUNTIME_DIR=str(runtime),QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',SPECTRUM_AUDIO_TEST_COMMAND=str(command),SPECTRUM_AUDIO_TEST_LOG=str(directory/'calls.jsonl'))
    for name,marker in [('AudioWidgetTests','Full audio'),('AudioVolumeQueueTests','Volume queue')]:
        path=directory/(name+'.qml')
        path.write_text((root/'tests/qml'/(name+'.qml')).read_text().replace('../../configs/','configs/'))
        result=subprocess.run(['qs','--path',str(path),'--no-color'],capture_output=True,text=True,env=environment,timeout=15)
        output=result.stdout+result.stderr
        print(output,end='')
        if result.returncode or not re.search(re.escape(marker)+r': \d+ passed 0 failed',output):raise SystemExit(1)
