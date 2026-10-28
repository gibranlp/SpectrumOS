#!/usr/bin/env python3
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='spectrum-update-panel-') as temporary:
    folder = Path(temporary)
    shutil.copytree(root/'configs/spectrum-shell', folder/'shell')
    panel = folder/'shell/UpdatePanel.qml'
    source = panel.read_text().replace('PanelWindow {', 'FloatingWindow {\n    implicitWidth:1100;implicitHeight:900', 1)
    for line in ['    WlrLayershell.layer: WlrLayer.Top\n', '    WlrLayershell.namespace: "spectrum-widget-updatepanel"\n',
                 '    anchors { top: true; bottom: true; left: true; right: true }\n', '    exclusionMode: ExclusionMode.Ignore\n',
                 '    WlrLayershell.keyboardFocus: panelFocus.mode\n']:
        source = source.replace(line, '', 1)
    panel.write_text(source)
    plan = {'release':{'version':'1.1','channel':'stable'},'preflight':{'disk':{'free_bytes':30*1024**3,'status':'pass'},
        'pacman_lock':{'status':'pass'},'pacman_transaction':{'status':'pass'},'snapshots':{'status':'pass'}},
        'packages':{'official':{'count':1},'foreign':{'count':0}},'blockers':[],'warnings':[],'ready_for_execution':True}
    (folder/'plan.json').write_text(json.dumps(plan))
    backend = folder/'spectrum'
    backend.write_text('#!/usr/bin/env python3\nimport pathlib,sys\nassert sys.argv[1:]==["update","plan","--json"]\nprint(pathlib.Path(__file__).with_name("plan.json").read_text())\n')
    backend.chmod(0o755)
    checker = folder/'spectrum-update-check'
    checker.write_text('#!/usr/bin/env python3\nimport json,sys,time\nsys.argv[1:] == ["--status"] and time.sleep(0.2)\nprint(json.dumps({"checked_at":20 if sys.argv[1:]==["--check"] else 10,"installed_packages":[{"name":"spectrum-desktop","installed":"1"}],"inventory_error":"","eligible":True,"error":"","packages":[{"name":"spectrum-desktop","installed":"1","available":"2"}] if sys.argv[1:]==["--check"] else []}))\n')
    checker.chmod(0o755)
    (folder/'Test.qml').write_text((root/'tests/qml/UpdatePanelTests.qml').read_text().replace('"../../configs/spectrum-shell"','"shell"'))
    runtime=folder/'runtime';runtime.mkdir(mode=0o700)
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime),SPECTRUM_UPDATE_TEST_BACKEND=str(folder),PATH=str(folder)+os.pathsep+os.environ['PATH'])
    result=subprocess.run(['qs','--path',str(folder/'Test.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=20)
    output=result.stdout+result.stderr
    print(output,end='')
    if result.returncode or not re.search(r'Update panel: \d+ passed 0 failed',output):raise SystemExit(1)
